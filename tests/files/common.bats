#!/usr/bin/env bats
# Post-apply asserts for `profile=core` on Linux. Runs in CI after
# `chezmoi apply` against a clean devcontainer (Codespaces-style):
# verifies dotfile presence, content sanity, OS-package install, and
# mise-managed core tools (fzf + zoxide).
#
# Profile-aware: stricter asserts (dev/mac tools) would go in
# tests/files/dev.bats / tests/files/mac.bats — out of scope for the
# minimal Phase-1 smoke harness.

setup() {
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    hash -r 2>/dev/null || true
}

# --- chezmoi config + profile ----------------------------------------------

@test "chezmoi config profile is core" {
    grep -qE '^\s*profile\s*=\s*"core"' "$HOME/.config/chezmoi/chezmoi.toml"
}

@test "chezmoi diff is empty post-apply (idempotent)" {
    run chezmoi diff
    # Print full diagnostic on any failure so CI logs surface the cause.
    if [ "$status" -ne 0 ] || [ -n "$output" ]; then
        echo "---" >&2
        echo "chezmoi diff exit=$status" >&2
        echo "chezmoi diff output:" >&2
        echo "$output" >&2
        echo "---" >&2
        echo "chezmoi verify:" >&2
        chezmoi verify >&2 2>&1 || true
        echo "---" >&2
        echo "chezmoi managed | head -5:" >&2
        chezmoi managed 2>&1 | head -5 >&2 || true
    fi
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- core dotfiles ----------------------------------------------------------

@test "~/.zshrc exists" {
    [ -f "$HOME/.zshrc" ]
}

@test "~/.zshrc activates mise" {
    grep -q 'mise activate' "$HOME/.zshrc"
}

@test "~/.zshrc references mise where fzf" {
    grep -q 'mise where fzf' "$HOME/.zshrc"
}

@test "~/.vimrc exists" {
    [ -f "$HOME/.vimrc" ]
}

@test "~/.tmux.conf.local exists" {
    [ -f "$HOME/.tmux.conf.local" ]
}

@test "~/.p10k.zsh exists" {
    [ -f "$HOME/.p10k.zsh" ]
}

@test "~/.gitconfig exists" {
    [ -f "$HOME/.gitconfig" ]
}

@test "~/.gitignore_global exists (target of core.excludesFile)" {
    [ -f "$HOME/.gitignore_global" ]
    grep -q '\.DS_Store' "$HOME/.gitignore_global"
}

@test "~/.zshrc_local seeded by create_dot_zshrc_local (chezmoi-create_, never overwritten)" {
    [ -f "$HOME/.zshrc_local" ]
}

@test "~/.zshrc sources ~/.zshrc_local LAST (after p10k + SSH tints, so local wins)" {
    # The source line must come after the SSH tint block that sets
    # tmux_conf_theme_*. Grep both anchors; assert line order.
    src_line=$(grep -n 'source ~/.zshrc_local' "$HOME/.zshrc" | tail -1 | cut -d: -f1)
    ssh_line=$(grep -n 'tmux_conf_theme_status_bg' "$HOME/.zshrc" | tail -1 | cut -d: -f1)
    [ -n "$src_line" ]
    [ -n "$ssh_line" ]
    [ "$src_line" -gt "$ssh_line" ]
}

# --- AI tooling configs -----------------------------------------------------

@test "~/.claude/CLAUDE.md exists" {
    [ -f "$HOME/.claude/CLAUDE.md" ]
}

@test "~/.claude/settings.json exists and is valid JSON" {
    [ -f "$HOME/.claude/settings.json" ]
    jq -e . "$HOME/.claude/settings.json" >/dev/null
}

@test "~/.claude/rules/no-code-without-go.md present" {
    [ -f "$HOME/.claude/rules/no-code-without-go.md" ]
}

@test "~/.codex/AGENTS.md exists" {
    [ -f "$HOME/.codex/AGENTS.md" ]
}

@test "~/.codex/config.toml exists" {
    [ -f "$HOME/.codex/config.toml" ]
}

# --- mise config + tools (profile=core: only fzf + zoxide) -----------------

@test "~/.config/mise/config.toml exists" {
    [ -f "$HOME/.config/mise/config.toml" ]
}

@test "~/.config/mise/config.toml has core tools" {
    grep -q 'aqua:junegunn/fzf' "$HOME/.config/mise/config.toml"
    grep -q 'aqua:ajeetdsouza/zoxide' "$HOME/.config/mise/config.toml"
}

@test "~/.config/mise/config.toml does NOT have dev tools at core profile" {
    ! grep -q 'aqua:kubernetes/kubernetes/kubectl' "$HOME/.config/mise/config.toml"
    ! grep -q '^node ' "$HOME/.config/mise/config.toml"
}

@test "mise binary on PATH" {
    command -v mise
}

@test "fzf installed via mise" {
    command -v fzf
}

@test "zoxide installed via mise" {
    command -v zoxide
}

# --- OS-native core packages (Linux apt) -----------------------------------

@test "apt: zsh installed" {
    command -v zsh
}

@test "apt: vim installed" {
    command -v vim
}

@test "apt: tmux installed" {
    command -v tmux
}

@test "apt: git installed" {
    command -v git
}

@test "apt: ufw installed" {
    command -v ufw
}

@test "apt: tcpdump installed" {
    command -v tcpdump
}

# --- negatives -------------------------------------------------------------

@test "no stale fnm directory" {
    [ ! -e "$HOME/.fnm" ]
}

@test "no stale pyenv directory" {
    [ ! -e "$HOME/.pyenv" ]
}

@test "no rtk binary at core profile (gated to dev|workstation)" {
    ! command -v rtk
}

@test "no claude CLI at core profile (npm globals gated to dev|workstation)" {
    ! command -v claude
}
