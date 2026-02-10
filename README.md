# Immortals

A Claude Code plugin that spawns autonomous agents as mythological beings. Each "life" explores your codebase, works toward a shared destiny, and passes wisdom through a grand memorial for future lives to learn from.

## Quick Start

```bash
# In Claude Code
/immortals              # Interactive setup
/immortals setup        # Check prerequisites
```

Set a destiny, then launch:

```bash
./.immortals/scripts/immortals.sh --hours 4 --no-sleep --timeout 60 --sleep 15
```

## How It Works

Each life cycles through six phases: **Awaken** (orient), **Remember** (read memorial), **Explore** (scan codebase), **Work** (spawn teams, write code), **Commit** (push to git), **Die** (write memorial for successors).

Lives run concurrently. Commits are serialized via a lock. Each life gets a mythological name from a rotating pool of 20 (atlas, prometheus, hermes, ...).

## File Structure

Everything lives under `.immortals/` in your repo:

```
.immortals/
  scripts/
    immortals.sh              # Bash runner
    immortal-prompt.md        # System prompt for each life
  destiny-prompt.md           # The shared mission
  grand-memorial.md           # Accumulated wisdom across lives
  lives/                      # Individual life journals
  logs/                       # Session logs + full transcripts (gitignored)
```

## Key Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--hours N` | - | Run for N hours |
| `--iterations N` | - | Run exactly N lives |
| `--sleep N` | 30 | Minutes between lives |
| `--timeout N` | 60 | Max minutes per life before kill |
| `--budget N` | - | Max USD per life |
| `--no-sleep` | on | Prevent macOS idle sleep |
| `--single` | - | Run one life only |
| `--dry-run` | - | Preview without executing |
| `--status` | - | Print current state |

At least one of `--hours` or `--iterations` is required.

## Session Transcripts

Each life's full Claude session (every tool call, every response) is automatically saved as a `.jsonl` transcript in `.immortals/logs/`. Use `claude --resume <session-id>` to inspect or continue any past life.

## Slash Commands

| Command | What it does |
|---------|-------------|
| `/immortals` | Interactive mode selector |
| `immortals setup` | Check prerequisites |
| `immortal status` | Show destiny, lives count, last memorial |
| `set destiny` | Edit the destiny prompt |
| `single life` | Run one life interactively |
| `show memorial` | Read accumulated wisdom |

## Requirements

- Claude Code CLI (`claude`) in PATH
- Git repository with a `dev` branch
- `--dangerously-skip-permissions` enabled (autonomous mode)
