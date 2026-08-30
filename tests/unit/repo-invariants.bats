#!/usr/bin/env bats
# Source-tree invariants — no `chezmoi apply` needed, runs on a bare checkout.
# A skill tracked on one side only materialises as a dangling symlink in $HOME.

setup() {
    SOURCE_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    cd "$SOURCE_DIR" || return 1
}

skill_names() {
    # $1: dot_claude | dot_codex
    # -not -name '.*': a tool-written dotted dir is not a skill.
    find "$1/skills" -mindepth 1 -maxdepth 1 -type d -not -name '.*' \
        -exec basename {} \; | sort
}

@test "every Claude skill has a matching Codex symlink dir (and vice versa)" {
    run diff <(skill_names dot_claude) <(skill_names dot_codex)
    if [ "$status" -ne 0 ]; then
        echo "skill dirs differ ('<' = Claude only, '>' = Codex only):" >&2
        echo "$output" >&2
    fi
    [ "$status" -eq 0 ]
}

@test "every Codex skill symlink resolves to an existing Claude SKILL.md" {
    for link in dot_codex/skills/*/symlink_SKILL.md; do
        [ -f "$link" ] || continue
        name=$(basename "$(dirname "$link")")
        target=$(cat "$link")
        # Symlink bodies are relative to ~/.codex/skills/<name>/, i.e.
        # ../../../.claude/skills/<name>/SKILL.md → dot_claude/skills/<name>/.
        [ "$target" = "../../../.claude/skills/$name/SKILL.md" ] || {
            echo "unexpected symlink body for $name: $target" >&2
            return 1
        }
        [ -f "dot_claude/skills/$name/SKILL.md" ] || {
            echo "dangling: dot_claude/skills/$name/SKILL.md missing" >&2
            return 1
        }
    done
}

@test "every skill file is tracked by git (no .gitignore swallowing new skills)" {
    untracked=$(git ls-files --others --exclude-standard --ignored \
        -- 'dot_claude/skills/*' 'dot_codex/skills/*')
    if [ -n "$untracked" ]; then
        echo "ignored-but-present skill files:" >&2
        echo "$untracked" >&2
    fi
    [ -z "$untracked" ]
}
