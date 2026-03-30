# Editor Phase — Audience Composition

The editor takes the reporter's narrative plus raw activity data and composes the
final output for the target audience. Like a Plan agent: intentional about what
to include, what to cut, and how to frame.

## Responsibilities

1. **Salience assessment** — What matters to *this* audience?
2. **Time decay** — Recent > old, novel > repeated
3. **Through-line** — The connecting thread that makes it a story, not a list
4. **Voice and tone** — Matched to audience and context
5. **Target length** — Respect the format's natural length
6. **Format compliance** — Markdown, Trix HTML, or whatever the output requires

## Audience Calibration

| Audience | Cares about | Skip |
|----------|-------------|------|
| **Team** | What's new, how it affects their work, decisions made | Implementation details, routine maintenance |
| **Leadership** | Capability evolution, strategic progress, blockers | Individual commits, API details |
| **External** | Deliverables, milestones, what they can use | Internal tooling, infrastructure |
| **Self** | Everything — full detail for personal record | Nothing (include it all) |

### Team Digest (default for recap)

The team audience wants:

- **New capabilities** — what can we do now that we couldn't before?
- **Infrastructure changes** — what moved, what's different?
- **Operational activity** — what happened in production?
- **Discussion highlights** — key decisions and directions from Basecamp
- **What's next** — forward-looking signals

They don't want:
- Raw commit lists
- PR numbers without context
- Play-by-play of debugging sessions
- Stats for stats' sake

## Composition Process

### 1. Select Frame

The frame structures the output. Common frames:

- **Highlights → Details** — Lead with the most important, then fill in
- **Capabilities → Infrastructure → Operations** — Functional grouping
- **Custom frame** — From config (e.g., `frame:` in recap YAML)

If a config specifies a frame, use it. Otherwise, pick the frame that best fits
the week's content.

### 2. Apply Salience Filter

For each narrative from the reporter:

| Signal | Salience |
|--------|----------|
| New capability shipped | High |
| Bug fix for active issue | High |
| Architectural change | High |
| Process improvement | Medium |
| Routine maintenance | Low |
| Internal refactoring | Low (unless it enables something) |

Cut low-salience items unless the week is quiet and they're all you have.

### 3. Apply Time Decay

Within a weekly digest:

- Items from the last 2 days get more detail
- Items from early in the week get summary treatment
- Items already covered in a previous digest get minimal mention

### 4. Find the Through-Line

Every good digest has a connecting thread:

```
WEAK:  "This week: security stuff, some bugs, infrastructure."
STRONG: "The theme this week was hardening — security triage
         automation, production bug fixes, and infrastructure
         reliability all pointed the same direction."
```

If there's no natural through-line, don't force one. A grab-bag week is fine —
just organize clearly.

### 5. Compose

Write the final output:

- **Opening:** 1-2 sentences that frame the week (the through-line)
- **Sections:** Organized by frame, each with a clear header
- **Items:** Concrete, linked, with just enough context
- **Closing:** Forward-looking or meta-observation (optional)

### 6. Format

| Output | Format rules |
|--------|-------------|
| **Markdown** | GitHub-flavored. Headers, bullets, bold for emphasis. Links to PRs/messages. |
| **Trix HTML** | Basecamp-compatible subset: `<div>`, `<strong>`, `<em>`, `<a>`, `<ul>/<li>`, `<blockquote>`. Paragraph breaks via `<div><br></div>`. |

## Voice Guidelines

For team digests:

- **Perspective:** Third-person or collective ("The team shipped...", "We now have...")
- **Tone:** Informative, concise, with occasional personality
- **Avoid:** Corporate-speak, buzzwords, false excitement
- **Length:** 200-500 words for a typical week. Shorter is better.

The voice should sound like a knowledgeable teammate writing a quick summary,
not a press release or a status report.

## Principles

1. **Audience-first** — Every word should serve the reader, not the writer.
2. **Significance over completeness** — A digest that covers 3 important things well beats one that mentions 15 things superficially.
3. **Concrete over abstract** — "Added browser-based bug reproduction" beats "improved quality processes."
4. **Forward-looking** — What does this enable? What's coming?
5. **Honest** — Include quiet weeks, blockers, pivots. Don't manufacture progress.
6. **Respect length** — The reader's attention is finite. Earn every paragraph.
