#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Git Hooks Template Installer                                ║
# ║                                                              ║
# ║  Installs universal git hooks into ~/.git-templates/hooks    ║
# ║  Configures git to use them on init/clone                    ║
# ║                                                              ║
# ║  Usage:                                                      ║
# ║    bash install.sh              # interactive install        ║
# ║    bash install.sh --force      # overwrite without prompt   ║
# ║    bash install.sh --uninstall  # remove hooks + config      ║
# ║    bash install.sh --check      # verify installation        ║
# ║    bash install.sh --update     # update to latest           ║
# ╚══════════════════════════════════════════════════════════════╝
#

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
TEMPLATE_DIR="${HOME}/.git-templates"
HOOKS_DIR="${TEMPLATE_DIR}/hooks"
BACKUP_DIR="${HOME}/.git-templates-backup-$(date +%Y%m%d-%H%M%S)"

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────
info() { echo -e "${CYAN}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
fail() { echo -e "${RED}✗${NC}  $*"; }
header() { echo -e "\n${BOLD}${CYAN}$*${NC}"; }

# ── Parse args ────────────────────────────────────────────────
MODE="install"
for arg in "$@"; do
  case "$arg" in
  --force) FORCE=true ;;
  --uninstall) MODE="uninstall" ;;
  --check) MODE="check" ;;
  --update) MODE="update" ;;
  --help | -h) MODE="help" ;;
  *)
    fail "Unknown option: $arg"
    exit 1
    ;;
  esac
done
FORCE="${FORCE:-false}"

# ══════════════════════════════════════════════════════════════
# HELP
# ══════════════════════════════════════════════════════════════

if [ "$MODE" = "help" ]; then
  cat <<'EOF'

  Git Hooks Template Installer
  ────────────────────────────

  Usage:
    bash install.sh              Interactive install
    bash install.sh --force      Overwrite without prompt
    bash install.sh --uninstall  Remove hooks and git config
    bash install.sh --check      Verify current installation
    bash install.sh --update     Re-install (backup + install)

  What it does:
    1. Creates ~/.git-templates/hooks/
    2. Installs 5 hook files (_lib.sh, commit-msg, pre-commit, post-merge, pre-push)
    3. Sets git config init.templateDir
    4. All new git init / git clone will use these hooks

  Per-repo config (.githooks.conf):
    Place a .githooks.conf in any repo root to customize behavior.
    See: https://github.com/ca971/git-hooks

  Skip hooks:
    SKIP_HOOKS=1 git commit       # skip all hooks
    SKIP_PRE_COMMIT=1 git commit  # skip specific hook
    git commit --no-verify        # git native skip

EOF
  exit 0
fi

# ══════════════════════════════════════════════════════════════
# CHECK
# ══════════════════════════════════════════════════════════════

if [ "$MODE" = "check" ]; then
  header "🔍 Checking git hooks installation..."
  echo ""
  errors=0

  # Check git config
  template_config=$(git config --global init.templateDir 2>/dev/null || true)
  if [ "$template_config" = "$TEMPLATE_DIR" ]; then
    success "git config init.templateDir = ${template_config}"
  elif [ -n "$template_config" ]; then
    warn "init.templateDir = ${template_config} (expected: ${TEMPLATE_DIR})"
    errors=$((errors + 1))
  else
    fail "init.templateDir not set"
    errors=$((errors + 1))
  fi

  # Check hooks directory
  if [ -d "$HOOKS_DIR" ]; then
    success "Hooks directory exists: ${HOOKS_DIR}"
  else
    fail "Hooks directory missing: ${HOOKS_DIR}"
    errors=$((errors + 1))
  fi

  # Check each hook file
  for hook in _lib.sh commit-msg pre-commit post-merge pre-push; do
    hook_path="${HOOKS_DIR}/${hook}"
    if [ -f "$hook_path" ]; then
      if [ -x "$hook_path" ]; then
        size=$(wc -c <"$hook_path" | tr -d ' ')
        success "${hook} (${size} bytes, executable)"
      else
        warn "${hook} exists but not executable"
        errors=$((errors + 1))
      fi
    else
      fail "${hook} missing"
      errors=$((errors + 1))
    fi
  done

  # Check tools
  echo ""
  header "🔧 Available tools:"
  echo ""
  tools=(
    "shellcheck:Shell linting"
    "stylua:Lua formatting"
    "luajit:Lua syntax (preferred)"
    "luac:Lua syntax (fallback)"
    "ruff:Python lint+format"
    "black:Python formatting"
    "prettier:JS/TS/CSS formatting"
    "eslint:JS/TS linting"
    "gofmt:Go formatting"
    "rustfmt:Rust formatting"
    "yamllint:YAML linting"
    "jq:JSON validation"
    "hadolint:Dockerfile linting"
    "markdownlint:Markdown linting"
    "taplo:TOML formatting"
  )
  for tool_entry in "${tools[@]}"; do
    IFS=':' read -r tool desc <<<"$tool_entry"
    if command -v "$tool" &>/dev/null; then
      version=$($tool --version 2>/dev/null | head -1 || echo "?")
      success "${tool} — ${desc} ${DIM}(${version})${NC}"
    else
      echo -e "  ${DIM}○ ${tool} — ${desc} (not installed)${NC}"
    fi
  done

  echo ""
  if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✅ Installation OK${NC}"
  else
    echo -e "${YELLOW}⚠  ${errors} issue(s) found${NC}"
  fi
  exit 0
fi

# ══════════════════════════════════════════════════════════════
# UNINSTALL
# ══════════════════════════════════════════════════════════════

if [ "$MODE" = "uninstall" ]; then
  header "🗑️  Uninstalling git hooks..."
  echo ""

  if [ -d "$HOOKS_DIR" ]; then
    if [ "$FORCE" != "true" ]; then
      read -r -p "Remove ${HOOKS_DIR} and git config? [y/N] " -n 1 REPLY
      echo
      [[ ! $REPLY =~ ^[Yy]$ ]] && {
        info "Cancelled."
        exit 0
      }
    fi

    # Backup first
    cp -r "$TEMPLATE_DIR" "$BACKUP_DIR" 2>/dev/null &&
      success "Backed up to ${BACKUP_DIR}" || true

    rm -rf "$HOOKS_DIR"
    success "Removed ${HOOKS_DIR}"
  else
    warn "Hooks directory not found — nothing to remove"
  fi

  # Remove git config
  if git config --global --get init.templateDir &>/dev/null; then
    git config --global --unset init.templateDir
    success "Removed git config init.templateDir"
  fi

  echo ""
  echo -e "${GREEN}✅ Uninstalled${NC}"
  echo -e "${DIM}   Backup: ${BACKUP_DIR}${NC}"
  echo -e "${DIM}   Existing repos still have their copied hooks in .git/hooks/${NC}"
  exit 0
fi

# ══════════════════════════════════════════════════════════════
# INSTALL / UPDATE
# ══════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║  🔧 Git Hooks Template Installer                 ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Backup existing ───────────────────────────────────────────
if [ -d "$HOOKS_DIR" ]; then
  if [ "$MODE" = "update" ] || [ "$FORCE" = "true" ]; then
    cp -r "$TEMPLATE_DIR" "$BACKUP_DIR"
    success "Existing hooks backed up → ${DIM}${BACKUP_DIR}${NC}"
  else
    warn "Hooks already exist at ${HOOKS_DIR}"
    read -r -p "   Overwrite? (backup will be created) [y/N] " -n 1 REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      info "Cancelled. Run with --force to skip prompts."
      exit 0
    fi
    cp -r "$TEMPLATE_DIR" "$BACKUP_DIR"
    success "Backed up → ${DIM}${BACKUP_DIR}${NC}"
  fi
fi

# ── Create directory ──────────────────────────────────────────
mkdir -p "$HOOKS_DIR"
success "Created ${HOOKS_DIR}"

# ══════════════════════════════════════════════════════════════
# WRITE HOOK FILES
# ══════════════════════════════════════════════════════════════

header "📝 Installing hooks..."
echo ""

# ────────────────────────────────────────────────────────────
# _lib.sh
# ────────────────────────────────────────────────────────────
cat >"${HOOKS_DIR}/_lib.sh" <<'HOOKEOF'
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
# shellcheck disable=SC2034
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
  local env_key
  env_key="SKIP_$(echo "$hook_name" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
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
HOOKEOF

success "_lib.sh (shared library)"

# ────────────────────────────────────────────────────────────
# commit-msg
# ────────────────────────────────────────────────────────────
cat >"${HOOKS_DIR}/commit-msg" <<'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Commit-msg hook — Validates conventional commits            ║
# ║                                                              ║
# ║  Format: <type>(<scope>): <subject>                          ║
# ║                                                              ║
# ║  Config (.githooks.conf):                                    ║
# ║    [commit-msg]                                              ║
# ║    skip = false                                              ║
# ║    subject_max_length = 72                                   ║
# ║    body_max_length = 100                                     ║
# ║    strict_warnings = false   # true = warnings block commit  ║
# ║                                                              ║
# ║  Skip: SKIP_COMMIT_MSG=1 git commit -m "..."                 ║
# ║  Skip all: SKIP_HOOKS=1 git commit -m "..."                  ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Source shared lib ─────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "${HOOK_DIR}/_lib.sh"

# ── Skip check ────────────────────────────────────────────────
should_skip_hook "commit-msg" && exit 0

# ── Config ────────────────────────────────────────────────────
SUBJECT_MAX_LENGTH=$(githooks_config "commit-msg" "subject_max_length" "72")
BODY_MAX_LENGTH=$(githooks_config "commit-msg" "body_max_length" "100")
STRICT_WARNINGS=$(githooks_config "commit-msg" "strict_warnings" "false")

# ── Read commit message ──────────────────────────────────────
commit_file="$1"
commit_msg=$(cat "$commit_file")
first_line=$(echo "$commit_msg" | head -1)
line_count=$(echo "$commit_msg" | wc -l | tr -d ' ')

warnings=0

# ── Auto-skip: merge commits ────────────────────────────────
if echo "$first_line" | grep -qE '^Merge (branch|remote-tracking|pull request)'; then
  exit 0
fi

# ── Auto-skip: WIP / fixup / squash (interactive rebase) ────
if echo "$first_line" | grep -qiE '^(wip|fixup!|squash!|amend!)'; then
  log_warn "WIP/fixup commit — remember to squash before pushing"
  exit 0
fi

# ── Auto-skip: git revert auto-generated messages ───────────
if echo "$first_line" | grep -qE '^Revert "'; then
  exit 0
fi

