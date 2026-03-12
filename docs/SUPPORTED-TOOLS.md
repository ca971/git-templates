# Supported Tools — Install Guide

## Quick install (macOS — Homebrew)

```bash
# Essential
brew install shellcheck

# Lua
brew install luajit stylua

# Python
pip install ruff   # or: pip install black

# JavaScript / TypeScript
npm install -g prettier eslint

# Go (included with Go installation)
# brew install go

# Rust (included with Rust installation)
# rustup component add rustfmt clippy

# Data formats
pip install yamllint
brew install jq
brew install taplo

# Containers
brew install hadolint

# Markdown
npm install -g markdownlint-cli

# Terraform
brew install terraform
```

## Quick install (Ubuntu/Debian)

```bash
sudo apt install shellcheck jq
pip install ruff yamllint
npm install -g prettier eslint markdownlint-cli

# Lua
sudo apt install luajit
cargo install stylua

# Docker
wget -O hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
chmod +x hadolint && sudo mv hadolint /usr/local/bin/
```
