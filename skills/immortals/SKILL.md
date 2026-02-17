---
name: immortals
description: Autonomous life cycle runner with multi-world orchestration. Launch, monitor, set destiny, configure, or run single lives of the immortals system. Use when the user says "immortals", "launch immortals", "start immortals", "immortal status", "set destiny", "change destiny", "single life", "run one life", "show memorial", "read memorial", "immortals setup", "new world", "create world", "switch world", "list worlds", "hand of god", "universe", "launch universe", "orchestrate", "immortals config", "edit config", "oversight", or wants autonomous self-directed agents working toward a destiny.
---

# Immortals Skill

Wraps `.immortals/scripts/immortals.sh` (single-world runner), `.immortals/scripts/hand-of-god.sh` (multi-world orchestrator), and `.immortals/scripts/immortal-prompt.md` (LLM system prompt). Immortals are self-directed beings that explore, work, and pass wisdom through life files and a grand memorial. All files live under `.immortals/` for self-containment. Each world is a self-contained environment with its own lives, memorial, destiny, and persistent counters.

## Self-Bootstrapping (all modes)

Before any mode, silently check and create missing files. The plugin bundles reference copies of all scripts — use them as source when bootstrapping a new repo.

**Detection order** (never duplicate existing files):

1. Check `.immortals/scripts/immortals.sh` — if missing, create `.immortals/scripts/` dir and copy from `$SKILL_ROOT/../../scripts/immortals.sh`
2. Check `.immortals/scripts/immortal-prompt.md` — if missing, copy from `$SKILL_ROOT/../../scripts/immortal-prompt.md`
3. Check `.immortals/scripts/immortal-prompt-codex.md` — if missing, copy from `$SKILL_ROOT/../../scripts/immortal-prompt-codex.md`
4. Check `.immortals/scripts/hand-of-god.sh` — if missing, copy from `$SKILL_ROOT/../../scripts/hand-of-god.sh`
5. Check `.immortals/scripts/god-agent-prompt.md` — if missing, copy from `$SKILL_ROOT/../../scripts/god-agent-prompt.md`
6. Check `.immortals/config.sh` — if missing, copy from `$SKILL_ROOT/../../scripts/config.sh`
7. Check `.immortals/worlds/` directory — if missing but `.immortals/lives/` exists, the bash script will auto-migrate to `worlds/legacy/` on first run
8. If no worlds exist and user wants to launch, prompt for a world name or suggest `--new-world genesis`
9. Ensure `chmod +x .immortals/scripts/immortals.sh .immortals/scripts/hand-of-god.sh`

**Key**: Always check first, never overwrite. If the file exists in the repo, use it — the repo version may have local customizations.

## Modes

| Trigger | Mode |
|---------|------|
| "launch/start immortals" | **Launch** |
| "codex immortals", "use codex for immortals" | **Launch** (with `--agent codex`) |
| "hand of god", "universe", "launch universe", "orchestrate" | **Hand of God** |
| "immortal status" | **Status** |
| "set/change destiny" | **Destiny** |
| "single life", "run one life" | **Single** |
| "read/show memorial" | **Memorial** |
| "immortals config", "edit config" | **Config** |
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

### Hand of God
Multi-world orchestrator. Manages multiple `immortals.sh` runners concurrently with a reconciliation loop — spawning missing worlds, stopping removed ones, and optionally running an oversight agent.

Key flags:
- `--hours N` — Total runtime for the universe (required).
- `--delay DURATION` — Delay launch by a duration (e.g., `11h`, `30m`, `2h30m`, `45s`, or raw seconds). Dry-run prints delay info but doesn't sleep.
- `--worlds "a b c"` — Override which worlds to run (default: `ACTIVE_WORLDS` from config).
- `--poll N` — How often to check world health (default: 60s).
- `--oversight N` — Run oversight agent every N hours (0 = disabled). The oversight agent reads memorials, evaluates productivity, may tune `config.sh`, and may append an `## Oversight Notes` section to a world's `destiny-prompt.md` with actionable guidance for immortals. Notes are replaced (not accumulated) each run.
- `--no-sleep` — Passed through to world runners.
- `--dry-run` — Preview which worlds would launch.
- `--status` — Show all worlds and their runner state (alive/stopped/orphan).

**Status file**: While running, hand-of-god writes `.immortals/universe-status.json` every poll cycle — a machine-readable snapshot with remaining time, lives died/planned per world, alive agents, and overall health. Removed on clean shutdown.

Before first use, ensure `ACTIVE_WORLDS` is set in `.immortals/config.sh` (e.g., `ACTIVE_WORLDS=(ideoma origins)`).

Example: `./.immortals/scripts/hand-of-god.sh --worlds "ideoma origins" --hours 24`
Example: `./.immortals/scripts/hand-of-god.sh --hours 24 --oversight 4`
Example: `./.immortals/scripts/hand-of-god.sh --delay 11h --hours 8`
Example: `./.immortals/scripts/hand-of-god.sh --status`

