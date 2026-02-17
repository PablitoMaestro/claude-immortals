# .immortals/config.sh — Universe Configuration
# Hot-reloaded every CONFIG_POLL_SECONDS. Changes apply at next cycle.
# CLI flags always take highest priority over any config value.
#
# Per-world overrides: prefix any variable with WORLD_<name>_
# Example: WORLD_ideoma_SLEEP_MINUTES=20

# ─── Timing ──────────────────────────────────
# SLEEP_MINUTES=30              # Minutes between life cycles
# TIMEOUT_MINUTES=60            # Max minutes per life before kill
# CONFIG_POLL_SECONDS=60        # How often to check config during sleep

# ─── Agent ───────────────────────────────────
# AGENT=""                      # "claude" | "codex" | "" (auto-detect)
# CLAUDE_MODEL="claude-opus-4-6" # Model for Claude agent
# CODEX_MODEL="gpt-5.3-codex"  # Model for Codex agent
# BUDGET=""                     # Max USD per cycle (empty = unlimited)

# ─── Behavior ────────────────────────────────
# NO_SLEEP=true                 # Prevent macOS idle sleep via caffeinate
# PUSH_MAX_RETRIES=2            # Git push retry attempts
# ENABLED=true                  # Set false to pause (runner exits gracefully)

# ─── Memorial ────────────────────────────────
# MEMORIAL_MAX_LINES=500        # Trim memorial beyond this line count
# MEMORIAL_HEADER_LINES=5       # Lines to preserve as header when trimming

# ─── Name Pool ───────────────────────────────
# NAMES=(atlas prometheus hermes minerva orpheus
#        cassandra phoenix selene theseus aurora
#        daedalus calliope zephyr artemis helios
#        persephone icarus andromeda orion echo)

# ─── Universe (hand-of-god.sh) ───────────────
# ACTIVE_WORLDS=(ideoma origins)   # Which worlds to run simultaneously
# UNIVERSE_POLL_SECONDS=60         # hand-of-god polling interval
# OVERSIGHT_HOURS=0                # Run oversight agent every N hours (0 = disabled)
# OVERSIGHT_MODEL="claude-opus-4-6" # Model for oversight agent
# OVERSIGHT_BUDGET=5               # Budget per oversight run

# ─── Per-World Overrides ─────────────────────
# WORLD_ideoma_SLEEP_MINUTES=20
# WORLD_ideoma_BUDGET=5
# WORLD_origins_TIMEOUT_MINUTES=90
