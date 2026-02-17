#!/bin/bash

# Hand of God — Multi-World Universe Orchestrator
# Manages multiple immortals.sh runners, with optional oversight agent.
#
# Usage:
#   ./.immortals/scripts/hand-of-god.sh --hours 8
#   ./.immortals/scripts/hand-of-god.sh --status
#   ./.immortals/scripts/hand-of-god.sh --hours 24 --oversight 4
#   ./.immortals/scripts/hand-of-god.sh --worlds "ideoma origins" --hours 8
#   ./.immortals/scripts/hand-of-god.sh --dry-run

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
DELAY_SPEC=""
DRY_RUN=false
STATUS_MODE=false
NO_SLEEP=false
ACTIVE_WORLDS=()
UNIVERSE_POLL_SECONDS=60
OVERSIGHT_HOURS=0
OVERSIGHT_MODEL="claude-opus-4-6"
OVERSIGHT_BUDGET=5

# ─── Static Paths ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMMORTALS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$IMMORTALS_DIR/.." && pwd)"
WORLDS_DIR="$IMMORTALS_DIR/worlds"
GLOBAL_CONFIG="$IMMORTALS_DIR/config.sh"
GOD_LOG="$IMMORTALS_DIR/hand-of-god.log"
GOD_PROMPT="$SCRIPT_DIR/god-agent-prompt.md"
IMMORTALS_SCRIPT="$SCRIPT_DIR/immortals.sh"

# ─── Load Global Config ─────────────────────────────────────────
[[ -f "$GLOBAL_CONFIG" ]] && source "$GLOBAL_CONFIG"

# ─── Argument Parsing ────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours)      HOURS="$2";                    shift 2 ;;
    --dry-run)    DRY_RUN=true;                  shift   ;;
    --status)     STATUS_MODE=true;              shift   ;;
    --no-sleep)   NO_SLEEP=true;      _CLI_NO_SLEEP=true;                 shift   ;;
    --worlds)     IFS=' ' read -ra ACTIVE_WORLDS <<< "$2"; _CLI_WORLDS=true; shift 2 ;;
    --poll)       UNIVERSE_POLL_SECONDS="$2"; _CLI_UNIVERSE_POLL_SECONDS="$2";    shift 2 ;;
    --oversight)  OVERSIGHT_HOURS="$2"; _CLI_OVERSIGHT_HOURS="$2";          shift 2 ;;
    --delay)      DELAY_SPEC="$2";                                         shift 2 ;;
    -h|--help)
      echo "Hand of God — Multi-World Universe Orchestrator"
      echo ""
      echo "Usage: ./.immortals/scripts/hand-of-god.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --hours N          Total runtime for the universe"
      echo "  --delay DURATION   Delay launch (e.g., 11h, 30m, 2h30m, 45s)"
      echo "  --worlds \"a b c\"   Override ACTIVE_WORLDS from config"
      echo "  --poll N           Override UNIVERSE_POLL_SECONDS (default: 60)"
      echo "  --oversight N      Run oversight agent every N hours (0 = disabled)"
      echo "  --no-sleep         Pass through to world runners (caffeinate)"
      echo "  --dry-run          Preview which worlds would launch"
      echo "  --status           Show all worlds and their runner state"
      echo "  -h, --help         Show this help"
      echo ""
      echo "Configuration: $GLOBAL_CONFIG"
      echo "  Set ACTIVE_WORLDS=(world1 world2) to define which worlds run."
      echo ""
      echo "Output: .immortals/universe-status.json"
      echo "  Machine-readable status file, rewritten every poll cycle."
      echo ""
      echo "Examples:"
      echo "  # Run two worlds for 8 hours"
      echo "  ./hand-of-god.sh --hours 8"
      echo ""
      echo "  # Override which worlds to run"
      echo "  ./hand-of-god.sh --worlds 'ideoma origins' --hours 24"
      echo ""
      echo "  # Run with oversight agent checking every 4 hours"
      echo "  ./hand-of-god.sh --hours 24 --oversight 4"
      echo ""
      echo "  # Delay start by 11 hours, then run for 8 hours"
      echo "  ./hand-of-god.sh --delay 11h --hours 8"
      echo ""
      echo "  # Check status of all worlds"
      echo "  ./hand-of-god.sh --status"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Save CLI ACTIVE_WORLDS (array needs special handling)
