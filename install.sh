#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Git Hooks Template Installer                                ║
# ║                                                              ║
# ║  Downloads and installs universal git hooks from GitHub.     ║
# ║  Single source of truth: hooks/ directory in the repo.       ║
# ║                                                              ║
# ║  Usage:                                                      ║
# ║    bash install.sh              # interactive install        ║
# ║    bash install.sh --force      # overwrite without prompt   ║
# ║    bash install.sh --uninstall  # remove hooks + config      ║
# ║    bash install.sh --check      # verify installation        ║
# ║    bash install.sh --update     # update to latest           ║
# ║    bash install.sh --local      # install from local files   ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
TEMPLATE_DIR="${HOME}/.git-templates"
HOOKS_DIR="${TEMPLATE_DIR}/hooks"
BACKUP_DIR="${HOME}/.git-templates-backup-$(date +%Y%m%d-%H%M%S)"
REPO_URL="https://raw.githubusercontent.com/ca971/git-templates/main"
HOOK_FILES=("_lib.sh" "commit-msg" "pre-commit" "post-merge" "pre-push")

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
FORCE=false
LOCAL=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --uninstall) MODE="uninstall" ;;
    --check) MODE="check" ;;
    --update) MODE="update" ;;
    --local) LOCAL=true ;;
    --help | -h) MODE="help" ;;
    *)
      fail "Unknown option: $arg"
      exit 1
      ;;
  esac
done

# ── Detect if running from cloned repo ────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "${SCRIPT_DIR}/hooks" ] && [ -f "${SCRIPT_DIR}/hooks/_lib.sh" ]; then
  LOCAL_HOOKS_DIR="${SCRIPT_DIR}/hooks"
else
  LOCAL_HOOKS_DIR=""
fi

# ══════════════════════════════════════════════════════════════
# HELP
# ══════════════════════════════════════════════════════════════

if [ "$MODE" = "help" ]; then
  cat << 'EOF'

  Git Hooks Template Installer
  ────────────────────────────

  Usage:
    bash install.sh              Interactive install (downloads from GitHub)
    bash install.sh --local      Install from local hooks/ directory
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
    See: https://github.com/ca971/git-templates

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
  check_errors=0

  # Check git config
  template_config=$(git config --global init.templateDir 2> /dev/null || true)
  if [ "$template_config" = "$TEMPLATE_DIR" ]; then
    success "git config init.templateDir = ${template_config}"
  elif [ -n "$template_config" ]; then
    warn "init.templateDir = ${template_config} (expected: ${TEMPLATE_DIR})"
    check_errors=$((check_errors + 1))
  else
    fail "init.templateDir not set"
    check_errors=$((check_errors + 1))
  fi

  # Check hooks directory
  if [ -d "$HOOKS_DIR" ]; then
    success "Hooks directory exists: ${HOOKS_DIR}"
  else
    fail "Hooks directory missing: ${HOOKS_DIR}"
    check_errors=$((check_errors + 1))
  fi

  # Check each hook file
  for hook in "${HOOK_FILES[@]}"; do
    hook_path="${HOOKS_DIR}/${hook}"
    if [ -f "$hook_path" ]; then
      if [ -x "$hook_path" ]; then
        size=$(wc -c < "$hook_path" | tr -d ' ')
        success "${hook} (${size} bytes, executable)"
      else
        warn "${hook} exists but not executable"
        check_errors=$((check_errors + 1))
      fi
    else
      fail "${hook} missing"
      check_errors=$((check_errors + 1))
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
    IFS=':' read -r tool desc <<< "$tool_entry"
    if command -v "$tool" &> /dev/null; then
      version=$($tool --version 2> /dev/null | head -1 || echo "?")
      success "${tool} — ${desc} ${DIM}(${version})${NC}"
    else
      echo -e "  ${DIM}○ ${tool} — ${desc} (not installed)${NC}"
    fi
  done

  echo ""
  if [ $check_errors -eq 0 ]; then
    echo -e "${GREEN}✅ Installation OK${NC}"
  else
    echo -e "${YELLOW}⚠  ${check_errors} issue(s) found${NC}"
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

    cp -r "$TEMPLATE_DIR" "$BACKUP_DIR" 2> /dev/null \
      && success "Backed up to ${BACKUP_DIR}" || true

    rm -rf "$HOOKS_DIR"
    success "Removed ${HOOKS_DIR}"
  else
    warn "Hooks directory not found — nothing to remove"
  fi

  if git config --global --get init.templateDir &> /dev/null; then
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
# DOWNLOAD / COPY HOOK FILES
# ══════════════════════════════════════════════════════════════

