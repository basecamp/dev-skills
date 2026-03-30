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
# Usage: gh_search_all "full search query including type and date qualifiers"
# Writes JSON array to stdout.
#
gh_search_all() {
  local tmpdir
  tmpdir=$(mktemp -d)
  local query="$1"

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
    if [[ "$query" == *"is:pr"* ]]; then
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

# ── PRs authored ──
echo "  PRs authored..." >&2
QUERY="is:pr created:$SEARCH_RANGE author:$USERNAME"
[[ -n "$ORG" ]] && QUERY="$QUERY org:$ORG"
gh_search_all "$QUERY" > "$ALL_DIR/prs-authored.json"
PRS_COUNT=$(jq 'length' "$ALL_DIR/prs-authored.json")

# ── PRs reviewed — use updated: to capture reviews on older PRs ──
echo "  PRs reviewed..." >&2
QUERY="is:pr updated:$SEARCH_RANGE reviewed-by:$USERNAME"
[[ -n "$ORG" ]] && QUERY="$QUERY org:$ORG"
gh_search_all "$QUERY" > "$ALL_DIR/prs-reviewed.json"
REVIEWED_COUNT=$(jq 'length' "$ALL_DIR/prs-reviewed.json")

# ── Issues ──
echo "  Issues..." >&2
QUERY="is:issue created:$SEARCH_RANGE author:$USERNAME"
[[ -n "$ORG" ]] && QUERY="$QUERY org:$ORG"
gh_search_all "$QUERY" > "$ALL_DIR/issues.json"
ISSUES_COUNT=$(jq 'length' "$ALL_DIR/issues.json")

# ── Commits (via GraphQL contributions) ──
echo "  Commits..." >&2
SINCE_ISO="${SINCE_DAY}T00:00:00Z"
UNTIL_ISO="${UNTIL_DAY}T23:59:59Z"

gh api graphql -f query='
  query($login: String!, $from: DateTime!, $to: DateTime!) {
    user(login: $login) {
      contributionsCollection(from: $from, to: $to) {
        totalCommitContributions
        commitContributionsByRepository(maxRepositories: 100) {
          repository { nameWithOwner }
          contributions(first: 1) { totalCount }
        }
      }
    }
  }
' -f login="$USERNAME" -f from="$SINCE_ISO" -f to="$UNTIL_ISO" 2>/dev/null | \
  jq '.data.user.contributionsCollection' > "$ALL_DIR/commits.json"
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
  jq -n \
    --arg day "$day" \
    --arg next "$NEXT_DAY" \
    --arg user "$USERNAME" \
    --slurpfile authored "$ALL_DIR/prs-authored.json" \
    --slurpfile reviewed "$ALL_DIR/prs-reviewed.json" \
    --slurpfile issues "$ALL_DIR/issues.json" '
    def day_filter: [.[] | select(.created_at >= ($day + "T00:00:00Z") and .created_at < ($next + "T00:00:00Z"))];
    {
      user: $user,
      date: $day,
      prs_authored: ($authored[0] | day_filter),
      prs_reviewed: ($reviewed[0] | [.[] | select((.updated_at // .created_at) >= ($day + "T00:00:00Z") and (.updated_at // .created_at) < ($next + "T00:00:00Z"))]),
      issues: ($issues[0] | day_filter),
      metadata: { complete: true }
    }
  ' > "$CACHE_FILE"

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
