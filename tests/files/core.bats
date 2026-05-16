#!/usr/bin/env bats
# CORE-tier-only post-apply asserts. Runs after `chezmoi apply` against
# profile=core. Verifies the negative-space asserts: things that should
# NOT be present at the core tier (dev tools, rtk, claude CLI).
#
# Profile-agnostic asserts live in tests/files/common.bats.
# Dev-tier asserts live in tests/files/dev.bats.

setup() {
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    hash -r 2>/dev/null || true
}

@test "chezmoi config profile=core" {
    grep -qE '^\s*profile\s*=\s*"core"' "$HOME/.config/chezmoi/chezmoi.toml"
}

@test "~/.config/mise/config.toml does NOT have dev tools at core profile" {
    ! grep -q 'aqua:kubernetes/kubernetes/kubectl' "$HOME/.config/mise/config.toml"
    ! grep -q '^node ' "$HOME/.config/mise/config.toml"
}

@test "no rtk binary at core profile (install-rtk gated to dev|workstation)" {
    ! command -v rtk
}

@test "no claude CLI at core profile (npm globals gated to dev|workstation)" {
    ! command -v claude
}

@test "no codex CLI at core profile" {
    ! command -v codex
}
