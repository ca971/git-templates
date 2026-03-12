#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  _lib.sh — Shared functions for git hooks                    ║
# ║                                                              ║
# ║  Sourced by all hooks, never executed directly               ║
# ║                                                              ║
# ║  Features:                                                   ║
# ║  • Colors & formatting                                       ║
# ║  • Tool detection (command_exists)                           ║
# ║  • Language detection (has_files_with_ext)                   ║
# ║  • Config system (.githooks.conf + env vars)                 ║
# ║  • Skip logic (per-hook, global)                             ║
# ╚══════════════════════════════════════════════════════════════╝

# ── Colors ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Logging ────────────────────────────────────────────────────
log_ok() { echo -e "  ${GREEN}✓${NC} $*"; }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
log_fail() { echo -e "  ${RED}✗${NC} $*"; }
log_info() { echo -e "  ${CYAN}ℹ${NC} $*"; }
log_skip() { echo -e "  ${DIM}⊘ $* (skipped)${NC}"; }
log_title() { echo -e "${BOLD}$*${NC}"; }

# ── Tool detection ─────────────────────────────────────────────
command_exists() {
  command -v "$1" &>/dev/null
}

# ── File detection (staged or all) ────────────────────────────
# Usage: has_staged_files "lua" "py" "js"
has_staged_files() {
  local ext
  for ext in "$@"; do
    if git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | grep -qE "\.${ext}$"; then
      return 0
    fi
  done
  return 1
}

# Usage: get_staged_files "lua" "py"
get_staged_files() {
  local ext pattern=""
  for ext in "$@"; do
    [ -n "$pattern" ] && pattern="${pattern}|"
    pattern="${pattern}\\.${ext}$"
  done
  git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | grep -E "$pattern" || true
}

# Usage: has_repo_files "lua" "py" "js"
has_repo_files() {
  local ext
  for ext in "$@"; do
    if git ls-files 2>/dev/null | grep -qE "\.${ext}$"; then
      return 0
    fi
  done
  return 1
}

# Usage: get_repo_files "lua" "py"
get_repo_files() {
  local ext pattern=""
  for ext in "$@"; do
    [ -n "$pattern" ] && pattern="${pattern}|"
    pattern="${pattern}\\.${ext}$"
  done
  git ls-files 2>/dev/null | grep -E "$pattern" || true
}

# ── Config system ─────────────────────────────────────────────
# Priority: ENV > .githooks.conf > defaults
#
# .githooks.conf format (ini-like):
#   [commit-msg]
#   skip = false
#   subject_max_length = 72
#   body_max_length = 100
#   strict_warnings = false
#
#   [pre-commit]
#   skip = false
#   disable = stylua,black
#
#   [pre-push]
#   skip = false
#   allow_wip = false
#
#   [global]
#   skip_all = false

GITHOOKS_CONF="$(git rev-parse --show-toplevel 2>/dev/null)/.githooks.conf"

# Read a value from .githooks.conf
# Usage: githooks_config "commit-msg" "subject_max_length" "72"
githooks_config() {
  local section="$1" key="$2" default="${3:-}"

  # ENV override: GITHOOKS_COMMIT_MSG_SUBJECT_MAX_LENGTH
  local env_key
  env_key="GITHOOKS_$(echo "${section}" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_$(echo "${key}" | tr '[:lower:]' '[:upper:]')"
  local env_val="${!env_key:-}"
  if [ -n "$env_val" ]; then
    echo "$env_val"
    return
  fi

  # .githooks.conf file
  if [ -f "$GITHOOKS_CONF" ]; then
    local in_section=false
    while IFS= read -r line; do
      line=$(echo "$line" | sed 's/#.*//' | xargs)
      [ -z "$line" ] && continue
      if echo "$line" | grep -qE '^\[.*\]$'; then
        local current_section
        current_section=$(echo "$line" | tr -d '[]' | xargs)
        [ "$current_section" = "$section" ] && in_section=true || in_section=false
        continue
      fi
      if $in_section; then
        local k v
        k=$(echo "$line" | cut -d'=' -f1 | xargs)
        v=$(echo "$line" | cut -d'=' -f2- | xargs)
        if [ "$k" = "$key" ]; then
          echo "$v"
          return
        fi
      fi
    done <"$GITHOOKS_CONF"
  fi

  echo "$default"
}

