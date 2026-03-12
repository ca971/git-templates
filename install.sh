#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Git Hooks Template Installer                                ║
# ║                                                              ║
# ║  Installs universal git hooks into ~/.git-templates/hooks    ║
# ║  Configures git to use them on init/clone                    ║
# ║                                                              ║
# ║  Usage:                                                      ║
# ║    bash install.sh              # interactive install         ║
# ║    bash install.sh --force      # overwrite without prompt   ║
# ║    bash install.sh --uninstall  # remove hooks + config      ║
# ║    bash install.sh --check      # verify installation        ║
# ║    bash install.sh --update     # update to latest           ║
# ╚══════════════════════════════════════════════════════════════╝

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
info()    { echo -e "${CYAN}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✓${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
fail()    { echo -e "${RED}✗${NC}  $*"; }
header()  { echo -e "\n${BOLD}${CYAN}$*${NC}"; }

# ── Parse args ────────────────────────────────────────────────
MODE="install"
for arg in "$@"; do
    case "$arg" in
        --force)     FORCE=true ;;
        --uninstall) MODE="uninstall" ;;
        --check)     MODE="check" ;;
        --update)    MODE="update" ;;
        --help|-h)   MODE="help" ;;
        *)           fail "Unknown option: $arg"; exit 1 ;;
    esac
done
FORCE="${FORCE:-false}"

# ══════════════════════════════════════════════════════════════
# HELP
# ══════════════════════════════════════════════════════════════

if [ "$MODE" = "help" ]; then
    cat << 'EOF'

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
                size=$(wc -c < "$hook_path" | tr -d ' ')
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
        IFS=':' read -r tool desc <<< "$tool_entry"
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
            [[ ! $REPLY =~ ^[Yy]$ ]] && { info "Cancelled."; exit 0; }
        fi

        # Backup first
        cp -r "$TEMPLATE_DIR" "$BACKUP_DIR" 2>/dev/null && \
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
cat > "${HOOKS_DIR}/_lib.sh" << 'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  _lib.sh — Shared functions for git hooks                   ║
# ║  Sourced by all hooks, never executed directly               ║
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
log_ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
log_fail()  { echo -e "  ${RED}✗${NC} $*"; }
log_info()  { echo -e "  ${CYAN}ℹ${NC} $*"; }
log_skip()  { echo -e "  ${DIM}⊘ $* (skipped)${NC}"; }
log_title() { echo -e "${BOLD}$*${NC}"; }

# ── Tool detection ─────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }

# ── File detection ────────────────────────────────────────────
has_staged_files() {
    local ext
    for ext in "$@"; do
        if git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | grep -qE "\.${ext}$"; then
            return 0
        fi
    done
    return 1
}

get_staged_files() {
    local ext pattern=""
    for ext in "$@"; do
        [ -n "$pattern" ] && pattern="${pattern}|"
        pattern="${pattern}\\.${ext}$"
    done
    git diff --cached --name-only --diff-filter=ACMR 2>/dev/null | grep -E "$pattern" || true
}

has_repo_files() {
    local ext
    for ext in "$@"; do
        if git ls-files 2>/dev/null | grep -qE "\.${ext}$"; then
            return 0
        fi
    done
    return 1
}

get_repo_files() {
    local ext pattern=""
    for ext in "$@"; do
        [ -n "$pattern" ] && pattern="${pattern}|"
        pattern="${pattern}\\.${ext}$"
    done
    git ls-files 2>/dev/null | grep -E "$pattern" || true
}

# ── Config system ─────────────────────────────────────────────
GITHOOKS_CONF="$(git rev-parse --show-toplevel 2>/dev/null)/.githooks.conf"

githooks_config() {
    local section="$1" key="$2" default="${3:-}"
    local env_key
    env_key="GITHOOKS_$(echo "${section}" | tr '-' '_' | tr '[:lower:]' '[:upper:]')_$(echo "${key}" | tr '[:lower:]' '[:upper:]')"
    local env_val="${!env_key:-}"
    if [ -n "$env_val" ]; then echo "$env_val"; return; fi

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
                if [ "$k" = "$key" ]; then echo "$v"; return; fi
            fi
        done < "$GITHOOKS_CONF"
    fi
    echo "$default"
}

# ── Skip logic ─────────────────────────────────────────────────
should_skip_hook() {
    local hook_name="$1"
    if [ "${SKIP_HOOKS:-}" = "1" ] || [ "${GITHOOKS_SKIP:-}" = "1" ]; then
        echo -e "${DIM}⊘ All hooks skipped (SKIP_HOOKS=1)${NC}"; return 0
    fi
    local env_key="SKIP_$(echo "$hook_name" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"
    if [ "${!env_key:-}" = "1" ]; then
        echo -e "${DIM}⊘ ${hook_name} skipped (${env_key}=1)${NC}"; return 0
    fi
    local skip_val
    skip_val=$(githooks_config "$hook_name" "skip" "false")
    if [ "$skip_val" = "true" ] || [ "$skip_val" = "1" ]; then
        echo -e "${DIM}⊘ ${hook_name} skipped (.githooks.conf)${NC}"; return 0
    fi
    skip_val=$(githooks_config "global" "skip_all" "false")
    if [ "$skip_val" = "true" ] || [ "$skip_val" = "1" ]; then
        echo -e "${DIM}⊘ All hooks skipped (.githooks.conf)${NC}"; return 0
    fi
    return 1
}

# ── Checker registry ──────────────────────────────────────────
is_checker_disabled() {
    local hook_name="$1" checker="$2"
    local disabled
    disabled=$(githooks_config "$hook_name" "disable" "")
    if [ -n "$disabled" ]; then
        echo "$disabled" | tr ',' '\n' | grep -qiE "^${checker}$"
        return $?
    fi
    return 1
}
HOOKEOF

success "_lib.sh (shared library)"

# ────────────────────────────────────────────────────────────
# commit-msg
# ────────────────────────────────────────────────────────────
cat > "${HOOKS_DIR}/commit-msg" << 'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Commit-msg hook — Conventional commits validation           ║
# ║  Skip: SKIP_COMMIT_MSG=1 git commit -m "..."                ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${HOOK_DIR}/_lib.sh"
should_skip_hook "commit-msg" && exit 0

