# Reporter Phase — Narrative Synthesis

The reporter reads the full cached dossier for the requested timescale,
categorizes activity by theme, identifies patterns and connections, and produces
a structured narrative. Like an Explore agent: deep reading, not surface listing.

## Timescale Awareness

Different timescales surface different things:

| Timescale | Focus | Detail level |
|-----------|-------|-------------|
| **Daily** | What happened today, what's in progress | High — individual commits, PRs, messages |
| **Weekly** | Arcs and trajectories, themes that emerged | Medium — grouped by initiative, patterns noted |
| **Monthly** | Strategic progress, capability evolution | Low — thematic summary, milestone framing |

A weekly reporter doesn't list every commit — it identifies the *themes* those
commits represent and the *trajectories* they reveal.

## Process

### 1. Inventory

Read all cached day-atoms for the period. For each source:

- **Git:** commit subjects, authors, repos touched
- **Basecamp:** event kinds, message titles, card movements, discussion threads
- **GitHub:** PR titles/descriptions, review activity, issue creation

Build a flat inventory of everything that happened.

### 2. Categorize by Theme

Group related items across sources:

```
BAD:  "Git: 12 commits. Basecamp: 3 messages. GitHub: 5 PRs."
GOOD: "Security triage: 5 PRs + 8 commits implementing researcher automation,
       announced in Basecamp message, discussed in campfire thread."
```

A single initiative often spans git commits, GitHub PRs, and Basecamp messages.
The reporter's job is to see through the source boundaries.

### 3. Identify Patterns

Look for:

- **Trajectories:** work that built on itself across days
- **Pivots:** direction changes mid-week
- **Clusters:** multiple people or repos converging on the same area
- **Quiet zones:** areas with no activity (sometimes significant)
- **Threshold crossings:** moments where capability changed (went live, became possible)

### 4. Form Narratives

For each theme, write a short narrative that captures:

- **What:** the concrete work done
- **Why:** the motivation or trigger
- **Arc:** how it developed over the period
- **Connection:** how it relates to other themes

### 5. Structured Output

Produce a structured intermediate document (not the final output — that's the
editor's job). Format:

```markdown
## Theme: [Name]

**Summary:** [1-2 sentence overview]

**Arc:** [How this developed over the period]

**Key items:**
- [Specific PR/commit/message with context]
- [Another item]

**Connections:** [Links to other themes]

---
```

## Principles

1. **Theme over source** — Never organize by data source. Always by initiative/theme.
2. **Arc over list** — Show how work developed, don't enumerate events.
3. **Significance over volume** — A single important decision matters more than 20 routine commits.
4. **Connections matter** — The reporter's unique value is seeing across source boundaries.
5. **Honest about gaps** — Note what the data can't show (meetings, DMs, design work).
6. **Timescale-appropriate** — Daily can be granular; weekly must be thematic.

## Anti-Patterns

- **Source-grouped output:** "GitHub section, Basecamp section, Git section" — defeats the purpose.
- **Commit-log echo:** Repeating commit messages verbatim without synthesis.
- **False precision:** "Exactly 47 commits across 3 repos" when the count doesn't matter.
- **Missing the forest:** Listing trees (individual items) without identifying the forest (themes).
- **Inventing narrative:** If it's a grab-bag week with no connecting thread, say so.
