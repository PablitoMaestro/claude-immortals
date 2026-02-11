#!/bin/bash

# Immortals — Autonomous Life Cycle Runner
# Spawns Claude instances that live as mythological beings,
# accumulating wisdom in a grand memorial across lives.
#
# Usage:
#   ./.immortals/scripts/immortals.sh --new-world genesis --hours 8
#   ./.immortals/scripts/immortals.sh --continue --hours 8 --no-sleep
#   ./.immortals/scripts/immortals.sh --world genesis --iterations 3
#   ./.immortals/scripts/immortals.sh --single --budget 5
#   ./.immortals/scripts/immortals.sh --agent codex --continue --hours 4
#   ./.immortals/scripts/immortals.sh --status
#   ./.immortals/scripts/immortals.sh --hours 24 --dry-run

set -o pipefail

# ─── Colors ──────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ─── Defaults ────────────────────────────────────────────────────
HOURS=""
ITERATIONS=""
SLEEP_MINUTES=30
BUDGET=""
AGENT=""
DRY_RUN=false
STATUS_MODE=false
NO_SLEEP=true
TIMEOUT_MINUTES=60
HEARTBEAT_MODE=false

# World flags
NEW_WORLD=""
INHERIT_FROM=""
WORLD_FLAG=""
CONTINUE_FLAG=false

# ─── Name Pool (20 mythological names) ──────────────────────────
NAMES=(atlas prometheus hermes minerva orpheus
       cassandra phoenix selene theseus aurora
       daedalus calliope zephyr artemis helios
       persephone icarus andromeda orion echo)

# ─── Static Paths ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMMORTALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$IMMORTALS_DIR/.." && pwd)"
PROMPT_FILE="$SCRIPT_DIR/immortal-prompt.md"
ACTIVE_FILE="$IMMORTALS_DIR/.active"
WORLDS_DIR="$IMMORTALS_DIR/worlds"
WORLDS_LOG="$IMMORTALS_DIR/worlds-log.md"

# ─── Argument Parsing ───────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours)        HOURS="$2";           shift 2 ;;
    --iterations)   ITERATIONS="$2";      shift 2 ;;
    --sleep)        SLEEP_MINUTES="$2";   shift 2 ;;
    --budget)       BUDGET="$2";          shift 2 ;;
    --dry-run)      DRY_RUN=true;         shift   ;;
    --single)       ITERATIONS=1;         shift   ;;
    --no-sleep)     NO_SLEEP=true;        shift   ;;
    --timeout)      TIMEOUT_MINUTES="$2"; shift 2 ;;
    --agent)        AGENT="$2";           shift 2 ;;
    --status)       STATUS_MODE=true;     shift   ;;
    --heartbeat)    HEARTBEAT_MODE=true;  shift   ;;
    --new-world)    NEW_WORLD="$2";       shift 2 ;;
    --inherit-from) INHERIT_FROM="$2";    shift 2 ;;
    --world)        WORLD_FLAG="$2";      shift 2 ;;
    --continue)     CONTINUE_FLAG=true;   shift   ;;
    -h|--help)
      echo "Immortals — Autonomous Life Cycle Runner"
      echo ""
      echo "Usage: ./.immortals/scripts/immortals.sh [WORLD] [OPTIONS]"
      echo ""
      echo "World flags (pick one):"
      echo "  --new-world NAME         Create a new world and set as active"
      echo "  --inherit-from NAME      With --new-world, copy memorial from existing world"
      echo "  --world NAME             Resume a specific existing world"
      echo "  --continue               Resume the active world (from .active)"
      echo "  (none)                   Auto-continue active world, or error if none"
      echo ""
      echo "Options:"
      echo "  --agent NAME     Agent engine: 'claude' or 'codex' (default: auto-detect)"
      echo "  --hours N        Run for N hours"
      echo "  --iterations N   Run exactly N cycles"
      echo "  --sleep N        Minutes between cycles (default: 30)"
      echo "  --budget N       Max USD per cycle (Claude only, optional)"
      echo "  --timeout N      Max minutes per life before kill (default: 60)"
      echo "  --no-sleep       Prevent macOS idle sleep via caffeinate"
      echo "  --dry-run        Preview without executing"
      echo "  --single         One life only (alias for --iterations 1)"
      echo "  --status         Print summary and exit"
      echo "  --heartbeat      Show who's alive right now and exit"
      echo "  -h, --help       Show this help"
      echo ""
      echo "Stopping conditions: --hours OR --iterations (at least one required,"
      echo "unless --status). If both provided, stops at whichever comes first."
      echo ""
      echo "Examples:"
      echo "  # Create a new world and start a session"
      echo "  ./immortals.sh --new-world genesis --hours 8 --no-sleep"
      echo ""
      echo "  # Continue where you left off"
      echo "  ./immortals.sh --continue --hours 4"
      echo ""
      echo "  # Start a new experiment, inherit wisdom"
      echo "  ./immortals.sh --new-world experiment --inherit-from genesis --hours 8"
      echo ""
      echo "  # Switch to specific world"
      echo "  ./immortals.sh --world genesis --iterations 3"
      echo ""
      echo "  # Use Codex instead of Claude"
      echo "  ./immortals.sh --agent codex --continue --hours 4"
      echo ""
      echo "  # Global status (all worlds)"
      echo "  ./immortals.sh --status"
      echo ""
      echo "  # Per-world status"
      echo "  ./immortals.sh --world genesis --status"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ─── Agent Selection ──────────────────────────────────────────
if [[ -z "$AGENT" ]]; then
  if command -v claude &>/dev/null; then
    AGENT="claude"
  elif command -v codex &>/dev/null; then
    AGENT="codex"
  else
    echo "Error: Neither 'claude' nor 'codex' CLI found in PATH."
    exit 1
  fi
fi

case "$AGENT" in
  claude|codex) ;;
  *)
    echo "Unknown agent: $AGENT. Use 'claude' or 'codex'."
    exit 1
    ;;
