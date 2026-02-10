# Life File Template

> Reference for the expected format of individual life files stored in `.immortals/lives/`.
> Each immortal creates one life file per cycle, named `{NNN}-{name}.md`.

---

## Template

```markdown
# Life of {Name}

**Born**: YYYY-MM-DD HH:MM:SS
**Destiny**: {one-line summary from destiny-prompt.md}
**Died**: (filled at end of life)

---

## What I Found

(Phase 3 — Explore: observations about the codebase's current state relevant to the destiny)

- Key files examined
- Current state of progress toward destiny
- Gaps or issues identified
- Decision on what to work on this life and why

## What I Did

(Phase 4 — Work: concrete description of work accomplished)

- Team spawned: `immortal-{name}` with N teammates
- Tasks created and completed
- Files modified or created
- Quality gate results

## What I Learned

(Phase 6 — Die: genuine insights from this life)

- What patterns or approaches worked well
- What didn't work and why
- Surprising discoveries about the codebase
- Connections between components that future lives should know

## For Those Who Follow

<memorial>
(3-8 lines of critical wisdom extracted by the bash script into grand-memorial.md)
(Be concrete and actionable — file paths, patterns, gotchas)
(This is the ONLY thing guaranteed to reach all future lives)
</memorial>
```

## Naming Convention

Life files are named: `{NNN}-{name}.md` where:
- `{NNN}` is a zero-padded 3-digit sequence number (001, 002, ...)
- `{name}` is the immortal's name from the name pool

Example: `001-atlas.md`, `002-prometheus.md`, `023-atlas.md` (names cycle)

## Section Rules

| Section | When Written | Required |
|---------|-------------|----------|
| Header (Born) | Phase 1 — Awaken | Yes |
| What I Found | Phase 3 — Explore | Yes |
| What I Did | Phase 4 — Work | Yes |
| Header (Died) | Phase 6 — Die | Yes |
| What I Learned | Phase 6 — Die | Yes |
| Memorial | Phase 6 — Die | **Mandatory** — even on failure |