header "📝 Installing hooks..."
echo ""

# ── Determine source: local or remote ────────────────────────
if [ "$LOCAL" = "true" ] && [ -n "$LOCAL_HOOKS_DIR" ]; then
  SOURCE="local"
  info "Installing from local: ${LOCAL_HOOKS_DIR}"
elif [ -n "$LOCAL_HOOKS_DIR" ] && [ "$LOCAL" != "false" ]; then
  # Auto-detect: if running from cloned repo, use local files
  SOURCE="local"
  info "Detected local repo — installing from: ${LOCAL_HOOKS_DIR}"
else
  SOURCE="remote"
  info "Downloading from: ${REPO_URL}"
fi

echo ""

install_failed=false

for hook in "${HOOK_FILES[@]}"; do
  if [ "$SOURCE" = "local" ]; then
    # ── Local copy ────────────────────────────────────────
    if [ -f "${LOCAL_HOOKS_DIR}/${hook}" ]; then
      cp -f "${LOCAL_HOOKS_DIR}/${hook}" "${HOOKS_DIR}/${hook}"
      chmod +x "${HOOKS_DIR}/${hook}"
      size=$(wc -c < "${HOOKS_DIR}/${hook}" | tr -d ' ')
      success "${hook} (${size} bytes)"
    else
      fail "${hook} not found in ${LOCAL_HOOKS_DIR}"
      install_failed=true
    fi
  else
    # ── Remote download ───────────────────────────────────
    if curl -fsSL "${REPO_URL}/hooks/${hook}" -o "${HOOKS_DIR}/${hook}" 2> /dev/null; then
      chmod +x "${HOOKS_DIR}/${hook}"
      size=$(wc -c < "${HOOKS_DIR}/${hook}" | tr -d ' ')
      success "${hook} (${size} bytes, downloaded)"
    else
      fail "${hook} — download failed"
      install_failed=true
    fi
  fi
done

if [ "$install_failed" = "true" ]; then
  echo ""
  fail "Some hooks failed to install"
  echo -e "${DIM}   Check your internet connection or try: bash install.sh --local${NC}"
  exit 1
fi

# ══════════════════════════════════════════════════════════════
# CONFIGURE GIT
# ══════════════════════════════════════════════════════════════

header "⚙️  Configuring git..."
echo ""

current_template=$(git config --global init.templateDir 2> /dev/null || true)

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
# CREATE EXAMPLE CONFIG
# ══════════════════════════════════════════════════════════════

EXAMPLE_CONF="${TEMPLATE_DIR}/githooks.conf.example"

if [ "$SOURCE" = "local" ] && [ -f "${SCRIPT_DIR}/githooks.conf.example" ]; then
  cp -f "${SCRIPT_DIR}/githooks.conf.example" "$EXAMPLE_CONF"
else
  # Download or generate
  if ! curl -fsSL "${REPO_URL}/githooks.conf.example" -o "$EXAMPLE_CONF" 2> /dev/null; then
    # Fallback: generate minimal config
    cat > "$EXAMPLE_CONF" << 'CONFEOF'
# ╔══════════════════════════════════════════════════════════════╗
# ║  .githooks.conf — Per-repo hook configuration                ║
# ║  Place this file at your repo root as .githooks.conf         ║
# ╚══════════════════════════════════════════════════════════════╝

[global]
# skip_all = false

[commit-msg]
# skip = false
# subject_max_length = 72
# body_max_length = 100
# strict_warnings = false

[pre-commit]
# skip = false
# max_file_size = 5242880
# debug_markers_block = false
# trailing_ws_block = false
# enable = shellcheck,markdownlint
# disable = stylua,black

[pre-push]
# skip = false
# protected_branches = main,master,production,release,staging
# allow_wip = false
# run_tests = false
# test_command =
# enable = shellcheck
# disable = eslint,prettier

[post-merge]
# skip = false
# show_stat = true
# max_files_shown = 10
CONFEOF
  fi
fi

success "Example config → ${DIM}${EXAMPLE_CONF}${NC}"

# ══════════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  ✅ Installation complete!                       ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Installed:${NC}"
for hook in "${HOOK_FILES[@]}"; do
  echo -e "    ${HOOKS_DIR}/${hook}"
done
echo ""
echo -e "  ${BOLD}Source:${NC} ${SOURCE}"
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
