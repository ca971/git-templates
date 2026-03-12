# Configuration Reference

See the [README](../README.md#%EF%B8%8F-configuration) for the full configuration reference.

## Environment Variables

| Variable | Effect |
|----------|--------|
| `SKIP_HOOKS=1` | Skip all hooks |
| `SKIP_COMMIT_MSG=1` | Skip commit-msg hook |
| `SKIP_PRE_COMMIT=1` | Skip pre-commit hook |
| `SKIP_PRE_PUSH=1` | Skip pre-push hook |
| `SKIP_POST_MERGE=1` | Skip post-merge hook |
| `GITHOOKS_SKIP=1` | Alias for SKIP_HOOKS |

## Config File Priority

1. **Environment variable** (highest priority)
2. **`.githooks.conf`** in repo root
3. **Default value** (lowest priority)

## Disabling Specific Checkers

In `.githooks.conf`:

```ini
[pre-commit]
disable = stylua,black,eslint

[pre-push]
disable = stylua,eslint,tsc
```

## Available Checker names

| Checker | Language | Hook |
|---------|----------|------|
| `stylua` | Lua | pre-commit, pre-push |
| `lua-syntax` | Lua | pre-commit, pre-push |
| `shellcheck` | Shell | pre-commit, pre-push |
| `ruff` | Python | pre-commit, pre-push |
| `black` | Python | pre-commit, pre-push |
| `python-syntax` | Python | pre-commit, pre-push |
| `prettier` | JS/TS/CSS | pre-commit, pre-push |
| `eslint` | JS/TS | pre-commit, pre-push |
| `biome` | JS/TS | pre-commit |
| `tsc` | TypeScript | pre-push |
| `gofmt` | Go | pre-commit, pre-push |
| `govet` | Go | pre-commit, pre-push |
| `go-build` | Go | pre-push |
| `rustfmt` | Rust | pre-commit, pre-push |
| `clippy` | Rust | pre-commit, pre-push |
| `cargo-check` | Rust | pre-push |
| `yamllint` | YAML | pre-commit |
| `json-syntax` | JSON | pre-commit |
| `taplo` | TOML | pre-commit |
| `markdownlint` | Markdown | pre-commit |
| `hadolint` | Dockerfile | pre-commit |
| `terraform` | Terraform | pre-commit |
| `stylelint` | CSS/SCSS | pre-commit |