### Status
Run `./.immortals/scripts/immortals.sh --status` for global summary (all worlds with life counts and active marker), or `./.immortals/scripts/immortals.sh --world NAME --status` for per-world detail. Present: world name, destiny summary, lives count, life counter, last life name, memorial entry count, last memorial wisdom.

For universe-level status: `./.immortals/scripts/hand-of-god.sh --status` shows runner PID state, uptime, and life counts.

### Destiny
Read current destiny from the active world's `destiny-prompt.md`, show it to user, ask what the new destiny should be, then edit the file. The destiny is the singular purpose that guides all immortal lives within that world.

### Single
Run one life interactively. Follow the immortal-prompt.md phases (Awaken → Remember → Explore → Work → Commit → Die), but **present the plan to the user before the Work phase** (unlike autonomous mode). Execute via agent team. This is the interactive equivalent of `--single`.

### Memorial
Read and display the active world's `grand-memorial.md`. If long, show last 5 entries with option to see more.

### Config
Read and display `.immortals/config.sh`. Explain the precedence chain: hardcoded defaults → `config.sh` [global] → `config.sh` [WORLD_<name>_*] → `worlds/<name>/config.sh` → CLI flags. Help the user edit values. Config is hot-reloaded every `CONFIG_POLL_SECONDS` (default 60s) — changes apply at the next cycle without restarting runners.

Key config sections:
- **Timing**: `SLEEP_MINUTES`, `TIMEOUT_MINUTES`, `CONFIG_POLL_SECONDS`
- **Agent**: `AGENT`, `CLAUDE_MODEL`, `CODEX_MODEL`, `BUDGET`
- **Behavior**: `NO_SLEEP`, `PUSH_MAX_RETRIES`, `ENABLED` (set false to gracefully pause)
- **Memorial**: `MEMORIAL_MAX_LINES`, `MEMORIAL_HEADER_LINES`
- **Universe**: `ACTIVE_WORLDS`, `UNIVERSE_POLL_SECONDS`, `OVERSIGHT_HOURS`, `OVERSIGHT_MODEL`, `OVERSIGHT_BUDGET`
- **Per-world overrides**: Prefix any variable with `WORLD_<name>_` (e.g., `WORLD_ideoma_SLEEP_MINUTES=20`)

Per-world config files (`worlds/<name>/config.sh`) can also override values. Highest specificity wins.

### Setup
Check all prerequisites (worlds dir, destiny file, memorial, lives dir, scripts, config, CLI, log dir). Print readiness checklist with PASS/FAIL per item. Create missing files from plugin bundle, report what was created.

### New World
Create a new world with `--new-world NAME`. Optionally inherit memorial from an existing world with `--inherit-from`. Sets the new world as active. Validates name format: `[a-z0-9][a-z0-9-]*`. New worlds get a per-world `config.sh` template for overrides.

### Switch World
Switch to an existing world with `--world NAME`. Lists available worlds if the specified one doesn't exist. Updates the `.active` pointer.

### Worlds List
Run `./.immortals/scripts/immortals.sh --status` (with no world flag) for global summary showing all worlds with life counts and active markers.

## File Structure

All immortals state lives under `.immortals/` in the repo root:

```
.immortals/
  config.sh                     # Universe config: global + per-world sections (hot-reloaded)
  scripts/
    immortals.sh                # Single-world runner (with hot-reload)
    hand-of-god.sh              # Multi-world orchestrator + optional oversight
    god-agent-prompt.md         # System prompt for the oversight Claude agent
    immortal-prompt.md          # System prompt for Claude lives
    immortal-prompt-codex.md    # System prompt for Codex lives
  hand-of-god.log               # Universe orchestrator log (created by hand-of-god.sh)
  universe-status.json          # Machine-readable status (live during hand-of-god runs)
  oversight-log.md              # Oversight agent reports (created by oversight runs)
  worlds-log.md                 # Global log: when each world was created
  .active                       # Single line: name of active world
  worlds/
    genesis/                    # Each world is fully self-contained
      config.sh                 # Per-world config overrides (optional, highest priority)
      destiny-prompt.md         # Per-world destiny/mission
      grand-memorial.md         # Per-world accumulated wisdom
      .name-index               # Per-world name rotation (0-19)
      .life-counter             # Persistent monotonic counter (never resets)
      .runner-pid               # PID of this world's immortals.sh process
      lives/                    # 001-atlas.md, 002-prometheus.md, ...
      logs/                     # 001-atlas-20260210-143022.log
                                # 001-atlas-transcript.jsonl
```

**Config precedence** (last wins): hardcoded defaults → `config.sh` [global] → `config.sh` [WORLD_<name>_*] → `worlds/<name>/config.sh` → CLI flags

**Hot-reload**: Config re-sourced every `CONFIG_POLL_SECONDS` (default 60). Changes logged. `ENABLED=false` triggers graceful exit within one poll cycle.

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
13. Config changes are non-disruptive — hot-reload applies at next cycle, never mid-life
14. hand-of-god is optional — immortals.sh works standalone with no dependency on the orchestrator