# ── Skip logic ─────────────────────────────────────────────────
# Usage: should_skip_hook "commit-msg" && exit 0
should_skip_hook() {
  local hook_name="$1"

  # Global skip: SKIP_HOOKS=1 or GITHOOKS_SKIP=1
  if [ "${SKIP_HOOKS:-}" = "1" ] || [ "${GITHOOKS_SKIP:-}" = "1" ]; then
    echo -e "${DIM}⊘ All hooks skipped (SKIP_HOOKS=1)${NC}"
    return 0
  fi

  # Per-hook env: SKIP_COMMIT_MSG=1, SKIP_PRE_COMMIT=1, etc.
  local env_key="SKIP_$(echo "$hook_name" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
  if [ "${!env_key:-}" = "1" ]; then
    echo -e "${DIM}⊘ ${hook_name} hook skipped (${env_key}=1)${NC}"
    return 0
  fi

  # Config file skip
  local skip_val
  skip_val=$(githooks_config "$hook_name" "skip" "false")
  if [ "$skip_val" = "true" ] || [ "$skip_val" = "1" ]; then
    echo -e "${DIM}⊘ ${hook_name} hook skipped (.githooks.conf)${NC}"
    return 0
  fi

  # Global config skip
  skip_val=$(githooks_config "global" "skip_all" "false")
  if [ "$skip_val" = "true" ] || [ "$skip_val" = "1" ]; then
    echo -e "${DIM}⊘ All hooks skipped (.githooks.conf skip_all)${NC}"
    return 0
  fi

  return 1
}

# ── Checker registry ──────────────────────────────────────────
# Logic:
#   1. enable defined + non-empty → whitelist mode (ONLY listed run)
#   2. disable defined            → blocklist mode (all EXCEPT listed)
#   3. neither                    → everything runs (auto-detect)

is_checker_enabled() {
  local hook_name="$1" checker="$2"

  # ── 1. Check enable (whitelist — takes priority) ──────────
  local enabled
  enabled=$(githooks_config "$hook_name" "enable" "")

  if [ -n "$enabled" ]; then
    # Whitelist mode: checker MUST be in the list
    if [ "$enabled" = "*" ]; then
      return 0 # wildcard = all enabled
    fi
    if echo "$enabled" | tr ',' '\n' | grep -qiE "^${checker}$"; then
      return 0 # in whitelist
    fi
    return 1 # not in whitelist → disabled
  fi

  # ── 2. Check disable (blocklist — fallback) ──────────────
  local disabled
  disabled=$(githooks_config "$hook_name" "disable" "")

  if [ -n "$disabled" ]; then
    if echo "$disabled" | tr ',' '\n' | grep -qiE "^${checker}$"; then
      return 1 # in blocklist → disabled
    fi
  fi

  # ── 3. Neither → enabled by default ──────────────────────
  return 0
}

# ── Wrapper with skip message ─────────────────────────────────
checker_guard() {
  local hook_name="$1" checker="$2"
  if ! is_checker_enabled "$hook_name" "$checker"; then
    # Only show skip message if verbose or checker was explicitly disabled
    # (don't spam "skipped" for every language not in enable list)
    local enabled
    enabled=$(githooks_config "$hook_name" "enable" "")
    if [ -z "$enabled" ]; then
      # disable mode → show skip (user explicitly disabled it)
      log_skip "$checker (disabled in .githooks.conf)"
    fi
    # enable mode → silent skip (user didn't ask for it, no noise)
    return 1
  fi
  return 0
}