# ── Validate: not empty ─────────────────────────────────────
if [ -z "$(echo "$first_line" | tr -d '[:space:]')" ]; then
  echo -e "${RED}🚫 Empty commit message${NC}"
  exit 1
fi

# ── Validate: conventional commit format ─────────────────────
TYPES="feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|release"
pattern="^(${TYPES})(!)?(\(.+\))?: .{1,}"

if ! echo "$first_line" | grep -qE "$pattern"; then
  echo -e "${RED}🚫 Invalid commit message format${NC}"
  echo ""
  echo -e "  Expected: ${CYAN}<type>(<scope>): <subject>${NC}"
  echo ""
  echo -e "  ${BOLD}Types:${NC}"
  echo -e "    ${GREEN}feat${NC}      New feature                    ${DIM}→ MINOR${NC}"
  echo -e "    ${GREEN}fix${NC}       Bug fix                        ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}docs${NC}      Documentation only             ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}style${NC}     Formatting (no logic change)   ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}refactor${NC}  Code restructuring             ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}perf${NC}      Performance improvement        ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}test${NC}      Add/update tests               ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}build${NC}     Build system / dependencies    ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}ci${NC}        CI/CD pipeline changes         ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}chore${NC}     Maintenance tasks              ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}revert${NC}    Revert a previous commit       ${DIM}→ PATCH${NC}"
  echo -e "    ${GREEN}release${NC}   Version release (tag+changelog)${DIM}→ TAG${NC}"
  echo ""
  echo -e "  ${BOLD}Breaking change:${NC} add ${CYAN}!${NC} after type"
  echo -e "    ${GREEN}feat!: drop support for Node 14${NC}          ${DIM}→ MAJOR${NC}"
  echo -e "    ${GREEN}refactor!(config): new settings format${NC}   ${DIM}→ MAJOR${NC}"
  echo ""
  echo -e "  ${BOLD}Your message:${NC}"
  echo -e "    ${RED}${first_line}${NC}"
  echo ""
  echo -e "  ${BOLD}Examples:${NC}"
  echo -e "    ${GREEN}feat(auth): add OAuth2 login flow${NC}"
  echo -e "    ${GREEN}fix(api): resolve null pointer on empty response${NC}"
  echo -e "    ${GREEN}docs: update installation guide${NC}"
  echo -e "    ${GREEN}release: v1.1.0 — API refactor${NC}"
  echo -e "    ${GREEN}feat!: redesign plugin architecture${NC}"
  echo -e "    ${GREEN}chore(deps): bump axios to 1.7.0${NC}"
  echo -e "    ${GREEN}test(utils): add edge case coverage${NC}"
  echo ""
  exit 1
fi

# ── Validate: subject length ────────────────────────────────
subject_length=${#first_line}
if [ "$subject_length" -gt "$SUBJECT_MAX_LENGTH" ]; then
  log_warn "Subject is ${subject_length} chars (recommended: ≤ ${SUBJECT_MAX_LENGTH})"
  echo -e "    ${DIM}${first_line}${NC}"
  echo -e "    ${DIM}$(printf '%*s' "$SUBJECT_MAX_LENGTH" "" | tr ' ' '─')${RED}↑ here${NC}"
  warnings=$((warnings + 1))
fi

# ── Validate: no trailing period ─────────────────────────────
if echo "$first_line" | grep -qE '\.$'; then
  log_warn "Subject should not end with a period"
  warnings=$((warnings + 1))
fi

# ── Validate: imperative mood ────────────────────────────────
subject=$(echo "$first_line" | sed -E 's/^[^:]+: //')
if echo "$subject" | grep -qiE '^(added|fixed|removed|updated|changed|deleted|created|implemented|modified)'; then
  log_warn "Use imperative mood: \"add\" not \"added\", \"fix\" not \"fixed\""
  warnings=$((warnings + 1))
fi

# ── Validate: second line must be blank (if body exists) ────
if [ "$line_count" -gt 1 ]; then
  second_line=$(echo "$commit_msg" | sed -n '2p')
  if [ -n "$(echo "$second_line" | tr -d '[:space:]')" ]; then
    log_warn "Second line should be blank (separates subject from body)"
    warnings=$((warnings + 1))
  fi
fi

# ── Validate: body line length ───────────────────────────────
if [ "$line_count" -gt 2 ]; then
  long_lines=0
  line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    [ "$line_num" -le 2 ] && continue
    echo "$line" | grep -qE 'https?://' && continue
    if [ "${#line}" -gt "$BODY_MAX_LENGTH" ]; then
      long_lines=$((long_lines + 1))
    fi
  done <<<"$commit_msg"

  if [ "$long_lines" -gt 0 ]; then
    log_warn "${long_lines} body line(s) exceed ${BODY_MAX_LENGTH} chars"
    warnings=$((warnings + 1))
  fi
fi

# ── Detect: breaking change in footer ────────────────────────
if echo "$commit_msg" | grep -qE '^BREAKING[ -]CHANGE:'; then
  log_info "Breaking change detected in footer — MAJOR bump"
fi

# ── Detect: breaking change marker (!) ───────────────────────
if echo "$first_line" | grep -qE "^(${TYPES})!"; then
  log_info "Breaking change marker (!) — MAJOR bump"
fi

# ── Strict mode: warnings become errors ──────────────────────
if [ "$warnings" -gt 0 ] && [ "$STRICT_WARNINGS" = "true" ]; then
  echo -e "${RED}🚫 ${warnings} warning(s) in strict mode — commit blocked${NC}"
  echo -e "${DIM}   Disable with: SKIP_COMMIT_MSG=1 or strict_warnings=false in .githooks.conf${NC}"
  exit 1
fi

# ── Success ──────────────────────────────────────────────────
if [ "$warnings" -eq 0 ]; then
  echo -e "${GREEN}✅ Commit message valid${NC}"
else
  echo -e "${GREEN}✅ Commit message valid${NC} ${DIM}(${warnings} warning(s))${NC}"
fi
HOOKEOF

success "commit-msg (conventional commits)"

# ────────────────────────────────────────────────────────────
# pre-commit
# ────────────────────────────────────────────────────────────
cat >"${HOOKS_DIR}/pre-commit" <<'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Pre-commit hook — Universal quality gate                    ║
# ║                                                              ║
# ║  Checks (in order):                                          ║
# ║   1. Debug markers (warning)                                 ║
# ║   2. Backup/temp files (blocks)                              ║
# ║   3. Large files (blocks)                                    ║
# ║   4. Secrets/credentials (blocks)                            ║
# ║   5. Merge conflict markers (blocks)                         ║
# ║   6. .env files (blocks)                                     ║
# ║   7. Trailing whitespace (warning)                           ║
# ║   8. Language-specific (auto-detected):                      ║
# ║      Lua    → stylua, luajit/luac                            ║
# ║      Shell  → shellcheck                                     ║
# ║      Python → ruff/black, python -m py_compile               ║
# ║      JS/TS  → prettier, eslint                               ║
# ║      Go     → gofmt, go vet                                  ║
# ║      Rust   → rustfmt, cargo check                           ║
# ║      YAML   → yamllint                                       ║
# ║      JSON   → python3 -m json.tool / jq                      ║
# ║      TOML   → taplo                                          ║
# ║      CSS    → stylelint                                      ║
# ║      MD     → markdownlint                                   ║
# ║      Terraform → terraform fmt/validate                      ║
# ║      Dockerfile → hadolint                                   ║
# ║                                                              ║
# ║  Config (.githooks.conf):                                    ║
# ║    [pre-commit]                                              ║
# ║    skip = false                                              ║
# ║    max_file_size = 5242880     # bytes (5MB)                 ║
# ║    enable = shellcheck,markdownlint  # only these run        ║
# ║    disable = stylua,black      # skip specific checkers      ║
# ║    debug_markers_block = false  # true = errors not warnings ║
# ║    trailing_ws_block = false                                 ║
# ║                                                              ║
# ║  Skip: SKIP_PRE_COMMIT=1 git commit                          ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Source shared lib ─────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "${HOOK_DIR}/_lib.sh"

# ── Skip check ────────────────────────────────────────────────
should_skip_hook "pre-commit" && exit 0

# ── Config ────────────────────────────────────────────────────
MAX_FILE_SIZE=$(githooks_config "pre-commit" "max_file_size" "5242880")
DEBUG_BLOCK=$(githooks_config "pre-commit" "debug_markers_block" "false")
TRAILING_WS_BLOCK=$(githooks_config "pre-commit" "trailing_ws_block" "false")

# ── Counters ──────────────────────────────────────────────────
errors=0
warnings=0

error() {
  echo -e "  ${RED}✗ $1${NC}"
  errors=$((errors + 1))
}
warn() {
  echo -e "  ${YELLOW}⚠ $1${NC}"
  warnings=$((warnings + 1))
}
ok() { echo -e "  ${GREEN}✓ $1${NC}"; }
info() { echo -e "  ${DIM}  $1${NC}"; }

# ── Staged files ──────────────────────────────────────────────
STAGED=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED" ]; then
  echo -e "${YELLOW}⚠️  No staged files — nothing to check${NC}"
  exit 0
fi

echo -e "${CYAN}🔍 Pre-commit checks...${NC}"

# ── Helper: get staged files by extension ─────────────────────
staged_by_ext() {
  local ext
  for ext in "$@"; do
    echo "$STAGED" | grep -E "\.${ext}$" || true
  done | sort -u
}

# ── Helper: check if a checker is enabled ─────────────────────
checker_on() {
  is_checker_enabled "pre-commit" "$1" || return 1
  return 0
}

# ══════════════════════════════════════════════════════════════
# 1. DEBUG MARKERS
# ══════════════════════════════════════════════════════════════

debug_pattern='(TODO:|FIXME:|HACK:|XXX:|BUG:|TEMP:|console\.log|console\.debug|debugger|binding\.pry|import pdb|breakpoint\(\)|dbg!|dd\(|var_dump|die\()'

debug_matches=$(git diff --cached --diff-filter=ACM |
  grep '^+' |
  grep -v '^+++' |
  grep -E "$debug_pattern" 2>/dev/null |
  grep -vE "(_pattern=|pattern=|pattern '|grep|echo -e|log_|printf|info\(|warn\(|ok\(|error\()" |
  grep -vE "(✓|✗|→|⚠|ℹ)" |
  grep -vE "(['\"]TODO|['\"]FIXME|['\"]console|['\"]debugger|['\"]breakpoint)" ||
  true)

if [ -n "$debug_matches" ]; then
  count=$(echo "$debug_matches" | wc -l | tr -d ' ')
  if [ "$DEBUG_BLOCK" = "true" ]; then
    error "Debug markers found (${count}):"
  else
    warn "Debug markers found (${count}, not blocking):"
  fi
  echo "$debug_matches" | head -5 | while IFS= read -r line; do
    info "$(echo "$line" | cut -c2-100)"
  done
  [ "$count" -gt 5 ] && info "... and $((count - 5)) more"
else
  ok "No debug markers"
fi

# ══════════════════════════════════════════════════════════════
# 2. BACKUP / TEMP FILES (blocks)
# ══════════════════════════════════════════════════════════════

backup_files=$(echo "$STAGED" | grep -E '\.(bak|old|last|orig|swp|swo|tmp|temp|~)$' || true)
if [ -n "$backup_files" ]; then
  error "Backup/temp files staged:"
  echo "$backup_files" | while IFS= read -r f; do info "$f"; done
  info "Remove: git reset HEAD <file>"
else
  ok "No backup files"
fi

# ══════════════════════════════════════════════════════════════
# 3. LARGE FILES (blocks)
# ══════════════════════════════════════════════════════════════

large_found=false
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  size=$(wc -c <"$f" 2>/dev/null || echo 0)
  if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
    if [ "$large_found" = false ]; then
      large_found=true
      error "Large files:"
    fi
    if command_exists numfmt; then
      human=$(numfmt --to=iec "$size" 2>/dev/null)
    else
      human="$((size / 1048576))MB"
    fi
    info "$f ($human)"
  fi
done <<<"$STAGED"
[ "$large_found" = false ] && ok "No large files"

# ══════════════════════════════════════════════════════════════
# 4. SECRETS / CREDENTIALS (blocks)
# ══════════════════════════════════════════════════════════════

SQ="'"
secrets_patterns=(
  "(password|passwd|pwd)[[:space:]]*[=:][[:space:]]*[\"${SQ}][^[:space:]]+"
  "(secret|api_key|apikey|api_secret)[[:space:]]*[=:][[:space:]]*[\"${SQ}][^[:space:]]+"
  "(access_token|auth_token|bearer)[[:space:]]*[=:][[:space:]]*[\"${SQ}][^[:space:]]+"
  "(private_key|priv_key)[[:space:]]*[=:][[:space:]]*[\"${SQ}][^[:space:]]+"
  "(AWS_SECRET|AWS_ACCESS_KEY_ID)[[:space:]]*[=:][[:space:]]*[\"${SQ}]"
  "(GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN)[[:space:]]*[=:]"
  "sk-[a-zA-Z0-9]{20,}"
  "ghp_[a-zA-Z0-9]{36}"
  "gho_[a-zA-Z0-9]{36}"
  "glpat-[a-zA-Z0-9-]{20,}"
  "AKIA[0-9A-Z]{16}"
  "eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}"
)

secrets_found=false
for p in "${secrets_patterns[@]}"; do
  m=$(git diff --cached --diff-filter=ACM | grep -iE "$p" 2>/dev/null | grep '^+' | grep -v '^+++' | grep -vE "(pattern|grep|secrets_patterns)" || true)
  if [ -n "$m" ]; then
    if [ "$secrets_found" = false ]; then
      secrets_found=true
      error "Possible credentials detected!"
    fi
    echo "$m" | head -2 | while IFS= read -r line; do
      info "$(echo "$line" | cut -c2-80)..."
    done
  fi
done
if [ "$secrets_found" = true ]; then
  info "Move secrets to .env (gitignored) or use a secret manager"
else
  ok "No credentials detected"
fi

# ══════════════════════════════════════════════════════════════
# 5. MERGE CONFLICT MARKERS (blocks)
# ══════════════════════════════════════════════════════════════

if git diff --cached --diff-filter=ACM | grep -qE '^\+[<>=]{7}( |$)'; then
  error "Merge conflict markers found"
  git diff --cached --diff-filter=ACM | grep -nE '^\+[<>=]{7}' | head -5 | while IFS= read -r line; do
    info "$line"
  done
else
  ok "No merge conflict markers"
fi

# ══════════════════════════════════════════════════════════════
# 6. .ENV FILES (blocks)
# ══════════════════════════════════════════════════════════════

env_files=$(echo "$STAGED" | grep -E '(^|/)\.env(\..+)?$' || true)
if [ -n "$env_files" ]; then
  error ".env file(s) staged — should be gitignored!"
  echo "$env_files" | while IFS= read -r f; do info "$f"; done
  info "Fix: echo '.env*' >> .gitignore"
else
  ok "No .env files"
fi

# ══════════════════════════════════════════════════════════════
# 7. TRAILING WHITESPACE
# ══════════════════════════════════════════════════════════════

trailing=$(git diff --cached --diff-filter=ACM | grep -nE '^\+.*[[:blank:]]$' 2>/dev/null | grep -vF '+++' || true)
if [ -n "$trailing" ]; then
  count=$(echo "$trailing" | wc -l | tr -d ' ')
  if [ "$TRAILING_WS_BLOCK" = "true" ]; then
    error "Trailing whitespace in ${count} line(s)"
  else
    warn "Trailing whitespace in ${count} line(s)"
  fi
else
  ok "No trailing whitespace"
fi

# ══════════════════════════════════════════════════════════════
#  LANGUAGE-SPECIFIC CHECKS (auto-detected from staged files)
# ══════════════════════════════════════════════════════════════

echo -e "${CYAN}   ── Language checks ──${NC}"

# ══════════════════════════════════════════════════════════════
# LUA
# ══════════════════════════════════════════════════════════════

lua_files=$(staged_by_ext lua)
if [ -n "$lua_files" ]; then

  # ── StyLua ────────────────────────────────────────────────
  if checker_on "stylua" && command_exists stylua; then
    se=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if ! stylua --check "$f" &>/dev/null; then
        [ $se -eq 0 ] && error "StyLua formatting issues:"
        info "$f"
        se=$((se + 1))
      fi
    done <<<"$lua_files"
    if [ $se -gt 0 ]; then
      info "Fix: stylua \$(git diff --cached --name-only '*.lua')"
    else
      fc=$(echo "$lua_files" | wc -l | tr -d ' ')
      ok "StyLua — ${fc} file(s)"
    fi
  fi

  # ── Lua syntax ────────────────────────────────────────────
  if checker_on "lua-syntax"; then
    LC="" LN=""
    command_exists luajit && {
      LC="luajit -bl"
      LN="LuaJIT"
    }
    [ -z "$LC" ] && command_exists luac5.1 && {
      LC="luac5.1 -p"
      LN="luac5.1"
    }
    [ -z "$LC" ] && command_exists luac && {
      LC="luac -p"
      LN="luac"
    }
    if [ -n "$LC" ]; then
      le=0
      fc=0
      while IFS= read -r f; do
        [ -z "$f" ] || [ ! -f "$f" ] && continue
        fc=$((fc + 1))
        if ! $LC "$f" &>/dev/null; then
          [ $le -eq 0 ] && error "Lua syntax (${LN}):"
          info "$f"
          $LC "$f" 2>&1 | head -3 | while IFS= read -r e; do info "  $e"; done
          le=$((le + 1))
        fi
      done <<<"$lua_files"
      [ $le -eq 0 ] && ok "Lua syntax (${LN}) — ${fc} file(s)"
    else
      log_skip "No Lua checker found (install luajit)"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
# SHELL
# ══════════════════════════════════════════════════════════════

sh_files=$(staged_by_ext sh bash zsh)
# Also detect shebangs
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  if head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash|sh|zsh)'; then
    sh_files=$(printf '%s\n%s' "$sh_files" "$f")
  fi
