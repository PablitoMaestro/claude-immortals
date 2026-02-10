#!/bin/bash

# Immortals — Autonomous Life Cycle Runner
# Spawns Claude instances that live as mythological beings,
# accumulating wisdom in a grand memorial across lives.
#
# Usage:
#   ./scripts/immortals.sh --hours 8 --sleep 30
#   ./scripts/immortals.sh --hours 8 --no-sleep          # prevent idle sleep
#   ./scripts/immortals.sh --hours 8 --timeout 30        # 30min per life
#   ./scripts/immortals.sh --iterations 3 --sleep 5
#   ./scripts/immortals.sh --single --budget 5
#   ./scripts/immortals.sh --status
#   ./scripts/immortals.sh --hours 24 --dry-run

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
DRY_RUN=false
STATUS_MODE=false
NO_SLEEP=true
TIMEOUT_MINUTES=60

# ─── Name Pool (20 mythological names) ──────────────────────────
NAMES=(atlas prometheus hermes minerva orpheus
       cassandra phoenix selene theseus aurora
       daedalus calliope zephyr artemis helios
       persephone icarus andromeda orion echo)

# ─── Paths (relative to repo root) ──────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_FILE="$REPO_ROOT/scripts/immortals/immortal-prompt.md"
DESTINY_FILE="$REPO_ROOT/.immortals/destiny-prompt.md"
MEMORIAL_FILE="$REPO_ROOT/.immortals/grand-memorial.md"
LIVES_DIR="$REPO_ROOT/.immortals/lives"
LOG_DIR="$REPO_ROOT/logs/immortals"
NAME_INDEX_FILE="$REPO_ROOT/.immortals/.name-index"

# ─── Argument Parsing ───────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours)      HOURS="$2";         shift 2 ;;
    --iterations) ITERATIONS="$2";    shift 2 ;;
    --sleep)      SLEEP_MINUTES="$2"; shift 2 ;;
    --budget)     BUDGET="$2";        shift 2 ;;
    --dry-run)    DRY_RUN=true;       shift   ;;
    --single)     ITERATIONS=1;       shift   ;;
    --no-sleep)   NO_SLEEP=true;      shift   ;;
    --timeout)    TIMEOUT_MINUTES="$2"; shift 2 ;;
    --status)     STATUS_MODE=true;   shift   ;;
    -h|--help)
      echo "Immortals — Autonomous Life Cycle Runner"
      echo ""
      echo "Usage: ./scripts/immortals.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --hours N        Run for N hours (default: 8)"
      echo "  --iterations N   Run exactly N cycles"
      echo "  --sleep N        Minutes between cycles (default: 30)"
      echo "  --budget N       Max USD per cycle (optional)"
      echo "  --timeout N      Max minutes per life before kill (default: 20)"
      echo "  --no-sleep       Prevent macOS idle sleep via caffeinate"
      echo "  --dry-run        Preview without executing"
      echo "  --single         One life only (alias for --iterations 1)"
      echo "  --status         Print summary and exit"
      echo "  -h, --help       Show this help"
      echo ""
      echo "Stopping conditions: --hours OR --iterations (at least one required)."
      echo "If both provided, stops at whichever comes first."
      echo ""
      echo "Files:"
      echo "  scripts/immortals/immortal-prompt.md   System prompt for each life"
      echo "  .immortals/destiny-prompt.md             Destiny/mission for this run"
      echo "  .immortals/grand-memorial.md            Accumulated wisdom across lives"
      echo "  .immortals/lives/                       Individual life logs"
      echo "  logs/immortals/                         Raw Claude session logs"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ─── Status Mode ────────────────────────────────────────────────
