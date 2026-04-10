#!/usr/bin/env bash
# Shipworthy — Shared Hook Library
# Sourced by all hooks for common functionality.

# --- Robust JSON field extraction ---
# Uses jq > python3 > regex fallback chain
# Usage: parse_json_field "$INPUT" "field_name"
parse_json_field() {
  local input="$1"
  local field="$2"
  local result=""

  # Try jq first (handles all edge cases)
  if command -v jq &>/dev/null; then
    result=$(printf '%s' "$input" | jq -r --arg f "$field" '.tool_input[$f] // .[$f] // empty' 2>/dev/null || true)
    if [ -n "$result" ] && [ "$result" != "null" ]; then
      printf '%s' "$result"
      return
    fi
  fi

  # Try python3 (handles escaped quotes)
  if command -v python3 &>/dev/null; then
    result=$(printf '%s' "$input" | _SW_FIELD="$field" python3 -c '
import json, sys, os
try:
    d = json.loads(sys.stdin.read())
    f = os.environ["_SW_FIELD"]
    v = d.get("tool_input", d).get(f, "")
    print(v, end="")
except: pass
' 2>/dev/null || true)
    if [ -n "$result" ]; then
      printf '%s' "$result"
      return
    fi
  fi

  # Regex fallback (fails on escaped quotes but better than nothing)
  result=$(printf '%s' "$input" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//' 2>/dev/null || true)
  printf '%s' "$result"
}

# --- Robust JSON escaping ---
# Uses jq > python3 > awk fallback chain
escape_json() {
  local input="$1"

  # Try jq first
  if command -v jq &>/dev/null; then
    printf '%s' "$input" | jq -Rs '.[:-1]' 2>/dev/null | sed 's/^"//;s/"$//' && return
  fi

  # Try python3
  if command -v python3 &>/dev/null; then
    printf '%s' "$input" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1], end="")' 2>/dev/null && return
  fi

  # Portable awk fallback (works on macOS and Linux)
  printf '%s' "$input" | LC_ALL=C awk '
    BEGIN { ORS="" }
    {
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "\\r")
      if (NR > 1) print "\\n"
      print
    }
  ' | tr -d '\000'
}

# --- Debug logging ---
# Logs to ~/.shipworthy/debug.log when SHIPWORTHY_DEBUG=1
# Usage: debug_log "hook-name" "message"
SHIPWORTHY_LOG_DIR="${HOME}/.shipworthy"
SHIPWORTHY_LOG_FILE="${SHIPWORTHY_LOG_DIR}/debug.log"
SHIPWORTHY_LOG_MAX_SIZE=1048576  # 1MB

debug_log() {
  [ "${SHIPWORTHY_DEBUG:-0}" = "1" ] || return 0
  local hook_name="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")

  # Create log dir if needed
  [ -d "$SHIPWORTHY_LOG_DIR" ] || mkdir -p "$SHIPWORTHY_LOG_DIR" 2>/dev/null || return 0

  # Rotate if over max size
  if [ -f "$SHIPWORTHY_LOG_FILE" ]; then
    local size
    size=$(wc -c < "$SHIPWORTHY_LOG_FILE" 2>/dev/null || echo "0")
    if [ "$size" -gt "$SHIPWORTHY_LOG_MAX_SIZE" ]; then
      mv "$SHIPWORTHY_LOG_FILE" "${SHIPWORTHY_LOG_FILE}.old" 2>/dev/null || true
    fi
  fi

  printf '[%s] [%s] %s\n' "$timestamp" "$hook_name" "$message" >> "$SHIPWORTHY_LOG_FILE" 2>/dev/null || true
}

# --- Read project config overrides ---
# Returns value from .shipworthy/config.json, empty string if not found
# Usage: read_config "overrides.allow_console_log" "$PROJECT_ROOT"
read_config() {
  local key_path="$1"
  local project_root="${2:-.}"
  local config_file="$project_root/.shipworthy/config.json"

  [ -f "$config_file" ] || return 0

  if command -v jq &>/dev/null; then
    jq -r ".$key_path // empty" "$config_file" 2>/dev/null || true
  elif command -v python3 &>/dev/null; then
    _SW_CF="$config_file" _SW_KP="$key_path" python3 -c '
import json, functools, os
try:
    d = json.load(open(os.environ["_SW_CF"]))
    keys = os.environ["_SW_KP"].split(".")
    v = functools.reduce(lambda a,k: a[k], keys, d)
    print(v if v is not None else "", end="")
except: pass
' 2>/dev/null || true
  fi
}

