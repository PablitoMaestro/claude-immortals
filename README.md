# Immortals

A Claude Code plugin that spawns autonomous agents as mythological beings. Each "life" explores your codebase, works toward a shared destiny, and passes wisdom through a grand memorial for future lives to learn from.

## Quick Start

```bash
# In Claude Code
/immortals              # Interactive setup
/immortals setup        # Check prerequisites
```

Create a world, set a destiny, then launch:

```bash
# Create your first world
./.immortals/scripts/immortals.sh --new-world genesis --hours 4 --no-sleep --timeout 60

# Continue where you left off (persistent life numbering)
./.immortals/scripts/immortals.sh --continue --hours 4 --sleep 15

# Start a new experiment, inherit accumulated wisdom
./.immortals/scripts/immortals.sh --new-world experiment --inherit-from genesis --hours 8

# Use Codex instead of Claude
./.immortals/scripts/immortals.sh --agent codex --continue --hours 4
```

## How It Works

Each life cycles through six phases: **Awaken** (orient), **Remember** (read memorial), **Explore** (scan codebase), **Work** (spawn teams, write code), **Commit** (push to git), **Die** (write memorial for successors).

Worlds are self-contained environments — each has its own destiny, memorial, lives, and persistent life counter. Life numbering never resets, so stopping and restarting a world picks up where it left off.

Lives run concurrently. Commits are serialized via a lock. Each life gets a mythological name from a rotating pool of 20 (atlas, prometheus, hermes, ...).

## Config System

All configuration lives in `.immortals/config.sh` and is **hot-reloaded** every 60 seconds (configurable via `CONFIG_POLL_SECONDS`). Changes apply at the next cycle — no restart needed.

**Precedence chain** (last wins):
```
Hardcoded defaults → config.sh [global] → config.sh [WORLD_<name>_*] → worlds/<name>/config.sh → CLI flags
```

Per-world overrides use inline naming in the global config:
```bash
# In .immortals/config.sh
WORLD_ideoma_SLEEP_MINUTES=20
WORLD_ideoma_BUDGET=5
WORLD_origins_TIMEOUT_MINUTES=90
```

Or create a per-world config file at `worlds/<name>/config.sh` for the highest file-based priority.

Set `ENABLED=false` (globally or per-world) to gracefully pause runners within one poll cycle.

Key config sections:
- **Timing**: `SLEEP_MINUTES`, `TIMEOUT_MINUTES`, `CONFIG_POLL_SECONDS`
- **Agent**: `AGENT`, `CLAUDE_MODEL`, `CODEX_MODEL`, `BUDGET`
- **Behavior**: `NO_SLEEP`, `PUSH_MAX_RETRIES`, `ENABLED`
- **Memorial**: `MEMORIAL_MAX_LINES`, `MEMORIAL_HEADER_LINES`
- **Universe**: `ACTIVE_WORLDS`, `UNIVERSE_POLL_SECONDS`, `OVERSIGHT_HOURS`, `OVERSIGHT_MODEL`, `OVERSIGHT_BUDGET`

## Hand of God — Multi-World Orchestrator

Run multiple worlds concurrently with automatic reconciliation:

```bash
# Run two worlds for 24 hours
./.immortals/scripts/hand-of-god.sh --hours 24

# Override which worlds to run
./.immortals/scripts/hand-of-god.sh --worlds "ideoma origins" --hours 24

# Run with oversight agent checking every 4 hours
./.immortals/scripts/hand-of-god.sh --hours 24 --oversight 4

# Check status of all worlds
./.immortals/scripts/hand-of-god.sh --status
```

The orchestrator spawns and monitors `immortals.sh` runners for each world in `ACTIVE_WORLDS`. It reconciles every `UNIVERSE_POLL_SECONDS` — spawning missing runners, stopping removed worlds, and handling `ENABLED=false` flags.

### Oversight Agent