SUBJECT_MAX=$(githooks_config "commit-msg" "subject_max_length" "72")
BODY_MAX=$(githooks_config "commit-msg" "body_max_length" "100")
STRICT=$(githooks_config "commit-msg" "strict_warnings" "false")

commit_file="$1"
commit_msg=$(cat "$commit_file")
first_line=$(echo "$commit_msg" | head -1)
line_count=$(echo "$commit_msg" | wc -l | tr -d ' ')
warnings=0

# Auto-skip: merge / revert
echo "$first_line" | grep -qE '^Merge (branch|remote-tracking|pull request)' && exit 0
echo "$first_line" | grep -qE '^Revert "' && exit 0

# Auto-skip: WIP/fixup (warn)
if echo "$first_line" | grep -qiE '^(wip|fixup!|squash!|amend!)'; then
    log_warn "WIP/fixup commit — remember to squash before pushing"
    exit 0
fi

# Empty check
if [ -z "$(echo "$first_line" | tr -d '[:space:]')" ]; then
    echo -e "${RED}🚫 Empty commit message${NC}"; exit 1
fi

# Conventional commit format
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
    echo -e "    ${GREEN}release${NC}   Version release                ${DIM}→ TAG${NC}"
    echo ""
    echo -e "  ${BOLD}Examples:${NC}"
    echo -e "    ${GREEN}feat(auth): add OAuth2 login flow${NC}"
    echo -e "    ${GREEN}fix(api): resolve null pointer on empty response${NC}"
    echo -e "    ${GREEN}docs: update installation guide${NC}"
    echo -e "    ${GREEN}release: v1.1.0 — API refactor${NC}"
    echo -e "    ${GREEN}feat!: redesign plugin architecture${NC}"
    echo -e "    ${GREEN}chore(deps): bump axios to 1.7.0${NC}"
    echo ""
    echo -e "  ${BOLD}Your message:${NC} ${RED}${first_line}${NC}"
    echo ""
    exit 1
fi

# Subject length
if [ "${#first_line}" -gt "$SUBJECT_MAX" ]; then
    log_warn "Subject is ${#first_line} chars (max: ${SUBJECT_MAX})"
    echo -e "    ${DIM}${first_line}${NC}"
    echo -e "    ${DIM}$(printf '%*s' "$SUBJECT_MAX" | tr ' ' '─')${RED}↑${NC}"
    warnings=$((warnings + 1))
fi

# No trailing period
if echo "$first_line" | grep -qE '\.$'; then
    log_warn "Subject should not end with a period"
    warnings=$((warnings + 1))
fi

# Imperative mood
subject=$(echo "$first_line" | sed -E 's/^[^:]+: //')
if echo "$subject" | grep -qiE '^(added|fixed|removed|updated|changed|deleted|created|implemented|modified)'; then
    log_warn "Use imperative mood: \"add\" not \"added\""
    warnings=$((warnings + 1))
fi

# Blank second line
if [ "$line_count" -gt 1 ]; then
    second_line=$(echo "$commit_msg" | sed -n '2p')
    if [ -n "$(echo "$second_line" | tr -d '[:space:]')" ]; then
        log_warn "Second line should be blank"
        warnings=$((warnings + 1))
    fi
fi

# Body line length
if [ "$line_count" -gt 2 ]; then
    long_lines=0
    line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        [ "$line_num" -le 2 ] && continue
        echo "$line" | grep -qE 'https?://' && continue
        [ "${#line}" -gt "$BODY_MAX" ] && long_lines=$((long_lines + 1))
    done <<< "$commit_msg"
    [ "$long_lines" -gt 0 ] && { log_warn "${long_lines} body line(s) exceed ${BODY_MAX} chars"; warnings=$((warnings + 1)); }
fi

# Breaking change detection
echo "$commit_msg" | grep -qE '^BREAKING[ -]CHANGE:' && log_info "Breaking change in footer — MAJOR bump"
echo "$first_line" | grep -qE "^(${TYPES})!" && log_info "Breaking change marker (!) — MAJOR bump"

# Strict mode
if [ "$warnings" -gt 0 ] && [ "$STRICT" = "true" ]; then
    echo -e "${RED}🚫 ${warnings} warning(s) in strict mode — blocked${NC}"
    exit 1
fi

# Success
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
cat > "${HOOKS_DIR}/pre-commit" << 'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Pre-commit hook — Universal quality gate                    ║
# ║  Skip: SKIP_PRE_COMMIT=1 git commit                         ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${HOOK_DIR}/_lib.sh"
should_skip_hook "pre-commit" && exit 0

MAX_FILE_SIZE=$(githooks_config "pre-commit" "max_file_size" "5242880")
DEBUG_BLOCK=$(githooks_config "pre-commit" "debug_markers_block" "false")
TRAILING_BLOCK=$(githooks_config "pre-commit" "trailing_ws_block" "false")

errors=0; warnings=0
error() { echo -e "  ${RED}✗ $1${NC}"; errors=$((errors + 1)); }
warn()  { echo -e "  ${YELLOW}⚠ $1${NC}"; warnings=$((warnings + 1)); }
ok()    { echo -e "  ${GREEN}✓ $1${NC}"; }
info()  { echo -e "  ${DIM}  $1${NC}"; }

STAGED=$(git diff --cached --name-only --diff-filter=ACM)
STAGED_DIFF=$(git diff --cached --diff-filter=ACM)

if [ -z "$STAGED" ]; then
    echo -e "${YELLOW}⚠️  No staged files${NC}"; exit 0
fi

echo -e "${CYAN}🔍 Pre-commit checks...${NC}"

staged_by_ext() { for ext in "$@"; do echo "$STAGED" | grep -E "\.${ext}$" || true; done | sort -u; }

checker_on() {
    local name="$1"
    is_checker_disabled "pre-commit" "$name" && { log_skip "$name"; return 1; }
    return 0
}