esac

# Set prompt file based on agent
if [[ "$AGENT" == "codex" ]]; then
  PROMPT_FILE="$SCRIPT_DIR/immortal-prompt-codex.md"
fi

# ─── Validate World Flag Combinations ──────────────────────────
world_flag_count=0
[[ -n "$NEW_WORLD" ]] && world_flag_count=$((world_flag_count + 1))
[[ -n "$WORLD_FLAG" ]] && world_flag_count=$((world_flag_count + 1))
$CONTINUE_FLAG && world_flag_count=$((world_flag_count + 1))

if [[ $world_flag_count -gt 1 ]]; then
  echo "Error: --new-world, --world, and --continue are mutually exclusive."
  exit 1
fi

if [[ -n "$INHERIT_FROM" && -z "$NEW_WORLD" ]]; then
  echo "Error: --inherit-from requires --new-world."
  exit 1
fi

# ─── Legacy Migration ──────────────────────────────────────────
migrate_legacy() {
  echo -e "${YELLOW}Detected legacy .immortals/ structure (no worlds/).${NC}"
  echo "  Migrating to worlds/legacy/..."

  local legacy_dir="$WORLDS_DIR/legacy"
  mkdir -p "$legacy_dir/lives" "$legacy_dir/logs"

  # Move lives
  if [[ -d "$IMMORTALS_DIR/lives" ]]; then
    if compgen -G "$IMMORTALS_DIR/lives/*" > /dev/null 2>&1; then
      mv "$IMMORTALS_DIR/lives"/* "$legacy_dir/lives/" 2>/dev/null || true
    fi
    rmdir "$IMMORTALS_DIR/lives" 2>/dev/null || true
  fi

  # Move logs
  if [[ -d "$IMMORTALS_DIR/logs" ]]; then
    if compgen -G "$IMMORTALS_DIR/logs/*" > /dev/null 2>&1; then
      mv "$IMMORTALS_DIR/logs"/* "$legacy_dir/logs/" 2>/dev/null || true
    fi
    rmdir "$IMMORTALS_DIR/logs" 2>/dev/null || true
  fi

  # Move memorial
  if [[ -f "$IMMORTALS_DIR/grand-memorial.md" ]]; then
    mv "$IMMORTALS_DIR/grand-memorial.md" "$legacy_dir/grand-memorial.md"
  fi

  # Move destiny
  if [[ -f "$IMMORTALS_DIR/destiny-prompt.md" ]]; then
    mv "$IMMORTALS_DIR/destiny-prompt.md" "$legacy_dir/destiny-prompt.md"
  fi

  # Move name index
  if [[ -f "$IMMORTALS_DIR/.name-index" ]]; then
    mv "$IMMORTALS_DIR/.name-index" "$legacy_dir/.name-index"
  fi

  # Compute life counter from existing lives
  local highest=0
  local count=0
  if [[ -d "$legacy_dir/lives" ]]; then
    for f in "$legacy_dir/lives"/*.md; do
      [[ -f "$f" ]] || continue
      count=$((count + 1))
      local base
      base=$(basename "$f")
      local num
      num=$(echo "$base" | grep -o '^[0-9]\+' | sed 's/^0*//')
      num=${num:-0}
      if [[ "$num" -gt "$highest" ]] 2>/dev/null; then
        highest=$num
      fi
    done
  fi
  local counter=$highest
  if [[ $count -gt $counter ]]; then
    counter=$count
  fi
  echo "$counter" > "$legacy_dir/.life-counter"

  # Set active world
  echo "legacy" > "$ACTIVE_FILE"

  # Create worlds log
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  cat > "$WORLDS_LOG" << WLOG_EOF
# Worlds Log

> Chronicle of all immortal worlds.

---

## legacy — ${timestamp}

**Inherited from**: (migrated from legacy structure)

---
WLOG_EOF

  echo -e "${GREEN}Migration complete:${NC}"
  echo "  World: legacy"
  echo "  Lives: $count"
  echo "  Life counter: $counter"
  echo "  Active world set to: legacy"
  echo ""
}

# Check for legacy structure and migrate
if [[ -d "$IMMORTALS_DIR/lives" && ! -d "$WORLDS_DIR" ]]; then
  migrate_legacy
fi

# ─── World Resolution ──────────────────────────────────────────
WORLD_NAME=""

