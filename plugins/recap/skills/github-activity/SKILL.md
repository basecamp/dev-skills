---
name: github-activity
description: |
  Fetch GitHub PRs, reviews, issues, and commits into day-cached JSON atoms.
  Uses the gh CLI for authentication and API calls.
  Part of the recap plugin's activity fetcher pipeline.
triggers:
  - /recap:github-activity
  - github activity
  - github PRs
---

# GitHub Activity Fetcher

Fetch GitHub activity — PRs authored, PRs reviewed, issues created, commit
contributions — into per-day cached JSON atoms at
`~/.cache/recap/github/{user}/{YYYY-MM-DD}/activity.json`.

## Invocation

```
/recap:github-activity --since 2026-03-23
/recap:github-activity --since 2026-03-23 --until 2026-03-30
/recap:github-activity --user jeremy --org basecamp --since 2026-03-23 --reuse
```

## Contract

- **Idempotent:** same input produces same output, safe to re-run
- **Day-cached:** one JSON file per user per day
- **`--reuse`:** skip fetch if cache exists and is marked complete
- **Rate-limit aware:** uses `gh api --paginate` with built-in backoff

## Quick Run

```bash
# 1. Validate auth
gh auth status || { echo "Run: gh auth login"; exit 1; }

# 2. Determine date range
SINCE=$(date -d "7 days ago" +%Y-%m-%d)
UNTIL=$(date +%Y-%m-%d)

# 3. Run the fetcher
"$SKILL_DIR/scripts/github-activity.sh" --since "$SINCE" --until "$UNTIL"

# 4. Verify cache
USER=$(gh api user --jq '.login')
ls ~/.cache/recap/github/$USER/
cat ~/.cache/recap/github/$USER/$SINCE/activity.json | jq '.metadata'
```

Where `$SKILL_DIR` = directory containing this SKILL.md.

## Output Format

Each `activity.json` contains:

```json
{
  "user": "jeremy",
  "date": "2026-03-24",
  "prs_authored": [
    {
      "title": "Add weekly digest skill",
      "html_url": "https://github.com/basecamp/coworker/pull/99",
      "created_at": "2026-03-24T14:30:00Z",
      "repository_url": "https://api.github.com/repos/basecamp/coworker",
      "state": "closed",
      "pull_request": { "merged_at": "2026-03-24T15:00:00Z" }
    }
  ],
  "prs_reviewed": [],
  "issues": [],
  "metadata": {
    "complete": true,
    "counts": { "prs_authored": 1, "prs_reviewed": 0, "issues": 0 }
  }
}
```

Commit contributions are cached separately as an aggregate at
`~/.cache/recap/github/{user}/commits-{since}-{until}.json` since GitHub's
GraphQL API returns them as a period summary, not per-day.

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--since` | Yes | Start date (YYYY-MM-DD) |
| `--until` | No | End date (default: today) |
| `--user` | No | GitHub username (default: authenticated user) |
| `--org` | No | Filter to a specific GitHub org |
| `--reuse` | No | Skip fetch if cache exists and is complete |

## Cache Structure

```
~/.cache/recap/github/
  jeremy/
    2026-03-24/activity.json
    2026-03-25/activity.json
    commits-2026-03-23-2026-03-30.json
```

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth login`)
- `jq` for JSON parsing

## Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| "gh: not logged in" | Token expired | `gh auth login` |
| Empty results | No activity in range | Expected — empty days cached as complete |
| Rate limit (403) | Too many API calls | Wait ~1hr and retry |
| >1000 PRs | Search API limit | Narrow date range or add `--org` filter |
