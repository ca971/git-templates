## [README.md](readme.md.md)

<div align="center">

# 🔧 git-templates

**Universal Git hooks that work everywhere — zero config, any language, any project.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/ca971/git-templates/pulls)

Production-grade git hooks that auto-detect your stack and enforce quality gates.
<br>No frameworks. No dependencies. Pure Bash. Works on every `git init` and `git clone`.

[Quick Install](#-quick-install) •
[Features](#-features) •
[Supported Languages](#-supported-languages) •
[Configuration](#%EF%B8%8F-configuration) •
[Skip Hooks](#-skip-hooks)

</div>

---

## ⚡ Quick Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ca971/git-templates/main/install.sh)
```

Or clone and install:

```bash
git clone https://github.com/ca971/git-templates.git
cd git-templates
bash install.sh
```

That's it. Every future `git init` and `git clone` will include the hooks automatically.

---

## 🎯 Features

### 4 hooks, 1 shared library

| Hook | When | What it does |
|------|------|-------------|
| **`commit-msg`** | On commit | Validates [Conventional Commits](https://www.conventionalcommits.org/) format |
| **`pre-commit`** | On commit | Quality gate — secrets, formatting, syntax, large files |
| **`pre-push`** | On push | Final gate — WIP detection, full lint, branch protection, tests |
| **`post-merge`** | On pull/merge | Smart summary — deps changes, version bumps, action items |
| **`_lib.sh`** | Shared | Colors, config system, skip logic, tool detection |

### What makes it different

```
✅ Zero config         Works out of the box on ANY repo
✅ Auto-detection      Only checks languages actually present
✅ Fail gracefully     Missing tools = skip, never crash
✅ Per-repo config     .githooks.conf for fine-tuning
✅ 3 skip levels       Env var, config file, --no-verify
✅ No dependencies     Pure Bash — no Node, no Python, no framework
✅ Non-destructive     Warnings vs errors — you choose what blocks
```

---

## 🚦 What Gets Checked

### `commit-msg` — Message validation

```
✓ Conventional Commits format (feat, fix, docs, chore, ...)
✓ Breaking change detection (! marker + BREAKING CHANGE footer)
✓ Subject length (configurable, default 72)
✓ Imperative mood ("add" not "added")
✓ No trailing period
✓ Body formatting (blank line separator, line length)
✓ Auto-skip: merge, revert, WIP/fixup commits
```

<details>
<summary>📸 Example output</summary>

```
🚫 Invalid commit message format

  Expected: <type>(<scope>): <subject>

  Types:
    feat      New feature                    → MINOR
    fix       Bug fix                        → PATCH
    docs      Documentation only             → PATCH
    refactor  Code restructuring             → PATCH
    ...

  Your message: updated the readme

  Examples:
    feat(auth): add OAuth2 login flow
    fix(api): resolve null pointer on empty response
    docs: update installation guide
```

</details>

### `pre-commit` — Quality gate

```
Universal checks (always active):
  ✓ Debug markers (TODO, console.log, debugger, binding.pry, ...)
  ✓ Backup/temp files (.bak, .swp, .old, ...)
  ✓ Large files (> 5MB, configurable)
  ✓ Secrets & credentials (API keys, tokens, passwords, AWS, GitHub, ...)
  ✓ Merge conflict markers (<<<<<<<, =======, >>>>>>>)
  ✓ .env files (should be gitignored)
  ✓ Trailing whitespace

Language checks (auto-detected):
  ✓ Lua        → StyLua + syntax (LuaJIT/luac)
  ✓ Python     → Ruff / Black + syntax
  ✓ JavaScript → Prettier + ESLint
  ✓ TypeScript → Prettier + ESLint
  ✓ Go         → gofmt + go vet
  ✓ Rust       → rustfmt + Clippy
  ✓ Shell      → ShellCheck
  ✓ YAML       → yamllint
  ✓ JSON       → jq / python3
  ✓ TOML       → Taplo
  ✓ Markdown   → markdownlint
  ✓ Dockerfile → Hadolint
  ✓ Terraform  → terraform fmt
  ✓ CSS/SCSS   → Stylelint
```

<details>
<summary>📸 Example output</summary>

```
🔍 Pre-commit checks...
  ✓ No debug markers
  ✓ No backup files
  ✓ No large files
  ✓ No credentials detected
  ✓ No merge conflict markers
  ✓ No .env files
  ✓ No trailing whitespace
   ── Language checks ──
  ✓ StyLua formatting — 42 file(s)
  ✓ Lua syntax (LuaJIT) — 42 file(s)
  ✓ ShellCheck — 3 file(s)

✅ All pre-commit checks passed
```

</details>

### `pre-push` — Final gate

```
  ✓ WIP/fixup/squash commit detection (blocks push)
  ✓ Full language checks (same as pre-commit, all tracked files)
  ✓ Tag validation (version file ↔ tag consistency)
  ✓ Changelog entry check (on tag push)
  ✓ Branch protection (interactive confirm on main/master/production)
  ✓ Uncommitted changes warning
  ✓ Test suite runner (opt-in, auto-detected)
```

### `post-merge` — Smart summary

```
  ✓ File changes breakdown (dynamic directory grouping with icons)
  ✓ Dependency lockfile detection (22 package managers)
  ✓ Version bump detection (10+ ecosystems)
  ✓ Changelog updates
  ✓ New / deleted files summary
  ✓ Config change detection (Docker, CI, Terraform, Makefile, ...)
  ✓ Actionable recommendations
  ✓ Commit count & authors
```

<details>
<summary>📸 Example output</summary>

```
╔══════════════════════════════════════════════════╗
║  📋 Post-merge summary                           ║
╚══════════════════════════════════════════════════╝

  Files changed: 23 total
    + 5 added
    ~ 16 modified
    - 2 deleted

  By area:
    📦 src/              12 file(s)
    🧪 tests/             5 file(s)
    🤖 .github/           3 file(s)
    📁 config/            2 file(s)
    📄 (root)             1 file(s)

  📦 Dependencies changed:
    package-lock.json (npm)

  🏷️  Version → v2.1.0

  📋 ## [2.1.0] — 2025-01-15

  📌 Recommended actions:
    1. npm install
    2. Review build targets

  ─────────────────────────────────────────────
  8 commit(s) merged
  Authors: Alice, Bob

✅ Merge complete
```

</details>

---

## 🌍 Supported Languages

| Language | Formatter | Linter | Syntax Check |
|----------|-----------|--------|-------------|
| **Lua** | [StyLua](https://github.com/JohnnyMorganz/StyLua) | — | LuaJIT / luac |
| **Python** | [Ruff](https://github.com/astral-sh/ruff) / [Black](https://github.com/psf/black) | Ruff | `py_compile` |
| **JavaScript** | [Prettier](https://prettier.io/) | [ESLint](https://eslint.org/) | — |
| **TypeScript** | Prettier | ESLint | `tsc --noEmit` |
| **Go** | `gofmt` | `go vet` | `go build` |
| **Rust** | `rustfmt` | [Clippy](https://github.com/rust-lang/rust-clippy) | `cargo check` |
| **Shell** | — | [ShellCheck](https://github.com/koalaman/shellcheck) | — |
| **YAML** | — | [yamllint](https://github.com/adrienverge/yamllint) | — |
| **JSON** | — | — | `jq` / `python3` |
| **TOML** | [Taplo](https://taplo.tamasfe.dev/) | — | — |
| **Markdown** | — | [markdownlint](https://github.com/DavidAnson/markdownlint) | — |
| **Dockerfile** | — | [Hadolint](https://github.com/hadolint/hadolint) | — |
| **Terraform** | `terraform fmt` | `terraform validate` | — |
| **CSS/SCSS** | — | [Stylelint](https://stylelint.io/) | — |

> **No tool installed? No problem.** Checks are skipped gracefully — never crash, never block.

### 📦 Recognized Lockfiles (post-merge)

<details>
<summary>22 package managers</summary>

| Lockfile | Manager | Action |
|----------|---------|--------|
| `package-lock.json` | npm | `npm install` |
| `yarn.lock` | Yarn | `yarn install` |
| `pnpm-lock.yaml` | pnpm | `pnpm install` |
| `bun.lockb` | Bun | `bun install` |
| `requirements.txt` | pip | `pip install -r requirements.txt` |
| `Pipfile.lock` | Pipenv | `pipenv install` |
| `poetry.lock` | Poetry | `poetry install` |
| `uv.lock` | uv | `uv sync` |
| `Gemfile.lock` | Bundler | `bundle install` |
| `composer.lock` | Composer | `composer install` |
| `go.sum` | Go modules | `go mod download` |
| `Cargo.lock` | Cargo | `cargo build` |
| `mix.lock` | Mix | `mix deps.get` |
| `pubspec.lock` | Flutter/Dart | `flutter pub get` |
| `Podfile.lock` | CocoaPods | `pod install` |
| `flake.lock` | Nix | `nix flake update` |
| `lazy-lock.json` | lazy.nvim | `:Lazy sync` |
| `build.zig.zon` | Zig | `zig build` |
| `pdm.lock` | PDM | `pdm install` |
| `packages.lock.json` | .NET | `dotnet restore` |

</details>

---

## ⚙️ Configuration

### Per-repo: `.githooks.conf`

Place a `.githooks.conf` at your repo root to customize behavior:

```ini
# Example: Python API project
[commit-msg]
subject_max_length = 72
strict_warnings = true        # warnings block commit

[pre-commit]
max_file_size = 10485760      # 10MB
debug_markers_block = true
disable = prettier,eslint     # not a JS project

[pre-push]
protected_branches = main,staging,production
run_tests = true
test_command = pytest -q -x
disable = prettier,eslint

[post-merge]
show_stat = true
max_files_shown = 15
```

### Quick start configs

<details>
<summary>📝 Docs/Notes repo</summary>

```ini
[pre-commit]
disable = stylua,shellcheck,ruff,eslint,prettier,gofmt,rustfmt
[pre-push]
disable = stylua,lua-syntax,ruff,eslint,prettier,tsc,gofmt,govet,rustfmt,cargo-check
```

</details>

<details>
<summary>🌙 Neovim plugin (Lua)</summary>

```ini
[pre-commit]
debug_markers_block = true
[pre-push]
run_tests = false
```

</details>

<details>
<summary>⚛️ React/Next.js app</summary>

```ini
[pre-push]
run_tests = true
test_command = npm test -- --watchAll=false
protected_branches = main,staging
```

</details>

<details>
<summary>🦀 Rust project</summary>

```ini
[pre-push]
run_tests = true
test_command = cargo test --quiet
```

</details>

<details>
<summary>🐹 Go service</summary>

```ini
[pre-push]
run_tests = true
test_command = go test ./...
protected_branches = main,production
```

</details>

### Config reference

| Section | Key | Default | Description |
|---------|-----|---------|-------------|
| `[global]` | `skip_all` | `false` | Disable all hooks for this repo |
| `[commit-msg]` | `skip` | `false` | Skip this hook |
| | `subject_max_length` | `72` | Max subject line length |
| | `body_max_length` | `100` | Max body line length |
| | `strict_warnings` | `false` | Warnings become errors |
| `[pre-commit]` | `skip` | `false` | Skip this hook |
| | `max_file_size` | `5242880` | Max file size in bytes (5MB) |
| | `debug_markers_block` | `false` | Debug markers become errors |
| | `trailing_ws_block` | `false` | Trailing whitespace becomes error |
| | `disable` | _(empty)_ | Comma-separated checkers to skip |
| `[pre-push]` | `skip` | `false` | Skip this hook |
| | `protected_branches` | `main,master,production,release,staging` | Branches requiring confirmation |
| | `allow_wip` | `false` | Allow WIP commits to be pushed |
| | `run_tests` | `false` | Run test suite before push |
| | `test_command` | _(auto)_ | Custom test command |
| | `disable` | _(empty)_ | Comma-separated checkers to skip |
| `[post-merge]` | `skip` | `false` | Skip this hook |
| | `show_stat` | `true` | Show git diff --stat |
| | `max_files_shown` | `10` | Max files in stat output |

---

## ⏭️ Skip Hooks

Three levels of escape hatches:

```bash
# Skip ALL hooks (one-time)
SKIP_HOOKS=1 git commit -m "feat: emergency fix"
SKIP_HOOKS=1 git push

# Skip SPECIFIC hook (one-time)
SKIP_COMMIT_MSG=1 git commit -m "wip"
SKIP_PRE_COMMIT=1 git commit
SKIP_PRE_PUSH=1 git push
SKIP_POST_MERGE=1 git pull

# Git native (skips pre-commit + commit-msg)
git commit --no-verify
git push --no-verify

# Permanent skip for a repo (.githooks.conf)
# [pre-commit]
# skip = true
```

---

## 🔄 Managing Hooks

```bash
# Check installation status
bash install.sh --check

# Update to latest version
bash install.sh --update

# Uninstall completely
bash install.sh --uninstall

# Inject hooks into existing repo
cd your-existing-repo && git init   # safe — won't erase anything

# Inject into ALL repos under a directory
find ~/Projects -name ".git" -type d -maxdepth 3 -exec dirname {} \; | \
    xargs -I{} sh -c 'cd "{}" && git init'
```

### Injection in existing repos
```bash
# Bonus script : Inject in ALL your existing repos
inject-hooks() {
    local dir="${1:-$HOME/Projects}"
    find "$dir" -name ".git" -type d -maxdepth 3 2>/dev/null | while read -r gitdir; do
        repo=$(dirname "$gitdir")
        echo -e "  → ${repo}"
        (cd "$repo" && git init) 2>/dev/null
    done
    echo -e "\n✅ Done"
}

# Usage:
inject-hooks ~/Projects
```

### Useful aliases (`.zshrc` / `.bashrc`)

```bash
# ── Git hooks shortcuts ───────────────────────────────────────
alias ghcheck='bash ~/.git-templates/install.sh --check'
alias ghupdate='bash ~/.git-templates/install.sh --update'

# Skip shortcuts
alias gc!='SKIP_HOOKS=1 git commit'
alias gp!='SKIP_HOOKS=1 git push'

# Reinject hooks in current repo
alias ghinit='git init'  # safe — just copies hooks

# Edit hooks config for current repo
alias ghconf='${EDITOR:-vim} .githooks.conf'
alias ghconf-init='cp ~/.git-templates/githooks.conf.example .githooks.conf && ${EDITOR:-vim} .githooks.conf'
```

---

## 🏗️ Architecture

```
~/.git-templates/hooks/
├── _lib.sh         Shared foundation
│                   ├── Colors & formatting
│                   ├── Tool detection (command_exists)
│                   ├── File detection (staged/tracked by extension)
│                   ├── Config system (.githooks.conf parser)
│                   ├── Skip logic (3 levels)
│                   └── Checker registry (enable/disable)
│
├── commit-msg      Conventional Commits enforcement
│                   └── Format → Type → Length → Mood → Body
│
├── pre-commit      Quality gate (staged files only = fast)
│                   ├── Universal: secrets, large files, markers, .env
│                   └── Language: 14 auto-detected ecosystems
│
├── pre-push        Final gate (all tracked files)
│                   ├── WIP/fixup detection
│                   ├── Language checks (full scan)
│                   ├── Tag ↔ version consistency
│                   ├── Branch protection
│                   └── Test runner (opt-in)
│
└── post-merge      Intelligence (informational, never blocks)
                    ├── Dynamic file breakdown
                    ├── 22 lockfile detections
                    ├── Version bump detection
                    └── Actionable recommendations
```
---
## 🚥 Features

```bash ~/.git-templates/
├── hooks/
│   ├── _lib.sh            ← Shared: colors, config, skip, detection
│   ├── commit-msg         ← Conventional commits (universal)
│   ├── pre-commit         ← Quality gate (14 languages)
│   ├── post-merge         ← Post-pull intelligence (22 lockfiles)
│   └── pre-push           ← Final gate (6 languages + tests + tags)
├── githooks.conf.example  ← Configuration template
└── install.sh             ← One-command installer
```

* ✅ **14 languages** auto-detected
* ✅ **22 lockfiles** recognized
* ✅ **10+ versioning formats** supported
* ✅ **3 skip levels** (env / config / global)
* ✅ Per-repo **deactivatable checkers**
* ✅ **Zero-crash** design on empty or minimal repos
* ✅ Full lifecycle: **install / update / uninstall / check**
* ✅ **Automatic backup** before every update

---

## 🤝 Contributing

PRs welcome! Some ideas:

- [ ] Add support for more languages (Kotlin, Swift, Dart, Zig, ...)
- [ ] Add `pre-rebase` hook
- [ ] Add `prepare-commit-msg` hook (auto-prefix with branch name)
- [ ] Performance benchmarks
- [ ] Fish shell support

---

## 📄 License

[MIT](LICENSE) — Use it, fork it, make it yours.

---

<div align="center">

**Made with 🔧 by [ca971](https://github.com/ca971)**

If this saves you time, ⭐ the repo!

</div>