run_fmt() {
    local name="$1" chk="$2" fix="$3"; shift 3
    local errs=0
    for f in "$@"; do
        [ -f "$f" ] || continue
        if ! eval "$chk \"$f\"" &>/dev/null; then
            [ $errs -eq 0 ] && error "${name} formatting issues:"
            info "$f"; errs=$((errs + 1))
        fi
    done
    [ $errs -gt 0 ] && info "Fix: ${fix}"
    [ $errs -eq 0 ] && [ $# -gt 0 ] && ok "${name} — $# file(s)"
}

run_syn() {
    local name="$1" cmd="$2"; shift 2
    local errs=0
    for f in "$@"; do
        [ -f "$f" ] || continue
        if ! eval "$cmd \"$f\"" &>/dev/null; then
            [ $errs -eq 0 ] && error "${name} syntax errors:"
            info "$f"
            eval "$cmd \"$f\"" 2>&1 | head -3 | while IFS= read -r e; do info "  $e"; done
            errs=$((errs + 1))
        fi
    done
    [ $errs -eq 0 ] && [ $# -gt 0 ] && ok "${name} — $# file(s)"
}

# ── 1. DEBUG MARKERS ──────────────────────────────────────────
debug_pattern='(TODO:|FIXME:|HACK:|XXX:|BUG:|TEMP:|console\.log|console\.debug|debugger|binding\.pry|import pdb|breakpoint\(\)|dbg!|dd\(|var_dump|die\()'
debug_matches=$(echo "$STAGED_DIFF" | grep -nE "$debug_pattern" 2>/dev/null | grep -v '^---' || true)
if [ -n "$debug_matches" ]; then
    count=$(echo "$debug_matches" | wc -l | tr -d ' ')
    [ "$DEBUG_BLOCK" = "true" ] && error "Debug markers (${count})" || warn "Debug markers (${count}, not blocking)"
    echo "$debug_matches" | head -5 | while IFS= read -r l; do info "$(echo "$l" | cut -c1-100)"; done
else ok "No debug markers"; fi

# ── 2. BACKUP FILES ──────────────────────────────────────────
bak=$(echo "$STAGED" | grep -E '\.(bak|old|orig|swp|swo|tmp|temp|~)$' || true)
if [ -n "$bak" ]; then
    error "Backup/temp files staged:"
    echo "$bak" | while IFS= read -r f; do info "$f"; done
else ok "No backup files"; fi

# ── 3. LARGE FILES ───────────────────────────────────────────
large=false
while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    size=$(wc -c < "$f" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        [ "$large" = false ] && { error "Large files:"; large=true; }
        h=$((size / 1048576)); info "$f (${h}MB)"
    fi
done <<< "$STAGED"
[ "$large" = false ] && ok "No large files"

# ── 4. SECRETS ────────────────────────────────────────────────
secret_patterns=(
    '(password|passwd|pwd)\s*[=:]\s*["\x27][^\s]+'
    '(secret|api_key|apikey|api_secret)\s*[=:]\s*["\x27][^\s]+'
    '(access_token|auth_token|bearer)\s*[=:]\s*["\x27][^\s]+'
    '(private_key|priv_key)\s*[=:]\s*["\x27][^\s]+'
    '(AWS_SECRET|AWS_ACCESS_KEY_ID)\s*[=:]\s*["\x27]'
    '(GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN)\s*[=:]'
    'sk-[a-zA-Z0-9]{20,}'
    'ghp_[a-zA-Z0-9]{36}'
    'gho_[a-zA-Z0-9]{36}'
    'glpat-[a-zA-Z0-9\-]{20,}'
    'AKIA[0-9A-Z]{16}'
    'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}'
)
sec=false
for p in "${secret_patterns[@]}"; do
    m=$(echo "$STAGED_DIFF" | grep -iE "$p" 2>/dev/null | grep -v '^-' || true)
    if [ -n "$m" ]; then
        [ "$sec" = false ] && { error "Credentials detected!"; sec=true; }
        echo "$m" | head -2 | while IFS= read -r l; do info "$(echo "$l" | cut -c1-80)..."; done
    fi
done
[ "$sec" = true ] && info "Move to .env (gitignored) or secret manager"
[ "$sec" = false ] && ok "No credentials"

# ── 5. MERGE MARKERS ─────────────────────────────────────────
if echo "$STAGED_DIFF" | grep -qE '^\+[<>=]{7}( |$)'; then
    error "Merge conflict markers found"
else ok "No merge markers"; fi

# ── 6. .ENV FILES ────────────────────────────────────────────
env=$(echo "$STAGED" | grep -E '(^|/)\.env(\..+)?$' || true)
if [ -n "$env" ]; then
    error ".env files staged!"
    echo "$env" | while IFS= read -r f; do info "$f"; done
else ok "No .env files"; fi

# ── 7. TRAILING WHITESPACE ───────────────────────────────────
trail=$(echo "$STAGED_DIFF" | grep -nE '^\+.*[[:blank:]]$' 2>/dev/null | grep -v '^\+\+\+' || true)
if [ -n "$trail" ]; then
    c=$(echo "$trail" | wc -l | tr -d ' ')
    [ "$TRAILING_BLOCK" = "true" ] && error "Trailing whitespace (${c} lines)" || warn "Trailing whitespace (${c} lines)"
else ok "No trailing whitespace"; fi

# ── LANGUAGE CHECKS ──────────────────────────────────────────
echo -e "${CYAN}   ── Language checks ──${NC}"

# LUA
lua_f=$(staged_by_ext lua)
if [ -n "$lua_f" ]; then
    mapfile -t lua_a <<< "$lua_f"
    if checker_on "stylua" && command_exists stylua; then
        run_fmt "StyLua" "stylua --check" "stylua $(echo "$lua_f" | tr '\n' ' ')" "${lua_a[@]}"
    fi
    if checker_on "lua-syntax"; then
        LC="" LN=""
        command_exists luajit && { LC="luajit -bl"; LN="LuaJIT"; } || \
        command_exists luac5.1 && { LC="luac5.1 -p"; LN="luac5.1"; } || \
        command_exists luac && { LC="luac -p"; LN="luac"; }
        [ -n "$LC" ] && run_syn "Lua ($LN)" "$LC" "${lua_a[@]}"
    fi
fi

# SHELL
sh_f=$(staged_by_ext sh bash zsh)
while IFS= read -r f; do
    [ -z "$f" ] || [ ! -f "$f" ] && continue
    head -1 "$f" 2>/dev/null | grep -qE '^#!.*(bash|sh|zsh)' && sh_f=$(printf '%s\n%s' "$sh_f" "$f")
done <<< "$STAGED"
sh_f=$(echo "$sh_f" | sort -u | grep -v '^$' || true)
if [ -n "$sh_f" ] && checker_on "shellcheck" && command_exists shellcheck; then
    mapfile -t sh_a <<< "$sh_f"
    sc_e=0
    for f in "${sh_a[@]}"; do
        [ -f "$f" ] || continue
        if ! shellcheck -S warning "$f" &>/dev/null; then
            [ $sc_e -eq 0 ] && warn "ShellCheck warnings:"
            info "$f"; sc_e=$((sc_e + 1))
        fi
    done
    [ $sc_e -eq 0 ] && ok "ShellCheck — ${#sh_a[@]} file(s)"
fi

# PYTHON
py_f=$(staged_by_ext py)
if [ -n "$py_f" ]; then
    mapfile -t py_a <<< "$py_f"
    if checker_on "ruff" && command_exists ruff; then
        run_fmt "Ruff format" "ruff format --check" "ruff format $(echo "$py_f" | tr '\n' ' ')" "${py_a[@]}"
    elif checker_on "black" && command_exists black; then
        run_fmt "Black" "black --check --quiet" "black $(echo "$py_f" | tr '\n' ' ')" "${py_a[@]}"
    fi
    if checker_on "python-syntax" && command_exists python3; then
        run_syn "Python" "python3 -m py_compile" "${py_a[@]}"
    fi
fi

# JS / TS
js_f=$(staged_by_ext js jsx mjs cjs ts tsx)
if [ -n "$js_f" ]; then
    mapfile -t js_a <<< "$js_f"
    if checker_on "prettier"; then
        P=""; command_exists prettier && P="prettier" || { [ -f "node_modules/.bin/prettier" ] && P="npx prettier"; }
        [ -n "$P" ] && run_fmt "Prettier" "$P --check" "$P --write $(echo "$js_f" | tr '\n' ' ')" "${js_a[@]}"
    fi
    if checker_on "eslint"; then
        E=""; command_exists eslint && E="eslint" || { [ -f "node_modules/.bin/eslint" ] && E="npx eslint"; }
        if [ -n "$E" ]; then
            el_e=0
            for f in "${js_a[@]}"; do [ -f "$f" ] && ! $E --quiet "$f" &>/dev/null && { [ $el_e -eq 0 ] && warn "ESLint issues:"; info "$f"; el_e=$((el_e+1)); }; done
            [ $el_e -eq 0 ] && ok "ESLint — ${#js_a[@]} file(s)"
        fi
    fi
fi

# GO
go_f=$(staged_by_ext go)
if [ -n "$go_f" ]; then
    mapfile -t go_a <<< "$go_f"
    if checker_on "gofmt" && command_exists gofmt; then
        gf_e=0
        for f in "${go_a[@]}"; do
            [ -f "$f" ] || continue
            [ -n "$(gofmt -l "$f" 2>/dev/null)" ] && { [ $gf_e -eq 0 ] && error "Go format issues:"; info "$f"; gf_e=$((gf_e+1)); }
        done
        [ $gf_e -gt 0 ] && info "Fix: gofmt -w ." || ok "gofmt — ${#go_a[@]} file(s)"
    fi
    checker_on "govet" && [ -f "go.mod" ] && command_exists go && {
        go vet ./... &>/dev/null && ok "go vet" || warn "go vet issues"
    }
fi

# RUST
rs_f=$(staged_by_ext rs)
if [ -n "$rs_f" ]; then
    mapfile -t rs_a <<< "$rs_f"
    checker_on "rustfmt" && command_exists rustfmt && \
        run_fmt "rustfmt" "rustfmt --check" "rustfmt $(echo "$rs_f" | tr '\n' ' ')" "${rs_a[@]}"
    checker_on "clippy" && [ -f "Cargo.toml" ] && command_exists cargo && {
        cargo clippy --quiet -- -D warnings &>/dev/null && ok "Clippy" || warn "Clippy warnings"
    }
fi

# YAML
ym_f=$(staged_by_ext yml yaml)
if [ -n "$ym_f" ] && checker_on "yamllint" && command_exists yamllint; then
    mapfile -t ym_a <<< "$ym_f"
    yl_e=0
    for f in "${ym_a[@]}"; do [ -f "$f" ] && ! yamllint -d relaxed "$f" &>/dev/null && { [ $yl_e -eq 0 ] && warn "YAML lint:"; info "$f"; yl_e=$((yl_e+1)); }; done
    [ $yl_e -eq 0 ] && ok "YAML lint — ${#ym_a[@]} file(s)"
fi

# JSON
jn_f=$(staged_by_ext json)
if [ -n "$jn_f" ] && checker_on "json-syntax"; then
    JC=""; command_exists jq && JC="jq empty" || { command_exists python3 && JC="python3 -m json.tool"; }
    if [ -n "$JC" ]; then mapfile -t jn_a <<< "$jn_f"; run_syn "JSON" "$JC" "${jn_a[@]}"; fi
fi

# TOML
to_f=$(staged_by_ext toml)
[ -n "$to_f" ] && checker_on "taplo" && command_exists taplo && {
    mapfile -t to_a <<< "$to_f"
    run_fmt "Taplo" "taplo format --check" "taplo format $(echo "$to_f" | tr '\n' ' ')" "${to_a[@]}"
}

# MARKDOWN
md_f=$(staged_by_ext md mdx)
[ -n "$md_f" ] && checker_on "markdownlint" && command_exists markdownlint && {
    mapfile -t md_a <<< "$md_f"
    ml_e=0
    for f in "${md_a[@]}"; do [ -f "$f" ] && ! markdownlint "$f" &>/dev/null && { [ $ml_e -eq 0 ] && warn "Markdown lint:"; info "$f"; ml_e=$((ml_e+1)); }; done
    [ $ml_e -eq 0 ] && ok "markdownlint — ${#md_a[@]} file(s)"
}

# DOCKERFILE
dk_f=$(echo "$STAGED" | grep -iE '(^|/)Dockerfile' || true)
[ -n "$dk_f" ] && checker_on "hadolint" && command_exists hadolint && {
    mapfile -t dk_a <<< "$dk_f"
    hl_e=0
    for f in "${dk_a[@]}"; do [ -f "$f" ] && ! hadolint "$f" &>/dev/null && { [ $hl_e -eq 0 ] && warn "Hadolint:"; hl_e=$((hl_e+1)); }; done
    [ $hl_e -eq 0 ] && ok "Hadolint — ${#dk_a[@]} file(s)"
}

# TERRAFORM
tf_f=$(staged_by_ext tf)
[ -n "$tf_f" ] && checker_on "terraform" && command_exists terraform && {
    terraform fmt -check -diff . &>/dev/null && ok "Terraform fmt" || { error "Terraform fmt issues"; info "Fix: terraform fmt"; }
}

# ── SUMMARY ───────────────────────────────────────────────────
echo ""
if [ $errors -gt 0 ]; then
    echo -e "${RED}🚫 ${errors} error(s), ${warnings} warning(s) — commit rejected${NC}"
    echo -e "${DIM}   Bypass: git commit --no-verify${NC}"
    exit 1
fi
[ $warnings -gt 0 ] && echo -e "${GREEN}✅ Pre-commit passed${NC} ${YELLOW}(${warnings} warning(s))${NC}" \
                     || echo -e "${GREEN}✅ All pre-commit checks passed${NC}"
HOOKEOF

success "pre-commit (universal quality gate)"

# ────────────────────────────────────────────────────────────
# post-merge
# ────────────────────────────────────────────────────────────
cat > "${HOOKS_DIR}/post-merge" << 'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Post-merge hook — Universal intelligence after pull/merge   ║
# ║  Skip: SKIP_POST_MERGE=1 git pull                           ║
# ╚══════════════════════════════════════════════════════════════╝

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${HOOK_DIR}/_lib.sh"
should_skip_hook "post-merge" && exit 0

SHOW_STAT=$(githooks_config "post-merge" "show_stat" "true")
MAX_FILES=$(githooks_config "post-merge" "max_files_shown" "10")

changed=$(git diff --name-only HEAD@{1} HEAD 2>/dev/null || true)
if [ -z "$changed" ]; then echo -e "${GREEN}✅ Already up to date${NC}"; exit 0; fi

total=$(echo "$changed" | wc -l | tr -d ' ')
added=$(git diff --name-only --diff-filter=A HEAD@{1} HEAD 2>/dev/null | wc -l | tr -d ' ')
modified=$(git diff --name-only --diff-filter=M HEAD@{1} HEAD 2>/dev/null | wc -l | tr -d ' ')
deleted=$(git diff --name-only --diff-filter=D HEAD@{1} HEAD 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  📋 Post-merge summary                           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

declare -a ACTIONS=()

# ── File breakdown ────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Files changed:${NC} ${total} total"
[ "$added" -gt 0 ]    && echo -e "    ${GREEN}+ ${added} added${NC}"
[ "$modified" -gt 0 ] && echo -e "    ${YELLOW}~ ${modified} modified${NC}"
[ "$deleted" -gt 0 ]  && echo -e "    ${RED}- ${deleted} deleted${NC}"

# Dynamic directory grouping
echo ""
echo -e "${BOLD}  By area:${NC}"

dir_icon() {
    case "$1" in
        src|lib) echo "📦";; test|tests|spec|__tests__) echo "🧪";;
        docs|doc) echo "📖";; .github|.gitlab) echo "🤖";;
        scripts|bin) echo "⚡";; config|conf) echo "⚙️ ";;
        migrations|db) echo "🗄️ ";; assets|static|public) echo "🎨";;
        lua) echo "🌙";; cmd|internal|pkg) echo "📦";;
        components) echo "🧩";; pages|views) echo "🖼️ ";;
        *) echo "📁";;
    esac
}