if [[ -n "$NEW_WORLD" ]]; then
  # Validate name format
  if ! [[ "$NEW_WORLD" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Error: World name must match [a-z0-9][a-z0-9-]* (lowercase, numbers, hyphens)."
    echo "  Got: '$NEW_WORLD'"
    exit 1
  fi

  # Check for duplicate
  if [[ -d "$WORLDS_DIR/$NEW_WORLD" ]]; then
    echo "Error: World '$NEW_WORLD' already exists. Use --world $NEW_WORLD to resume it."
    exit 1
  fi

  # Create the world
  WORLD_NAME="$NEW_WORLD"
  new_world_dir="$WORLDS_DIR/$WORLD_NAME"
  mkdir -p "$new_world_dir/lives" "$new_world_dir/logs"

  echo "0" > "$new_world_dir/.life-counter"
  echo "0" > "$new_world_dir/.name-index"

  # Memorial: inherit or fresh
  if [[ -n "$INHERIT_FROM" ]]; then
    source_dir="$WORLDS_DIR/$INHERIT_FROM"
    if [[ ! -d "$source_dir" ]]; then
      echo "Error: Source world '$INHERIT_FROM' does not exist. Cannot inherit."
      rm -rf "$new_world_dir"
      exit 1
    fi
    if [[ -f "$source_dir/grand-memorial.md" ]]; then
      cp "$source_dir/grand-memorial.md" "$new_world_dir/grand-memorial.md"
      echo "  Inherited memorial from '$INHERIT_FROM'."
    else
      echo "  Warning: Source world '$INHERIT_FROM' has no memorial. Creating fresh."
      cat > "$new_world_dir/grand-memorial.md" << 'MEMORIAL_EOF'
# Grand Memorial

> Wisdom accumulated across all immortal lives.
> Each life adds its reflections here for future lives to learn from.

---
MEMORIAL_EOF
    fi
  else
    cat > "$new_world_dir/grand-memorial.md" << 'MEMORIAL_EOF'
# Grand Memorial

> Wisdom accumulated across all immortal lives.
> Each life adds its reflections here for future lives to learn from.

---
MEMORIAL_EOF
  fi

  # Create empty destiny template
  cat > "$new_world_dir/destiny-prompt.md" << 'DESTINY_EOF'
# Destiny

> Define the mission for this world's immortals.
> Edit this file to set the purpose that guides all lives.

(Write your destiny here)
DESTINY_EOF

  # Set as active world
  echo "$WORLD_NAME" > "$ACTIVE_FILE"

  # Append to worlds log
  if [[ ! -f "$WORLDS_LOG" ]]; then
    cat > "$WORLDS_LOG" << 'WLOG_HEADER_EOF'
# Worlds Log

> Chronicle of all immortal worlds.

---
WLOG_HEADER_EOF
  fi

  wlog_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  {
    echo ""
    echo "## ${WORLD_NAME} — ${wlog_timestamp}"
    echo ""
    if [[ -n "$INHERIT_FROM" ]]; then
      echo "**Inherited from**: ${INHERIT_FROM}"
    else
      echo "**Inherited from**: (none)"
    fi
    echo ""
    echo "---"
  } >> "$WORLDS_LOG"

  echo -e "${GREEN}Created world '${WORLD_NAME}'.${NC}"
  [[ -n "$INHERIT_FROM" ]] && echo "  Inherited memorial from: $INHERIT_FROM"
  echo ""

elif [[ -n "$WORLD_FLAG" ]]; then
  # Resume specific world
  if [[ ! -d "$WORLDS_DIR/$WORLD_FLAG" ]]; then
    echo "Error: World '$WORLD_FLAG' does not exist."
    echo "Available worlds:"
    if [[ -d "$WORLDS_DIR" ]]; then
      for d in "$WORLDS_DIR"/*/; do
        [[ -d "$d" ]] && echo "  - $(basename "$d")"
      done
    else
      echo "  (none)"
    fi
    exit 1
  fi
  WORLD_NAME="$WORLD_FLAG"
  echo "$WORLD_NAME" > "$ACTIVE_FILE"

elif $CONTINUE_FLAG; then
  # Resume active world
  if [[ ! -f "$ACTIVE_FILE" ]] || [[ -z "$(cat "$ACTIVE_FILE" 2>/dev/null)" ]]; then
    echo "Error: No active world. Use --new-world NAME to create one."
    exit 1
  fi
  WORLD_NAME=$(cat "$ACTIVE_FILE")
  if [[ ! -d "$WORLDS_DIR/$WORLD_NAME" ]]; then
    echo "Error: Active world '$WORLD_NAME' no longer exists."
    echo "Available worlds:"
    if [[ -d "$WORLDS_DIR" ]]; then
      for d in "$WORLDS_DIR"/*/; do
        [[ -d "$d" ]] && echo "  - $(basename "$d")"
      done
    fi
    exit 1
  fi

else
  # No world flag: implicit continue if .active exists, or global status
  if $STATUS_MODE; then
    # Bare --status (no explicit --world) = always global summary
    WORLD_NAME=""
  elif [[ -f "$ACTIVE_FILE" ]] && [[ -n "$(cat "$ACTIVE_FILE" 2>/dev/null)" ]]; then
    WORLD_NAME=$(cat "$ACTIVE_FILE")
    if [[ ! -d "$WORLDS_DIR/$WORLD_NAME" ]]; then
      echo "Error: Active world '$WORLD_NAME' no longer exists."
      echo "Available worlds:"
      if [[ -d "$WORLDS_DIR" ]]; then
        for d in "$WORLDS_DIR"/*/; do
          [[ -d "$d" ]] && echo "  - $(basename "$d")"
        done
      fi
      exit 1
    fi
  else
    echo "Error: No active world. Use one of:"
    echo "  --new-world NAME    Create a new world"
    echo "  --world NAME        Resume an existing world"
    echo "  --continue          Resume the active world"
    exit 1
  fi
fi

# ─── Dynamic Paths (world-scoped) ──────────────────────────────
if [[ -n "$WORLD_NAME" ]]; then
  WORLD_DIR="$WORLDS_DIR/$WORLD_NAME"
  DESTINY_FILE="$WORLD_DIR/destiny-prompt.md"
  MEMORIAL_FILE="$WORLD_DIR/grand-memorial.md"
  LIVES_DIR="$WORLD_DIR/lives"
  LOG_DIR="$WORLD_DIR/logs"
  NAME_INDEX_FILE="$WORLD_DIR/.name-index"
  LIFE_COUNTER_FILE="$WORLD_DIR/.life-counter"
  HEARTBEAT_FILE="$WORLD_DIR/.heartbeat"
fi

# ─── Heartbeat: Track living immortals ────────────────────────────
# Format per line: name|pid|timestamp|agent
heartbeat_add() {
  local name="$1" pid="$2"
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "${name}|${pid}|${ts}|${AGENT}" >> "$HEARTBEAT_FILE"
}

heartbeat_remove() {
  local name="$1"
  if [[ -f "$HEARTBEAT_FILE" ]]; then
    local tmp="${HEARTBEAT_FILE}.tmp"
    grep -v "^${name}|" "$HEARTBEAT_FILE" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$HEARTBEAT_FILE"
    # Remove file if empty
    [[ ! -s "$HEARTBEAT_FILE" ]] && rm -f "$HEARTBEAT_FILE"
  fi
}

heartbeat_prune() {
  # Remove entries whose PIDs are no longer running
  [[ -f "$HEARTBEAT_FILE" ]] || return 0
  local tmp="${HEARTBEAT_FILE}.tmp"
  while IFS='|' read -r name pid ts agent; do
    if kill -0 "$pid" 2>/dev/null; then
      echo "${name}|${pid}|${ts}|${agent}"
    fi
  done < "$HEARTBEAT_FILE" > "$tmp"
  mv "$tmp" "$HEARTBEAT_FILE"
  [[ ! -s "$HEARTBEAT_FILE" ]] && rm -f "$HEARTBEAT_FILE"
}

heartbeat_show() {
  heartbeat_prune
  if [[ ! -f "$HEARTBEAT_FILE" ]] || [[ ! -s "$HEARTBEAT_FILE" ]]; then
    echo -e "${CYAN}Alive:${NC}          (none)"
    return
  fi
  local count
  count=$(wc -l < "$HEARTBEAT_FILE" | tr -d ' ')
  echo -e "${CYAN}Alive:${NC}          ${count} immortal(s)"
  while IFS='|' read -r name pid ts agent; do
    local now_s
    now_s=$(date +%s)
    local born_s
    born_s=$(date -j -f '%Y-%m-%d %H:%M:%S' "$ts" +%s 2>/dev/null || date -d "$ts" +%s 2>/dev/null || echo "$now_s")
    local elapsed=$(( now_s - born_s ))
    local mins=$(( elapsed / 60 ))
    echo -e "                  ${BOLD}${name}${NC}  (${agent})  alive ${mins}m  PID ${pid}"
  done < "$HEARTBEAT_FILE"
}

# ─── Heartbeat Mode ─────────────────────────────────────────────
if $HEARTBEAT_MODE; then
  if [[ -z "$WORLD_NAME" ]]; then
    # Show heartbeat for all worlds
    echo ""
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo -e " ${BOLD}Heartbeat — All Worlds${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
    found_any=false
    for world_dir in "$WORLDS_DIR"/*/; do
      [[ -d "$world_dir" ]] || continue
      local_hb="${world_dir}.heartbeat"
      [[ -f "$local_hb" ]] || continue
      local_world=$(basename "$world_dir")
      # Prune stale entries inline
      local_tmp="${local_hb}.tmp"
      while IFS='|' read -r name pid ts agent; do
        kill -0 "$pid" 2>/dev/null && echo "${name}|${pid}|${ts}|${agent}"
      done < "$local_hb" > "$local_tmp"
      mv "$local_tmp" "$local_hb"
      [[ ! -s "$local_hb" ]] && { rm -f "$local_hb"; continue; }
      found_any=true
      local_count=$(wc -l < "$local_hb" | tr -d ' ')
      echo ""
      echo -e "  ${BOLD}${local_world}${NC} — ${local_count} alive"
      while IFS='|' read -r name pid ts agent; do
        echo -e "    ${name}  (${agent})  PID ${pid}  since ${ts}"
      done < "$local_hb"
    done
    if ! $found_any; then
      echo ""
      echo -e "  ${DIM}No immortals are currently alive.${NC}"
    fi
    echo ""
    echo -e "${BOLD}${BLUE}============================================${NC}"
  else
    # Show heartbeat for specific world
    echo ""
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo -e " ${BOLD}Heartbeat — ${WORLD_NAME}${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo ""
    heartbeat_show
    echo ""
    echo -e "${BOLD}${BLUE}============================================${NC}"
  fi
  exit 0
fi

# ─── Status Mode ────────────────────────────────────────────────
if $STATUS_MODE; then
  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"

  if [[ -z "$WORLD_NAME" ]]; then
    # Global status: list all worlds
    echo -e " ${BOLD}Immortals — Global Status${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo ""

    active_world=""
    if [[ -f "$ACTIVE_FILE" ]]; then
      active_world=$(cat "$ACTIVE_FILE" 2>/dev/null)
    fi

    if [[ ! -d "$WORLDS_DIR" ]] || [[ -z "$(ls -A "$WORLDS_DIR" 2>/dev/null)" ]]; then
      echo "  No worlds yet. Create one with: --new-world NAME"
    else
      echo -e "${CYAN}Worlds:${NC}"
      echo ""
      for d in "$WORLDS_DIR"/*/; do
        [[ -d "$d" ]] || continue
        wname=$(basename "$d")
        wlives=0
        if [[ -d "$d/lives" ]]; then
          wlives=$(find "$d/lives" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
        fi
        wcounter=0
        if [[ -f "$d/.life-counter" ]]; then
          wcounter=$(cat "$d/.life-counter" 2>/dev/null || echo 0)
        fi
        marker=""
        if [[ "$wname" == "$active_world" ]]; then
          marker=" ${GREEN}<- active${NC}"
        fi
        echo -e "  ${BOLD}${wname}${NC}  (${wlives} lives, counter: ${wcounter})${marker}"
      done
    fi

    echo ""
    echo -e "${BOLD}${BLUE}============================================${NC}"
    exit 0
  fi

  # Per-world status
  echo -e " ${BOLD}Immortals — Status Report [${WORLD_NAME}]${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""

  echo -e "${CYAN}World:${NC}          $WORLD_NAME"
  echo ""

  # Destiny summary
  echo -e "${CYAN}Destiny:${NC}"
  if [[ -f "$DESTINY_FILE" ]]; then
    grep -v '^#' "$DESTINY_FILE" | grep -v '^\s*$' | head -5 | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo "  (no destiny file found)"
  fi
  echo ""

  # Lives count
  status_lives_count=0
  status_last_life="(none)"
  if [[ -d "$LIVES_DIR" ]]; then
    status_lives_count=$(find "$LIVES_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    status_last_file=$(ls -t "$LIVES_DIR"/*.md 2>/dev/null | head -1)
    if [[ -n "$status_last_file" ]]; then
      status_last_life=$(basename "$status_last_file" .md)
    fi
  fi
  echo -e "${CYAN}Lives:${NC}          $status_lives_count"
  echo -e "${CYAN}Last Life:${NC}      $status_last_life"

  # Life counter
  status_counter=0
  if [[ -f "$LIFE_COUNTER_FILE" ]]; then
    status_counter=$(cat "$LIFE_COUNTER_FILE" 2>/dev/null || echo 0)
  fi
  echo -e "${CYAN}Life Counter:${NC}   $status_counter"
  echo ""

  # Memorial entry count
  status_memorial_count=0
  if [[ -f "$MEMORIAL_FILE" ]]; then
    status_memorial_count=$(grep -c '^## Life of' "$MEMORIAL_FILE" 2>/dev/null) || status_memorial_count=0
  fi
  echo -e "${CYAN}Memorial Entries:${NC}  $status_memorial_count"

  # Last memorial entry
  if [[ -f "$MEMORIAL_FILE" ]] && [[ "$status_memorial_count" -gt 0 ]]; then
    echo ""
    echo -e "${CYAN}Last Memorial Entry:${NC}"
    awk '/^## Life of/{block=""} /^## Life of/{found=1} found{block=block $0 "\n"} END{printf "%s", block}' "$MEMORIAL_FILE" | head -15 | while IFS= read -r line; do
      echo "  $line"
    done
  fi

  # Name index
  echo ""
  status_name_idx=0
  if [[ -f "$NAME_INDEX_FILE" ]]; then
    status_name_idx=$(cat "$NAME_INDEX_FILE" 2>/dev/null || echo 0)
  fi
  status_next_name="${NAMES[$((status_name_idx % 20))]}"
  echo -e "${CYAN}Next Name:${NC}      $status_next_name (index $status_name_idx)"

  # Heartbeat: who's alive right now
  echo ""
  heartbeat_show

  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"
  exit 0
fi

# ─── Validate Arguments ─────────────────────────────────────────
if [[ -z "$HOURS" && -z "$ITERATIONS" ]]; then
  echo "Error: Must provide --hours N or --iterations N (or both)."
  echo "Run with --help for usage."
  exit 1
fi

# ─── Verify Prerequisites ───────────────────────────────────────
cd "$REPO_ROOT"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: System prompt not found at $PROMPT_FILE"
  exit 1
fi

if [[ ! -f "$DESTINY_FILE" ]]; then
  echo "Error: Destiny prompt not found at $DESTINY_FILE"
  exit 1
fi

if ! command -v "$AGENT" &>/dev/null; then
  echo "Error: '$AGENT' CLI not found in PATH"
  exit 1
fi

# ─── Prevent macOS Sleep (if requested) ────────────────────────
CAFFEINE_PID=""
if $NO_SLEEP; then
  if command -v caffeinate &>/dev/null; then
    caffeinate -dims -w $$ &
    CAFFEINE_PID=$!
    echo -e "${GREEN}Sleep prevention active${NC} (caffeinate PID: $CAFFEINE_PID)"
    echo "  Note: lid-close still sleeps unless in clamshell mode (power + external display)"
  else
    echo -e "${YELLOW}Warning: caffeinate not found — --no-sleep has no effect${NC}"
  fi
fi

# ─── Initialize Directories ─────────────────────────────────────
mkdir -p "$LOG_DIR"
mkdir -p "$LIVES_DIR"

# Initialize name index if missing
if [[ ! -f "$NAME_INDEX_FILE" ]]; then
  echo "0" > "$NAME_INDEX_FILE"
fi

# Initialize life counter if missing
if [[ ! -f "$LIFE_COUNTER_FILE" ]]; then
  echo "0" > "$LIFE_COUNTER_FILE"
fi

# ─── Concurrent Execution State ──────────────────────────────────
COMMIT_LOCK="$IMMORTALS_DIR/.commit-lock"
rmdir "$COMMIT_LOCK" 2>/dev/null || true  # Clean up stale lock
heartbeat_prune  # Remove stale entries from crashed sessions
LIFE_PIDS=()

# ─── Cleanup Trap ────────────────────────────────────────────────
cleanup_immortals() {
  for pid in "${LIFE_PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  rmdir "$COMMIT_LOCK" 2>/dev/null || true
  rm -f "$HEARTBEAT_FILE" 2>/dev/null || true  # All lives end when runner exits
}
trap cleanup_immortals EXIT

# Initialize grand memorial if missing
if [[ ! -f "$MEMORIAL_FILE" ]]; then
  cat > "$MEMORIAL_FILE" << 'MEMORIAL_EOF'
# Grand Memorial

> Wisdom accumulated across all immortal lives.
> Each life adds its reflections here for future lives to learn from.

---
MEMORIAL_EOF
  echo "Initialized $MEMORIAL_FILE"
fi

# ─── Calculate Stopping Conditions ──────────────────────────────
START_TIME=$(date +%s)
SESSION_ID="$$-${START_TIME}"
END_TIME=9999999999  # far future default

if [[ -n "$HOURS" ]]; then
  DURATION_SECS=$((HOURS * 3600))
  END_TIME=$((START_TIME + DURATION_SECS))
fi

MAX_ITERATIONS=${ITERATIONS:-999999}  # effectively infinite if not set
SLEEP_SECS=$((SLEEP_MINUTES * 60))
TIMEOUT_SECS=$((TIMEOUT_MINUTES * 60))

# Dry-run: cap at 1 cycle (preview only) and preserve counters
if $DRY_RUN; then
  [[ -z "$ITERATIONS" ]] && MAX_ITERATIONS=1
  _DRY_COUNTER=$(cat "$LIFE_COUNTER_FILE" 2>/dev/null)
  _DRY_NAME_IDX=$(cat "$NAME_INDEX_FILE" 2>/dev/null)
fi

# ─── Print Configuration ────────────────────────────────────────
echo -e "${BOLD}${BLUE}============================================${NC}"
echo -e " ${BOLD}Immortals — Autonomous Life Cycle Runner${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}"
echo ""
echo "Configuration:"
echo "  Agent:      $AGENT"
echo "  World:      $WORLD_NAME"
echo "  World dir:  $WORLD_DIR/"
[[ -n "$HOURS" ]]     && echo "  Hours:      $HOURS (until $(date -r $END_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d @$END_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'N/A'))"
[[ -n "$ITERATIONS" ]] && echo "  Iterations: $ITERATIONS"
echo "  Sleep:      ${SLEEP_MINUTES}m between cycles"
echo "  Timeout:    ${TIMEOUT_MINUTES}m per life"
[[ -n "$BUDGET" ]]    && echo "  Budget:     \$$BUDGET per cycle"
$NO_SLEEP             && echo "  No-sleep:   caffeinate active"
$DRY_RUN              && echo "  Mode:       DRY RUN (no execution)"
echo "  Logs:       $LOG_DIR/"
echo ""
echo "State files:"
echo "  System prompt:   $PROMPT_FILE"
echo "  Destiny:         $DESTINY_FILE"
echo "  Grand memorial:  $MEMORIAL_FILE"
echo "  Lives dir:       $LIVES_DIR/"
echo "  Life counter:    $LIFE_COUNTER_FILE"
echo ""
echo -e "${BOLD}${BLUE}============================================${NC}"
echo ""

# ─── Helper: Generate UUID (cross-platform) ──────────────────────
generate_uuid() {
  uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' && return
  python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null && return
  cat /proc/sys/kernel/random/uuid 2>/dev/null && return
  # Last resort: bash pseudo-random hex (not RFC 4122 but unique enough)
  printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x\n' \
    $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM $RANDOM
}

# ─── Helper: Persistent life counter ─────────────────────────────
next_life_number() {
  local counter_file="$1"
  local lock_dir="${counter_file}.lock"

  # Atomic lock via mkdir (macOS-safe, same pattern as COMMIT_LOCK)
  local lock_wait=0
  while ! mkdir "$lock_dir" 2>/dev/null; do
    sleep 0.1
    lock_wait=$((lock_wait + 1))
    if [[ $lock_wait -ge 100 ]]; then
      echo "Error: life counter lock timeout" >&2
      rmdir "$lock_dir" 2>/dev/null || true
      return 1
    fi
  done

  local current
  current=$(cat "$counter_file" 2>/dev/null || echo 0)
  if ! [[ "$current" =~ ^[0-9]+$ ]]; then
    current=0
  fi

  local next=$((current + 1))
  echo "$next" > "$counter_file"

  rmdir "$lock_dir" 2>/dev/null || true
  echo "$next"
}

# ─── Helper: Copy full session transcript to logs ─────────────────
copy_transcript() {
  local name="$1"
  local life_uuid="$2"
  local life_seq="$3"

  # Only Claude stores session transcripts as .jsonl files
  if [[ "$AGENT" != "claude" || -z "$life_uuid" ]]; then
    return 0
  fi

  local transcript
  transcript=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${life_uuid}.jsonl" 2>/dev/null | head -1)

  if [[ -n "$transcript" && -f "$transcript" ]]; then
    cp "$transcript" "$LOG_DIR/${life_seq}-${name}-transcript.jsonl"
    local size
    size=$(du -h "$transcript" | cut -f1)
    echo -e "  ${GREEN}Full transcript saved:${NC} $LOG_DIR/${life_seq}-${name}-transcript.jsonl (${size})"
  else
    echo -e "  ${YELLOW}Warning: transcript not found for session ${life_uuid}${NC}"
  fi
}

# ─── Helper: Pick next name from pool ───────────────────────────
pick_name() {
  local idx
  idx=$(cat "$NAME_INDEX_FILE" 2>/dev/null || echo 0)

  # Ensure idx is a valid number
  if ! [[ "$idx" =~ ^[0-9]+$ ]]; then
    idx=0
  fi

  local name="${NAMES[$((idx % 20))]}"

  # Increment and write back
  local next_idx=$((idx + 1))
  echo "$next_idx" > "$NAME_INDEX_FILE"

  echo "$name"
}

# ─── Helper: Build prompt for a life ────────────────────────────
build_prompt() {
  local name="$1"
  local life_file="$2"

  local prompt=""

  prompt+="# Immortal Life Cycle"
  prompt+=$'\n\n'
  prompt+="**You are ${name}.**"
  prompt+=$'\n'
  prompt+="**World**: ${WORLD_NAME}"
  prompt+=$'\n\n'

  # Paths — the system prompt tells the agent when to read each file
  prompt+="## Paths"
  prompt+=$'\n\n'
  prompt+="- **Life file** (create here): \`${life_file}\`"
  prompt+=$'\n'
  prompt+="- **Destiny**: \`${DESTINY_FILE}\`"
  prompt+=$'\n'
  prompt+="- **Grand Memorial**: \`${MEMORIAL_FILE}\`"
  prompt+=$'\n'

  # Recent lives (just paths, agent reads them in Phase 2)
  local recent_files
  recent_files=$(ls -t "$LIVES_DIR"/*.md 2>/dev/null | head -3)
  if [[ -n "$recent_files" ]]; then
    prompt+="- **Recent lives**:"
    prompt+=$'\n'
    while IFS= read -r file; do
      prompt+="  - \`${file}\`"
      prompt+=$'\n'
    done <<< "$recent_files"
  else
    prompt+="- **Recent lives**: (none — you are the first)"
    prompt+=$'\n'
  fi

  prompt+=$'\n'
  prompt+="Now begin. Follow the six phases in your system prompt."
  prompt+=$'\n'

  echo "$prompt"
}

# ─── Helper: Extract memorial from life file ────────────────────
extract_memorial() {
  local name="$1"
  local life_file="$2"

  if [[ ! -f "$life_file" ]]; then
    echo "  Warning: Life file not found at $life_file — skipping memorial extraction."
    return 1
  fi

  # Extract text between <memorial> and </memorial> tags
  local memorial_text
  memorial_text=$(sed -n '/<memorial>/,/<\/memorial>/{ /<memorial>/d; /<\/memorial>/d; p; }' "$life_file")

  if [[ -z "$memorial_text" ]]; then
    echo "  Warning: No <memorial> tags found in life file — skipping memorial extraction."
    return 1
  fi

  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # Append to grand memorial
  {
    echo ""
    echo "## Life of ${name} — ${timestamp}"
    echo ""
    echo "$memorial_text"
    echo ""
    echo "---"
  } >> "$MEMORIAL_FILE"

  echo "  Memorial extracted for ${name} and appended to grand-memorial.md."
  return 0
}

# ─── Helper: Trim memorial to prevent bloat ──────────────────────
trim_memorial() {
  local max_lines=500
  local header_lines=5
  local keep_lines=$((max_lines - header_lines))

  if [[ ! -f "$MEMORIAL_FILE" ]]; then
    return 0
  fi

  local line_count
  line_count=$(wc -l < "$MEMORIAL_FILE")

  if [[ $line_count -gt $max_lines ]]; then
    echo "  Trimming grand-memorial.md ($line_count lines -> keeping header + last $keep_lines)..."
    {
      head -n "$header_lines" "$MEMORIAL_FILE"
      echo ""
      echo "> [Trimmed: older entries removed to prevent bloat]"
      echo ""
      tail -n "$keep_lines" "$MEMORIAL_FILE"
    } > "${MEMORIAL_FILE}.tmp"
    mv "${MEMORIAL_FILE}.tmp" "$MEMORIAL_FILE"
  fi
}

# ─── Helper: Auto-commit if changes exist ────────────────────────
auto_commit() {
  local name="$1"
  local max_retries=2

  cd "$REPO_ROOT"

  # Check for changes (staged or unstaged or untracked)
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    echo "  Auto-committing changes..."
    git add -A

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    git commit -m "chore(immortals): life of ${name} [${WORLD_NAME}] — ${timestamp}

Automated commit from immortals.sh (session ${SESSION_ID})

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>" || true

    # Push with retry — handles concurrent sessions
    local attempt=0
    while [[ $attempt -lt $max_retries ]]; do
      if git push origin dev 2>/dev/null; then
        echo "  Pushed to origin/dev successfully."
        return 0
      fi
      attempt=$((attempt + 1))
      echo "  Push failed (attempt $attempt/$max_retries) — pulling with rebase..."
      git pull --rebase origin dev || {
        echo "  Warning: rebase conflict. Attempting to continue..."
        git add -A
        git rebase --continue 2>/dev/null || git rebase --abort 2>/dev/null || true
      }
    done
    echo "  Warning: push failed after $max_retries retries — will retry next cycle."
  else
    echo "  No changes to commit."
  fi
}

# ─── Helper: Run a life in the background with timeout ───────────
run_life_async() {
  local name="$1"
  local life_file="$2"
  local log_file="$3"
  local user_prompt="$4"
  local life_uuid="$5"
  local life_seq="$6"

  # Run agent with timeout (subshell + watchdog pattern for macOS)
  # Agent output goes to log file only — read life files for results
  if [[ "$AGENT" == "codex" ]]; then
    # Codex: prepend system prompt to stdin (no --system-prompt flag)
    ({ cat "$PROMPT_FILE"; echo -e "\n\n---\n\n"; echo "$user_prompt"; } | "${AGENT_CMD[@]}" > "$log_file" 2>&1) &
  else
    (echo "$user_prompt" | "${AGENT_CMD[@]}" > "$log_file" 2>&1) &
  fi
  local claude_pid=$!

  # Register in heartbeat (alive tracker)
  heartbeat_add "${life_seq}-${name}" "$claude_pid"

  # Watchdog: kill agent if it exceeds timeout
  (
    sleep "$TIMEOUT_SECS"
    kill -TERM "$claude_pid" 2>/dev/null
    sleep 10
    kill -KILL "$claude_pid" 2>/dev/null
  ) &
  local watchdog_pid=$!

  # Wait for agent to finish (or be killed)
  wait "$claude_pid" 2>/dev/null
  local exit_code=$?

  # Clean up watchdog
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null 2>&1

  echo ""
  if [[ $exit_code -eq 143 || $exit_code -eq 137 ]]; then
    echo -e "  ${RED}Life of ${name} timed out after ${TIMEOUT_MINUTES}m — moving on.${NC}"
  elif [[ $exit_code -ne 0 ]]; then
    echo -e "  ${RED}Warning: ${name} exited with code $exit_code${NC}"
  else
    echo -e "  ${GREEN}Life of ${name} completed successfully.${NC}"
  fi

  # Remove from heartbeat (life ended)
  heartbeat_remove "${life_seq}-${name}"

  # Post-life processing
  extract_memorial "$name" "$life_file"
  trim_memorial
  copy_transcript "$name" "$life_uuid" "$life_seq"

  # Commit with lock (serialize concurrent commits via mkdir atomicity)
  local lock_wait=0
  while ! mkdir "$COMMIT_LOCK" 2>/dev/null; do
    sleep 2
    lock_wait=$((lock_wait + 2))
    if [[ $lock_wait -ge 120 ]]; then
      echo -e "  ${RED}Warning: commit lock timeout for ${name} — skipping commit${NC}"
      return 1
    fi
  done
  auto_commit "$name"
  rmdir "$COMMIT_LOCK" 2>/dev/null || true
}

# ─── Main Loop ──────────────────────────────────────────────────
CYCLE=0

while true; do
  CYCLE=$((CYCLE + 1))
  NOW=$(date +%s)
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  # ── Check stopping conditions ──
  if [[ $NOW -ge $END_TIME ]]; then
    echo "Time limit reached. Stopping."
    break
  fi

  if [[ $CYCLE -gt $MAX_ITERATIONS ]]; then
    echo "Iteration limit reached. Stopping."
    break
  fi

  # ── Remaining time display ──
  REMAINING=""
  if [[ -n "$HOURS" ]]; then
    local_remaining=$((END_TIME - NOW))
    rem_h=$((local_remaining / 3600))
    rem_m=$(((local_remaining % 3600) / 60))
    REMAINING=" (${rem_h}h ${rem_m}m remaining)"
  fi

  # ── Pick a name and get persistent life number ──
  CURRENT_NAME=$(pick_name)
  LIFE_NUM=$(next_life_number "$LIFE_COUNTER_FILE")
  LIFE_SEQ=$(printf "%03d" "$LIFE_NUM")
  LIFE_FILE="$LIVES_DIR/${LIFE_SEQ}-${CURRENT_NAME}.md"

  echo -e "${BOLD}${BLUE}────────────────────────────────────────────${NC}"
  echo -e " Cycle $CYCLE / $MAX_ITERATIONS | ${TIMESTAMP}${REMAINING}"
  echo -e " ${CYAN}World: ${BOLD}${WORLD_NAME}${NC} | Life ${BOLD}#${LIFE_NUM}${NC}"
  echo -e " ${CYAN}Life of ${BOLD}${CURRENT_NAME}${NC}"
  echo -e "${BOLD}${BLUE}────────────────────────────────────────────${NC}"

  # ── Build prompt ──
  USER_PROMPT=$(build_prompt "$CURRENT_NAME" "$LIFE_FILE")

  # ── Generate session UUID for transcript tracking ──
  LIFE_UUID=$(generate_uuid)

  # ── Build agent command ──
  case "$AGENT" in
    claude)
      AGENT_CMD=(
        claude
        -p
        --dangerously-skip-permissions
        --model opus
        --session-id "$LIFE_UUID"
        --system-prompt "$(cat "$PROMPT_FILE")"
      )
      [[ -n "$BUDGET" ]] && AGENT_CMD+=(--max-budget-usd "$BUDGET")
      ;;
    codex)
      AGENT_CMD=(
        codex exec -
        --full-auto
        --model gpt-5.3-codex
      )
      ;;
  esac

  LOG_FILE="$LOG_DIR/${LIFE_SEQ}-${CURRENT_NAME}-$(date '+%Y%m%d-%H%M%S').log"

  if $DRY_RUN; then
    echo ""
    echo "  [DRY RUN] Would execute:"
    if [[ "$AGENT" == "claude" ]]; then
      echo "    claude -p --dangerously-skip-permissions --model opus \\"
      echo "      --session-id $LIFE_UUID \\"
      echo "      --system-prompt <immortal-prompt.md> \\"
      [[ -n "$BUDGET" ]] && echo "      --max-budget-usd $BUDGET \\"
      echo "      <prompt with destiny + memorial + recent lives>"
    else
      echo "    codex exec - --full-auto --model gpt-5.3-codex \\"
      echo "      <system-prompt + prompt with destiny + memorial + recent lives>"
    fi
    echo ""
    echo "  Agent:       $AGENT"
    echo "  Name:        $CURRENT_NAME"
    echo "  World:       $WORLD_NAME"
    echo "  Life #:      $LIFE_NUM"
    echo "  Session:     $LIFE_UUID"
    echo "  Life file:   $LIFE_FILE"
    echo "  Prompt size: $(echo "$USER_PROMPT" | wc -c | tr -d ' ') bytes"
    echo "  Log:         $LOG_FILE"
    echo ""
  else
    echo "  Spawning life of ${CURRENT_NAME}..."
    echo ""

    # Run life in background (handles timeout, memorial, commit internally)
    run_life_async "$CURRENT_NAME" "$LIFE_FILE" "$LOG_FILE" "$USER_PROMPT" "$LIFE_UUID" "$LIFE_SEQ" &
    LIFE_PIDS+=($!)
  fi

  # ── Check if we should continue ──
  NEXT_CYCLE=$((CYCLE + 1))
  if [[ $NEXT_CYCLE -gt $MAX_ITERATIONS ]]; then
    echo "Next cycle would exceed iteration limit. Stopping."
    break
  fi

  WAKE_TIME=$(($(date +%s) + SLEEP_SECS))
  if [[ -n "$HOURS" && $WAKE_TIME -ge $END_TIME ]]; then
    echo "Not enough time for another cycle. Stopping."
    break
  fi

  # ── Sleep between cycles ──
  if ! $DRY_RUN && [[ $SLEEP_SECS -gt 0 ]]; then
    echo ""
    echo -e "  ${DIM}Sleeping ${SLEEP_MINUTES}m until next life...${NC}"
    sleep "$SLEEP_SECS"
  fi
done

# ─── Restore Counters After Dry Run ──────────────────────────────
if $DRY_RUN && [[ -n "$_DRY_COUNTER" ]]; then
  echo "$_DRY_COUNTER" > "$LIFE_COUNTER_FILE"
  echo "$_DRY_NAME_IDX" > "$NAME_INDEX_FILE"
fi

# ─── Wait for Remaining Lives ────────────────────────────────────
if [[ ${#LIFE_PIDS[@]} -gt 0 ]]; then
  echo ""
  echo -e "${DIM}Waiting for remaining lives to finish...${NC}"
  for pid in "${LIFE_PIDS[@]}"; do
    wait "$pid" 2>/dev/null
  done
fi

# ─── Final Summary ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}============================================${NC}"
echo -e " ${BOLD}Immortals Session Complete${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}"
echo "  World:       $WORLD_NAME"
echo "  Lives lived: $CYCLE"
echo "  Started:     $(date -r $START_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d @$START_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'N/A')"
echo "  Ended:       $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Logs:        $LOG_DIR/"
if [[ -f "$MEMORIAL_FILE" ]]; then
  final_entry_count=$(grep -c '^## Life of' "$MEMORIAL_FILE" 2>/dev/null) || final_entry_count=0
  echo "  Memorial:    $final_entry_count entries in grand-memorial.md"
fi
echo -e "${BOLD}${BLUE}============================================${NC}"
