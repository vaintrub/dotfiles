#!/usr/bin/env bash
#
# sync-plugins.sh — reconcile Codex marketplaces with the declarative
# list below, and refresh installed plugins.
#
# Subcommands:
#   sync       (default) ensure marketplaces registered → upgrade all
#   update     run `codex plugin marketplace upgrade` (refresh registries
#              and re-resolve plugin SHAs against the new state)
#   list       show what config.toml declares + what's cached on disk
#   help       this message
#
# Flags:
#   --dry-run  print actions without executing
#
# Codex CLI limitations (as of v0.128.0):
#   - There is NO `codex plugin install <id>` CLI. Plugin install and
#     uninstall happen ONLY in the TUI via the `/plugins` slash command.
#   - `codex plugin marketplace` subcommands (add / remove / upgrade)
#     are CLI-friendly and what this script uses.
#   - To DELETE a plugin: open `codex`, run `/plugins`, select the
#     plugin, choose remove. Then edit ~/.codex/config.toml to remove
#     its `[plugins."<id>"]` block (the git clean filter doesn't strip
#     those — see codex/scripts/strip-runtime-sections.awk).
#
# Workflow:
#   1. Edit ~/.codex/config.toml to add/remove `[plugins."<name>@<src>"]
#      enabled = true` blocks.
#   2. To install new plugins: open `codex`, `/plugins`, install.
#   3. To upgrade existing: `codex/scripts/sync-plugins.sh update`.

set -euo pipefail

# --- editable: marketplaces this user trusts ---------------------------------
# `openai-curated` is auto-registered by Codex and not listed here.
# Format: <name>  <source>  (anything `codex plugin marketplace add` accepts:
#   owner/repo[@ref], HTTPS git URL, SSH URL, or local path)
EXTRA_MARKETPLACES=$(cat <<'EOF'
# example: my-team-codex-plugins  github.com/example/codex-plugins
EOF
)
# -----------------------------------------------------------------------------

CONFIG="${HOME}/.codex/config.toml"
DRY_RUN=0

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
run() {
    if (( DRY_RUN )); then
        printf '  [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

require() { command -v "$1" >/dev/null 2>&1 || die "$1 not found on PATH"; }

# Plugin IDs declared in config.toml as [plugins."<id>"] blocks, regardless
# of enabled/disabled value (we sync presence, not state — state is local).
declared_plugins() {
    grep -oE '^\[plugins\."[^"]+"\]' "$CONFIG" 2>/dev/null \
        | sed -E 's|^\[plugins\."||; s|"\]$||' \
        | sort -u
}

# Plugin IDs whose payload is cached on disk (one cache dir per plugin SHA).
cached_plugins() {
    [[ -d ~/.codex/plugins/cache ]] || return 0
    find ~/.codex/plugins/cache -maxdepth 2 -mindepth 2 -type d 2>/dev/null \
        | sed -E "s|^$HOME/.codex/plugins/cache/||; s|^([^/]+)/(.+)$|\\2@\\1|" \
        | sort -u
}

ensure_marketplaces() {
    say "→ extra marketplaces"
    local registered any=0
    registered=$(codex plugin marketplace add --help >/dev/null 2>&1 \
        && codex plugin marketplace upgrade --help >/dev/null 2>&1 \
        && grep -oE 'name = "[^"]+"' "$CONFIG" 2>/dev/null \
        || true)
    # Cheaper: just attempt add; Codex idempotently no-ops if already there.
    while read -r name source; do
        [[ -z $name || $name = \#* ]] && continue
        any=1
        run codex plugin marketplace add "$source"
    done <<<"$EXTRA_MARKETPLACES"
    (( any )) || say "  (none beyond openai-curated)"
}

cmd_update() {
    say "→ upgrade marketplaces (refresh registries + plugin SHAs)"
    run codex plugin marketplace upgrade
}

cmd_sync() {
    ensure_marketplaces
    cmd_update

    say
    say "→ install/uninstall (TUI-only — codex has no CLI for this)"
    local declared cached missing orphans
    declared=$(declared_plugins)
    cached=$(cached_plugins)
    missing=$(comm -23 <(echo "$declared") <(echo "$cached"))
    orphans=$(comm -13 <(echo "$declared") <(echo "$cached"))

    if [[ -n $missing ]]; then
        say "  Declared but NOT cached on disk (use /plugins in TUI to install):"
        printf '    + %s\n' $missing
    fi
    if [[ -n $orphans ]]; then
        say "  Cached but NOT declared in config.toml (orphan caches):"
        printf '    - %s\n' $orphans
        say "    (open codex, /plugins, remove each; or clean ~/.codex/plugins/cache manually)"
    fi
    if [[ -z $missing && -z $orphans ]]; then
        say "  ✓ declared and cached match"
    fi
}

cmd_list() {
    say "Declared in $CONFIG ([plugins.\"<id>\"] blocks):"
    declared_plugins | sed 's/^/  /' || say "  (none)"
    say
    say "Cached on disk (~/.codex/plugins/cache/<source>/<plugin>/<sha>/):"
    cached_plugins | sed 's/^/  /' || say "  (none)"
}

cmd_help() { sed -n '3,/^$/{ s/^# \{0,1\}//; p; }' "$0"; }

main() {
    require codex
    require comm
    require grep
    require sed

    local cmd=sync
    while (( $# )); do
        case "$1" in
            sync|update|list|help|-h|--help) cmd=${1#--}; cmd=${cmd#-}; cmd=${cmd:-help}; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            *) die "unknown argument: $1 (try: $0 help)" ;;
        esac
    done

    case "$cmd" in
        sync)    cmd_sync ;;
        update)  cmd_update ;;
        list)    cmd_list ;;
        help|h)  cmd_help ;;
        *)       die "unknown subcommand: $cmd" ;;
    esac
}

main "$@"
