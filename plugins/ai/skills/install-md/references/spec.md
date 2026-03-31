# install.md Spec

## Template

```markdown
I want you to install [Product] for me. Execute all steps autonomously.

OBJECTIVE: [What will be installed - single sentence]

DONE WHEN: [Runnable check command with ${VAR:-default} for any env vars]

## TODO

- [ ] [Step 0 - prerequisites]
- [ ] [Step 1]
- [ ] [Step 2]

## Step 0: [Prerequisites] (optional, for dependency checks)

```bash
[command]
```

**Verify:**
```bash
[check command]
# Expected: [output hint]
```

## Step 1: [Action]

...

EXECUTE NOW: Start with Step 0. Mark TODO items complete as you go. Stop when [same DONE WHEN command].

---

## Optional: [Additional Content]
(Agent variants, updating instructions, etc.)
```

## Rules

| Element | Requirement |
|---------|-------------|
| Opening | "I want you to install [X] for me. Execute all steps autonomously." |
| OBJECTIVE: | Single line, starts with "OBJECTIVE:" |
| DONE WHEN: | Runnable command, env vars use `${VAR:-default}` |
| TODO | 3-7 unchecked `- [ ]` items |
| Steps | Each has one command block + one **Verify:** block |
| EXECUTE NOW: | Restates same command from DONE WHEN |
| Optional | Allowed after `---` separator, after EXECUTE NOW |
| Word count | 400-800 |
| Excluded | Troubleshooting in main flow, HTML |

## Anti-Patterns

- `## Objective` (use `OBJECTIVE:`)
- `## Completion Criteria` (use `DONE WHEN:`)
- `If you see an error...` (no troubleshooting in main flow)
- `<table>` or other HTML
- More than 7 TODO items
- Missing verify blocks
- Vague success criteria ("installed successfully")
- `$VAR` without default (use `${VAR:-default}`)
- Extra sections before EXECUTE NOW (move to Optional)
- Multiple variants in one step (use Optional section)
