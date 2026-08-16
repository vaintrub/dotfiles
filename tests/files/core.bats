#!/usr/bin/env bats
# Post-apply asserts for profile=core: dev tools must NOT be present.

setup() {
    export PATH="$HOME/.local/bin:$PATH"
    # `mise activate --shims` emits the shims PATH itself — no hardcoded layout.
    command -v mise >/dev/null && eval "$(mise activate bash --shims)"
    hash -r 2>/dev/null || true
}

@test "chezmoi config profile=core" {
    grep -qE '^\s*profile\s*=\s*"core"' "$HOME/.config/chezmoi/chezmoi.toml"
}

@test "~/.config/mise/config.toml does NOT have dev tools at core profile" {
    ! grep -q 'aqua:kubernetes/kubernetes/kubectl' "$HOME/.config/mise/config.toml"
    ! grep -q '^node ' "$HOME/.config/mise/config.toml"
}

@test "no rtk binary at core profile (mise dev-only block)" {
    ! command -v rtk
}

@test "no claude CLI at core profile (mise dev-only block)" {
    ! command -v claude
}

@test "no codex CLI at core profile" {
    ! command -v codex
}