An optional Claude instance that periodically evaluates all worlds:
- Reads memorials and git history
- Assesses productivity, detects stuck worlds, spots conflicts
- Writes reports to `.immortals/oversight-log.md`
- May tune `config.sh` (adjust timeouts, budgets, disable struggling worlds)
- Never touches destiny files — that's the human's domain

Enable with `OVERSIGHT_HOURS=4` in config or `--oversight 4` flag.

### Hand of God Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--hours N` | - | Total runtime for the universe (required) |
| `--worlds "a b c"` | config | Override `ACTIVE_WORLDS` |
| `--poll N` | 60 | Seconds between reconciliation checks |
| `--oversight N` | 0 | Run oversight agent every N hours (0 = disabled) |
| `--no-sleep` | off | Passed through to world runners |
| `--dry-run` | - | Preview which worlds would launch |
| `--status` | - | Show all worlds and runner state |

## File Structure

Everything lives under `.immortals/` in your repo:

```
.immortals/
  config.sh                     # Universe config: global + per-world sections (hot-reloaded)
  scripts/
    immortals.sh                # Single-world runner (with hot-reload)
    hand-of-god.sh              # Multi-world orchestrator + optional oversight
    god-agent-prompt.md         # System prompt for the oversight agent
    immortal-prompt.md          # System prompt for Claude lives
    immortal-prompt-codex.md    # System prompt for Codex lives
  hand-of-god.log               # Universe orchestrator log
  oversight-log.md              # Oversight agent reports
  worlds-log.md                 # Chronicle of all worlds created
  .active                       # Pointer to the active world
  worlds/
    genesis/                    # Each world is self-contained
      config.sh                 # Per-world config overrides (optional)
      destiny-prompt.md         # The shared mission for this world
      grand-memorial.md         # Accumulated wisdom across lives
      .life-counter             # Persistent life numbering (never resets)
      .name-index               # Name rotation counter
      .runner-pid               # PID of this world's runner process
      lives/                    # Individual life journals
      logs/                     # Session logs + transcripts (gitignored)
```

## Single-World Runner Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--new-world NAME` | - | Create a new world and set as active |
| `--inherit-from NAME` | - | With `--new-world`, copy memorial from existing world |
| `--world NAME` | - | Resume a specific existing world |
| `--continue` | - | Resume the active world |
| `--agent NAME` | auto | Agent engine: `claude` or `codex` |
| `--hours N` | - | Run for N hours |
| `--iterations N` | - | Run exactly N lives |
| `--sleep N` | 30 | Minutes between lives |
| `--timeout N` | 60 | Max minutes per life before kill |
| `--budget N` | - | Max USD per life |
| `--no-sleep` | on | Prevent macOS idle sleep |
| `--single` | - | Run one life only |
| `--dry-run` | - | Preview without executing |
| `--status` | - | Print current state (global or per-world) |
| `--heartbeat` | - | Show who's alive right now |

A world flag is required for running lives (or an active world must exist). At least one of `--hours` or `--iterations` is required for running.

## Session Transcripts

Each life's full Claude session (every tool call, every response) is automatically saved as a `.jsonl` transcript in the world's `logs/` directory. Use `claude --resume <session-id>` to inspect or continue any past life.

## Slash Commands

| Command | What it does |
|---------|-------------|
| `/immortals` | Interactive mode selector |
| `immortals setup` | Check prerequisites |
| `immortal status` | Show destiny, lives count, last memorial |
| `set destiny` | Edit the destiny prompt |
| `single life` | Run one life interactively |
| `show memorial` | Read accumulated wisdom |
| `new world` | Create a new world |
| `switch world` | Switch to an existing world |
| `list worlds` | Show all worlds with status |
| `hand of god` | Launch multi-world orchestrator |
| `immortals config` | View and edit config |

## Requirements

- Claude Code CLI (`claude`) in PATH (or `codex` for Codex agent)
- Git repository with a `dev` branch
- `--dangerously-skip-permissions` enabled (autonomous mode)
