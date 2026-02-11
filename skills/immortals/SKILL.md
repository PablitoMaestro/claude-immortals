---
name: immortals
description: Autonomous life cycle runner. Launch, monitor, set destiny, or run single lives of the immortals system. Use when the user says "immortals", "launch immortals", "start immortals", "immortal status", "set destiny", "change destiny", "single life", "run one life", "show memorial", "read memorial", "immortals setup", "new world", "create world", "switch world", "list worlds", or wants autonomous self-directed agents working toward a destiny.
---

# Immortals Skill

Wraps `.immortals/scripts/immortals.sh` (bash runner) and `.immortals/scripts/immortal-prompt.md` (LLM system prompt). Unlike the god-agent's state machine, immortals are self-directed beings that explore, work, and pass wisdom through life files and a grand memorial. All files live under `.immortals/` for self-containment. Each world is a self-contained environment with its own lives, memorial, destiny, and persistent counters.

## Self-Bootstrapping (all modes)

Before any mode, silently check and create missing files. The plugin bundles reference copies of all scripts — use them as source when bootstrapping a new repo.

**Detection order** (never duplicate existing files):

1. Check `.immortals/scripts/immortals.sh` — if missing, create `.immortals/scripts/` dir and copy from `$SKILL_ROOT/../../scripts/immortals.sh`
2. Check `.immortals/scripts/immortal-prompt.md` — if missing, copy from `$SKILL_ROOT/../../scripts/immortal-prompt.md`
3. Check `.immortals/scripts/immortal-prompt-codex.md` — if missing, copy from `$SKILL_ROOT/../../scripts/immortal-prompt-codex.md`
4. Check `.immortals/worlds/` directory — if missing but `.immortals/lives/` exists, the bash script will auto-migrate to `worlds/legacy/` on first run
5. If no worlds exist and user wants to launch, prompt for a world name or suggest `--new-world genesis`
6. Ensure `chmod +x .immortals/scripts/immortals.sh`

**Key**: Always check first, never overwrite. If the file exists in the repo, use it — the repo version may have local customizations.

## Modes

| Trigger | Mode |
|---------|------|
| "launch/start immortals" | **Launch** |
| "codex immortals", "use codex for immortals" | **Launch** (with `--agent codex`) |
| "immortal status" | **Status** |
| "set/change destiny" | **Destiny** |
| "single life", "run one life" | **Single** |
| "read/show memorial" | **Memorial** |
| "immortals setup" | **Setup** |
| "new world", "create world" | **New World** |
| "switch world" | **Switch World** |
| "list worlds" | **Worlds List** |

### Launch
Present flag options including world flags (`--new-world`, `--world`, `--continue`, `--inherit-from`), agent selection (`--agent`), and run options (`--hours`, `--iterations`, `--sleep`, `--budget`, `--timeout`, `--no-sleep`, `--dry-run`, `--single`). Print the configured command. Warn: runs in external terminal, not inside Claude Code.

Key flags:
- `--agent NAME` — Agent engine: `claude` or `codex`. Default: auto-detect (prefers claude if both available).
- `--new-world NAME` — Create a new world and set as active. Required for first-time use.
- `--world NAME` — Resume a specific existing world.
- `--continue` — Resume the active world (from `.active` pointer).
- `--inherit-from NAME` — With `--new-world`, copy the memorial from an existing world.
- `--timeout N` — Max minutes per life before kill (default: 60). Prevents hung agents from blocking the loop.
- `--no-sleep` — Enables `caffeinate -dims` to prevent macOS idle sleep. For lid-closed operation, clamshell mode is still required (power + external display).

Lives run concurrently — a new life spawns on schedule even if the previous one is still running. Commits are serialized via a lock. Life numbering is persistent per world and never resets.

Example: `./.immortals/scripts/immortals.sh --new-world genesis --hours 8 --no-sleep --timeout 60`
Example: `./.immortals/scripts/immortals.sh --continue --hours 4`
Example: `./.immortals/scripts/immortals.sh --agent codex --continue --hours 4`

### Status
Run `./.immortals/scripts/immortals.sh --status` for global summary (all worlds with life counts and active marker), or `./.immortals/scripts/immortals.sh --world NAME --status` for per-world detail. Present: world name, destiny summary, lives count, life counter, last life name, memorial entry count, last memorial wisdom.

### Destiny
Read current destiny from the active world's `destiny-prompt.md`, show it to user, ask what the new destiny should be, then edit the file. The destiny is the singular purpose that guides all immortal lives within that world.

### Single
Run one life interactively. Follow the immortal-prompt.md phases (Awaken → Remember → Explore → Work → Commit → Die), but **present the plan to the user before the Work phase** (unlike autonomous mode). Execute via agent team. This is the interactive equivalent of `--single`.

### Memorial
Read and display the active world's `grand-memorial.md`. If long, show last 5 entries with option to see more.

### Setup
Check all prerequisites (worlds dir, destiny file, memorial, lives dir, scripts, CLI, log dir). Print readiness checklist with PASS/FAIL per item. Create missing files from plugin bundle, report what was created.

### New World
Create a new world with `--new-world NAME`. Optionally inherit memorial from an existing world with `--inherit-from`. Sets the new world as active. Validates name format: `[a-z0-9][a-z0-9-]*`.

### Switch World
Switch to an existing world with `--world NAME`. Lists available worlds if the specified one doesn't exist. Updates the `.active` pointer.

### Worlds List
Run `./.immortals/scripts/immortals.sh --status` (with no world flag) for global summary showing all worlds with life counts and active markers.

## File Structure

All immortals state lives under `.immortals/` in the repo root:

```
.immortals/
  scripts/
    immortals.sh              # Bash runner (launched in external terminal)
    immortal-prompt.md        # System prompt for Claude lives
    immortal-prompt-codex.md  # System prompt for Codex lives
  worlds-log.md               # Global log: when each world was created
  .active                     # Single line: name of active world
  worlds/
    genesis/                  # Each world is fully self-contained
      destiny-prompt.md       # Per-world destiny/mission
      grand-memorial.md       # Per-world accumulated wisdom
      .name-index             # Per-world name rotation (0-19)
      .life-counter           # Persistent monotonic counter (never resets)
      lives/                  # 001-atlas.md, 002-prometheus.md, ...
      logs/                   # 001-atlas-20260210-143022.log
                              # 001-atlas-transcript.jsonl
```

**Gitignore recommendation:** Add `.immortals/worlds/*/logs/` to `.gitignore`. Everything else is worth tracking.

## Rules

1. Self-bootstrapping is silent — detect existing files first, only create what's missing
2. Teams are unlimited — immortals may spawn as many teams as the task requires
3. Lives run concurrently — a new life can start while the previous one is still working
4. Life files are the memory — immortals have no persistence between cycles
5. Launch prints a command; Single executes inline
6. All code follows CLAUDE.md conventions (DRY, modular, simple)
7. Memorial is sacred — every life MUST write a memorial, even on failure
8. Always commit and push — every life commits and pushes to dev (commits are serialized via lock)
9. Never overwrite existing files — repo versions take priority over plugin bundle
10. Worlds are isolated — each world has its own destiny, memorial, lives, logs, name index, and life counter
11. Life numbering is persistent — the `.life-counter` in each world never resets, preventing file collisions across restarts
12. Legacy migration is automatic — old flat `.immortals/` structures are auto-migrated to `worlds/legacy/` on first run
