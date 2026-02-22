# AGENTS.md Specification

## Required Deploy Format

The dev-prelude and drift gate parse these lines by exact prefix. Do not
deviate from the format.

```markdown
## Deploy

Default branch: `<branch>`
Deploy: `bin/kamal deploy -d <destination>`
Destinations: <comma-separated list>
```

Add a `Pre-deploy:` line if needed (e.g., Fizzy's `bin/rails saas:enable`).

## MUST Sections

These sections are required. The dev-prelude depends on them.

| Section | Content |
|---------|---------|
| **Deploy** | Default branch, deploy command, destinations, pre-deploy steps |
| **Commands** | `bin/setup`, test commands (single file + full suite), linting |

## SHOULD Sections

Include when the app deviates from standard Rails conventions.

| Section | When to Include |
|---------|----------------|
| **Architecture** | Non-standard patterns (multi-tenancy, sharding, etc.) |
| **Observability** | Grafana/Sentry/Loki identifiers, Chrome MCP dev URLs |
| **Code Style** | Style guide references, specific conventions |
| **Local Dev** | Non-standard setup, gotchas, required services |

## Anti-Patterns

- Restating Rails conventions ("routes are in config/routes.rb")
- Hardcoding `master` or `main` without checking the repo's actual default
- Documenting gem APIs (link to docs instead)
- Prose where a table suffices
- Duplicating shared observability docs from `shipyard/share/AGENTS.md`
