#!/usr/bin/env bats
# Source-tree invariants — no `chezmoi apply` needed, runs on a bare checkout.
# A skill tracked on one side only materialises as a dangling symlink in $HOME.

setup() {
    SOURCE_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    cd "$SOURCE_DIR" || return 1
}

claude_skills() {
    # -not -name '.*': a tool-written dotted dir is not a skill.
    find dot_claude/skills -mindepth 1 -maxdepth 1 -type d -not -name '.*' \
        -exec basename {} \; | sort
}

codex_skill_links() {
    find dot_agents/skills -mindepth 1 -maxdepth 1 -name 'symlink_*' \
        -exec basename {} \; | sed 's/^symlink_//' | sort
}

@test "every Claude skill has a Codex link in ~/.agents/skills (and vice versa)" {
    run diff <(claude_skills) <(codex_skill_links)
    if [ "$status" -ne 0 ]; then
        echo "skill sets differ ('<' = Claude only, '>' = Codex only):" >&2
        echo "$output" >&2
    fi
    [ "$status" -eq 0 ]
}

@test "every Codex skill link points at its Claude skill directory" {
    # Directory links: Codex skips a symlink that resolves to a file.
    for link in dot_agents/skills/symlink_*; do
        [ -f "$link" ] || continue
        name=${link##*/symlink_}
        target=$(cat "$link")
        # Bodies are relative to ~/.agents/skills/.
        [ "$target" = "../../.claude/skills/$name" ] || {
            echo "unexpected link body for $name: $target" >&2
            return 1
        }
        [ -f "dot_claude/skills/$name/SKILL.md" ] || {
            echo "dangling: dot_claude/skills/$name/SKILL.md missing" >&2
            return 1
        }
    done
}

@test "every script that runs claude or codex puts mise's shims on PATH" {
    # chezmoi exec()s each script as a fresh child, so one script's PATH export
    # never reaches the next, and both exist only as mise shims.
    for f in .chezmoiscripts/*.sh.tmpl .chezmoiscripts/*/*.sh.tmpl; do
        grep -qE 'command -v (claude|codex)' "$f" || continue
        grep -q '^export PATH=.*\.local/share/mise/shims' "$f" || {
            echo "$f probes PATH without exporting mise's shims" >&2
            return 1
        }
    done
}

@test "every source path save-to-dotfiles names exists" {
    # Agents follow this table without checking it, and it has rotted before.
    # Placeholders (<name>) and brace sets are skipped; globs must match.
    missing=""
    while IFS= read -r p; do
        case "$p" in *'<'*|*'{'*|*' '*) continue ;; esac
        if [[ $p == *'*'* ]]; then
            compgen -G "$p" >/dev/null || missing="$missing $p"
        else
            [ -e "$p" ] || missing="$missing $p"
        fi
    done < <(grep -oE '`(dot_|\.chezmoi)[^`]*`' dot_claude/skills/save-to-dotfiles/SKILL.md \
        | tr -d '`' | sort -u)
    if [ -n "$missing" ]; then
        echo "save-to-dotfiles names source paths that do not exist:$missing" >&2
    fi
    [ -z "$missing" ]
}

@test "dot_p10k.zsh keeps the hand-written settings a wizard re-run drops" {
    # p10k configure rewrites the file wholesale. It recommends verbose instant
    # prompt and never writes TERM_SHELL_INTEGRATION, so both vanish silently.
    grep -qE '^[[:space:]]*typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet$' dot_p10k.zsh
    grep -q "'quiet' not 'verbose': direnv prints" dot_p10k.zsh
    grep -qE '^[[:space:]]*typeset -g POWERLEVEL9K_TERM_SHELL_INTEGRATION=true$' dot_p10k.zsh
    grep -q 'Emits OSC 133 semantic marks' dot_p10k.zsh
}

@test "every zsh plugin bundle is pinned to a full commit SHA" {
    # An unpinned bundle is cloned from HEAD at shell start on every machine.
    unpinned=$(grep -vE '^[[:space:]]*(#|$)' dot_zsh_plugins.txt \
        | grep -vE '(^|[[:space:]])pin:[0-9a-f]{40}([[:space:]]|$)' || true)
    if [ -n "$unpinned" ]; then
        echo "unpinned bundles in dot_zsh_plugins.txt:" >&2
        echo "$unpinned" >&2
    fi
    [ -z "$unpinned" ]
}

@test "every skill file is tracked by git (no .gitignore swallowing new skills)" {
    untracked=$(git ls-files --others --exclude-standard --ignored \
        -- 'dot_claude/skills/*' 'dot_agents/skills/*')
    if [ -n "$untracked" ]; then
        echo "ignored-but-present skill files:" >&2
        echo "$untracked" >&2
    fi
    [ -z "$untracked" ]
}
