#!/usr/bin/env bash
#
# GitHub activity fetcher — PRs, reviews, commits, day-cached.
#
# Uses the `gh` CLI for authentication and API calls.
# Caches per day at ~/.cache/recap/github/{user}/{YYYY-MM-DD}/prs.json
#
# Usage:
#   ./github-activity.sh --since DATE --until DATE [--user USERNAME] [--org ORG] [--reuse]
#
set -euo pipefail

SINCE_DATE=""
UNTIL_DATE=""
USERNAME=""
ORG=""
REUSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --since) SINCE_DATE="$2"; shift 2 ;;
    --until) UNTIL_DATE="$2"; shift 2 ;;
    --user) USERNAME="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --reuse) REUSE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SINCE_DATE" ]]; then
  echo "Error: --since DATE is required" >&2
  exit 1
fi

[[ -z "$UNTIL_DATE" ]] && UNTIL_DATE=$(date -u +%Y-%m-%d)
[[ -z "$USERNAME" ]] && USERNAME=$(gh api user --jq '.login')

SINCE_DAY="${SINCE_DATE:0:10}"
UNTIL_DAY="${UNTIL_DATE:0:10}"
SEARCH_RANGE="${SINCE_DAY}..${UNTIL_DAY}"

CACHE_BASE="$HOME/.cache/recap/github/$USERNAME"

echo "Fetching GitHub activity for $USERNAME ($SINCE_DAY to $UNTIL_DAY)..." >&2

# We fetch the full range then split by day, since GitHub search is date-ranged
# and splitting per-day would multiply API calls unnecessarily.

ALL_DIR=$(mktemp -d)

# ── PRs authored ──
echo "  PRs authored..." >&2
ORG_FILTER=""
[[ -n "$ORG" ]] && ORG_FILTER=" org:$ORG"
gh api --paginate "search/issues?q=type:pr+author:${USERNAME}+created:${SEARCH_RANGE}${ORG_FILTER}&per_page=100&sort=created&order=desc" \
  --jq '.items' 2>/dev/null | jq -s 'add // []' > "$ALL_DIR/prs-authored.json"
PRS_COUNT=$(jq 'length' "$ALL_DIR/prs-authored.json")
echo "    $PRS_COUNT PRs" >&2

# ── PRs reviewed ──
echo "  PRs reviewed..." >&2
gh api --paginate "search/issues?q=type:pr+reviewed-by:${USERNAME}+created:${SEARCH_RANGE}${ORG_FILTER}&per_page=100&sort=created&order=desc" \
  --jq '.items' 2>/dev/null | jq -s 'add // []' > "$ALL_DIR/prs-reviewed.json"
REVIEWED_COUNT=$(jq 'length' "$ALL_DIR/prs-reviewed.json")
echo "    $REVIEWED_COUNT PRs" >&2

# ── Issues ──
echo "  Issues..." >&2
gh api --paginate "search/issues?q=type:issue+author:${USERNAME}+created:${SEARCH_RANGE}${ORG_FILTER}&per_page=100&sort=created&order=desc" \
  --jq '.items' 2>/dev/null | jq -s 'add // []' > "$ALL_DIR/issues.json"
ISSUES_COUNT=$(jq 'length' "$ALL_DIR/issues.json")
echo "    $ISSUES_COUNT issues" >&2

# ── Commits (via GraphQL contributions) ──
echo "  Commits..." >&2
SINCE_ISO="${SINCE_DAY}T00:00:00Z"
UNTIL_ISO="${UNTIL_DAY}T23:59:59Z"

gh api graphql -f query='
  query($from: DateTime!, $to: DateTime!) {
    viewer {
      contributionsCollection(from: $from, to: $to) {
        totalCommitContributions
        commitContributionsByRepository(maxRepositories: 100) {
          repository { nameWithOwner }
          contributions(first: 1) { totalCount }
        }
      }
    }
  }
' -f from="$SINCE_ISO" -f to="$UNTIL_ISO" 2>/dev/null | \
  jq '.data.viewer.contributionsCollection' > "$ALL_DIR/commits.json"
COMMIT_COUNT=$(jq '.totalCommitContributions // 0' "$ALL_DIR/commits.json")
echo "    $COMMIT_COUNT commits" >&2

# ── Split PRs authored into per-day cache atoms ──

# Generate list of days
days_in_range() {
  local current="$1" end="$2"
  while [[ "$current" < "$end" || "$current" == "$end" ]]; do
    echo "$current"
    current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
  done
}

for day in $(days_in_range "$SINCE_DAY" "$UNTIL_DAY"); do
  CACHE_DIR="$CACHE_BASE/$day"
  CACHE_FILE="$CACHE_DIR/activity.json"

  if [[ "$REUSE" == "true" && -f "$CACHE_FILE" ]]; then
    if jq -e '.metadata.complete == true' "$CACHE_FILE" >/dev/null 2>&1; then
      continue
    fi
  fi

  mkdir -p "$CACHE_DIR"

  NEXT_DAY=$(date -d "$day + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$day" +%Y-%m-%d)

  # Filter each category to this day
  jq --arg day "$day" --arg next "$NEXT_DAY" --arg user "$USERNAME" '
    def day_filter: [.[] | select(.created_at >= ($day + "T00:00:00Z") and .created_at < ($next + "T00:00:00Z"))];
    {
      user: $user,
      date: $day,
      prs_authored: (input | day_filter),
      prs_reviewed: (input | day_filter),
      issues: (input | day_filter),
      metadata: { complete: true }
    }
  ' "$ALL_DIR/prs-authored.json" "$ALL_DIR/prs-reviewed.json" "$ALL_DIR/issues.json" > "$CACHE_FILE" 2>/dev/null || {
    # Simpler fallback: just PRs authored for this day
    jq --arg day "$day" --arg next "$NEXT_DAY" --arg user "$USERNAME" '[
      .[] | select(.created_at >= ($day + "T00:00:00Z") and .created_at < ($next + "T00:00:00Z"))
    ] | {
      user: $user,
      date: $day,
      prs_authored: .,
      metadata: { complete: true }
    }' "$ALL_DIR/prs-authored.json" > "$CACHE_FILE"
  }

  # Add counts
  jq '.metadata.counts = {
    prs_authored: (.prs_authored | length),
    prs_reviewed: (.prs_reviewed // [] | length),
    issues: (.issues // [] | length)
  }' "$CACHE_FILE" > "${CACHE_FILE}.tmp" && mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
done

# Also cache the commits summary (not day-split — GitHub returns aggregate)
COMMITS_CACHE="$CACHE_BASE/commits-${SINCE_DAY}-${UNTIL_DAY}.json"
cp "$ALL_DIR/commits.json" "$COMMITS_CACHE"

rm -rf "$ALL_DIR"

echo '{"status":"complete","cache_base":"'"$CACHE_BASE"'","prs_authored":'"$PRS_COUNT"',"prs_reviewed":'"$REVIEWED_COUNT"',"issues":'"$ISSUES_COUNT"',"commits":'"$COMMIT_COUNT"'}'