# --- Check if a rule is enabled (not turned off in config) ---
# Rules default to enabled. Only disabled when config says "off".
# Usage: is_rule_enabled "console_log" "$PROJECT_ROOT"
# Returns 0 (enabled / run the check) or 1 (disabled / skip it)
is_rule_enabled() {
  local rule_name="$1"
  local project_root="${2:-.}"
  local val
  val=$(read_config "rules.${rule_name}" "$project_root" 2>/dev/null || true)
  [ "$val" = "off" ] && return 1
  return 0
}

# --- Read config with default ---
# Usage: read_config_default "overrides.allow_console_log" "false" "$PROJECT_ROOT"
read_config_default() {
  local key_path="$1"
  local default_val="$2"
  local project_root="${3:-.}"
  local val
  val=$(read_config "$key_path" "$project_root" 2>/dev/null || true)
  if [ -n "$val" ]; then
    printf '%s' "$val"
  else
    printf '%s' "$default_val"
  fi
}

# --- Check if path should be ignored ---
# Usage: is_ignored_path "$FILE_PATH" "$PROJECT_ROOT"
is_ignored_path() {
  local file_path="$1"
  local project_root="${2:-.}"
  local config_file="$project_root/.shipworthy/config.json"

  [ -f "$config_file" ] || return 1  # not ignored

  local relative_path="${file_path#"$project_root"/}"

  if command -v jq &>/dev/null; then
    local ignored
    ignored=$(jq -r '.ignore_paths[]? // empty' "$config_file" 2>/dev/null || true)
    while IFS= read -r pattern; do
      [ -z "$pattern" ] && continue
      case "$relative_path" in
        $pattern*) return 0 ;;  # ignored
      esac
    done <<< "$ignored"
  fi

  return 1  # not ignored
}

# --- Session signal capture ---
# Appends session events to .shipworthy/.session-signals for automatic context building.
# Format: TIMESTAMP|HOOK|CATEGORY|DETAIL
# Processed by /retro (or auto-retro at next session start), then cleared.
# Usage: sw_signal "hook-name" "category" "detail message"
sw_signal() {
  local hook="$1"
  local category="$2"
  local detail="$3"
  local project_root
  project_root="$(timeout 2 git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local signals_dir="$project_root/.shipworthy"
  local signals_file="$signals_dir/.session-signals"

  # Only capture if .shipworthy/ exists (project has opted into Shipworthy)
  [ -d "$signals_dir" ] || return 0

  local timestamp
  timestamp="$(date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo 'unknown')"

  # Append signal (fast: just an echo, no locking needed for advisory data)
  echo "${timestamp}|${hook}|${category}|${detail}" >> "$signals_file" 2>/dev/null || true

  # Show in terminal so users see context intelligence happening
  sw_log info "signal" "captured: ${category} — ${detail}"

  debug_log "signal" "${hook}|${category}|${detail}"
}

# --- Transparency logging ---
# Writes color-coded status to stderr so users see what Shipworthy is doing.
# Separate from debug_log (file-based). Controlled by SHIPWORTHY_TRANSPARENCY env var
# or .shipworthy/config.json "transparency" field. Default: enabled.

# ANSI color constants
_SW_RESET='\033[0m'
_SW_BOLD_CYAN='\033[1;36m'
_SW_BOLD_WHITE='\033[1;37m'
_SW_CYAN='\033[36m'
_SW_GREEN='\033[32m'
_SW_YELLOW='\033[33m'
_SW_BOLD_RED='\033[1;31m'
_SW_DIM='\033[2m'

