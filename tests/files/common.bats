#!/usr/bin/env bats
# Profile-AGNOSTIC post-apply asserts. Runs from BOTH apply-core and apply-dev
# CI jobs (and locally on any profile). Verifies things that should be true on
# every machine after chezmoi apply, regardless of which profile is active.
#
# Profile-SPECIFIC asserts live in:
#   tests/files/core.bats — core-only (no rtk, no dev tools)
#   tests/files/dev.bats  — dev tier asserts (mise tools, claude CLI, etc.)

setup() {
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    hash -r 2>/dev/null || true
}

# --- chezmoi state ---------------------------------------------------------

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

@test "~/.zshrc sources fzf shell integration" {
    grep -q 'fzf --zsh' "$HOME/.zshrc"
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

# --- mise itself + core tools (fzf + zoxide installed at every tier) ------

@test "~/.config/mise/config.toml exists" {
    [ -f "$HOME/.config/mise/config.toml" ]
}

@test "~/.config/mise/config.toml has core tools (fzf + zoxide)" {
    grep -q 'aqua:junegunn/fzf' "$HOME/.config/mise/config.toml"
    grep -q 'aqua:ajeetdsouza/zoxide' "$HOME/.config/mise/config.toml"
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

# --- OS-native core packages (Linux apt — always installed at every tier) -

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
