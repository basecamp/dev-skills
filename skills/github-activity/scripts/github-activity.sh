#!/usr/bin/env bash
#
# GitHub activity fetcher — PRs, reviews, commits, day-cached.
#
# Uses the `gh` CLI REST search API (not gh search, which silently drops
# private org repos). Handles >1000 results by splitting by state.
# Caches per day at ~/.cache/recap/github/{user}/{YYYY-MM-DD}/activity.json
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

ALL_DIR=$(mktemp -d)

# ─────────────────────────────────────────────────
# Helper: paginated search with >1000-result overflow handling
# ─────────────────────────────────────────────────
# Uses REST search API via `gh api search/issues` with -f q= for proper
# URL encoding. Splits by state (merged/closed/open) when a single query
# hits GitHub's 1000-result hard cap.
#
# Usage: gh_search_all prs|issues QUERY_QUALIFIERS...
# Writes JSON array to stdout.
#
gh_search_all() {
  local search_type="$1"; shift
  local tmpdir
  tmpdir=$(mktemp -d)

  local type_q="is:pr"
  [[ "$search_type" == "issues" ]] && type_q="is:issue"

  local query="$type_q created:$SEARCH_RANGE"
  while [[ $# -gt 0 ]]; do
    query="$query $1"
    shift
  done

  # Paginated fetch via REST search API
  gh api "search/issues" --method GET -f q="$query" -f per_page=100 \
    --paginate --jq '.items' > "$tmpdir/raw.jsonl" 2>"$tmpdir/stderr.txt" \
    || true
  jq -s 'add // []' "$tmpdir/raw.jsonl" > "$tmpdir/all.json"

  local count
  count=$(jq 'length' "$tmpdir/all.json")

  if [[ "$count" -ge 1000 ]]; then
    echo "  (Hit 1000-result cap, splitting by state...)" >&2
    local states
    if [[ "$search_type" == "prs" ]]; then
      states="merged closed open"
    else
      states="closed open"
    fi

    for state in $states; do
      gh api "search/issues" --method GET \
        -f q="${query} is:${state}" -f per_page=100 \
        --paginate --jq '.items' > "$tmpdir/state_${state}.raw" 2>/dev/null \
        || true
      jq -s 'add // []' "$tmpdir/state_${state}.raw" > "$tmpdir/state_${state}.json"
      rm -f "$tmpdir/state_${state}.raw"
      local sc
      sc=$(jq 'length' "$tmpdir/state_${state}.json")
      echo "    state=$state: $sc" >&2
      [[ "$sc" -ge 1000 ]] && echo "    WARNING: state=$state hit 1000 cap — narrow date range" >&2
    done

    jq -s 'add | unique_by(.html_url)' "$tmpdir"/state_*.json > "$tmpdir/all.json"
    count=$(jq 'length' "$tmpdir/all.json")
  fi

  cat "$tmpdir/all.json"
  rm -rf "$tmpdir"
  echo "    $count" >&2
}

# Build qualifier list
QUALIFIERS=("author:$USERNAME")
[[ -n "$ORG" ]] && QUALIFIERS+=("org:$ORG")

# ── PRs authored ──
echo "  PRs authored..." >&2
gh_search_all prs "${QUALIFIERS[@]}" > "$ALL_DIR/prs-authored.json"
PRS_COUNT=$(jq 'length' "$ALL_DIR/prs-authored.json")

# ── PRs reviewed ──
echo "  PRs reviewed..." >&2
REVIEW_QUALS=("reviewed-by:$USERNAME")
[[ -n "$ORG" ]] && REVIEW_QUALS+=("org:$ORG")
gh_search_all prs "${REVIEW_QUALS[@]}" > "$ALL_DIR/prs-reviewed.json"
REVIEWED_COUNT=$(jq 'length' "$ALL_DIR/prs-reviewed.json")

# ── Issues ──
echo "  Issues..." >&2
gh_search_all issues "${QUALIFIERS[@]}" > "$ALL_DIR/issues.json"
ISSUES_COUNT=$(jq 'length' "$ALL_DIR/issues.json")

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

# ── Split into per-day cache atoms ──

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
