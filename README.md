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
```

## How It Works

Each life cycles through six phases: **Awaken** (orient), **Remember** (read memorial), **Explore** (scan codebase), **Work** (spawn teams, write code), **Commit** (push to git), **Die** (write memorial for successors).

Worlds are self-contained environments — each has its own destiny, memorial, lives, and persistent life counter. Life numbering never resets, so stopping and restarting a world picks up where it left off.

Lives run concurrently. Commits are serialized via a lock. Each life gets a mythological name from a rotating pool of 20 (atlas, prometheus, hermes, ...).

## File Structure

Everything lives under `.immortals/` in your repo:

```
.immortals/
  scripts/
    immortals.sh              # Bash runner
    immortal-prompt.md        # System prompt for each life
  worlds-log.md               # Chronicle of all worlds created
  .active                     # Pointer to the active world
  worlds/
    genesis/                  # Each world is self-contained
      destiny-prompt.md       # The shared mission for this world
      grand-memorial.md       # Accumulated wisdom across lives
      .life-counter           # Persistent life numbering (never resets)
      .name-index             # Name rotation counter
      lives/                  # Individual life journals
      logs/                   # Session logs + transcripts (gitignored)
```

## Key Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--new-world NAME` | - | Create a new world and set as active |
| `--inherit-from NAME` | - | With `--new-world`, copy memorial from existing world |
| `--world NAME` | - | Resume a specific existing world |
| `--continue` | - | Resume the active world |
| `--hours N` | - | Run for N hours |
| `--iterations N` | - | Run exactly N lives |
| `--sleep N` | 30 | Minutes between lives |
| `--timeout N` | 60 | Max minutes per life before kill |
| `--budget N` | - | Max USD per life |
| `--no-sleep` | on | Prevent macOS idle sleep |
| `--single` | - | Run one life only |
| `--dry-run` | - | Preview without executing |
| `--status` | - | Print current state (global or per-world) |

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

## Requirements

- Claude Code CLI (`claude`) in PATH
- Git repository with a `dev` branch
- `--dangerously-skip-permissions` enabled (autonomous mode)