if $STATUS_MODE; then
  echo ""
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e " ${BOLD}Immortals — Status Report${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""

  # Destiny summary
  echo -e "${CYAN}Destiny:${NC}"
  if [[ -f "$DESTINY_FILE" ]]; then
    # Show first 5 non-empty, non-comment content lines
    grep -v '^#' "$DESTINY_FILE" | grep -v '^\s*$' | head -5 | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo "  (no destiny file found)"
  fi
  echo ""

  # Lives count
  local_lives_count=0
  local_last_life="(none)"
  if [[ -d "$LIVES_DIR" ]]; then
    local_lives_count=$(find "$LIVES_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    local_last_file=$(ls -t "$LIVES_DIR"/*.md 2>/dev/null | head -1)
    if [[ -n "$local_last_file" ]]; then
      local_last_life=$(basename "$local_last_file" .md)
    fi
  fi
  echo -e "${CYAN}Lives:${NC}          $local_lives_count"
  echo -e "${CYAN}Last Life:${NC}      $local_last_life"
  echo ""

  # Memorial entry count
  local_memorial_count=0
  if [[ -f "$MEMORIAL_FILE" ]]; then
    local_memorial_count=$(grep -c '^## Life of' "$MEMORIAL_FILE" 2>/dev/null) || local_memorial_count=0
  fi
  echo -e "${CYAN}Memorial Entries:${NC}  $local_memorial_count"

  # Last memorial entry
  if [[ -f "$MEMORIAL_FILE" ]] && [[ "$local_memorial_count" -gt 0 ]]; then
    echo ""
    echo -e "${CYAN}Last Memorial Entry:${NC}"
    # Extract last block starting with "## Life of"
    awk '/^## Life of/{block=""} /^## Life of/{found=1} found{block=block $0 "\n"} END{printf "%s", block}' "$MEMORIAL_FILE" | head -15 | while IFS= read -r line; do
      echo "  $line"
    done
  fi

  # Name index
  echo ""
  local_name_idx=0
  if [[ -f "$NAME_INDEX_FILE" ]]; then
    local_name_idx=$(cat "$NAME_INDEX_FILE" 2>/dev/null || echo 0)
  fi
  local_next_name="${NAMES[$((local_name_idx % 20))]}"
  echo -e "${CYAN}Next Name:${NC}      $local_next_name (index $local_name_idx)"

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

if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found in PATH"
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
mkdir -p "$(dirname "$NAME_INDEX_FILE")"

# Initialize name index if missing
if [[ ! -f "$NAME_INDEX_FILE" ]]; then
  echo "0" > "$NAME_INDEX_FILE"
fi

# ─── Concurrent Execution State ──────────────────────────────────
COMMIT_LOCK="$REPO_ROOT/.immortals/.commit-lock"
rmdir "$COMMIT_LOCK" 2>/dev/null || true  # Clean up stale lock
LIFE_PIDS=()

# ─── Cleanup Trap ────────────────────────────────────────────────
cleanup_immortals() {
  for pid in "${LIFE_PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  rmdir "$COMMIT_LOCK" 2>/dev/null || true
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

# ─── Print Configuration ────────────────────────────────────────
echo -e "${BOLD}${BLUE}============================================${NC}"
echo -e " ${BOLD}Immortals — Autonomous Life Cycle Runner${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}"
echo ""
echo "Configuration:"
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
echo ""
echo -e "${BOLD}${BLUE}============================================${NC}"
echo ""

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
  prompt+=$'\n\n'
  prompt+="Write your life's work to: \`${life_file}\`"
  prompt+=$'\n\n'

  # Destiny
  prompt+="## Destiny (Your Mission)"
  prompt+=$'\n\n'
  prompt+='```markdown'
  prompt+=$'\n'
  prompt+="$(cat "$DESTINY_FILE")"
  prompt+=$'\n'
  prompt+='```'
  prompt+=$'\n\n'

  # Grand memorial (accumulated wisdom)
  if [[ -f "$MEMORIAL_FILE" ]]; then
    prompt+="## Grand Memorial (Wisdom from Past Lives)"
    prompt+=$'\n\n'
    prompt+='```markdown'
    prompt+=$'\n'
    prompt+="$(cat "$MEMORIAL_FILE")"
    prompt+=$'\n'
    prompt+='```'
    prompt+=$'\n\n'
  fi

  # Recent lives (last 3)
  prompt+="## Recent Lives (for context)"
  prompt+=$'\n\n'
  local recent_files
  recent_files=$(ls -t "$LIVES_DIR"/*.md 2>/dev/null | head -3)
  if [[ -n "$recent_files" ]]; then
    local file
    while IFS= read -r file; do
      local basename_file
      basename_file=$(basename "$file")
      prompt+="### ${basename_file}"
      prompt+=$'\n\n'
      prompt+='```markdown'
      prompt+=$'\n'
      # Limit each life file to 200 lines to avoid prompt bloat
      prompt+="$(head -200 "$file")"
      prompt+=$'\n'
      prompt+='```'
      prompt+=$'\n\n'
    done <<< "$recent_files"
  else
    prompt+="(No previous lives yet. You are the first.)"
    prompt+=$'\n\n'
  fi

  prompt+="## Instructions"
  prompt+=$'\n\n'
  prompt+="1. Study the destiny and memorial above."
  prompt+=$'\n'
  prompt+="2. Do your life's work as ${name} — advance the destiny."
  prompt+=$'\n'
  prompt+="3. Write your life log to \`${life_file}\`."
  prompt+=$'\n'
  prompt+="4. At the end of your life file, include a memorial section wrapped in tags:"
  prompt+=$'\n'
  prompt+='```'
  prompt+=$'\n'
  prompt+='<memorial>'
  prompt+=$'\n'
  prompt+='Your key insights, lessons learned, and advice for future lives.'
  prompt+=$'\n'
  prompt+='</memorial>'
  prompt+=$'\n'
  prompt+='```'
  prompt+=$'\n'
  prompt+="5. This memorial will be extracted and added to the Grand Memorial for future lives."
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

    git commit -m "chore(immortals): life of ${name} — ${timestamp}

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

  # Run Claude with timeout (subshell + watchdog pattern for macOS)
  (echo "$user_prompt" | "${CLAUDE_CMD[@]}" 2>&1 | tee "$log_file") &
  local claude_pid=$!

  # Watchdog: kill Claude if it exceeds timeout
  (
    sleep "$TIMEOUT_SECS"
    kill -TERM "$claude_pid" 2>/dev/null
    sleep 10
    kill -KILL "$claude_pid" 2>/dev/null
  ) &
  local watchdog_pid=$!

  # Wait for Claude to finish (or be killed)
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

  # Post-life processing
  extract_memorial "$name" "$life_file"
  trim_memorial

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

  # ── Pick a name ──
  CURRENT_NAME=$(pick_name)
  LIFE_SEQ=$(printf "%03d" "$CYCLE")
  LIFE_FILE="$LIVES_DIR/${LIFE_SEQ}-${CURRENT_NAME}.md"

  echo -e "${BOLD}${BLUE}────────────────────────────────────────────${NC}"
  echo -e " Cycle $CYCLE / $MAX_ITERATIONS | ${TIMESTAMP}${REMAINING}"
  echo -e " ${CYAN}Life of ${BOLD}${CURRENT_NAME}${NC}"
  echo -e "${BOLD}${BLUE}────────────────────────────────────────────${NC}"

  # ── Build prompt ──
  USER_PROMPT=$(build_prompt "$CURRENT_NAME" "$LIFE_FILE")

  # ── Build Claude command ──
  CLAUDE_CMD=(
    claude
    -p
    --dangerously-skip-permissions
    --model opus
    --system-prompt "$(cat "$PROMPT_FILE")"
  )

  if [[ -n "$BUDGET" ]]; then
    CLAUDE_CMD+=(--max-budget-usd "$BUDGET")
  fi

  LOG_FILE="$LOG_DIR/${CURRENT_NAME}-$(date '+%Y%m%d-%H%M%S').log"

  if $DRY_RUN; then
    echo ""
    echo "  [DRY RUN] Would execute:"
    echo "    claude -p --dangerously-skip-permissions --model opus \\"
    echo "      --system-prompt <immortal-prompt.md> \\"
    [[ -n "$BUDGET" ]] && echo "      --max-budget-usd $BUDGET \\"
    echo "      <prompt with destiny + memorial + recent lives>"
    echo ""
    echo "  Name:        $CURRENT_NAME"
    echo "  Life file:   $LIFE_FILE"
    echo "  Prompt size: $(echo "$USER_PROMPT" | wc -c | tr -d ' ') bytes"
    echo "  Log:         $LOG_FILE"
    echo ""
  else
    echo "  Spawning life of ${CURRENT_NAME}..."
    echo ""

    # Run life in background (handles timeout, memorial, commit internally)
    run_life_async "$CURRENT_NAME" "$LIFE_FILE" "$LOG_FILE" "$USER_PROMPT" &
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
echo "  Lives lived: $CYCLE"
echo "  Started:     $(date -r $START_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d @$START_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'N/A')"
echo "  Ended:       $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Logs:        $LOG_DIR/"
if [[ -f "$MEMORIAL_FILE" ]]; then
  local_entry_count=$(grep -c '^## Life of' "$MEMORIAL_FILE" 2>/dev/null) || local_entry_count=0
  echo "  Memorial:    $local_entry_count entries in grand-memorial.md"
fi
echo -e "${BOLD}${BLUE}============================================${NC}"
