---
name: basecamp-activity
description: |
  Fetch Basecamp project or person activity into day-cached JSON atoms.
  Uses the Basecamp API with pagination and rate-limit backoff.
  Part of the recap plugin's activity fetcher pipeline.
triggers:
  - /recap:basecamp-activity
  - basecamp activity
  - basecamp project activity
---

# Basecamp Activity Fetcher

Fetch Basecamp activity events into per-day cached JSON atoms. Supports two
scopes:

- **Project-scoped** (`--project`): all events in a Basecamp project
- **Person-scoped** (`--person`): all activity by a specific user

Caches at `~/.cache/recap/basecamp-project/{id}/{YYYY-MM-DD}/activity.json` or
`~/.cache/recap/basecamp-person/{slug}/{YYYY-MM-DD}/activity.json`.

## Invocation

```
/recap:basecamp-activity --project 43483623 --since 2026-03-23
/recap:basecamp-activity --project 43483623 --since 2026-03-23 --until 2026-03-30 --reuse
/recap:basecamp-activity --person "Jeremy Daer" --since 2026-03-23
```

## Contract

- **Idempotent:** same input produces same output, safe to re-run
- **Day-cached:** one JSON file per scope per day
- **`--reuse`:** skip fetch if cache exists and is marked complete
- **Rate-limit aware:** exponential backoff on 429 responses

## Quick Run

```bash
# 1. Validate auth
basecamp auth status | jq -e '.data.authenticated' || { echo "Run: basecamp auth login"; exit 1; }

# 2. Determine date range
SINCE=$(date -d "7 days ago" +%Y-%m-%d)
UNTIL=$(date +%Y-%m-%d)

# 3. Run the fetcher (project-scoped)
"$SKILL_DIR/scripts/basecamp-activity.sh" \
  --project 43483623 --since "$SINCE" --until "$UNTIL"

# 4. Verify cache
ls ~/.cache/recap/basecamp-project/43483623/
cat ~/.cache/recap/basecamp-project/43483623/$SINCE/activity.json | jq '.metadata'
```

Where `$SKILL_DIR` = directory containing this SKILL.md.

## Output Format

Each `activity.json` contains:

```json
{
  "scope": "project 43483623",
  "date": "2026-03-24",
  "events": [
    {
      "id": 123456,
      "kind": "message_created",
      "created_at": "2026-03-24T14:30:00Z",
      "creator": { "id": 789, "name": "Jeremy" },
      "title": "Weekly update",
      "url": "https://3.basecampapi.com/..."
    }
  ],
  "metadata": { "complete": true, "count": 5 }
}
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--project` | One of project/person | Basecamp project ID |
| `--person` | One of project/person | Person name or ID (passed to `basecamp timeline --person`) |
| `--since` | Yes | Start date (YYYY-MM-DD) |
| `--until` | No | End date (default: today) |
| `--reuse` | No | Skip fetch if cache exists and is complete |

## Cache Structure

```
~/.cache/recap/basecamp-project/
  43483623/
    2026-03-24/activity.json
    2026-03-25/activity.json
```

## Prerequisites

- `basecamp` CLI installed and authenticated (`basecamp auth login`)
- `jq` for JSON parsing
- `curl` for API calls

## Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| "basecamp not authenticated" | Token expired | `basecamp auth login` |
| "account not configured" | Missing config | `basecamp config setup` |
| Rate limit | Too many API calls | Script retries automatically with backoff |
| Empty activity | No events in range | Expected — empty days are cached as complete |
| HTTP 404 | Wrong project ID | Verify project ID in Basecamp URL |