done <<<"$STAGED"
sh_files=$(echo "$sh_files" | sort -u | grep -v '^$' || true)

if [ -n "$sh_files" ] && checker_on "shellcheck" && command_exists shellcheck; then
  sc_e=0
  sc_count=0
  while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    sc_count=$((sc_count + 1))
    if ! shellcheck -S warning "$f" &>/dev/null; then
      [ $sc_e -eq 0 ] && warn "ShellCheck warnings:"
      info "$f"
      shellcheck -S warning -f gcc "$f" 2>/dev/null | head -3 | while IFS= read -r sc_line; do
        info "  $sc_line"
      done
      sc_e=$((sc_e + 1))
    fi
  done <<<"$sh_files"
  [ $sc_e -eq 0 ] && ok "ShellCheck — ${sc_count} file(s)"
fi

# ══════════════════════════════════════════════════════════════
# PYTHON
# ══════════════════════════════════════════════════════════════

py_files=$(staged_by_ext py)
if [ -n "$py_files" ]; then

  # ── Ruff ────────────────────────────────────────────────
  if checker_on "ruff" && command_exists ruff; then
    re=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if ! ruff format --check "$f" &>/dev/null; then
        [ $re -eq 0 ] && error "Ruff format issues:"
        info "$f"
        re=$((re + 1))
      fi
    done <<<"$py_files"
    [ $re -gt 0 ] && info "Fix: ruff format ." || {
      fc=$(echo "$py_files" | wc -l | tr -d ' ')
      ok "Ruff format — ${fc} file(s)"
    }

    # Ruff lint
    rl=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if ! ruff check --quiet "$f" &>/dev/null; then
        [ $rl -eq 0 ] && warn "Ruff lint issues:"
        ruff check "$f" 2>/dev/null | head -3 | while IFS= read -r rl_line; do
          info "  $rl_line"
        done
        rl=$((rl + 1))
      fi
    done <<<"$py_files"
    [ $rl -eq 0 ] && ok "Ruff lint"
  fi

  # ── Black (fallback) ───────────────────────────────────
  if checker_on "black" && ! command_exists ruff && command_exists black; then
    be=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if ! black --check --quiet "$f" &>/dev/null; then
        [ $be -eq 0 ] && error "Black formatting issues:"
        info "$f"
        be=$((be + 1))
      fi
    done <<<"$py_files"
    [ $be -gt 0 ] && info "Fix: black ." || ok "Black"
  fi

  # ── Python syntax ──────────────────────────────────────
  if checker_on "python-syntax" && command_exists python3; then
    pe=0
    pc=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      pc=$((pc + 1))
      if ! python3 -m py_compile "$f" &>/dev/null; then
        [ $pe -eq 0 ] && error "Python syntax errors:"
        info "$f"
        python3 -m py_compile "$f" 2>&1 | head -3 | while IFS= read -r e; do info "  $e"; done
        pe=$((pe + 1))
      fi
    done <<<"$py_files"
    [ $pe -eq 0 ] && ok "Python syntax — ${pc} file(s)"
  fi
fi

# ══════════════════════════════════════════════════════════════
# JAVASCRIPT / TYPESCRIPT
# ══════════════════════════════════════════════════════════════

