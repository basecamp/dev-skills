#!/usr/bin/env bash
#
# Basecamp activity fetcher — project or person scoped, day-cached.
#
# Uses the Basecamp API via the `basecamp` CLI for authentication.
# Caches activity per day at ~/.cache/recap/basecamp-project/{id}/{YYYY-MM-DD}/activity.json
# or ~/.cache/recap/basecamp-person/{slug}/{YYYY-MM-DD}/activity.json.
#
# Usage:
#   ./basecamp-activity.sh --project PROJECT_ID --since DATE --until DATE [--reuse]
#   ./basecamp-activity.sh --person SLUG --user USER_ID --since DATE --until DATE [--reuse]
#
set -euo pipefail

# Activate mise for basecamp CLI
eval "$(mise hook-env 2>/dev/null)" || true

PROJECT_ID=""
PERSON=""
USER_ID=""
SINCE_DATE=""
UNTIL_DATE=""
REUSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --project) PROJECT_ID="$2"; shift 2 ;;
    --person) PERSON="$2"; shift 2 ;;
    --user) USER_ID="$2"; shift 2 ;;
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

# Auth
TOKEN=$(basecamp auth token 2>/dev/null)
ACCOUNT_ID=$(basecamp config show --json --quiet | jq -r '.data.account_id.value // .account_id.value // empty')

if [[ -z "$TOKEN" || -z "$ACCOUNT_ID" ]]; then
  echo "Error: basecamp not authenticated or account not configured" >&2
  exit 1
fi

# Determine cache path and API endpoint
if [[ -n "$PROJECT_ID" ]]; then
  CACHE_BASE="$HOME/.cache/recap/basecamp-project/$PROJECT_ID"
  SCOPE="project $PROJECT_ID"
else
  CACHE_BASE="$HOME/.cache/recap/basecamp-person/$PERSON"
  SCOPE="person $PERSON"
  if [[ -z "$USER_ID" ]]; then
    USER_ID=$(basecamp auth status --json --quiet | jq -r '.user_id')
  fi
fi

echo "Fetching Basecamp activity for $SCOPE ($SINCE_DAY to $UNTIL_DAY)..." >&2

# curl with HTTP status check + 429 backoff
bc_curl() {
  local url="$1"
  local tmp_body http_code
  tmp_body=$(mktemp)
  local max_retries=3 attempt=0 delay=5

  while (( attempt <= max_retries )); do
    http_code=$(curl -sS -w "%{http_code}" -o "$tmp_body" \
      -H "Authorization: Bearer $TOKEN" \
      -H "User-Agent: recap-basecamp-activity/1.0" \
      "$url" 2>/dev/null) || http_code="000"

    if [[ "$http_code" =~ ^2 ]]; then
      cat "$tmp_body"
      rm -f "$tmp_body"
      return 0
    elif [[ "$http_code" == "429" ]]; then
      attempt=$((attempt + 1))
      if (( attempt > max_retries )); then break; fi
      echo "  Rate limited, retry $attempt/$max_retries in ${delay}s..." >&2
      sleep "$delay"
      delay=$((delay * 2))
    else
      echo "  HTTP $http_code from $url" >&2
      rm -f "$tmp_body"
      return 1
    fi
  done

  rm -f "$tmp_body"
  return 1
}

# Generate list of days in range
days_in_range() {
  local current="$1" end="$2"
  while [[ "$current" < "$end" || "$current" == "$end" ]]; do
    echo "$current"
    current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
  done
}

# Fetch all activity events for the full range, then split by day.
# The Basecamp API paginates backward from most recent, so we fetch the full
# window and cache per-day atoms afterward.

ALL_EVENTS_FILE=$(mktemp)
echo "[]" > "$ALL_EVENTS_FILE"

if [[ -n "$PROJECT_ID" ]]; then
  # Project activity: paginate through project events
  echo "  Fetching project activity..." >&2
  SINCE_ISO="${SINCE_DAY}T00:00:00Z"

  for page in $(seq 1 200); do
    BODY=$(bc_curl "https://3.basecampapi.com/$ACCOUNT_ID/buckets/$PROJECT_ID/events.json?page=$page") || {
      echo "  WARN: API error on page $page" >&2
      break
    }

    if ! echo "$BODY" | jq empty 2>/dev/null; then
      echo "  WARN: invalid JSON on page $page" >&2
      break
    fi

    COUNT=$(echo "$BODY" | jq 'length')
    [[ "$COUNT" -eq 0 ]] && break

    # Append to all events
    jq -s 'add' "$ALL_EVENTS_FILE" <(echo "$BODY") > "${ALL_EVENTS_FILE}.tmp"
    mv "${ALL_EVENTS_FILE}.tmp" "$ALL_EVENTS_FILE"

    echo "  Page $page: $COUNT events" >&2

    # Stop when oldest event is before our window
    OLDEST=$(echo "$BODY" | jq -r '.[-1].created_at // empty')
    if [[ -z "$OLDEST" || "$OLDEST" < "$SINCE_ISO" ]]; then
      break
    fi

    sleep 0.1
  done
else
  # Person activity: use progress report API
  echo "  Fetching person activity..." >&2
  SINCE_ISO="${SINCE_DAY}T00:00:00Z"

  for page in $(seq 1 200); do
    BODY=$(bc_curl "https://3.basecampapi.com/$ACCOUNT_ID/reports/users/progress/$USER_ID.json?page=$page") || {
      echo "  WARN: API error on page $page" >&2
      break
    }

    if ! echo "$BODY" | jq empty 2>/dev/null; then
      echo "  WARN: invalid JSON on page $page" >&2
      break
    fi

    EVENTS=$(echo "$BODY" | jq '.events // []')
    COUNT=$(echo "$EVENTS" | jq 'length')
    [[ "$COUNT" -eq 0 ]] && break

    jq -s 'add' "$ALL_EVENTS_FILE" <(echo "$EVENTS") > "${ALL_EVENTS_FILE}.tmp"
    mv "${ALL_EVENTS_FILE}.tmp" "$ALL_EVENTS_FILE"

    echo "  Page $page: $COUNT events" >&2

    OLDEST=$(echo "$EVENTS" | jq -r '.[-1].created_at // empty')
    if [[ -z "$OLDEST" || "$OLDEST" < "$SINCE_ISO" ]]; then
      break
    fi

    sleep 0.1
  done
fi

# Filter to window
UNTIL_ISO="${UNTIL_DAY}T23:59:59Z"
jq --arg since "${SINCE_DAY}T00:00:00Z" --arg until "$UNTIL_ISO" '
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

rm -f "$ALL_EVENTS_FILE" "${ALL_EVENTS_FILE}.filtered" "${ALL_EVENTS_FILE}.tmp"

echo '{"status":"complete","cache_base":"'"$CACHE_BASE"'","total_events":'"$TOTAL"'}'
