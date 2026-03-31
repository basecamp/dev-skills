# install.md Guide

Create install.md files that AI agents can execute autonomously. Every output must enable an agent to install software without human clarification.

---

## Spec

An install.md optimized for autonomous agent execution has this structure:

```markdown
I want you to install [Product] for me. Execute all steps autonomously.

OBJECTIVE: [Single sentence describing what will be installed]

DONE WHEN: [Runnable check command with default fallbacks for any env vars]

## TODO

- [ ] [Step 1 description]
- [ ] [Step 2 description]
- [ ] [Step 3 description]
(3-7 items)

## Step 0: [Prerequisites] (optional)

[Dependency check command]

**Verify:**
[Check command]
[Expected output hint]

## Step 1: [Action]

...

EXECUTE NOW: Start with Step 0. Mark TODO items complete as you go. Stop when [restate DONE WHEN condition].

---

## Optional: [Additional Content]
(Optional sections allowed after EXECUTE NOW separator)
```

### Spec Rules

| Element | Requirement |
|---------|-------------|
| Opening | Must begin with "I want you to install [X] for me. Execute all steps autonomously." |
| OBJECTIVE | Single line starting with "OBJECTIVE:" |
| DONE WHEN | Single line starting with "DONE WHEN:" with runnable check command; env vars must have defaults like `${VAR:-default}` |
| TODO | Section with 3-7 unchecked `- [ ]` items |
| Steps | Each step (## Step N) has exactly one command block + one **Verify:** block |
| EXECUTE NOW | Must restate the DONE WHEN condition (same command) |
| Optional sections | Allowed only after EXECUTE NOW, preceded by `---` separator |
| Word count | 400-800 words |
| Troubleshooting | Excluded from main flow (agents shouldn't debug) |
| HTML | None (plain markdown only) |

---

## Process

### 1. Analyze

Gather these facts before drafting:
- Product name (exact)
- Target OS(s)
- Install method (curl | bash, brew, npm, etc.)
- Success signals (version command, status command)
- Auth steps (if any)
- Dependencies (if any)

### 2. Draft Skeleton

Enforce exact order:
1. Opening request line
2. OBJECTIVE: line
3. DONE WHEN: line
4. ## TODO section
5. Steps with verify blocks
6. EXECUTE NOW: closing

### 3. Author Steps

For each step:
- One command block
- One verify block with expected output hint
- No optional variations inline (put in separate section if needed)

### 4. Clean Content

Remove:
- Troubleshooting sections
- "If you see an error" blocks
- Optional configuration
- HTML tags
- Marketing language

Keep:
- Commands
- Verify blocks
- Expected output hints

### 5. Tune Word Count

Target: 400-800 words

If under 400:
- Add expected output hints
- Add verify blocks for missing steps
- Add dependency checks

If over 800:
- Remove optional steps
- Consolidate agent variants
- Remove explanatory prose

### 6. Validate

Run all 12 eval checks. Fix failures before shipping.

---

## Eval Checks

| # | Check | Command | Pass |
|---|-------|---------|------|
| 1 | Has opening request | `head -1 install.md \| grep -qi "I want you to install"` | Exit 0 |
| 2 | Has OBJECTIVE: | `grep -q "^OBJECTIVE:" install.md` | Exit 0 |
| 3 | Has DONE WHEN: | `grep -q "^DONE WHEN:" install.md` | Exit 0 |
| 4 | Has TODO section | `grep -q "^## TODO" install.md` | Exit 0 |
| 5 | TODO has 3-7 items | `grep -c "^- \[ \]" install.md` | 3-7 |
| 6 | Word count in range | `wc -w < install.md` | 400-800 |
| 7 | No HTML tags | `grep -qE "<[a-z]+" install.md` | Exit 1 |
| 8 | Has EXECUTE NOW: | `grep -q "^EXECUTE NOW:" install.md` | Exit 0 |
| 9 | No troubleshooting | `grep -qi "troubleshoot" install.md` | Exit 1 |
| 10 | Each Step has Verify | Compare step count to verify count | Equal |
| 11 | Env vars have defaults | `grep -E '\$[A-Z_]+($\|[^}:-])' install.md` | Exit 1 (none without defaults) |
| 12 | EXECUTE NOW restates DONE WHEN | Manual: compare the two conditions | Same command |

```bash
# Run from directory containing install.md
FILE="install.md"

echo "1) Has opening request (first line):"
head -1 "$FILE" | grep -qi "I want you to install" && echo "PASS" || echo "FAIL"

echo "2) Has OBJECTIVE:"
grep -q "^OBJECTIVE:" "$FILE" && echo "PASS" || echo "FAIL"

echo "3) Has DONE WHEN:"
grep -q "^DONE WHEN:" "$FILE" && echo "PASS" || echo "FAIL"

echo "4) Has TODO section:"
grep -q "^## TODO" "$FILE" && echo "PASS" || echo "FAIL"

echo "5) TODO has 3-7 items:"
COUNT=$(grep -c "^- \[ \]" "$FILE")
[ "$COUNT" -ge 3 ] && [ "$COUNT" -le 7 ] && echo "PASS ($COUNT items)" || echo "FAIL ($COUNT items)"

echo "6) Word count in range (400-800):"
WC=$(wc -w < "$FILE")
[ "$WC" -ge 400 ] && [ "$WC" -le 800 ] && echo "PASS ($WC words)" || echo "FAIL ($WC words)"

echo "7) No HTML tags:"
grep -qE "<[a-z]+" "$FILE" && echo "FAIL" || echo "PASS"

echo "8) Has EXECUTE NOW:"
grep -q "^EXECUTE NOW:" "$FILE" && echo "PASS" || echo "FAIL"

echo "9) No troubleshooting:"
grep -qi "troubleshoot" "$FILE" && echo "FAIL" || echo "PASS"

echo "10) Each Step has Verify (main flow only):"
# Count steps and verifies before EXECUTE NOW (main flow)
MAIN_FLOW=$(sed '/^EXECUTE NOW:/q' "$FILE")
STEPS=$(echo "$MAIN_FLOW" | grep -c "^## Step")
VERIFIES=$(echo "$MAIN_FLOW" | grep -c "^\*\*Verify:\*\*")
[ "$STEPS" -eq "$VERIFIES" ] && echo "PASS ($STEPS steps, $VERIFIES verifies)" || echo "FAIL ($STEPS steps, $VERIFIES verifies)"

echo "11) Env vars have defaults:"
# Check for $VAR patterns that don't use ${VAR:-default} syntax (including end-of-line)
if grep -E '\$[A-Z_]+($|[^}:-])' "$FILE" | grep -qv ':-'; then
  echo "WARN: Check env vars manually"
else
  echo "PASS"
fi

echo "12) EXECUTE NOW restates DONE WHEN:"
echo "Manual check - compare:"
grep "^DONE WHEN:" "$FILE"
grep "^EXECUTE NOW:" "$FILE"
```

---

## Failure Modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Template drift | Agent uses heading format (## Objective) instead of single-line | Add regex check for exact format |
| Over-compression | Cutting verify steps to meet word count | Require verify per step in eval |
| Vague DONE WHEN | Uses "installed successfully" | Require measurable check command |
| TODO inflation | More than 7 items | Hard limit in eval check |
| EXECUTE NOW mismatch | Lists commands, not done condition | Check closing restates DONE WHEN |
| Troubleshooting included | Legacy pattern from human docs | Eval check 9 catches this |
| Missing verify blocks | Steps copied without verification | Audit each step for verify block |
| HTML in output | Copied from web docs | Eval check 7 catches this |
| Env var without default | Uses $VAR instead of ${VAR:-default} | Agent can't verify if var unset |
| Extra sections in main flow | Updating, paths, etc. before EXECUTE NOW | Move to Optional section after EXECUTE NOW |
| Multi-variant steps | Multiple agent options in one step | Split into Optional section or separate docs |
| Steps start at 1 | Prerequisites not counted | Use Step 0 for prerequisites |

---

## Exemplars

Study before starting:
- `~/Work/basecamp/bcq/INSTALL.md` (Target 1 - co-developed with this skill)

---

## Self-Eval Checks

This skill must pass skill-crafting criteria.

| # | Check | Command | Pass |
|---|-------|---------|------|
| 1 | Has frontmatter with name | `head -1 SKILL.md \| grep -q "^---" && head -15 SKILL.md \| grep -q "^name:"` | Exit 0 |
| 2 | Has guide.md | `test -f references/guide.md` | Exit 0 |
| 3 | Failure modes has table | `sed '/^```/,/^```/d' references/guide.md \| grep -A5 "^## Failure Modes" \| grep -q "^\|"` | Exit 0 |
| 4 | Eval checks has table | `sed '/^```/,/^```/d' references/guide.md \| grep -EA10 "^## (Self-Eval\|Eval) Checks" \| grep -q "^\|"` | Exit 0 |
| 5 | Exemplars has real entries | `sed '/^```/,/^```/d' references/guide.md \| grep -A10 "^## Exemplars" \| grep -qE "^- .*(skills/\|http\|~)"` | Exit 0 |

---

## Quick Start

1. Analyze target software
2. Draft skeleton in exact spec order
3. Author steps with verify blocks
4. Remove troubleshooting and optional content
5. Tune to 400-800 words
6. Run all 12 eval checks
7. Fix failures and re-check