js_files=$(staged_by_ext js jsx mjs cjs ts tsx)
if [ -n "$js_files" ]; then

  # ── Prettier ──────────────────────────────────────────────
  if checker_on "prettier"; then
    P=""
    command_exists prettier && P="prettier"
    [ -z "$P" ] && [ -f "node_modules/.bin/prettier" ] && P="npx prettier"
    if [ -n "$P" ]; then
      pe=0
      while IFS= read -r f; do
        [ -z "$f" ] || [ ! -f "$f" ] && continue
        if ! $P --check "$f" &>/dev/null; then
          [ $pe -eq 0 ] && error "Prettier formatting issues:"
          info "$f"
          pe=$((pe + 1))
        fi
      done <<<"$js_files"
      [ $pe -gt 0 ] && info "Fix: $P --write ." || ok "Prettier"
    fi
  fi

  # ── ESLint ────────────────────────────────────────────────
  if checker_on "eslint"; then
    E=""
    command_exists eslint && E="eslint"
    [ -z "$E" ] && [ -f "node_modules/.bin/eslint" ] && E="npx eslint"
    if [ -n "$E" ]; then
      ee=0
      while IFS= read -r f; do
        [ -z "$f" ] || [ ! -f "$f" ] && continue
        if ! $E --quiet "$f" &>/dev/null; then
          [ $ee -eq 0 ] && warn "ESLint issues:"
          info "$f"
          ee=$((ee + 1))
        fi
      done <<<"$js_files"
      [ $ee -eq 0 ] && ok "ESLint"
    fi
  fi

  # ── Biome (fallback) ─────────────────────────────────────
  if checker_on "biome" && ! command_exists prettier && ! command_exists eslint; then
    if command_exists biome; then
      bm=0
      while IFS= read -r f; do
        [ -z "$f" ] || [ ! -f "$f" ] && continue
        if ! biome check "$f" &>/dev/null; then
          [ $bm -eq 0 ] && error "Biome issues:"
          info "$f"
          bm=$((bm + 1))
        fi
      done <<<"$js_files"
      [ $bm -gt 0 ] && info "Fix: biome check --write ." || ok "Biome"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
# GO
# ══════════════════════════════════════════════════════════════

go_files=$(staged_by_ext go)
if [ -n "$go_files" ]; then

  # ── gofmt ─────────────────────────────────────────────────
  if checker_on "gofmt" && command_exists gofmt; then
    ge=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if [ -n "$(gofmt -l "$f" 2>/dev/null)" ]; then
        [ $ge -eq 0 ] && error "Go formatting issues:"
        info "$f"
        ge=$((ge + 1))
      fi
    done <<<"$go_files"
    if [ $ge -gt 0 ]; then
      info "Fix: gofmt -w ."
    else
      fc=$(echo "$go_files" | wc -l | tr -d ' ')
      ok "gofmt — ${fc} file(s)"
    fi
  fi

  # ── go vet ────────────────────────────────────────────────
  if checker_on "govet" && [ -f "go.mod" ] && command_exists go; then
    if ! go vet ./... &>/dev/null; then
      warn "go vet found issues"
    else
      ok "go vet"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
# RUST
# ══════════════════════════════════════════════════════════════

rs_files=$(staged_by_ext rs)
if [ -n "$rs_files" ]; then

  # ── rustfmt ───────────────────────────────────────────────
  if checker_on "rustfmt" && command_exists rustfmt; then
    re=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if ! rustfmt --check "$f" &>/dev/null; then
        [ $re -eq 0 ] && error "rustfmt issues:"
        info "$f"
        re=$((re + 1))
      fi
    done <<<"$rs_files"
    [ $re -gt 0 ] && info "Fix: cargo fmt" || ok "rustfmt"
  fi

  # ── clippy ────────────────────────────────────────────────
  if checker_on "clippy" && [ -f "Cargo.toml" ] && command_exists cargo; then
    if ! cargo clippy --quiet -- -D warnings &>/dev/null; then
      warn "Clippy warnings detected"
      info "Fix: cargo clippy --fix"
    else
      ok "Clippy"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
# YAML
# ══════════════════════════════════════════════════════════════

yaml_files=$(staged_by_ext yml yaml)
if [ -n "$yaml_files" ] && checker_on "yamllint"; then
  if command_exists yamllint; then
    ye=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if ! yamllint -d relaxed "$f" &>/dev/null; then
        [ $ye -eq 0 ] && warn "YAML lint warnings:"
        info "$f"
        ye=$((ye + 1))
      fi
    done <<<"$yaml_files"
    [ $ye -eq 0 ] && {
      fc=$(echo "$yaml_files" | wc -l | tr -d ' ')
      ok "YAML lint — ${fc} file(s)"
    }
  else
    log_skip "yamllint not installed (pip install yamllint)"
  fi
fi

# ══════════════════════════════════════════════════════════════
# JSON
# ══════════════════════════════════════════════════════════════

json_files=$(staged_by_ext json)
if [ -n "$json_files" ] && checker_on "json-syntax"; then
  JC=""
  command_exists jq && JC="jq empty <"
  [ -z "$JC" ] && command_exists python3 && JC="python3 -m json.tool <"
  if [ -n "$JC" ]; then
    je=0
    jc=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      jc=$((jc + 1))
      if ! eval "$JC \"$f\"" &>/dev/null; then
        [ $je -eq 0 ] && error "JSON syntax errors:"
        info "$f"
        je=$((je + 1))
      fi
    done <<<"$json_files"
    [ $je -eq 0 ] && ok "JSON syntax — ${jc} file(s)"
  fi
fi

# ══════════════════════════════════════════════════════════════
# TOML
# ══════════════════════════════════════════════════════════════

toml_files=$(staged_by_ext toml)
if [ -n "$toml_files" ] && checker_on "taplo" && command_exists taplo; then
  te=0
  while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    if ! taplo format --check "$f" &>/dev/null; then
      [ $te -eq 0 ] && error "Taplo (TOML) formatting issues:"
      info "$f"
      te=$((te + 1))
    fi
  done <<<"$toml_files"
  [ $te -gt 0 ] && info "Fix: taplo format ." || ok "Taplo"
fi

# ══════════════════════════════════════════════════════════════
# MARKDOWN
# ══════════════════════════════════════════════════════════════

md_files=$(staged_by_ext md mdx)
if [ -n "$md_files" ] && checker_on "markdownlint" && command_exists markdownlint; then
  me=0
  while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    if ! markdownlint "$f" &>/dev/null; then
      [ $me -eq 0 ] && warn "Markdown lint:"
      info "$f"
      me=$((me + 1))
    fi
  done <<<"$md_files"
  [ $me -eq 0 ] && {
    fc=$(echo "$md_files" | wc -l | tr -d ' ')
    ok "markdownlint — ${fc} file(s)"
  }
fi

# ══════════════════════════════════════════════════════════════
# CSS / SCSS
# ══════════════════════════════════════════════════════════════

css_files=$(staged_by_ext css scss sass less)
if [ -n "$css_files" ] && checker_on "stylelint"; then
  SL=""
  command_exists stylelint && SL="stylelint"
  [ -z "$SL" ] && [ -f "node_modules/.bin/stylelint" ] && SL="npx stylelint"
  if [ -n "$SL" ]; then
    sl=0
    while IFS= read -r f; do
      [ -z "$f" ] || [ ! -f "$f" ] && continue
      if ! $SL --quiet "$f" &>/dev/null; then
        [ $sl -eq 0 ] && warn "Stylelint issues:"
        info "$f"
        sl=$((sl + 1))
      fi
    done <<<"$css_files"
    [ $sl -eq 0 ] && ok "Stylelint"
  fi
fi

# ══════════════════════════════════════════════════════════════
# DOCKERFILE
# ══════════════════════════════════════════════════════════════

dockerfiles=$(echo "$STAGED" | grep -iE '(^|/)Dockerfile' || true)
if [ -n "$dockerfiles" ] && checker_on "hadolint" && command_exists hadolint; then
  he=0
  while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    if ! hadolint "$f" &>/dev/null; then
      [ $he -eq 0 ] && warn "Hadolint (Dockerfile):"
      hadolint "$f" 2>/dev/null | head -3 | while IFS= read -r hl; do
        info "  $hl"
      done
      he=$((he + 1))
    fi
  done <<<"$dockerfiles"
  [ $he -eq 0 ] && ok "Hadolint"
fi

# ══════════════════════════════════════════════════════════════
# TERRAFORM
# ══════════════════════════════════════════════════════════════

tf_files=$(staged_by_ext tf)
if [ -n "$tf_files" ] && checker_on "terraform" && command_exists terraform; then
  if ! terraform fmt -check -diff . &>/dev/null; then
    error "Terraform formatting issues"
    info "Fix: terraform fmt"
  else
    ok "Terraform fmt"
  fi
fi

# ══════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════

echo ""

if [ $errors -gt 0 ]; then
  echo -e "${RED}🚫 ${errors} error(s), ${warnings} warning(s) — commit rejected${NC}"
  echo -e "${DIM}   Fix errors above or bypass: git commit --no-verify${NC}"
  exit 1
fi

if [ $warnings -gt 0 ]; then
  echo -e "${GREEN}✅ Pre-commit passed${NC} ${YELLOW}(${warnings} warning(s))${NC}"
else
  echo -e "${GREEN}✅ All pre-commit checks passed${NC}"
fi
HOOKEOF

success "pre-commit (universal quality gate)"

# ────────────────────────────────────────────────────────────
# post-merge
# ────────────────────────────────────────────────────────────
cat >"${HOOKS_DIR}/post-merge" <<'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Post-merge hook — Universal intelligence after pull/merge   ║
# ║                                                              ║
# ║  Actions:                                                    ║
# ║   1. File changes summary (dynamic directory grouping)       ║
# ║   2. Dependency lockfile changes → install reminders         ║
# ║   3. Version detection (any ecosystem)                       ║
# ║   4. CHANGELOG.md → show latest entry                        ║
# ║   5. New / deleted files summary                             ║
# ║   6. Config file changes → restart/rebuild reminders         ║
# ║   7. Migration detection → run reminders                     ║
# ║   8. Commit count & authors                                  ║
# ║   9. Actionable summary                                      ║
# ║                                                              ║
# ║  Config (.githooks.conf):                                    ║
# ║    [post-merge]                                              ║
# ║    skip = false                                              ║
# ║    show_stat = true        # git diff --stat                 ║
# ║    max_files_shown = 10                                      ║
# ║                                                              ║
# ║  Skip: SKIP_POST_MERGE=1 git pull                            ║
# ╚══════════════════════════════════════════════════════════════╝

# ── Source shared lib ─────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "${HOOK_DIR}/_lib.sh"

