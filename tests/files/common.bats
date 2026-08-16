#!/usr/bin/env bats
# Post-apply asserts true at every profile.

setup() {
    export PATH="$HOME/.local/bin:$PATH"
    # `mise activate --shims` emits the shims PATH itself — no hardcoded layout.
    command -v mise >/dev/null && eval "$(mise activate bash --shims)"
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

@test "~/.codex/config.toml exists and is mode 0600 (matches Codex's own write mode)" {
    [ -f "$HOME/.codex/config.toml" ]
    [ "$(stat -c %a "$HOME/.codex/config.toml" 2>/dev/null \
        || stat -f %OLp "$HOME/.codex/config.toml")" = "600" ]
}

@test "codex skill symlinks resolve into ~/.claude/skills" {
    # -f follows the symlink, so a dangling one fails here.
    [ -f "$HOME/.codex/skills/save-to-dotfiles/SKILL.md" ]
}

# --- 1Password SSH agent ----------------------------------------------------

@test "~/.config/1Password/ssh/agent.toml exists and is mode 0600" {
    [ -f "$HOME/.config/1Password/ssh/agent.toml" ]
    [ "$(stat -c %a "$HOME/.config/1Password/ssh/agent.toml" 2>/dev/null \
        || stat -f %OLp "$HOME/.config/1Password/ssh/agent.toml")" = "600" ]
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

# --- OS-native core packages (every tier) ----------------------------------
# These come from apt/dnf, so they only apply on Linux.

require_linux() {
    [ "$(uname -s)" = Linux ] || skip "Linux-only package assert"
}

@test "pkg: zsh installed" {
    require_linux
    command -v zsh
}

@test "pkg: vim installed" {
    require_linux
    command -v vim
}

@test "pkg: tmux installed" {
    require_linux
    command -v tmux
}

@test "pkg: git installed" {
    require_linux
    command -v git
}

@test "pkg: ufw installed" {
    require_linux
    command -v ufw
}

@test "pkg: tcpdump installed" {
    require_linux
    command -v tcpdump
}

# --- negatives -------------------------------------------------------------

@test "no stale fnm directory" {
    [ ! -e "$HOME/.fnm" ]
}

@test "no stale pyenv directory" {
    [ ! -e "$HOME/.pyenv" ]
}