# Check if transparency logging is enabled
# Returns 0 (enabled) or 1 (disabled)
sw_transparency_enabled() {
  local val="${SHIPWORTHY_TRANSPARENCY:-}"
  if [ -n "$val" ]; then
    [ "$val" != "0" ] && return 0
    return 1
  fi
  # Fallback to config file (read directly — read_config's // empty swallows false)
  local config_file="${PROJECT_ROOT:-.}/.shipworthy/config.json"
  if [ -f "$config_file" ]; then
    local cfg_val=""
    if command -v jq &>/dev/null; then
      cfg_val=$(jq -r '.transparency' "$config_file" 2>/dev/null || true)
    elif command -v python3 &>/dev/null; then
      cfg_val=$(_SW_CF="$config_file" python3 -c '
import json, os
try: print(json.load(open(os.environ["_SW_CF"])).get("transparency",""))
except: pass
' 2>/dev/null || true)
    fi
    [ "$cfg_val" = "false" ] && return 1
  fi
  return 0  # default: enabled
}

# Primary transparency log function
# Usage: sw_log <level> <source> <message>
# Levels: info, security, warn, block
sw_log() {
  sw_transparency_enabled || return 0
  local level="$1"
  local source="$2"
  local message="$3"
  local timestamp
  timestamp=$(date '+%H:%M:%S' 2>/dev/null || echo "??:??:??")

  local msg_color="$_SW_CYAN"
  case "$level" in
    security) msg_color="$_SW_GREEN" ;;
    warn)     msg_color="$_SW_YELLOW" ;;
    block)    msg_color="$_SW_BOLD_RED" ;;
  esac

  printf "${_SW_BOLD_CYAN}⚓ shipworthy${_SW_RESET}  ${_SW_DIM}%s${_SW_RESET}  ${_SW_BOLD_WHITE}%s${_SW_RESET}  ${_SW_DIM}›${_SW_RESET}  ${msg_color}%s${_SW_RESET}\n" \
    "$timestamp" "$source" "$message" >&2

  # Also maintain file log
  debug_log "$source" "$message" 2>/dev/null || true
}

# Security check shorthand
# Usage: sw_check <source> <check_name> <result>
# result: "pass" or "warn"
sw_check() {
  sw_transparency_enabled || return 0
  local source="$1"
  local check_name="$2"
  local result="$3"
  local timestamp
  timestamp=$(date '+%H:%M:%S' 2>/dev/null || echo "??:??:??")

  if [ "$result" = "pass" ]; then
    printf "${_SW_BOLD_CYAN}⚓ shipworthy${_SW_RESET}  ${_SW_DIM}%s${_SW_RESET}  ${_SW_BOLD_WHITE}%s${_SW_RESET}  ${_SW_DIM}›${_SW_RESET}  ${_SW_GREEN}✓ %s: pass${_SW_RESET}\n" \
      "$timestamp" "$source" "$check_name" >&2
  else
    printf "${_SW_BOLD_CYAN}⚓ shipworthy${_SW_RESET}  ${_SW_DIM}%s${_SW_RESET}  ${_SW_BOLD_WHITE}%s${_SW_RESET}  ${_SW_DIM}›${_SW_RESET}  ${_SW_YELLOW}! %s: WARN${_SW_RESET}\n" \
      "$timestamp" "$source" "$check_name" >&2
  fi
}

# Session start banner
# Usage: sw_banner <tier> <health> <skill_count>
sw_banner() {
  sw_transparency_enabled || return 0
  local tier="$1"
  local health="$2"
  local skill_count="${3:-55}"
  local tier_upper
  tier_upper=$(echo "$tier" | tr '[:lower:]' '[:upper:]')

  printf >&2 '%s┌─ ⚓ shipworthy ─────────────────────────────┐%s\n' "$_SW_BOLD_CYAN" "$_SW_RESET"
  printf >&2 '%s│%s  Tier: %s%-8s%s %s│%s  Health: %s%-16s%s %s│%s\n' "$_SW_BOLD_CYAN" "$_SW_RESET" "$_SW_BOLD_WHITE" "$tier_upper" "$_SW_RESET" "$_SW_BOLD_CYAN" "$_SW_RESET" "$_SW_GREEN" "$health" "$_SW_RESET" "$_SW_BOLD_CYAN" "$_SW_RESET"
  printf >&2 '%s│%s  Skills: %s%-6s%s %s│%s  Hooks: %s%-17s%s %s│%s\n' "$_SW_BOLD_CYAN" "$_SW_RESET" "$_SW_BOLD_WHITE" "$skill_count" "$_SW_RESET" "$_SW_BOLD_CYAN" "$_SW_RESET" "$_SW_CYAN" "6 active" "$_SW_RESET" "$_SW_BOLD_CYAN" "$_SW_RESET"
  printf >&2 '%s└──────────────────────────────────────────────┘%s\n' "$_SW_BOLD_CYAN" "$_SW_RESET"
}
