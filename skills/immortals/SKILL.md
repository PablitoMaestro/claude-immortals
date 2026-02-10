---
name: immortals
description: Autonomous life cycle runner. Launch, monitor, set destiny, or run single lives of the immortals system. Use when the user says "immortals", "launch immortals", "start immortals", "immortal status", "set destiny", "change destiny", "single life", "run one life", "show memorial", "read memorial", "immortals setup", or wants autonomous self-directed agents working toward a destiny.
---

# Immortals Skill

Wraps `.immortals/scripts/immortals.sh` (bash runner) and `.immortals/scripts/immortal-prompt.md` (LLM system prompt). Unlike the god-agent's state machine, immortals are self-directed beings that explore, work, and pass wisdom through life files and a grand memorial. All files live under `.immortals/` for self-containment.

## Self-Bootstrapping (all modes)

Before any mode, silently check and create missing files. The plugin bundles reference copies of all scripts — use them as source when bootstrapping a new repo.

**Detection order** (never duplicate existing files):

1. Check `.immortals/scripts/immortals.sh` — if missing, create `.immortals/scripts/` dir and copy from `$SKILL_ROOT/../../scripts/immortals.sh`
2. Check `.immortals/scripts/immortal-prompt.md` — if missing, copy from `$SKILL_ROOT/../../scripts/immortal-prompt.md`
3. Check `.immortals/destiny-prompt.md` — if missing, create with empty destiny template
4. Check `.immortals/grand-memorial.md` — if missing, create with header
5. Check `.immortals/lives/` — create directory if missing
6. Check `.immortals/logs/` — create directory if missing
7. Ensure `chmod +x .immortals/scripts/immortals.sh`

**Key**: Always check first, never overwrite. If the file exists in the repo, use it — the repo version may have local customizations.

## Modes

| Trigger | Mode |
|---------|------|
| "launch/start immortals" | **Launch** |
| "immortal status" | **Status** |
| "set/change destiny" | **Destiny** |
| "single life", "run one life" | **Single** |
| "read/show memorial" | **Memorial** |
| "immortals setup" | **Setup** |

### Launch
Present flag options (`--hours`, `--iterations`, `--sleep`, `--budget`, `--timeout`, `--no-sleep`, `--dry-run`, `--single`). Print the configured command. Warn: runs in external terminal, not inside Claude Code.

Key flags:
- `--timeout N` — Max minutes per life before kill (default: 60). Prevents hung agents from blocking the loop.
- `--no-sleep` — Enables `caffeinate -dims` to prevent macOS idle sleep. For lid-closed operation, clamshell mode is still required (power + external display).

Lives run concurrently — a new life spawns on schedule even if the previous one is still running. Commits are serialized via a lock.

Example: `./.immortals/scripts/immortals.sh --hours 8 --no-sleep --timeout 60`

### Status
Run `./.immortals/scripts/immortals.sh --status` or read state files directly. Present: destiny summary, lives count, last life name, memorial entry count, last memorial wisdom.

### Destiny
Read current `.immortals/destiny-prompt.md`, show it to user, ask what the new destiny should be, then edit the file. The destiny is the singular purpose that guides all immortal lives.

### Single
Run one life interactively. Follow the immortal-prompt.md phases (Awaken → Remember → Explore → Work → Commit → Die), but **present the plan to the user before the Work phase** (unlike autonomous mode). Execute via agent team. This is the interactive equivalent of `--single`.

### Memorial
Read and display `.immortals/grand-memorial.md`. If long, show last 5 entries with option to see more.

### Setup
Check all prerequisites (destiny file, memorial, lives dir, scripts, CLI, log dir). Print readiness checklist with PASS/FAIL per item. Create missing files from plugin bundle, report what was created.

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
