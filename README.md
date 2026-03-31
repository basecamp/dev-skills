```bash
npx skills add basecamp/house-skills
```

## Skills

| Skill | Plugin | Description |
|-------|--------|-------------|
| [address-pr-reviews](skills/address-pr-reviews) | dev | Address PR review comments - fix issues, reply to threads, mark resolved |
| [basecamp-activity](skills/basecamp-activity/) | Fetch Basecamp project or person activity into day-cached JSON atoms |
| [consult-outside-expert](skills/consult-outside-expert) | dev | Consult an outside expert to collaboratively refine and stress-test ideas |
| [git-activity](skills/git-activity/) | Fetch git log from local repos into day-cached JSON atoms |
| [github-activity](skills/github-activity/) | Fetch GitHub PRs, reviews, issues, and commits into day-cached JSON atoms |
| [ralph-lisa-loop](skills/ralph-lisa-loop) | dev | Automated plan-implement loop with expert review and rope-length autonomy control |
| [harden-github-actions](skills/harden-github-actions) | security | Resolve zizmor warnings in GitHub Actions workflows, harden CI pipelines, and pin actions to SHA hashes |
| [install-md](skills/install-md) | ai | Create install.md files optimized for AI agent execution |
| [recap](skills/recap/) | Activity digests — pluggable fetchers, timescale synthesis, audience-aware composition |
| [skill-crafting](skills/skill-crafting) | ai | Create and refine agent skills through co-development and eval loops |

## Structure

Real skill files live in `plugins/{plugin}/skills/`. The top-level `skills/` directory
contains symlinks for a unified view. See [AGENTS.md](AGENTS.md) for details.

[MIT License](MIT-LICENSE)
