#!/usr/bin/env bash
#
# Git activity fetcher — local git log to day-cached JSON.
#
# Usage:
#   ./git-activity.sh --repos name:path[,name:path,...] --since DATE --until DATE [--reuse]
#
# Output:
#   ~/.cache/recap/git/{repo}/{YYYY-MM-DD}/log.json  per-day per-repo
#   Prints cache paths to stdout when done.
#
set -euo pipefail

REPOS=""
SINCE_DATE=""
UNTIL_DATE=""
REUSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --repos) REPOS="$2"; shift 2 ;;
    --since) SINCE_DATE="$2"; shift 2 ;;
    --until) UNTIL_DATE="$2"; shift 2 ;;
    --reuse) REUSE=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REPOS" ]]; then
  echo "Error: --repos name:path[,name:path,...] is required" >&2
  exit 1
fi

if [[ -z "$SINCE_DATE" ]]; then
  echo "Error: --since DATE is required" >&2
  exit 1
fi

[[ -z "$UNTIL_DATE" ]] && UNTIL_DATE=$(date -u +%Y-%m-%d)

# Normalize to YYYY-MM-DD
SINCE_DAY="${SINCE_DATE:0:10}"
UNTIL_DAY="${UNTIL_DATE:0:10}"

CACHE_BASE="$HOME/.cache/recap/git"

# Generate list of days in range
days_in_range() {
  local current="$1" end="$2"
  while [[ "$current" < "$end" || "$current" == "$end" ]]; do
    echo "$current"
    current=$(date -d "$current + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$current" +%Y-%m-%d)
  done
}

# Parse repos: "name:path,name:path" → iterate
IFS=',' read -ra REPO_PAIRS <<< "$REPOS"

for pair in "${REPO_PAIRS[@]}"; do
  REPO_NAME="${pair%%:*}"
  REPO_PATH="${pair#*:}"

  # Expand ~ in path
  REPO_PATH="${REPO_PATH/#\~/$HOME}"

  if [[ ! -d "$REPO_PATH/.git" && ! -f "$REPO_PATH/.git" ]]; then
    echo "WARN: $REPO_PATH is not a git repo, skipping $REPO_NAME" >&2
    continue
  fi

  echo "Fetching git log for $REPO_NAME ($REPO_PATH)..." >&2

  for day in $(days_in_range "$SINCE_DAY" "$UNTIL_DAY"); do
    NEXT_DAY=$(date -d "$day + 1 day" +%Y-%m-%d 2>/dev/null || date -j -v+1d -f "%Y-%m-%d" "$day" +%Y-%m-%d)
    CACHE_DIR="$CACHE_BASE/$REPO_NAME/$day"
    CACHE_FILE="$CACHE_DIR/log.json"

    # Skip if reuse and cache exists with complete flag
    if [[ "$REUSE" == "true" && -f "$CACHE_FILE" ]]; then
      if jq -e '.metadata.complete == true' "$CACHE_FILE" >/dev/null 2>&1; then
        echo "  $day: reusing cache" >&2
        continue
      fi
    fi

    mkdir -p "$CACHE_DIR"

    # Fetch git log for this day
    COMMITS=$(git -C "$REPO_PATH" log \
      --format='%H%x00%h%x00%s%x00%an%x00%aI%x00%b%x1e' \
      --since="$day" --until="$NEXT_DAY" \
      --no-merges 2>/dev/null || echo "")

    if [[ -z "$COMMITS" ]]; then
      # No commits — write empty but complete
      jq -n --arg repo "$REPO_NAME" --arg day "$day" '{
        repo: $repo,
        date: $day,
        commits: [],
        metadata: { complete: true, count: 0 }
      }' > "$CACHE_FILE"
      continue
    fi

    # Parse commits into JSON
    echo "$COMMITS" | awk -v RS=$'\x1e' -v FS=$'\x00' '
      NF >= 5 {
        gsub(/\n/, "\\n", $6)
        gsub(/"/, "\\\"", $3)
        gsub(/"/, "\\\"", $4)
        gsub(/"/, "\\\"", $6)
        gsub(/\t/, "\\t", $6)
        # Trim leading/trailing whitespace from body
        sub(/^[[:space:]]+/, "", $6)
        sub(/[[:space:]]+$/, "", $6)
        printf "{\"hash\":\"%s\",\"short_hash\":\"%s\",\"subject\":\"%s\",\"author\":\"%s\",\"date\":\"%s\",\"body\":\"%s\"}\n", $1, $2, $3, $4, $5, $6
      }
    ' | jq -s --arg repo "$REPO_NAME" --arg day "$day" '{
      repo: $repo,
      date: $day,
      commits: .,
      metadata: { complete: true, count: (. | length) }
    }' > "$CACHE_FILE" 2>/dev/null || {
      # Fallback: simpler format if awk/jq pipeline fails
      git -C "$REPO_PATH" log \
        --format='{"short_hash":"%h","subject":"%s","author":"%an","date":"%aI"}' \
        --since="$day" --until="$NEXT_DAY" \
        --no-merges 2>/dev/null | \
        jq -s --arg repo "$REPO_NAME" --arg day "$day" '{
          repo: $repo,
          date: $day,
          commits: .,
          metadata: { complete: true, count: (. | length) }
        }' > "$CACHE_FILE"
    }

    COUNT=$(jq '.metadata.count' "$CACHE_FILE")
    echo "  $day: $COUNT commits" >&2
  done

  echo "$CACHE_BASE/$REPO_NAME" >&2
done

# Print summary to stdout as JSON
echo '{"status":"complete","cache_base":"'"$CACHE_BASE"'"}'