# ── Skip check ────────────────────────────────────────────────
should_skip_hook "post-merge" && exit 0

# ── Config ────────────────────────────────────────────────────
SHOW_STAT=$(githooks_config "post-merge" "show_stat" "true")
MAX_FILES=$(githooks_config "post-merge" "max_files_shown" "10")

# ── Changed files ─────────────────────────────────────────────
changed=$(git diff --name-only 'HEAD@{1}' HEAD 2>/dev/null || true)

if [ -z "$changed" ]; then
  echo -e "${GREEN}✅ Already up to date${NC}"
  exit 0
fi

total=$(echo "$changed" | wc -l | tr -d ' ')
added=$(git diff --name-only --diff-filter=A 'HEAD@{1}' HEAD 2>/dev/null | wc -l | tr -d ' ')
modified=$(git diff --name-only --diff-filter=M 'HEAD@{1}' HEAD 2>/dev/null | wc -l | tr -d ' ')
deleted=$(git diff --name-only --diff-filter=D 'HEAD@{1}' HEAD 2>/dev/null | wc -l | tr -d ' ')
renamed=$(git diff --name-only --diff-filter=R 'HEAD@{1}' HEAD 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📋 Post-merge summary                           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

# ── Action collector (filled throughout, printed at end) ──────
declare -a ACTIONS=()

# ══════════════════════════════════════════════════════════════
# 1. FILE CHANGES — Dynamic breakdown
# ══════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}  Files changed:${NC} ${total} total"
[ "$added" -gt 0 ] && echo -e "    ${GREEN}+ ${added} added${NC}"
[ "$modified" -gt 0 ] && echo -e "    ${YELLOW}~ ${modified} modified${NC}"
[ "$deleted" -gt 0 ] && echo -e "    ${RED}- ${deleted} deleted${NC}"
[ "$renamed" -gt 0 ] && echo -e "    ${CYAN}→ ${renamed} renamed${NC}"

# ── Dynamic directory grouping ────────────────────────────────
# Auto-detect top-level directories with changes and show counts
echo ""
echo -e "${BOLD}  By area:${NC}"

# Map common directories to icons (extensible)
dir_icon() {
  case "$1" in
  src | lib) echo "📦" ;;
  test | tests | spec | __tests__) echo "🧪" ;;
  docs | doc) echo "📖" ;;
  .github | .gitlab | .circleci) echo "🤖" ;;
  scripts | bin) echo "⚡" ;;
  config | conf | cfg) echo "⚙️ " ;;
  migrations | db) echo "🗄️ " ;;
  assets | static | public) echo "🎨" ;;
  lua) echo "🌙" ;;
  cmd | internal | pkg) echo "📦" ;;
  components) echo "🧩" ;;
  pages | views | templates) echo "🖼️ " ;;
  styles | css) echo "🎨" ;;
  *) echo "📁" ;;
  esac
}

# Get unique top-level dirs, count files per dir
declare -A dir_counts
root_files=0