declare -A dcounts; root_f=0
while IFS= read -r f; do
    [ -z "$f" ] && continue
    [[ "$f" == */* ]] && { d="${f%%/*}"; dcounts["$d"]=$(( ${dcounts["$d"]:-0}+1 )); } || root_f=$((root_f+1))
done <<< "$changed"

for d in $(for k in "${!dcounts[@]}"; do echo "${dcounts[$k]} $k"; done | sort -rn | awk '{print $2}'); do
    printf "    %s %-18s %s file(s)\n" "$(dir_icon "$d")" "${d}/" "${dcounts[$d]}"
done
[ "$root_f" -gt 0 ] && echo -e "    📄 (root)              ${root_f} file(s)"

[ "$SHOW_STAT" = "true" ] && {
    echo ""; echo -e "${DIM}  Top changes:${NC}"
    git diff --stat HEAD@{1} HEAD 2>/dev/null | head -"$MAX_FILES" | while IFS= read -r l; do echo -e "${DIM}    $l${NC}"; done
}

# ── Lockfiles ─────────────────────────────────────────────────
declare -A LOCKS=(
    ["package-lock.json"]="npm|npm install"
    ["yarn.lock"]="Yarn|yarn install"
    ["pnpm-lock.yaml"]="pnpm|pnpm install"
    ["bun.lockb"]="Bun|bun install"
    ["requirements.txt"]="pip|pip install -r requirements.txt"
    ["Pipfile.lock"]="Pipenv|pipenv install"
    ["poetry.lock"]="Poetry|poetry install"
    ["uv.lock"]="uv|uv sync"
    ["Gemfile.lock"]="Bundler|bundle install"
    ["composer.lock"]="Composer|composer install"
    ["go.sum"]="Go|go mod download"
    ["Cargo.lock"]="Cargo|cargo build"
    ["mix.lock"]="Mix|mix deps.get"
    ["pubspec.lock"]="Dart|flutter pub get"
    ["Podfile.lock"]="CocoaPods|pod install"
    ["flake.lock"]="Nix|nix flake update"
    ["lazy-lock.json"]="lazy.nvim|Open Neovim → :Lazy sync"
)

dep=false
while IFS= read -r f; do
    [ -z "$f" ] && continue
    bn=$(basename "$f")
    if [ -n "${LOCKS[$bn]+x}" ]; then
        IFS='|' read -r name cmd <<< "${LOCKS[$bn]}"
        [ "$dep" = false ] && { echo ""; echo -e "${YELLOW}  📦 Dependencies changed:${NC}"; dep=true; }
        echo -e "    ${YELLOW}${bn}${NC} ${DIM}(${name})${NC}"
        ACTIONS+=("${cmd}")
    fi
done <<< "$changed"

# ── Version detection ─────────────────────────────────────────
nv=""
for vf in package.json pyproject.toml Cargo.toml mix.exs VERSION VERSION.txt; do
    [ -f "$vf" ] && echo "$changed" | grep -q "$vf" && {
        nv=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z0-9.\-]*' "$vf" 2>/dev/null | head -1)
        [ -n "$nv" ] && break
    }
done
[ -z "$nv" ] && {
    vlua=$(echo "$changed" | grep -E 'version\.lua$' | head -1)
    [ -n "$vlua" ] && [ -f "$vlua" ] && {
        nv=$(grep -oE 'version\s*=\s*"[^"]+"' "$vlua" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        [ -z "$nv" ] && {
            ma=$(grep 'major' "$vlua" 2>/dev/null | grep -oE '[0-9]+' | head -1)
            mi=$(grep 'minor' "$vlua" 2>/dev/null | grep -oE '[0-9]+' | head -1)
            pa=$(grep 'patch' "$vlua" 2>/dev/null | grep -oE '[0-9]+' | head -1)
            [ -n "$ma" ] && [ -n "$mi" ] && [ -n "$pa" ] && nv="${ma}.${mi}.${pa}"
        }
    }
}
[ -n "$nv" ] && { echo ""; echo -e "${GREEN}  🏷️  Version → ${BOLD}v${nv}${NC}"; }

# ── Changelog ─────────────────────────────────────────────────
for cl in CHANGELOG.md CHANGELOG.rst CHANGES.md HISTORY.md; do
    echo "$changed" | grep -qi "^${cl}$" && [ -f "$cl" ] && {
        echo ""; le=$(grep -m1 -E '^## ' "$cl" 2>/dev/null || echo "$cl updated")
        echo -e "${CYAN}  📋 ${le}${NC}"; break
    }
done

# ── New / deleted files ───────────────────────────────────────
nf=$(git diff --name-only --diff-filter=A HEAD@{1} HEAD 2>/dev/null || true)
df=$(git diff --name-only --diff-filter=D HEAD@{1} HEAD 2>/dev/null || true)
[ -n "$nf" ] && { nc=$(echo "$nf" | wc -l | tr -d ' '); echo ""; echo -e "${GREEN}  ✨ ${nc} new file(s)${NC}"; echo "$nf" | head -5 | while IFS= read -r f; do echo -e "${DIM}    + $f${NC}"; done; }
[ -n "$df" ] && { dc=$(echo "$df" | wc -l | tr -d ' '); echo ""; echo -e "${RED}  🗑️  ${dc} removed${NC}"; echo "$df" | head -5 | while IFS= read -r f; do echo -e "${DIM}    - $f${NC}"; done; }

# ── Config change triggers ────────────────────────────────────
triggers=(
    "Dockerfile|🐳|Dockerfile changed|docker compose build"
    "docker-compose*.yml|🐳|Docker Compose changed|docker compose up -d"
    ".github/workflows/*|🤖|GitHub Actions updated|CI pipeline changed"
    "*.tf|🏗️ |Terraform changed|terraform plan"
    "migrations/*|🗄️ |Migrations changed|Run pending migrations"
    ".env.example|🔐|.env.example changed|Check your .env"
    ".envrc|🔐|.envrc changed|direnv allow"
    "Makefile|⚡|Makefile changed|Review build targets"
    "init.lua|🌙|init.lua changed|Restart Neovim"
    "tsconfig*.json|📐|TS config changed|Restart TS server"
)

cfg=false
for t in "${triggers[@]}"; do
    IFS='|' read -r pat icon desc act <<< "$t"
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        # shellcheck disable=SC2254
        case "$f" in $pat)
            [ "$cfg" = false ] && { echo ""; echo -e "${YELLOW}  🔄 Config changes:${NC}"; cfg=true; }
            echo -e "    ${icon} ${desc}"
            [ -n "$act" ] && ACTIONS+=("$act")
            break ;;
        esac
    done <<< "$changed"
done

# ── Commits & authors ────────────────────────────────────────
cc=$(git rev-list --count HEAD@{1}..HEAD 2>/dev/null || echo "?")
au=$(git log HEAD@{1}..HEAD --format='%an' 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/,$//' || true)
echo ""; echo -e "${DIM}  ─────────────────────────────────────────────${NC}"
echo -e "${DIM}  ${cc} commit(s) merged${NC}"
[ -n "$au" ] && echo -e "${DIM}  Authors: ${au}${NC}"

# ── Actions ───────────────────────────────────────────────────
if [ ${#ACTIONS[@]} -gt 0 ]; then
    echo ""; echo -e "${CYAN}  📌 Recommended actions:${NC}"
    declare -A seen; n=0
    for a in "${ACTIONS[@]}"; do
        [ -z "${seen[$a]+x}" ] && { seen["$a"]=1; n=$((n+1)); echo -e "    ${YELLOW}${n}.${NC} ${a}"; }
    done
fi

echo ""; echo -e "${GREEN}✅ Merge complete${NC}"
HOOKEOF

success "post-merge (universal intelligence)"

# ────────────────────────────────────────────────────────────
# pre-push
# ────────────────────────────────────────────────────────────
cat > "${HOOKS_DIR}/pre-push" << 'HOOKEOF'
#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  Pre-push hook — Universal last gate                         ║
# ║  Skip: SKIP_PRE_PUSH=1 git push                             ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${HOOK_DIR}/_lib.sh"
should_skip_hook "pre-push" && exit 0

PROTECTED=$(githooks_config "pre-push" "protected_branches" "main,master,production,release,staging")
ALLOW_WIP=$(githooks_config "pre-push" "allow_wip" "false")
RUN_TESTS=$(githooks_config "pre-push" "run_tests" "false")
TEST_CMD=$(githooks_config "pre-push" "test_command" "")

errors=0; warnings=0
error() { echo -e "  ${RED}✗ $1${NC}"; errors=$((errors + 1)); }
warn()  { echo -e "  ${YELLOW}⚠ $1${NC}"; warnings=$((warnings + 1)); }
ok()    { echo -e "  ${GREEN}✓ $1${NC}"; }
info()  { echo -e "  ${DIM}  $1${NC}"; }

branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
remote="${1:-origin}"; url="${2:-}"

pushing_tag=false; tag_name=""
while read -r local_ref local_sha remote_ref remote_sha; do
    echo "$remote_ref" | grep -q '^refs/tags/' && { pushing_tag=true; tag_name="${remote_ref#refs/tags/}"; }
done

echo -e "${CYAN}🔍 Pre-push checks...${NC}"
echo -e "${DIM}   Branch: ${branch}  Remote: ${remote}  Tag: ${tag_name:-none}${NC}"

tracked_ext() { for e in "$@"; do git ls-files "*.${e}" 2>/dev/null; done | sort -u | grep -v '^$' || true; }
checker_on() { is_checker_disabled "pre-push" "$1" && { log_skip "$1"; return 1; }; return 0; }

# ── 1. WIP COMMITS ───────────────────────────────────────────
if [ "$ALLOW_WIP" != "true" ]; then
    wip=$(git log @{upstream}..HEAD --oneline 2>/dev/null | grep -iE '(^[a-f0-9]+ wip |^[a-f0-9]+ wip:|fixup!|squash!|amend!)' || true)
    if [ -n "$wip" ]; then
        error "WIP/fixup commits — squash first:"
        echo "$wip" | while IFS= read -r l; do info "$l"; done
        info "Fix: git rebase -i --autosquash"
    else ok "No WIP/fixup commits"; fi
else ok "WIP allowed (config)"; fi

# ── 2. LANGUAGE CHECKS ───────────────────────────────────────
echo -e "${CYAN}   ── Language checks ──${NC}"

# LUA
lua_f=$(tracked_ext lua)
if [ -n "$lua_f" ]; then
    if checker_on "lua-syntax"; then
        LC="" LN=""
        command_exists luajit && { LC="luajit -bl"; LN="LuaJIT"; } || \
        command_exists luac5.1 && { LC="luac5.1 -p"; LN="luac5.1"; } || \
        command_exists luac && { LC="luac -p"; LN="luac"; }
        if [ -n "$LC" ]; then
            le=0; fc=0
            while IFS= read -r f; do
                [ -z "$f" ] || [ ! -f "$f" ] && continue; fc=$((fc+1))
                $LC "$f" &>/dev/null || { [ $le -eq 0 ] && error "Lua syntax (${LN}):"; info "$f"; le=$((le+1)); }
            done <<< "$lua_f"
            [ $le -eq 0 ] && ok "Lua syntax — ${fc} files (${LN})"
        fi
    fi
    if checker_on "stylua" && command_exists stylua; then
        se=0
        while IFS= read -r f; do
            [ -z "$f" ] || [ ! -f "$f" ] && continue
            stylua --check "$f" &>/dev/null || { [ $se -eq 0 ] && error "StyLua issues:"; info "$f"; se=$((se+1)); }
        done <<< "$lua_f"
        [ $se -gt 0 ] && info "Fix: stylua \$(git ls-files '*.lua')" || ok "StyLua formatting"
    fi
fi

# PYTHON
py_f=$(tracked_ext py)
if [ -n "$py_f" ]; then
    if checker_on "python-syntax" && command_exists python3; then
        pe=0; pc=0
        while IFS= read -r f; do
            [ -z "$f" ] || [ ! -f "$f" ] && continue; pc=$((pc+1))
            python3 -m py_compile "$f" &>/dev/null || { [ $pe -eq 0 ] && error "Python syntax:"; info "$f"; pe=$((pe+1)); }
        done <<< "$py_f"
        [ $pe -eq 0 ] && ok "Python syntax — ${pc} files"
    fi
    if checker_on "ruff" && command_exists ruff; then
        ruff check --quiet . &>/dev/null && ok "Ruff lint" || warn "Ruff lint issues"
        ruff format --check --quiet . &>/dev/null && ok "Ruff format" || { error "Ruff format issues"; info "Fix: ruff format ."; }
    elif checker_on "black" && command_exists black; then
        black --check --quiet . &>/dev/null && ok "Black" || { error "Black issues"; info "Fix: black ."; }
    fi
fi

# JS/TS
js_f=$(tracked_ext js jsx mjs cjs ts tsx)
if [ -n "$js_f" ]; then
    if checker_on "prettier"; then
        P=""; command_exists prettier && P="prettier" || { [ -f "node_modules/.bin/prettier" ] && P="npx prettier"; }
        [ -n "$P" ] && { $P --check . &>/dev/null 2>&1 && ok "Prettier" || { error "Prettier issues"; info "Fix: $P --write ."; }; }
    fi
    if checker_on "eslint"; then
        E=""; command_exists eslint && E="eslint" || { [ -f "node_modules/.bin/eslint" ] && E="npx eslint"; }
        [ -n "$E" ] && { $E --quiet . &>/dev/null 2>&1 && ok "ESLint" || warn "ESLint issues"; }
    fi
    if checker_on "tsc" && [ -f "tsconfig.json" ]; then
        T=""; command_exists tsc && T="tsc" || { [ -f "node_modules/.bin/tsc" ] && T="npx tsc"; }
        [ -n "$T" ] && { $T --noEmit &>/dev/null && ok "TypeScript" || error "TypeScript errors"; }
    fi
fi

# GO
go_f=$(tracked_ext go)
if [ -n "$go_f" ] && [ -f "go.mod" ]; then
    checker_on "gofmt" && command_exists gofmt && {
        uf=$(gofmt -l . 2>/dev/null | grep -v vendor/ || true)
        [ -n "$uf" ] && { error "Go fmt issues"; info "Fix: gofmt -w ."; } || ok "gofmt"
    }
    checker_on "govet" && command_exists go && {
        go vet ./... &>/dev/null && ok "go vet" || { error "go vet issues"; go vet ./... 2>&1 | head -3 | while IFS= read -r l; do info "$l"; done; }
    }
    checker_on "go-build" && command_exists go && {
        go build ./... &>/dev/null && ok "Go builds" || error "Go build failed"
    }
fi

# RUST
rs_f=$(tracked_ext rs)
if [ -n "$rs_f" ] && [ -f "Cargo.toml" ]; then
    checker_on "rustfmt" && command_exists cargo && { cargo fmt --check &>/dev/null 2>&1 && ok "rustfmt" || { error "rustfmt issues"; info "Fix: cargo fmt"; }; }
    checker_on "cargo-check" && command_exists cargo && { cargo check --quiet &>/dev/null 2>&1 && ok "cargo check" || error "cargo check failed"; }
    checker_on "clippy" && command_exists cargo && { cargo clippy --quiet -- -D warnings &>/dev/null 2>&1 && ok "Clippy" || warn "Clippy warnings"; }
fi

# SHELL
sh_f=$(tracked_ext sh bash zsh)
if [ -n "$sh_f" ] && checker_on "shellcheck" && command_exists shellcheck; then
    se=0
    while IFS= read -r f; do
        [ -z "$f" ] || [ ! -f "$f" ] && continue
        shellcheck -S error "$f" &>/dev/null || { [ $se -eq 0 ] && error "ShellCheck:"; info "$f"; se=$((se+1)); }
    done <<< "$sh_f"
    [ $se -eq 0 ] && ok "ShellCheck"
fi

# ── 3. TAG VALIDATION ────────────────────────────────────────
if [ "$pushing_tag" = true ]; then
    echo -e "${CYAN}   ── Tag validation ──${NC}"
    tv="${tag_name#v}"; dv=""
    for vf in package.json pyproject.toml Cargo.toml mix.exs VERSION VERSION.txt; do
        [ -f "$vf" ] && { dv=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z0-9.\-]*' "$vf" 2>/dev/null | head -1); [ -n "$dv" ] && break; }
    done
    [ -z "$dv" ] && {
        vl=$(git ls-files '**/version.lua' 'version.lua' 2>/dev/null | head -1)
        [ -n "$vl" ] && [ -f "$vl" ] && {
            dv=$(grep -oE 'version\s*=\s*"[^"]+"' "$vl" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            [ -z "$dv" ] && {
                ma=$(grep 'major' "$vl" 2>/dev/null | grep -oE '[0-9]+' | head -1)
                mi=$(grep 'minor' "$vl" 2>/dev/null | grep -oE '[0-9]+' | head -1)
                pa=$(grep 'patch' "$vl" 2>/dev/null | grep -oE '[0-9]+' | head -1)
                [ -n "$ma" ] && [ -n "$mi" ] && [ -n "$pa" ] && dv="${ma}.${mi}.${pa}"
            }
        }
    }
    [ -n "$dv" ] && { [ "$tv" = "$dv" ] && ok "Tag ${tag_name} = source (${dv})" || error "Tag ${tag_name} ≠ source (${dv})"; } \
                  || warn "No version file found"

    cl=""; for f in CHANGELOG.md CHANGELOG.rst CHANGES.md HISTORY.md; do [ -f "$f" ] && cl="$f" && break; done
    if [ -n "$cl" ]; then
        (grep -q "\[${tv}\]" "$cl" 2>/dev/null || grep -q "## ${tv}" "$cl" 2>/dev/null || grep -q "## v${tv}" "$cl" 2>/dev/null) \
            && ok "${cl} has ${tv}" || warn "${cl} missing ${tv}"
    fi
else ok "Not a tag push"; fi

# ── 4. BRANCH PROTECTION ─────────────────────────────────────
pr=$(echo "$PROTECTED" | tr ',' '|')
if echo "$branch" | grep -qE "^(${pr})$"; then
    ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "?")
    echo ""; echo -e "${YELLOW}  ⚠ Pushing ${BOLD}${ahead}${NC}${YELLOW} commit(s) to ${BOLD}${branch}${NC}"
    git log @{upstream}..HEAD --oneline 2>/dev/null | head -5 | while IFS= read -r l; do echo -e "${DIM}    $l${NC}"; done
    if [ -t 0 ]; then
        read -r -p "   Continue? [y/N] " -n 1 REPLY; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && { echo -e "${RED}🚫 Cancelled${NC}"; exit 1; }
    fi
fi

# ── 5. UNCOMMITTED CHANGES ───────────────────────────────────
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    dc=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    warn "${dc} uncommitted change(s) — NOT in push"
else ok "Working tree clean"; fi

# ── 6. TESTS ─────────────────────────────────────────────────
if [ "$RUN_TESTS" = "true" ]; then
    echo -e "${CYAN}   ── Tests ──${NC}"
    if [ -z "$TEST_CMD" ]; then
        [ -f "Makefile" ] && grep -q '^test:' Makefile 2>/dev/null && TEST_CMD="make test"
        [ -z "$TEST_CMD" ] && [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null && TEST_CMD="npm test"
        [ -z "$TEST_CMD" ] && [ -f "Cargo.toml" ] && TEST_CMD="cargo test --quiet"
        [ -z "$TEST_CMD" ] && [ -f "go.mod" ] && TEST_CMD="go test ./..."
        [ -z "$TEST_CMD" ] && ([ -f "pyproject.toml" ] || [ -f "setup.py" ]) && command_exists pytest && TEST_CMD="pytest -q"
        [ -z "$TEST_CMD" ] && [ -f "mix.exs" ] && TEST_CMD="mix test --quiet"
        [ -z "$TEST_CMD" ] && [ -f "Gemfile" ] && command_exists rspec && TEST_CMD="bundle exec rspec"
    fi
    if [ -n "$TEST_CMD" ]; then
        info "Running: ${TEST_CMD}"
        eval "$TEST_CMD" &>/dev/null && ok "Tests passed" || { error "Tests failed!"; info "Run: ${TEST_CMD}"; }
    else warn "No test command detected"; fi
fi

# ── SUMMARY ───────────────────────────────────────────────────
echo ""
if [ $errors -gt 0 ]; then
    echo -e "${RED}🚫 ${errors} error(s), ${warnings} warning(s) — push rejected${NC}"
    echo -e "${DIM}   Bypass: git push --no-verify${NC}"
    exit 1
fi
[ $warnings -gt 0 ] && echo -e "${GREEN}✅ Pre-push passed${NC} ${YELLOW}(${warnings} warning(s))${NC}" \
                     || echo -e "${GREEN}✅ All pre-push checks passed${NC}"
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
cat > "$EXAMPLE_CONF" << 'CONFEOF'
# ╔══════════════════════════════════════════════════════════════╗
# ║  .githooks.conf — Per-repo hook configuration               ║
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
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
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
