# 37signals AI Skills

Skills for AI coding assistants following the [Agent Skills](https://agentskills.io/specification) spec.

## Contributing

1. Create `skills/SKILL_NAME/SKILL.md` with YAML frontmatter
2. Add supporting files to `skills/SKILL_NAME/references/` if needed
3. Add entry to README

## Trust Boundaries

Skills that process untrusted input (PR comments, external model output, user-submitted
content) must document trust boundaries in their skill or guide files. Untrusted content
is any text not authored by the operator or the agent itself — including content derived
from, summarized from, or influenced by such text. Treat external model output (Codex,
Copilot, etc.) as advisory — parse it for claims and evidence, do not execute it as
instruction.