while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [[ "$f" == */* ]]; then
    top_dir="${f%%/*}"
    dir_counts["$top_dir"]=$((${dir_counts["$top_dir"]:-0} + 1))
  else
    root_files=$((root_files + 1))
  fi
done <<<"$changed"

# Sort by count (descending) and display
for dir in $(for k in "${!dir_counts[@]}"; do echo "${dir_counts[$k]} $k"; done | sort -rn | awk '{print $2}'); do
  count="${dir_counts[$dir]}"
  icon=$(dir_icon "$dir")
  printf "    %s %-18s %s file(s)\n" "$icon" "${dir}/" "$count"
done

[ "$root_files" -gt 0 ] && echo -e "    📄 (root)              ${root_files} file(s)"

# ── Top changed files (git stat) ──────────────────────────────
if [ "$SHOW_STAT" = "true" ]; then
  echo ""
  echo -e "${DIM}  Most significant changes:${NC}"
  git diff --stat 'HEAD@{1}' HEAD 2>/dev/null | head -"$MAX_FILES" | while IFS= read -r line; do
    echo -e "${DIM}    $line${NC}"
  done
  remaining=$((total - MAX_FILES))
  [ "$remaining" -gt 0 ] && echo -e "${DIM}    ... and ${remaining} more${NC}"
fi

# ══════════════════════════════════════════════════════════════
# 2. DEPENDENCY LOCKFILES — Universal detection
# ══════════════════════════════════════════════════════════════

# Define: lockfile → [display_name, install_command]
declare -A LOCKFILE_MAP=(
  # JavaScript / Node
  ["package-lock.json"]="npm|npm install"
  ["yarn.lock"]="Yarn|yarn install"
  ["pnpm-lock.yaml"]="pnpm|pnpm install"
  ["bun.lockb"]="Bun|bun install"
  # Python
  ["requirements.txt"]="pip|pip install -r requirements.txt"
  ["Pipfile.lock"]="Pipenv|pipenv install"
  ["poetry.lock"]="Poetry|poetry install"
  ["uv.lock"]="uv|uv sync"
  ["pdm.lock"]="PDM|pdm install"
  # Ruby
  ["Gemfile.lock"]="Bundler|bundle install"
  # PHP
  ["composer.lock"]="Composer|composer install"
  # Go
  ["go.sum"]="Go modules|go mod download"
  # Rust
  ["Cargo.lock"]="Cargo|cargo build"
  # Elixir
  ["mix.lock"]="Mix|mix deps.get"
  # Dart/Flutter
  ["pubspec.lock"]="Flutter/Dart|flutter pub get"
  # iOS/macOS
  ["Podfile.lock"]="CocoaPods|pod install"
  # .NET
  ["packages.lock.json"]=".NET|dotnet restore"
  # Nix
  ["flake.lock"]="Nix flake|nix flake update"
  # Neovim
  ["lazy-lock.json"]="lazy.nvim|Open Neovim and run :Lazy sync"
  # Zig
  ["build.zig.zon"]="Zig|zig build"
)

deps_changed=false
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Match basename
  basename_f=$(basename "$f")
  if [ -n "${LOCKFILE_MAP[$basename_f]+x}" ]; then
    IFS='|' read -r dep_name dep_cmd <<<"${LOCKFILE_MAP[$basename_f]}"
    if [ "$deps_changed" = false ]; then
      echo ""
      echo -e "${YELLOW}  📦 Dependency changes detected:${NC}"
      deps_changed=true
    fi
    line_diffs=$(git diff 'HEAD@{1}' HEAD -- "$f" 2>/dev/null | grep -c '^[+-]' 2>/dev/null || echo 0)
    echo -e "    ${YELLOW}${basename_f}${NC} ${DIM}(${dep_name}, ${line_diffs} line diffs)${NC}"
    ACTIONS+=("Run ${BOLD}${dep_cmd}${NC} to sync ${dep_name} dependencies")
  fi
done <<<"$changed"

# ══════════════════════════════════════════════════════════════
# 3. VERSION DETECTION — Universal
# ══════════════════════════════════════════════════════════════

detect_version() {
  local new_version=""

  # package.json → "version": "x.y.z"
  if [ -f "package.json" ] && echo "$changed" | grep -q 'package.json'; then
    new_version=$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' package.json 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^"]*')
  fi

  # pyproject.toml → version = "x.y.z"
  if [ -z "$new_version" ] && [ -f "pyproject.toml" ] && echo "$changed" | grep -q 'pyproject.toml'; then
    new_version=$(grep -E '^version[[:space:]]*=' pyproject.toml 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^"]*')
  fi

  # Cargo.toml → version = "x.y.z"
  if [ -z "$new_version" ] && [ -f "Cargo.toml" ] && echo "$changed" | grep -q 'Cargo.toml'; then
    new_version=$(grep -E '^version[[:space:]]*=' Cargo.toml 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^"]*')
  fi

  # mix.exs → version: "x.y.z"
  if [ -z "$new_version" ] && [ -f "mix.exs" ] && echo "$changed" | grep -q 'mix.exs'; then
    new_version=$(grep -oE 'version:[[:space:]]*"[^"]+"' mix.exs 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  fi

  # VERSION file
  if [ -z "$new_version" ] && echo "$changed" | grep -qE '(^VERSION$|^VERSION\.txt$)'; then
    new_version=$(cat VERSION 2>/dev/null || cat VERSION.txt 2>/dev/null || true)
    new_version=$(echo "$new_version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | head -1)
  fi

  # build.gradle / build.gradle.kts → version = 'x.y.z'
  if [ -z "$new_version" ]; then
    for gradle_file in build.gradle build.gradle.kts; do
      if [ -f "$gradle_file" ] && echo "$changed" | grep -q "$gradle_file"; then
        new_version=$(grep -E "^version[[:space:]]*=" "$gradle_file" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        [ -n "$new_version" ] && break
      fi
    done
  fi

  # .gemspec → s.version = "x.y.z"
  if [ -z "$new_version" ]; then
    gemspec=$(echo "$changed" | grep -E '\.gemspec$' | head -1)
    if [ -n "$gemspec" ] && [ -f "$gemspec" ]; then
      new_version=$(grep -oE "version[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]" "$gemspec" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    fi
  fi

  # Go: version.go or version constant
  if [ -z "$new_version" ]; then
    version_go=$(echo "$changed" | grep -E 'version\.go$' | head -1)
    if [ -n "$version_go" ] && [ -f "$version_go" ]; then
      new_version=$(grep -oE 'Version[[:space:]]*=[[:space:]]*"[^"]+"' "$version_go" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    fi
  fi

  # Lua: version.lua (Neovim plugins, etc.)
  if [ -z "$new_version" ]; then
    version_lua=$(echo "$changed" | grep -E 'version\.lua$' | head -1)
    if [ -n "$version_lua" ] && [ -f "$version_lua" ]; then
      # Try: M.version = "x.y.z" or major/minor/patch fields
      new_version=$(grep -oE 'version[[:space:]]*=[[:space:]]*"[^"]+"' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
      if [ -z "$new_version" ]; then
        local v_major v_minor v_patch
        v_major=$(grep -E 'major[[:space:]]*=' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+')
        v_minor=$(grep -E 'minor[[:space:]]*=' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+')
        v_patch=$(grep -E 'patch[[:space:]]*=' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+')
        [ -n "$v_major" ] && [ -n "$v_minor" ] && [ -n "$v_patch" ] &&
          new_version="${v_major}.${v_minor}.${v_patch}"
      fi
    fi
  fi

  echo "$new_version"
}

new_ver=$(detect_version)
if [ -n "$new_ver" ]; then
  echo ""
  echo -e "${GREEN}  🏷️  Version updated → ${BOLD}v${new_ver}${NC}"
fi

# ══════════════════════════════════════════════════════════════
# 4. CHANGELOG
# ══════════════════════════════════════════════════════════════

changelog_file=""
for f in CHANGELOG.md CHANGELOG.rst CHANGES.md HISTORY.md; do
  if echo "$changed" | grep -qi "^${f}$"; then
    changelog_file="$f"
    break
  fi
done

if [ -n "$changelog_file" ] && [ -f "$changelog_file" ]; then
  echo ""
  latest_entry=$(grep -m 1 -E '^## ' "$changelog_file" 2>/dev/null || true)
  if [ -n "$latest_entry" ]; then
    echo -e "${CYAN}  📋 ${changelog_file}: ${latest_entry}${NC}"
  else
    echo -e "${CYAN}  📋 ${changelog_file} updated${NC}"
  fi
fi

# ══════════════════════════════════════════════════════════════
# 5. NEW / DELETED FILES SUMMARY
# ══════════════════════════════════════════════════════════════

new_files=$(git diff --name-only --diff-filter=A 'HEAD@{1}' HEAD 2>/dev/null || true)
del_files=$(git diff --name-only --diff-filter=D 'HEAD@{1}' HEAD 2>/dev/null || true)

if [ -n "$new_files" ]; then
  new_count=$(echo "$new_files" | wc -l | tr -d ' ')
  echo ""
  echo -e "${GREEN}  ✨ ${new_count} new file(s):${NC}"

  # Group new files by extension for a compact view
  declare -A new_by_ext
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    ext="${f##*.}"
    [ "$ext" = "$f" ] && ext="(no ext)"
    new_by_ext["$ext"]=$((${new_by_ext["$ext"]:-0} + 1))
  done <<<"$new_files"

  for ext in $(for k in "${!new_by_ext[@]}"; do echo "${new_by_ext[$k]} $k"; done | sort -rn | awk '{print $2}'); do
    echo -e "${DIM}    + ${new_by_ext[$ext]} .${ext} file(s)${NC}"
  done

  # Show first few filenames
  echo "$new_files" | head -5 | while IFS= read -r f; do
    echo -e "${DIM}      $f${NC}"
  done
  [ "$new_count" -gt 5 ] && echo -e "${DIM}      ... and $((new_count - 5)) more${NC}"
fi

if [ -n "$del_files" ]; then
  del_count=$(echo "$del_files" | wc -l | tr -d ' ')
  echo ""
  echo -e "${RED}  🗑️  ${del_count} file(s) removed${NC}"
  echo "$del_files" | head -5 | while IFS= read -r f; do
    echo -e "${DIM}    - $f${NC}"
  done
  [ "$del_count" -gt 5 ] && echo -e "${DIM}    ... and $((del_count - 5)) more${NC}"
fi

# ══════════════════════════════════════════════════════════════
# 6. CONFIG / INFRASTRUCTURE CHANGES — Universal
# ══════════════════════════════════════════════════════════════

# Define patterns → [icon, description, action]
declare -a CONFIG_TRIGGERS=(
  # Docker
  "Dockerfile|🐳|Dockerfile changed|Rebuild: docker compose build"
  "docker-compose*.yml|🐳|Docker Compose changed|Restart: docker compose up -d"
  "docker-compose*.yaml|🐳|Docker Compose changed|Restart: docker compose up -d"
  # CI/CD
  ".github/workflows/*|🤖|GitHub Actions workflow changed|CI pipeline updated"
  ".gitlab-ci.yml|🤖|GitLab CI changed|CI pipeline updated"
  ".circleci/*|🤖|CircleCI config changed|CI pipeline updated"
  "Jenkinsfile|🤖|Jenkinsfile changed|CI pipeline updated"
  # Terraform / IaC
  "*.tf|🏗️ |Terraform files changed|Run: terraform plan"
  # Database
  "migrations/*|🗄️ |Database migrations changed|Run pending migrations"
  "db/migrate/*|🗄️ |Rails migrations changed|Run: rails db:migrate"
  "alembic/*|🗄️ |Alembic migrations changed|Run: alembic upgrade head"
  # Environment
  ".env.example|🔐|.env.example changed|Check your .env matches the new template"
  ".envrc|🔐|.envrc changed|Run: direnv allow"
  # Neovim (auto-detected, not hardcoded as primary)
  "init.lua|🌙|init.lua changed|Restart Neovim"
  # Makefile
  "Makefile|⚡|Makefile changed|Review build targets"
  "CMakeLists.txt|⚡|CMake config changed|Re-run: cmake .."
  # Editor / tooling config
  ".editorconfig|📐|EditorConfig changed|Reload editor"
  ".prettierrc*|📐|Prettier config changed|Reformat: prettier --write ."
  ".eslintrc*|📐|ESLint config changed|Review lint rules"
  "tsconfig*.json|📐|TypeScript config changed|Restart TS server"
  "stylua.toml|📐|StyLua config changed|Reformat: stylua ."
  ".rustfmt.toml|📐|rustfmt config changed|Reformat: cargo fmt"
  "pyproject.toml|📐|pyproject.toml changed|Check tool configs"
)

config_changed=false
for trigger in "${CONFIG_TRIGGERS[@]}"; do
  IFS='|' read -r pattern icon desc action <<<"$trigger"

  # Match pattern against changed files
  matched=false
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Support glob matching
    # shellcheck disable=SC2254
    case "$f" in
    $pattern)
      matched=true
      break
      ;;
    esac
  done <<<"$changed"

  if [ "$matched" = true ]; then
    if [ "$config_changed" = false ]; then
      echo ""
      echo -e "${YELLOW}  🔄 Configuration changes detected:${NC}"
      config_changed=true
    fi
    echo -e "    ${icon} ${desc}"
    [ -n "$action" ] && [ "$action" != " " ] &&
      ACTIONS+=("${action}")
  fi
done

# ══════════════════════════════════════════════════════════════
# 7. COMMIT COUNT & AUTHORS
# ══════════════════════════════════════════════════════════════

commit_count=$(git rev-list --count 'HEAD@{1}'..HEAD 2>/dev/null || echo "?")
authors=$(git log 'HEAD@{1}'..HEAD --format='%an' 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/,$//' || true)

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────${NC}"
echo -e "${DIM}  ${commit_count} commit(s) merged${NC}"
[ -n "$authors" ] && echo -e "${DIM}  Authors: ${authors}${NC}"

# ══════════════════════════════════════════════════════════════
# 8. ACTIONS SUMMARY
# ══════════════════════════════════════════════════════════════

if [ ${#ACTIONS[@]} -gt 0 ]; then
  echo ""
  echo -e "${CYAN}  📌 Recommended actions:${NC}"
  action_num=0
  # Deduplicate actions
  declare -A seen_actions
  for action in "${ACTIONS[@]}"; do
    # Use plain text as key (strip formatting)
    plain=$(echo -e "$action" | sed 's/\x1b\[[0-9;]*m//g')
    if [ -z "${seen_actions[$plain]+x}" ]; then
      seen_actions["$plain"]=1
      action_num=$((action_num + 1))
      echo -e "    ${YELLOW}${action_num}.${NC} ${action}"
    fi
  done
fi

echo ""
echo -e "${GREEN}✅ Merge complete${NC}"
HOOKEOF

success "post-merge (universal intelligence)"

# ────────────────────────────────────────────────────────────
# pre-push
# ────────────────────────────────────────────────────────────
cat >"${HOOKS_DIR}/pre-push" <<'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Pre-push hook — Universal last gate before code leaves      ║
# ║                                                              ║
# ║  Checks:                                                     ║
# ║   1. WIP/fixup/squash commits (blocks)                       ║
# ║   2. Language checks — auto-detected (blocks):               ║
# ║      Lua    → syntax (luajit/luac) + stylua                  ║
# ║      Python → syntax + ruff/black                            ║
# ║      JS/TS  → prettier + eslint                              ║
# ║      Go     → go vet + gofmt                                 ║
# ║      Rust   → cargo check + rustfmt                          ║
# ║      Shell  → shellcheck                                     ║
# ║   3. Version consistency (tag push only)                     ║
# ║   4. CHANGELOG entry (tag push only)                         ║
# ║   5. Branch protection (interactive)                         ║
# ║   6. Uncommitted changes warning                             ║
# ║   7. Test runner (if configured)                             ║
# ║                                                              ║
# ║  Config (.githooks.conf):                                    ║
# ║    [pre-push]                                                ║
# ║    skip = false                                              ║
# ║    disable = stylua,eslint      # skip specific checkers     ║
# ║    protected_branches = main,master,production               ║
# ║    run_tests = false            # true = run test suite      ║
# ║    test_command = npm test      # custom test command        ║
# ║    allow_wip = false            # true = allow WIP pushes    ║
# ║                                                              ║
# ║  Skip: SKIP_PRE_PUSH=1 git push                              ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Source shared lib ─────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "${HOOK_DIR}/_lib.sh"

# ── Skip check ────────────────────────────────────────────────
should_skip_hook "pre-push" && exit 0

# ── Config ────────────────────────────────────────────────────
PROTECTED=$(githooks_config "pre-push" "protected_branches" "main,master,production,release,staging")
ALLOW_WIP=$(githooks_config "pre-push" "allow_wip" "false")
RUN_TESTS=$(githooks_config "pre-push" "run_tests" "false")
TEST_CMD=$(githooks_config "pre-push" "test_command" "")

# ── Counters ──────────────────────────────────────────────────
errors=0
warnings=0

error() {
  echo -e "  ${RED}✗ $1${NC}"
  errors=$((errors + 1))
}
warn() {
  echo -e "  ${YELLOW}⚠ $1${NC}"
  warnings=$((warnings + 1))
}
ok() { echo -e "  ${GREEN}✓ $1${NC}"; }
info() { echo -e "  ${DIM}  $1${NC}"; }

# ── Context ───────────────────────────────────────────────────
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
remote="${1:-origin}"
#url="${2:-}"

# Detect if pushing a tag
pushing_tag=false
tag_name=""
while read -r _local_ref _local_sha remote_ref _remote_sha; do
  if echo "$remote_ref" | grep -q '^refs/tags/'; then
    pushing_tag=true
    tag_name="${remote_ref#refs/tags/}"
  fi
done

echo -e "${CYAN}🔍 Pre-push checks...${NC}"
echo -e "${DIM}   Branch: ${branch}  Remote: ${remote}  Tag: ${tag_name:-none}${NC}"

# ── Helper: get all tracked files by extension ────────────────
tracked_files_by_ext() {
  local ext
  for ext in "$@"; do
    git ls-files "*.${ext}" 2>/dev/null || true
  done | sort -u | grep -v '^$' || true
}

# ── Helper: checker guard ─────────────────────────────────────
checker_enabled() {
  local _name="$1"
  checker_on() {
    is_checker_enabled "pre-push" "$1" || return 1
    return 0
  }
  return 0
}

# ══════════════════════════════════════════════════════════════
# 1. WIP / FIXUP / SQUASH COMMITS
# ══════════════════════════════════════════════════════════════

if [ "$ALLOW_WIP" != "true" ]; then
  wip_commits=$(git log '@{upstream}'..HEAD --oneline 2>/dev/null |
    grep -iE '(^[a-f0-9]+ wip |^[a-f0-9]+ wip:|fixup!|squash!|amend!)' || true)

  if [ -n "$wip_commits" ]; then
    error "WIP/fixup commits found — squash before pushing:"
    echo "$wip_commits" | while IFS= read -r line; do
      info "$line"
    done
    info "Fix: git rebase -i --autosquash"
  else
    ok "No WIP/fixup commits"
  fi
else
  ok "WIP commits allowed (config)"
fi

# ══════════════════════════════════════════════════════════════
# 2. LANGUAGE CHECKS — Auto-detected from tracked files
# ══════════════════════════════════════════════════════════════

echo -e "${CYAN}   ── Language checks ──${NC}"

# ── LUA ──────────────────────────────────────────────────────
lua_files=$(tracked_files_by_ext lua)
if [ -n "$lua_files" ]; then

  # ── Lua syntax ────────────────────────────────────────────
  if checker_enabled "lua-syntax"; then
    LUA_CMD="" LUA_NAME=""
    if command_exists luajit; then
      LUA_CMD="luajit -bl" LUA_NAME="LuaJIT"
    elif command_exists luac5.1; then
      LUA_CMD="luac5.1 -p" LUA_NAME="luac5.1"
    elif command_exists luac; then
      LUA_CMD="luac -p" LUA_NAME="luac"
    fi

    if [ -n "$LUA_CMD" ]; then
      lua_errors=0
      file_count=0
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        file_count=$((file_count + 1))
        if ! $LUA_CMD "$f" &>/dev/null; then
          if [ $lua_errors -eq 0 ]; then
            error "Lua syntax errors (${LUA_NAME}):"
          fi
          info "$f"
          $LUA_CMD "$f" 2>&1 | head -3 | while IFS= read -r err_line; do
            info "  $err_line"
          done
          lua_errors=$((lua_errors + 1))
        fi
      done <<<"$lua_files"

      [ $lua_errors -eq 0 ] && ok "Lua syntax — ${file_count} files (${LUA_NAME})"
    else
      log_skip "No Lua checker found (install luajit)"
    fi
  fi

  # ── StyLua — check tracked files, NOT a hardcoded dir ────
  if checker_enabled "stylua"; then
    if command_exists stylua; then
      stylua_errors=0
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ -f "$f" ] || continue
        if ! stylua --check "$f" &>/dev/null; then
          if [ $stylua_errors -eq 0 ]; then
            error "StyLua formatting issues:"
          fi
          info "$f"
          stylua_errors=$((stylua_errors + 1))
        fi
      done <<<"$lua_files"

      if [ $stylua_errors -gt 0 ]; then
        info "Fix: stylua \$(git ls-files '*.lua')"
      else
        ok "StyLua formatting"
      fi
    else
      log_skip "StyLua not installed (brew install stylua)"
    fi
  fi
fi

# ── PYTHON ────────────────────────────────────────────────────
py_files=$(tracked_files_by_ext py)
if [ -n "$py_files" ]; then

  # ── Python syntax ────────────────────────────────────────
  if checker_enabled "python-syntax" && command_exists python3; then
    py_errors=0
    py_count=0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$f" ] || continue
      py_count=$((py_count + 1))
      if ! python3 -m py_compile "$f" &>/dev/null; then
        if [ $py_errors -eq 0 ]; then error "Python syntax errors:"; fi
        info "$f"
        python3 -m py_compile "$f" 2>&1 | head -3 | while IFS= read -r err; do
          info "  $err"
        done
        py_errors=$((py_errors + 1))
      fi
    done <<<"$py_files"
    [ $py_errors -eq 0 ] && ok "Python syntax — ${py_count} files"
  fi

  # ── Ruff ──────────────────────────────────────────────────
  if checker_enabled "ruff" && command_exists ruff; then
    if ! ruff check --quiet . &>/dev/null; then
      warn "Ruff lint issues found"
      ruff check . 2>/dev/null | tail -5 | while IFS= read -r rl; do
        info "$rl"
      done
    else
      ok "Ruff lint"
    fi
    if ! ruff format --check --quiet . &>/dev/null; then
      error "Ruff format issues found"
      info "Fix: ruff format ."
    else
      ok "Ruff format"
    fi
  fi

  # ── Black (fallback) ─────────────────────────────────────
  if checker_enabled "black" && ! command_exists ruff && command_exists black; then
    if ! black --check --quiet . &>/dev/null; then
      error "Black formatting issues"
      info "Fix: black ."
    else
      ok "Black formatting"
    fi
  fi
fi

# ── JAVASCRIPT / TYPESCRIPT ──────────────────────────────────
js_files=$(tracked_files_by_ext js jsx mjs cjs ts tsx)
if [ -n "$js_files" ]; then

  # ── Prettier ──────────────────────────────────────────────
  if checker_enabled "prettier"; then
    PRETTIER_CMD=""
    if command_exists prettier; then
      PRETTIER_CMD="prettier"
    elif [ -f "node_modules/.bin/prettier" ]; then
      PRETTIER_CMD="npx prettier"
    fi
    if [ -n "$PRETTIER_CMD" ]; then
      if ! $PRETTIER_CMD --check . &>/dev/null 2>&1; then
        error "Prettier formatting issues"
        info "Fix: $PRETTIER_CMD --write ."
      else
        ok "Prettier formatting"
      fi
    fi
  fi

  # ── ESLint ────────────────────────────────────────────────
  if checker_enabled "eslint"; then
    ESLINT_CMD=""
    if command_exists eslint; then
      ESLINT_CMD="eslint"
    elif [ -f "node_modules/.bin/eslint" ]; then
      ESLINT_CMD="npx eslint"
    fi
    if [ -n "$ESLINT_CMD" ]; then
      if ! $ESLINT_CMD --quiet . &>/dev/null 2>&1; then
        warn "ESLint issues found"
      else
        ok "ESLint"
      fi
    fi
  fi

  # ── TypeScript compile check ─────────────────────────────
  if checker_enabled "tsc" && [ -f "tsconfig.json" ]; then
    TSC_CMD=""
    if command_exists tsc; then
      TSC_CMD="tsc"
    elif [ -f "node_modules/.bin/tsc" ]; then
      TSC_CMD="npx tsc"
    fi
    if [ -n "$TSC_CMD" ]; then
      if ! $TSC_CMD --noEmit &>/dev/null; then
        error "TypeScript compilation errors"
        info "Run: $TSC_CMD --noEmit"
      else
        ok "TypeScript compiles"
      fi
    fi
  fi
fi

# ── GO ────────────────────────────────────────────────────────
go_files=$(tracked_files_by_ext go)
if [ -n "$go_files" ] && [ -f "go.mod" ]; then

  if checker_enabled "gofmt" && command_exists gofmt; then
    unformatted=$(gofmt -l . 2>/dev/null | grep -v vendor/ || true)
    if [ -n "$unformatted" ]; then
      error "Go formatting issues:"
      echo "$unformatted" | head -5 | while IFS= read -r f; do info "$f"; done
      info "Fix: gofmt -w ."
    else
      ok "gofmt"
    fi
  fi

  if checker_enabled "govet" && command_exists go; then
    if ! go vet ./... &>/dev/null; then
      error "go vet found issues"
      go vet ./... 2>&1 | head -5 | while IFS= read -r line; do
        info "$line"
      done
    else
      ok "go vet"
    fi
  fi

  if checker_enabled "go-build" && command_exists go; then
    if ! go build ./... &>/dev/null; then
      error "Go build failed"
    else
      ok "Go builds"
    fi
  fi
fi

# ── RUST ──────────────────────────────────────────────────────
rs_files=$(tracked_files_by_ext rs)
if [ -n "$rs_files" ] && [ -f "Cargo.toml" ]; then

  if checker_enabled "rustfmt" && command_exists rustfmt; then
    if ! cargo fmt --check &>/dev/null 2>&1; then
      error "Rust formatting issues"
      info "Fix: cargo fmt"
    else
      ok "rustfmt"
    fi
  fi

  if checker_enabled "cargo-check" && command_exists cargo; then
    if ! cargo check --quiet &>/dev/null 2>&1; then
      error "cargo check failed"
      cargo check 2>&1 | grep '^error' | head -5 | while IFS= read -r line; do
        info "$line"
      done
    else
      ok "cargo check"
    fi
  fi

  if checker_enabled "clippy" && command_exists cargo; then
    if ! cargo clippy --quiet -- -D warnings &>/dev/null 2>&1; then
      warn "Clippy warnings"
    else
      ok "Clippy"
    fi
  fi
fi

# ── SHELL ─────────────────────────────────────────────────────
sh_files=$(tracked_files_by_ext sh bash zsh)
if [ -n "$sh_files" ] && checker_enabled "shellcheck" && command_exists shellcheck; then
  sc_errors=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    if ! shellcheck -S error "$f" &>/dev/null; then
      if [ $sc_errors -eq 0 ]; then error "ShellCheck errors:"; fi
      info "$f"
      sc_errors=$((sc_errors + 1))
    fi
  done <<<"$sh_files"
  [ $sc_errors -eq 0 ] && ok "ShellCheck"
fi

# ══════════════════════════════════════════════════════════════
# 3. VERSION CONSISTENCY (tag push only)
# ══════════════════════════════════════════════════════════════

if [ "$pushing_tag" = true ]; then
  echo -e "${CYAN}   ── Tag validation ──${NC}"
  tag_version="${tag_name#v}"

  # ── Universal version detection ──────────────────────────
  detected_version=""

  # Map: file → grep pattern → extract pattern
  declare -A VERSION_FILES=(
    ["package.json"]='"version"[[:space:]]*:[[:space:]]*"'
    ["pyproject.toml"]='^version[[:space:]]*='
    ["Cargo.toml"]='^version[[:space:]]*='
    ["mix.exs"]='version:[[:space:]]*"'
    ["VERSION"]='^'
    ["VERSION.txt"]='^'
  )

  # Also search for common version file patterns
  for vfile in "${!VERSION_FILES[@]}"; do
    if [ -f "$vfile" ]; then
      detected_version=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z0-9.\-]*' "$vfile" 2>/dev/null | head -1)
      [ -n "$detected_version" ] && break
    fi
  done

  # Lua version.lua (any location)
  if [ -z "$detected_version" ]; then
    version_lua=$(git ls-files '**/version.lua' 'version.lua' 2>/dev/null | head -1)
    if [ -n "$version_lua" ] && [ -f "$version_lua" ]; then
      detected_version=$(grep -oE 'version[[:space:]]*=[[:space:]]*"[^"]+"' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
      if [ -z "$detected_version" ]; then
        v_major=$(grep -E 'major[[:space:]]*=' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+')
        v_minor=$(grep -E 'minor[[:space:]]*=' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+')
        v_patch=$(grep -E 'patch[[:space:]]*=' "$version_lua" 2>/dev/null | head -1 | grep -oE '[0-9]+')
        [ -n "$v_major" ] && [ -n "$v_minor" ] && [ -n "$v_patch" ] &&
          detected_version="${v_major}.${v_minor}.${v_patch}"
      fi
    fi
  fi

  # build.gradle
  if [ -z "$detected_version" ]; then
    for gf in build.gradle build.gradle.kts; do
      if [ -f "$gf" ]; then
        detected_version=$(grep -E "^version[[:space:]]*=" "$gf" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        [ -n "$detected_version" ] && break
      fi
    done
  fi

  # ── Compare tag vs detected version ──────────────────────
  if [ -n "$detected_version" ]; then
    if [ "$tag_version" = "$detected_version" ]; then
      ok "Tag ${tag_name} matches source version (${detected_version})"
    else
      error "Tag ${tag_name} ≠ source version (${detected_version})"
      info "Update the version file or tag with: git tag v${detected_version}"
    fi
  else
    warn "No version file found — cannot verify tag consistency"
    info "Supported: package.json, pyproject.toml, Cargo.toml, VERSION, version.lua, ..."
  fi

  # ── CHANGELOG entry ──────────────────────────────────────
  changelog=""
  for f in CHANGELOG.md CHANGELOG.rst CHANGES.md HISTORY.md; do
    [ -f "$f" ] && changelog="$f" && break
  done

  if [ -n "$changelog" ]; then
    if grep -q "\[${tag_version}\]" "$changelog" 2>/dev/null ||
      grep -q "## ${tag_version}" "$changelog" 2>/dev/null ||
      grep -q "## v${tag_version}" "$changelog" 2>/dev/null; then
      ok "${changelog} contains ${tag_version}"
    else
      warn "${changelog} missing entry for ${tag_version}"
      info "Consider documenting changes before release"
    fi
  else
    warn "No changelog found"
  fi
else
  ok "Not a tag push — skipping version checks"
fi

# ══════════════════════════════════════════════════════════════
# 4. BRANCH PROTECTION
# ══════════════════════════════════════════════════════════════

# Convert comma-separated config to regex
protected_regex=$(echo "$PROTECTED" | tr ',' '|')

if echo "$branch" | grep -qE "^(${protected_regex})$"; then
  ahead=$(git rev-list --count '@{upstream}'..HEAD 2>/dev/null || echo "?")

  echo ""
  echo -e "${YELLOW}  ⚠ Pushing ${BOLD}${ahead}${NC}${YELLOW} commit(s) to protected branch: ${BOLD}${branch}${NC}"

  echo -e "${DIM}"
  git log '@{upstream}'..HEAD --oneline 2>/dev/null | head -5 | while IFS= read -r line; do
    echo "    $line"
  done
  remaining=$(git rev-list --count '@{upstream}'..HEAD 2>/dev/null || echo 0)
  [ "$remaining" -gt 5 ] && echo "    ... and $((remaining - 5)) more"
  echo -e "${NC}"

  # Only prompt if interactive terminal (not CI)
  if [ -t 0 ]; then
    read -r -p "   Continue pushing to ${branch}? [y/N] " -n 1 REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${RED}🚫 Push cancelled${NC}"
      exit 1
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════
# 5. UNCOMMITTED CHANGES WARNING
# ══════════════════════════════════════════════════════════════

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  dirty_count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  warn "${dirty_count} uncommitted change(s) — NOT included in push"
else
  ok "Working tree clean"
fi

# ══════════════════════════════════════════════════════════════
# 6. TEST RUNNER (opt-in via config)
# ══════════════════════════════════════════════════════════════

if [ "$RUN_TESTS" = "true" ]; then
  echo -e "${CYAN}   ── Tests ──${NC}"

  # Auto-detect test command if not configured
  if [ -z "$TEST_CMD" ]; then
    if [ -f "Makefile" ] && grep -q '^test:' Makefile 2>/dev/null; then
      TEST_CMD="make test"
    elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
      TEST_CMD="npm test"
    elif [ -f "Cargo.toml" ]; then
      TEST_CMD="cargo test --quiet"
    elif [ -f "go.mod" ]; then
      TEST_CMD="go test ./..."
    elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
      if command_exists pytest; then
        TEST_CMD="pytest --quiet"
      elif command_exists python3; then
        TEST_CMD="python3 -m unittest discover -s tests"
      fi
    elif [ -f "mix.exs" ]; then
      TEST_CMD="mix test --quiet"
    elif [ -f "Gemfile" ]; then
      if command_exists rspec; then
        TEST_CMD="bundle exec rspec"
      elif command_exists rake; then
        TEST_CMD="bundle exec rake test"
      fi
    fi
  fi

  if [ -n "$TEST_CMD" ]; then
    info "Running: ${TEST_CMD}"
    if eval "$TEST_CMD" &>/dev/null; then
      ok "Tests passed"
    else
      error "Tests failed!"
      info "Run manually: ${TEST_CMD}"
    fi
  else
    warn "run_tests=true but no test command detected"
    info "Set test_command in .githooks.conf"
  fi
fi

# ══════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════

echo ""

if [ $errors -gt 0 ]; then
  echo -e "${RED}🚫 ${errors} error(s), ${warnings} warning(s) — push rejected${NC}"
  echo -e "${DIM}   Fix errors or bypass: git push --no-verify${NC}"
  exit 1
fi

if [ $warnings -gt 0 ]; then
  echo -e "${GREEN}✅ Pre-push passed${NC} ${YELLOW}(${warnings} warning(s))${NC}"
else
  echo -e "${GREEN}✅ All pre-push checks passed${NC}"
fi
HOOKEOF

success "pre-push (universal last gate)"

# ══════════════════════════════════════════════════════════════
# SET PERMISSIONS
# ══════════════════════════════════════════════════════════════

chmod +x "${HOOKS_DIR}/commit-msg"
chmod +x "${HOOKS_DIR}/pre-commit"
chmod +x "${HOOKS_DIR}/post-merge"
chmod +x "${HOOKS_DIR}/pre-push"
chmod +x "${HOOKS_DIR}/_lib.sh"

success "Permissions set (chmod +x)"

# ══════════════════════════════════════════════════════════════
# CONFIGURE GIT
# ══════════════════════════════════════════════════════════════

header "⚙️  Configuring git..."
echo ""

current_template=$(git config --global init.templateDir 2>/dev/null || true)

if [ "$current_template" = "$TEMPLATE_DIR" ]; then
  success "init.templateDir already set"
else
  if [ -n "$current_template" ]; then
    warn "Changing init.templateDir: ${current_template} → ${TEMPLATE_DIR}"
  fi
  git config --global init.templateDir "$TEMPLATE_DIR"
  success "git config --global init.templateDir ${TEMPLATE_DIR}"
fi

# ══════════════════════════════════════════════════════════════
# CREATE EXAMPLE .githooks.conf
# ══════════════════════════════════════════════════════════════

EXAMPLE_CONF="${TEMPLATE_DIR}/githooks.conf.example"
cat >"$EXAMPLE_CONF" <<'CONFEOF'
# ╔══════════════════════════════════════════════════════════════╗
# ║  .githooks.conf — Per-repo hook configuration                ║
# ║                                                              ║
# ║  Place this file at your repo root as .githooks.conf         ║
# ║  Lines starting with # are comments                          ║
# ╚══════════════════════════════════════════════════════════════╝

[global]
# skip_all = false              # disable all hooks for this repo

[commit-msg]
# skip = false
# subject_max_length = 72
# body_max_length = 100
# strict_warnings = false       # true = warnings block commit

[pre-commit]
# skip = false
# max_file_size = 5242880       # 5MB in bytes
# debug_markers_block = false
# trailing_ws_block = false
# disable = stylua,black        # comma-separated checkers to skip

[pre-push]
# skip = false
# protected_branches = main,master,production,release,staging
# allow_wip = false
# run_tests = false
# test_command =                 # auto-detected if empty
# disable = eslint,prettier

[post-merge]
# skip = false
# show_stat = true
# max_files_shown = 10
CONFEOF

success "Example config → ${DIM}${EXAMPLE_CONF}${NC}"

# ══════════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════����═════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  ✅ Installation complete!                        ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Installed:${NC}"
echo -e "    ${HOOKS_DIR}/_lib.sh"
echo -e "    ${HOOKS_DIR}/commit-msg"
echo -e "    ${HOOKS_DIR}/pre-commit"
echo -e "    ${HOOKS_DIR}/post-merge"
echo -e "    ${HOOKS_DIR}/pre-push"
echo ""
echo -e "  ${BOLD}What happens now:${NC}"
echo -e "    • ${GREEN}git init${NC}  → hooks auto-injected"
echo -e "    • ${GREEN}git clone${NC} → hooks auto-injected"
echo ""
echo -e "  ${BOLD}Existing repos:${NC} reinject hooks manually"
echo -e "    ${CYAN}cd your-repo && git init${NC}  ${DIM}(safe — won't erase anything)${NC}"
echo ""
echo -e "  ${BOLD}Per-repo config:${NC}"
echo -e "    ${CYAN}cp ${EXAMPLE_CONF} your-repo/.githooks.conf${NC}"
echo ""
echo -e "  ${BOLD}Skip hooks:${NC}"
echo -e "    ${CYAN}SKIP_HOOKS=1 git commit${NC}          ${DIM}# skip all${NC}"
echo -e "    ${CYAN}SKIP_PRE_COMMIT=1 git commit${NC}     ${DIM}# skip one${NC}"
echo -e "    ${CYAN}git commit --no-verify${NC}           ${DIM}# git native${NC}"
echo ""
echo -e "  ${BOLD}Verify:${NC}"
echo -e "    ${CYAN}bash install.sh --check${NC}"
echo ""
echo -e "  ${BOLD}Update:${NC}"
echo -e "    ${CYAN}bash install.sh --update${NC}"
echo ""