[[ -n "${_CLI_WORLDS+x}" ]] && _CLI_ACTIVE_WORLDS=("${ACTIVE_WORLDS[@]}")

# ─── Helpers ─────────────────────────────────────────────────────
log() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "[${ts}] $*" | tee -a "$GOD_LOG"
}

is_runner_alive() {
  local world="$1"
  local pid_file="$WORLDS_DIR/$world/.runner-pid"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return 0
    fi
    # Stale PID file — clean up
    rm -f "$pid_file"
  fi
  return 1
}

get_world_life_count() {
  local world="$1"
  local counter_file="$WORLDS_DIR/$world/.life-counter"
  if [[ -f "$counter_file" ]]; then
    cat "$counter_file" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

format_duration() {
  local secs=$1
  local h=$((secs / 3600))
  local m=$(((secs % 3600) / 60))
  echo "${h}h ${m}m"
}

format_timestamp() {
  local epoch="$1"
  date -r "$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
    || date -d "@$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
    || echo "N/A"
}

parse_duration() {
  local input="$1"
  local total=0
  # Try combined format: 2h30m, 1h, 30m, 45s, or raw seconds
  if [[ "$input" =~ ^([0-9]+h)?([0-9]+m)?([0-9]+s)?$ ]] && [[ -n "$input" ]]; then
    [[ "$input" =~ ([0-9]+)h ]] && total=$((total + ${BASH_REMATCH[1]} * 3600))
    [[ "$input" =~ ([0-9]+)m ]] && total=$((total + ${BASH_REMATCH[1]} * 60))
    [[ "$input" =~ ([0-9]+)s ]] && total=$((total + ${BASH_REMATCH[1]}))
    echo "$total"
  elif [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "$input"
  else
    echo "Error: Cannot parse duration '$input'. Use: 11h, 30m, 2h30m, 45s, or raw seconds." >&2
    return 1
  fi
}

get_world_sleep_minutes() {
  local world="$1"
  local sleep_min=30  # global default
  # Global config SLEEP_MINUTES (already sourced)
  [[ -n "${SLEEP_MINUTES+x}" ]] && sleep_min="$SLEEP_MINUTES"
  # Per-world override: WORLD_<name>_SLEEP_MINUTES
  local safe_world="${world//-/_}"
  local override_var="WORLD_${safe_world}_SLEEP_MINUTES"
  [[ -n "${!override_var+x}" ]] && sleep_min="${!override_var}"
  # World-level config.sh override
  local world_config="$WORLDS_DIR/$world/config.sh"
  if [[ -f "$world_config" ]]; then
    local wc_sleep
    wc_sleep=$(grep -E '^SLEEP_MINUTES=' "$world_config" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d "\"'")
    [[ -n "$wc_sleep" ]] && sleep_min="$wc_sleep"
  fi
  echo "$sleep_min"
}

oversight_interval_secs() {
  local secs
  secs=$(echo "$OVERSIGHT_HOURS * 3600" | bc 2>/dev/null || echo "$((OVERSIGHT_HOURS * 3600))")
  echo "${secs%.*}"
}

is_world_enabled() {
  local world="$1"
  local safe_world="${world//-/_}"
  local world_enabled="true"
  local enabled_var="WORLD_${safe_world}_ENABLED"
  [[ -n "${!enabled_var+x}" ]] && world_enabled="${!enabled_var}"
  local world_config="$WORLDS_DIR/$world/config.sh"
  if [[ -f "$world_config" ]]; then
    local wc_en
    wc_en=$(grep -E '^ENABLED=' "$world_config" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d "\"'")
    [[ -n "$wc_en" ]] && world_enabled="$wc_en"
  fi
  echo "$world_enabled"
}

get_world_alive_agents() {
  local world="$1"
  local hb_file="$WORLDS_DIR/$world/.heartbeat"
  local agents=()
  if [[ -f "$hb_file" ]]; then
    while IFS='|' read -r name pid ts agent; do
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        agents+=("\"${name}\"")
      fi
    done < "$hb_file"
  fi
  # Return JSON array
  if [[ ${#agents[@]} -eq 0 ]]; then
    echo "[]"
  else
    local joined
    joined=$(IFS=,; echo "${agents[*]}")
    echo "[${joined}]"
  fi
}

write_universe_status() {
  local now_s
  now_s=$(date +%s)
  local remaining_secs=$((END_TIME - now_s))
  [[ $remaining_secs -lt 0 ]] && remaining_secs=0
  local elapsed_secs=$((now_s - START_TIME))

  # Oversight info
  local oversight_enabled="false"
  local oversight_interval_h=0
  local oversight_last=""
  local oversight_next_in=""
  if [[ "$OVERSIGHT_HOURS" != "0" ]]; then
    oversight_enabled="true"
    oversight_interval_h="$OVERSIGHT_HOURS"
    oversight_last=$(format_timestamp "$LAST_OVERSIGHT")
    local oi_secs
    oi_secs=$(oversight_interval_secs)
    local next_oversight_secs=$((LAST_OVERSIGHT + oi_secs - now_s))
    [[ $next_oversight_secs -lt 0 ]] && next_oversight_secs=0
    oversight_next_in=$(format_duration "$next_oversight_secs")
  fi

  # Build worlds array
  local worlds_json=""
  local total_died=0
  local total_estimated=0
  local total_alive=0
  local total_stopped=0

  for world in "${ACTIVE_WORLDS[@]}"; do
    local world_dir="$WORLDS_DIR/$world"
    [[ -d "$world_dir" ]] || continue

    # Runner status
    local w_status="stopped"
    local w_pid=0
    local w_uptime=""
    local pid
    if pid=$(is_runner_alive "$world" 2>/dev/null); then
      w_status="alive"
      w_pid=$pid
      local pid_file="$WORLDS_DIR/$world/.runner-pid"
      local pid_mtime
      pid_mtime=$(stat -f %m "$pid_file" 2>/dev/null || stat -c %Y "$pid_file" 2>/dev/null || echo "$now_s")
      local up_secs=$((now_s - pid_mtime))
      w_uptime=$(format_duration "$up_secs")
      total_alive=$((total_alive + 1))
    else
      w_uptime="0h 0m"
      total_stopped=$((total_stopped + 1))
    fi

    # Life counts
    local lives_total
    lives_total=$(get_world_life_count "$world")
    local baseline
    baseline=$(get_baseline_lives "$world")
    [[ "$baseline" == "0" ]] && baseline=$lives_total
    local died=$((lives_total - baseline))
    [[ $died -lt 0 ]] && died=0
    total_died=$((total_died + died))

    # Sleep & estimated remaining
    local sleep_min
    sleep_min=$(get_world_sleep_minutes "$world")
    local estimated=0
    if [[ $sleep_min -gt 0 ]]; then
      estimated=$((remaining_secs / (sleep_min * 60)))
    fi
    total_estimated=$((total_estimated + estimated))

    # Alive agents
    local agents_json
    agents_json=$(get_world_alive_agents "$world")

    # Enabled flag
    local w_enabled
    w_enabled=$(is_world_enabled "$world")

    # Append to JSON
    [[ -n "$worlds_json" ]] && worlds_json+=","
    worlds_json+="
    {
      \"name\": \"${world}\",
      \"status\": \"${w_status}\",
      \"pid\": ${w_pid},
      \"uptime\": \"${w_uptime}\",
      \"lives_total\": ${lives_total},
      \"lives_died_this_session\": ${died},
      \"lives_estimated_remaining\": ${estimated},
      \"alive_agents\": ${agents_json},
      \"sleep_minutes\": ${sleep_min},
      \"enabled\": ${w_enabled}
    }"
  done

  # Write JSON
  cat > "$STATUS_FILE" <<EOF
{
  "updated_at": "$(date '+%Y-%m-%d %H:%M:%S')",
  "universe": {
    "started_at": "$(format_timestamp "$START_TIME")",
    "ends_at": "$(format_timestamp "$END_TIME")",
    "remaining": "$(format_duration "$remaining_secs")",
    "remaining_secs": ${remaining_secs},
    "elapsed": "$(format_duration "$elapsed_secs")",
    "elapsed_secs": ${elapsed_secs},
    "poll_secs": ${UNIVERSE_POLL_SECONDS},
    "oversight": {
      "enabled": ${oversight_enabled},
      "interval_hours": ${oversight_interval_h},
      "last_run": "${oversight_last}",
      "next_in": "${oversight_next_in}"
    }
  },
  "worlds": [${worlds_json}
  ],
  "totals": {
    "lives_died_this_session": ${total_died},
    "lives_estimated_remaining": ${total_estimated},
    "worlds_alive": ${total_alive},
    "worlds_stopped": ${total_stopped}
  }
}
EOF
}

# ─── Status Mode ─────────────────────────────────────────────────
if $STATUS_MODE; then
  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e " ${BOLD}Hand of God — Universe Status${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""
  [[ -f "$GLOBAL_CONFIG" ]] && echo -e "  Config:        $GLOBAL_CONFIG (loaded)" || echo -e "  Config:        (none)"
  echo -e "  Active worlds: ${ACTIVE_WORLDS[*]}"
  echo -e "  Poll:          ${UNIVERSE_POLL_SECONDS}s"
  if [[ "$OVERSIGHT_HOURS" != "0" ]]; then
    echo -e "  Oversight:     every ${OVERSIGHT_HOURS}h"
  else
    echo -e "  Oversight:     disabled"
  fi
  echo ""

  # Show each world
  for world in "${ACTIVE_WORLDS[@]}"; do
    local_dir="$WORLDS_DIR/$world"
    if [[ ! -d "$local_dir" ]]; then
      echo -e "  ${BOLD}${world}${NC}    ${RED}NOT FOUND${NC}   (no world directory)"
      continue
    fi

    pid=$(is_runner_alive "$world" 2>/dev/null) && alive=true || alive=false
    lives=$(get_world_life_count "$world")

    if $alive; then
      # Calculate uptime from PID file modification time
      pid_file="$WORLDS_DIR/$world/.runner-pid"
      pid_mtime=$(stat -f %m "$pid_file" 2>/dev/null || stat -c %Y "$pid_file" 2>/dev/null || echo "0")
      now_s=$(date +%s)
      uptime_s=$((now_s - pid_mtime))
      echo -e "  ${BOLD}${world}${NC}    ${GREEN}ALIVE${NC}   PID ${pid}   Life #${lives}   uptime $(format_duration $uptime_s)"
    else
      echo -e "  ${BOLD}${world}${NC}    ${DIM}STOPPED${NC}  Life #${lives}"
    fi
  done

  # Also show worlds not in ACTIVE_WORLDS
  if [[ -d "$WORLDS_DIR" ]]; then
    for d in "$WORLDS_DIR"/*/; do
      [[ -d "$d" ]] || continue
      local_world=$(basename "$d")
      # Skip if in ACTIVE_WORLDS
      in_active=false
      for aw in "${ACTIVE_WORLDS[@]}"; do
        [[ "$aw" == "$local_world" ]] && in_active=true && break
      done
      if ! $in_active; then
        lives=$(get_world_life_count "$local_world")
        pid=$(is_runner_alive "$local_world" 2>/dev/null) && alive=true || alive=false
        if $alive; then
          echo -e "  ${BOLD}${local_world}${NC}    ${YELLOW}ORPHAN${NC}  PID ${pid}   Life #${lives}  (not in ACTIVE_WORLDS)"
        else
          echo -e "  ${DIM}${local_world}${NC}    ${DIM}inactive${NC}  Life #${lives}"
        fi
      fi
    done
  fi

  # Status file note
  sf="$IMMORTALS_DIR/universe-status.json"
  if [[ -f "$sf" ]]; then
    echo ""
    echo -e "  ${CYAN}Live status file: .immortals/universe-status.json (updated every ${UNIVERSE_POLL_SECONDS}s)${NC}"
  fi

  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"
  exit 0
fi

# ─── Validate ────────────────────────────────────────────────────
if [[ ${#ACTIVE_WORLDS[@]} -eq 0 ]]; then
  echo "Error: No active worlds defined."
  echo "  Set ACTIVE_WORLDS in $GLOBAL_CONFIG or use --worlds \"world1 world2\""
  exit 1
fi

# ─── Validate Runtime ────────────────────────────────────────────
if [[ -z "$HOURS" ]]; then
  if $DRY_RUN; then
    HOURS=1  # Default for dry-run preview
  else
    echo "Error: Must provide --hours N."
    echo "Run with --help for usage."
    exit 1
  fi
fi

# ─── Delayed Start ──────────────────────────────────────────────
if [[ -n "$DELAY_SPEC" ]]; then
  DELAY_SECS=$(parse_duration "$DELAY_SPEC") || exit 1
  launch_time=$(($(date +%s) + DELAY_SECS))
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e " ${BOLD}Hand of God — Delayed Start${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""
  echo "  Delay:    $(format_duration $DELAY_SECS)"
  echo "  Launch:   $(format_timestamp $launch_time)"
  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""
  if ! $DRY_RUN; then
    log "Delaying start by $(format_duration $DELAY_SECS). Universe will begin at $(format_timestamp $launch_time)."
    sleep "$DELAY_SECS"
  else
    log "[DRY RUN] Would delay start by $(format_duration $DELAY_SECS)."
  fi
fi

# ─── Calculate Timing ────────────────────────────────────────────
START_TIME=$(date +%s)
DURATION_SECS=$((HOURS * 3600))
END_TIME=$((START_TIME + DURATION_SECS))
LAST_OVERSIGHT=$START_TIME

# ─── Cleanup Trap ────────────────────────────────────────────────
cleanup_god() {
  if $DRY_RUN; then return; fi
  log "${YELLOW}Shutting down universe...${NC}"
  for world in "${ACTIVE_WORLDS[@]}"; do
    pid=$(is_runner_alive "$world" 2>/dev/null) || continue
    log "  Sending SIGTERM to ${world} (PID ${pid})"
    kill -TERM "$pid" 2>/dev/null
  done
  sleep 3
  for world in "${ACTIVE_WORLDS[@]}"; do
    pid=$(is_runner_alive "$world" 2>/dev/null) || continue
    log "  Force-killing ${world} (PID ${pid})"
    kill -KILL "$pid" 2>/dev/null
  done
  rm -f "$STATUS_FILE" 2>/dev/null
  log "${GREEN}Universe shut down.${NC}"
}
trap cleanup_god EXIT

# ─── Reconcile Worlds ────────────────────────────────────────────
reconcile_worlds() {
  local remaining_secs=$((END_TIME - $(date +%s)))
  local remaining_hours=$(( (remaining_secs + 3599) / 3600 ))  # Ceiling division

  # Spawn missing runners
  for world in "${ACTIVE_WORLDS[@]}"; do
    local world_dir="$WORLDS_DIR/$world"

    # Check if world exists
    if [[ ! -d "$world_dir" ]]; then
      log "${RED}  World '${world}' does not exist — skipping${NC}"
      continue
    fi

    # Check per-world ENABLED flag
    local world_enabled
    world_enabled=$(is_world_enabled "$world")

    if [[ "$world_enabled" != "true" ]]; then
      # Kill if running
      local pid
      if pid=$(is_runner_alive "$world" 2>/dev/null); then
        log "  ${YELLOW}Stopping disabled world ${world} (PID ${pid})${NC}"
        kill -TERM "$pid" 2>/dev/null
      fi
      continue
    fi

    # Check if already running
    if is_runner_alive "$world" >/dev/null 2>&1; then
      continue
    fi

    # Spawn runner
    if $DRY_RUN; then
      log "  [DRY RUN] Would spawn: $IMMORTALS_SCRIPT --world $world --hours $remaining_hours"
    else
      local runner_args=(--world "$world" --hours "$remaining_hours")
      $NO_SLEEP && runner_args+=(--no-sleep)
      "$IMMORTALS_SCRIPT" "${runner_args[@]}" &
      log "  ${GREEN}Spawned runner for ${world} (PID $!)${NC}"
    fi
  done

  # Stop worlds not in ACTIVE_WORLDS
  if [[ -d "$WORLDS_DIR" ]]; then
    for d in "$WORLDS_DIR"/*/; do
      [[ -d "$d" ]] || continue
      local check_world
      check_world=$(basename "$d")
      local in_active=false
      for aw in "${ACTIVE_WORLDS[@]}"; do
        [[ "$aw" == "$check_world" ]] && in_active=true && break
      done
      if ! $in_active; then
        local orphan_pid
        if orphan_pid=$(is_runner_alive "$check_world" 2>/dev/null); then
          log "  ${YELLOW}Stopping orphan runner for ${check_world} (PID ${orphan_pid})${NC}"
          kill -TERM "$orphan_pid" 2>/dev/null
        fi
      fi
    done
  fi
}

# ─── Oversight Agent ──────────────────────────────────────────────
run_oversight() {
  if [[ ! -f "$GOD_PROMPT" ]]; then
    log "${YELLOW}Oversight prompt not found at $GOD_PROMPT — skipping${NC}"
    return 1
  fi

  if ! command -v claude &>/dev/null; then
    log "${YELLOW}Claude CLI not found — skipping oversight${NC}"
    return 1
  fi

  log "${CYAN}Running oversight agent...${NC}"

  # Build context: last 3 memorial entries per world
  local context="# Universe Oversight Report\n\n"
  context+="## Current Config\n\`\`\`\n$(cat "$GLOBAL_CONFIG" 2>/dev/null)\n\`\`\`\n\n"

  for world in "${ACTIVE_WORLDS[@]}"; do
    local memorial="$WORLDS_DIR/$world/grand-memorial.md"
    if [[ -f "$memorial" ]]; then
      # Get last 5 entries (each starts with "## Life of")
      local entries
      entries=$(awk '/^## Life of/{found++} found>=1' "$memorial" | tail -80)
      context+="## World: ${world}\n\n${entries}\n\n---\n\n"
    fi
  done

  # Git context
  context+="## Git Status\n\`\`\`\n$(cd "$REPO_ROOT" && git status --short 2>/dev/null)\n\`\`\`\n"
  context+="## Recent Commits\n\`\`\`\n$(cd "$REPO_ROOT" && git log --oneline -10 2>/dev/null)\n\`\`\`\n"

  local oversight_log="$IMMORTALS_DIR/oversight-log.md"

  if $DRY_RUN; then
    log "  [DRY RUN] Would run oversight agent with $OVERSIGHT_MODEL (budget: \$$OVERSIGHT_BUDGET)"
    return 0
  fi

  echo -e "$context" | claude \
    -p \
    --dangerously-skip-permissions \
    --model "$OVERSIGHT_MODEL" \
    --max-budget-usd "$OVERSIGHT_BUDGET" \
    --system-prompt "$(cat "$GOD_PROMPT")" \
    >> "$oversight_log" 2>&1

  local exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    log "${GREEN}  Oversight complete. Report appended to $oversight_log${NC}"
  else
    log "${RED}  Oversight agent exited with code $exit_code${NC}"
  fi
}

# ─── Print Startup ───────────────────────────────────────────────
echo -e "${BOLD}${BLUE}============================================${NC}"
echo -e " ${BOLD}Hand of God — Universe Orchestrator${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}"
echo ""
echo "Configuration:"
echo "  Hours:          $HOURS (until $(format_timestamp $END_TIME))"
echo "  Active worlds:  ${ACTIVE_WORLDS[*]}"
echo "  Poll interval:  ${UNIVERSE_POLL_SECONDS}s"
if [[ "$OVERSIGHT_HOURS" != "0" ]]; then
  echo "  Oversight:      every ${OVERSIGHT_HOURS}h (model: $OVERSIGHT_MODEL, budget: \$$OVERSIGHT_BUDGET)"
else
  echo "  Oversight:      disabled"
fi
[[ -n "$DELAY_SPEC" ]] && echo "  Delayed by:     $(format_duration $DELAY_SECS)"
$NO_SLEEP && echo "  No-sleep:       pass-through to runners"
$DRY_RUN  && echo "  Mode:           DRY RUN"
echo "  Config:         $GLOBAL_CONFIG"
echo "  Log:            $GOD_LOG"
echo "  Status file:    .immortals/universe-status.json"
echo ""
echo -e "${BOLD}${BLUE}============================================${NC}"
echo ""

# ─── Baseline Life Snapshots ──────────────────────────────────────
# bash 3.2 compatible: parallel arrays instead of associative array
BASELINE_WORLD_NAMES=()
BASELINE_WORLD_LIVES=()
for world in "${ACTIVE_WORLDS[@]}"; do
  BASELINE_WORLD_NAMES+=("$world")
  BASELINE_WORLD_LIVES+=("$(get_world_life_count "$world")")
done
STATUS_FILE="$IMMORTALS_DIR/universe-status.json"

get_baseline_lives() {
  local target="$1"
  local i
  for i in "${!BASELINE_WORLD_NAMES[@]}"; do
    if [[ "${BASELINE_WORLD_NAMES[$i]}" == "$target" ]]; then
      echo "${BASELINE_WORLD_LIVES[$i]}"
      return
    fi
  done
  echo "0"
}

log "Universe started. Worlds: ${ACTIVE_WORLDS[*]}. Runtime: ${HOURS}h."

# ─── Main Loop ───────────────────────────────────────────────────
while true; do
  NOW=$(date +%s)

  # Check time limit
  if [[ $NOW -ge $END_TIME ]]; then
    log "Time limit reached. Shutting down universe."
    break
  fi

  # Reload config (CLI flags always win)
  [[ -f "$GLOBAL_CONFIG" ]] && source "$GLOBAL_CONFIG"
  [[ -n "${_CLI_ACTIVE_WORLDS+x}" ]]          && ACTIVE_WORLDS=("${_CLI_ACTIVE_WORLDS[@]}")
  [[ -n "${_CLI_UNIVERSE_POLL_SECONDS+x}" ]]  && UNIVERSE_POLL_SECONDS="$_CLI_UNIVERSE_POLL_SECONDS"
  [[ -n "${_CLI_OVERSIGHT_HOURS+x}" ]]        && OVERSIGHT_HOURS="$_CLI_OVERSIGHT_HOURS"
  [[ -n "${_CLI_NO_SLEEP+x}" ]]               && NO_SLEEP="$_CLI_NO_SLEEP"

  # Reconcile: ensure desired worlds are running
  reconcile_worlds

  # Write machine-readable status file
  write_universe_status

  # Check oversight
  if [[ "$OVERSIGHT_HOURS" != "0" ]]; then
    oversight_interval=$(oversight_interval_secs)
    since_oversight=$((NOW - LAST_OVERSIGHT))
    if [[ $since_oversight -ge $oversight_interval ]]; then
      run_oversight
      LAST_OVERSIGHT=$(date +%s)
    fi
  fi

  # Sleep until next poll
  if $DRY_RUN; then
    log "Dry run complete. Would poll every ${UNIVERSE_POLL_SECONDS}s."
    break
  fi

  sleep "$UNIVERSE_POLL_SECONDS"
done

# ─── Final Summary ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${BLUE}============================================${NC}"
echo -e " ${BOLD}Hand of God — Universe Complete${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}"
echo "  Worlds:   ${ACTIVE_WORLDS[*]}"
echo "  Started:  $(format_timestamp $START_TIME)"
echo "  Ended:    $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Log:      $GOD_LOG"
for world in "${ACTIVE_WORLDS[@]}"; do
  lives=$(get_world_life_count "$world")
  echo "  ${world}: ${lives} lives"
done
echo -e "${BOLD}${BLUE}============================================${NC}"

log "Universe complete. Worlds: ${ACTIVE_WORLDS[*]}."
