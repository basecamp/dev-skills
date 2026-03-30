#!/usr/bin/env bash
#
# Basecamp activity fetcher — project or person scoped, day-cached.
#
# Uses the `basecamp` CLI (timeline command) for authentication and fetching.
# Caches activity per day at ~/.cache/recap/basecamp-project/{id}/{YYYY-MM-DD}/activity.json
# or ~/.cache/recap/basecamp-person/{slug}/{YYYY-MM-DD}/activity.json.
#
# Usage:
#   ./basecamp-activity.sh --project PROJECT_ID --since DATE --until DATE [--reuse]
#   ./basecamp-activity.sh --person SLUG --since DATE --until DATE [--reuse]
#
set -euo pipefail

# Activate mise for basecamp CLI
eval "$(mise hook-env 2>/dev/null)" || true

PROJECT_ID=""
PERSON=""
SINCE_DATE=""
UNTIL_DATE=""
REUSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT_ID="$2"; shift 2 ;;
    --person) PERSON="$2"; shift 2 ;;
    --since) SINCE_DATE="$2"; shift 2 ;;
    --until) UNTIL_DATE="$2"; shift 2 ;;
    --reuse) REUSE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$SINCE_DATE" ]]; then
  echo "Error: --since DATE is required" >&2
  exit 1
fi

if [[ -z "$PROJECT_ID" && -z "$PERSON" ]]; then
  echo "Error: --project PROJECT_ID or --person SLUG is required" >&2
  exit 1
fi

[[ -z "$UNTIL_DATE" ]] && UNTIL_DATE=$(date -u +%Y-%m-%d)

SINCE_DAY="${SINCE_DATE:0:10}"
UNTIL_DAY="${UNTIL_DATE:0:10}"

# Validate auth
if ! basecamp auth status --quiet >/dev/null 2>&1; then
  echo "Error: basecamp not authenticated. Run: basecamp auth login" >&2
  exit 1
fi

# Determine cache path and scope
if [[ -n "$PROJECT_ID" ]]; then
  CACHE_BASE="$HOME/.cache/recap/basecamp-project/$PROJECT_ID"
  SCOPE="project $PROJECT_ID"
else
  CACHE_BASE="$HOME/.cache/recap/basecamp-person/$PERSON"
  SCOPE="person $PERSON"
fi

echo "Fetching Basecamp activity for $SCOPE ($SINCE_DAY to $UNTIL_DAY)..." >&2

# Generate list of days in range
days_in_range() {
  local current="$1" end="$2"
  while [[ "$current" < "$end" || "$current" == "$end" ]]; do
    echo "$current"
    current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
  done
}

# Fetch all activity events using the basecamp timeline CLI, then split by day.
ALL_EVENTS_FILE=$(mktemp)

FETCH_FAILED=false
if [[ -n "$PROJECT_ID" ]]; then
  echo "  Fetching project timeline..." >&2
  basecamp timeline --in "$PROJECT_ID" --json --quiet --all 2>/dev/null > "$ALL_EVENTS_FILE" || {
    echo "  ERROR: timeline fetch failed for project $PROJECT_ID" >&2
    FETCH_FAILED=true
  }
else
  echo "  Fetching person timeline ($PERSON)..." >&2
  basecamp timeline --person "$PERSON" --json --quiet --all 2>/dev/null > "$ALL_EVENTS_FILE" || {
    echo "  ERROR: timeline fetch failed for person $PERSON" >&2
    FETCH_FAILED=true
  }
fi

if [[ "$FETCH_FAILED" == "true" ]]; then
  rm -f "$ALL_EVENTS_FILE"
  echo '{"status":"error","message":"timeline fetch failed"}' >&2
  exit 1
fi

# Filter to window
SINCE_ISO="${SINCE_DAY}T00:00:00Z"
UNTIL_ISO="${UNTIL_DAY}T23:59:59Z"
jq --arg since "$SINCE_ISO" --arg until "$UNTIL_ISO" '
  [.[] | select(.created_at >= $since and .created_at <= $until)] |
  sort_by(.created_at) | reverse
' "$ALL_EVENTS_FILE" > "${ALL_EVENTS_FILE}.filtered"

TOTAL=$(jq 'length' "${ALL_EVENTS_FILE}.filtered")
echo "  $TOTAL events in window" >&2

# Split into per-day cache atoms
for day in $(days_in_range "$SINCE_DAY" "$UNTIL_DAY"); do
  CACHE_DIR="$CACHE_BASE/$day"
  CACHE_FILE="$CACHE_DIR/activity.json"

  if [[ "$REUSE" == "true" && -f "$CACHE_FILE" ]]; then
    if jq -e '.metadata.complete == true' "$CACHE_FILE" >/dev/null 2>&1; then
      echo "  $day: reusing cache" >&2
      continue
    fi
  fi

  mkdir -p "$CACHE_DIR"

  NEXT_DAY=$(date -d "$day + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$day" +%Y-%m-%d)
  DAY_START="${day}T00:00:00Z"
  DAY_END="${NEXT_DAY}T00:00:00Z"

  jq --arg start "$DAY_START" --arg end "$DAY_END" --arg scope "$SCOPE" --arg day "$day" '
    [.[] | select(.created_at >= $start and .created_at < $end)] |
    {
      scope: $scope,
      date: $day,
      events: .,
      metadata: { complete: true, count: (. | length) }
    }
  ' "${ALL_EVENTS_FILE}.filtered" > "$CACHE_FILE"

  COUNT=$(jq '.metadata.count' "$CACHE_FILE")
  [[ "$COUNT" -gt 0 ]] && echo "  $day: $COUNT events" >&2
done

rm -f "$ALL_EVENTS_FILE" "${ALL_EVENTS_FILE}.filtered"

echo '{"status":"complete","cache_base":"'"$CACHE_BASE"'","total_events":'"$TOTAL"'}'
