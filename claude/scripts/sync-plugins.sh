#!/usr/bin/env bash
#
# sync-plugins.sh — reconcile installed Claude Code plugins with the
# declarative state in ~/.claude/settings.json (enabledPlugins).
#
# Subcommands:
#   sync       (default) install missing → update installed → prune orphans
#   install    install plugins listed in enabledPlugins but not on disk
#   update     update every currently-installed user-scope plugin
#   prune      uninstall user-scope plugins NOT in enabledPlugins
#   list       show desired vs installed
#   help       this message
#
# Flags:
#   --dry-run  print actions without executing
#
# Workflow:
#   1. Edit ~/.claude/settings.json (or claude/settings.json in dotfiles)
#      to add / remove entries under "enabledPlugins".
#   2. Run `claude/scripts/sync-plugins.sh` — installed state matches.
#   3. Commit settings.json. On other machines: `git pull` + sync.
#
# Marketplaces are declared in the MARKETPLACES table below. To add a
# new marketplace, append a row. The script registers each one
# idempotently via `claude plugin marketplace add` before installing.

set -euo pipefail

# --- editable: marketplaces this user trusts ---------------------------------
# Format: <name>  <source>
# <source> is anything `claude plugin marketplace add` accepts:
#   owner/repo, HTTPS git URL, SSH URL, or local path.
MARKETPLACES=$(cat <<'EOF'
claude-plugins-official     anthropics/claude-plugins-official
claude-code-plugins         anthropics/claude-code
EOF
)
# -----------------------------------------------------------------------------

SETTINGS="${HOME}/.claude/settings.json"
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

require() {
    command -v "$1" >/dev/null 2>&1 || die "$1 not found on PATH"
}

# Three categories of plugins from enabledPlugins (user-scope only):
#   enabled  → value=true   → install + enable
#   disabled → value=false  → install + disable (soft toggle, kept on disk)
#   orphan   → not present  → uninstall
#
# To DELETE a plugin: remove its entry from enabledPlugins (don't just set
# to false). To temporarily silence: set false; sync keeps it installed.
declared_plugins() {  # all keys regardless of value (set of "managed" plugins)
    python3 -c '
import json, sys
try:
    with open("'"$SETTINGS"'") as f:
        d = json.load(f)
except FileNotFoundError:
    sys.exit(0)
for k in d.get("enabledPlugins", {}):
    print(k)
' | sort -u
}

desired_enabled() {  # subset where value=true
    python3 -c '
import json, sys
try:
    with open("'"$SETTINGS"'") as f:
        d = json.load(f)
except FileNotFoundError:
    sys.exit(0)
for k, v in d.get("enabledPlugins", {}).items():
    if v: print(k)
' | sort -u
}

# Currently installed user-scope plugins (skip project-scope to avoid touching per-repo state).
installed_plugins() {
    claude plugin list --json 2>/dev/null | python3 -c '
import json, sys
for p in json.load(sys.stdin):
    if p.get("scope") == "user":
        print(p["id"])
' | sort -u
}

ensure_marketplaces() {
    say "→ marketplaces"
    while read -r name source; do
        [[ -z $name || $name = \#* ]] && continue
        if claude plugin marketplace list --json 2>/dev/null \
            | python3 -c 'import json,sys; sys.exit(0 if any(m["name"]=="'"$name"'" for m in json.load(sys.stdin)) else 1)'; then
            printf '  ✓ %s\n' "$name"
        else
            run claude plugin marketplace add "$source"
        fi
    done <<<"$MARKETPLACES"
}

cmd_install() {
    ensure_marketplaces
    say "→ install missing (all declared, regardless of enabled/disabled)"
    local declared installed missing
    declared=$(declared_plugins)
    installed=$(installed_plugins)
    missing=$(comm -23 <(echo "$declared") <(echo "$installed"))
    [[ -z $missing ]] && { say "  (nothing to install)"; return; }
    while IFS= read -r plugin; do
        [[ -z $plugin ]] && continue
        run claude plugin install "$plugin" --scope user
    done <<<"$missing"

    # Soft toggle: ensure value=false entries are actually disabled on disk.
    local disabled
    disabled=$(comm -23 <(echo "$declared") <(desired_enabled))
    [[ -z $disabled ]] && return
    say "→ apply soft-disable for entries with value=false"
    while IFS= read -r plugin; do
        [[ -z $plugin ]] && continue
        run claude plugin disable "$plugin" --scope user
    done <<<"$disabled"
}

cmd_update() {
    say "→ update installed (user scope)"
    local installed
    installed=$(installed_plugins)
    [[ -z $installed ]] && { say "  (nothing installed)"; return; }
    say "  refreshing marketplaces first"
    run claude plugin marketplace update
    while IFS= read -r plugin; do
        [[ -z $plugin ]] && continue
        run claude plugin update "$plugin" --scope user
    done <<<"$installed"
}

cmd_prune() {
    say "→ prune orphans (installed but ABSENT from enabledPlugins)"
    local declared installed orphans
    declared=$(declared_plugins)
    installed=$(installed_plugins)
    orphans=$(comm -13 <(echo "$declared") <(echo "$installed"))
    [[ -z $orphans ]] && { say "  (none to prune)"; return; }
    while IFS= read -r plugin; do
        [[ -z $plugin ]] && continue
        run claude plugin uninstall "$plugin" --scope user --prune -y
    done <<<"$orphans"
}

cmd_sync() { cmd_install; cmd_update; cmd_prune; }

cmd_list() {
    say "Declared in $SETTINGS → enabledPlugins:"
    python3 -c "
import json
try:
    d = json.load(open('$SETTINGS'))
except FileNotFoundError:
    print('  (no settings.json yet)'); exit()
ep = d.get('enabledPlugins', {})
if not ep: print('  (none)'); exit()
for k, v in ep.items():
    flag = 'enabled ' if v else 'disabled'
    print(f'  [{flag}] {k}')
"
    say
    say "Installed (claude plugin list --json | scope=user):"
    installed_plugins | sed 's/^/  /' || say "  (none)"
}

cmd_help() { sed -n '3,/^$/{ s/^# \{0,1\}//; p; }' "$0"; }

main() {
    require claude
    require python3
    require comm

    local cmd=sync
    while (( $# )); do
        case "$1" in
            sync|install|update|prune|list|help|-h|--help) cmd=${1#--}; cmd=${cmd#-}; cmd=${cmd:-help}; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            *) die "unknown argument: $1 (try: $0 help)" ;;
        esac
    done

    case "$cmd" in
        sync)    cmd_sync ;;
        install) cmd_install ;;
        update)  cmd_update ;;
        prune)   cmd_prune ;;
        list)    cmd_list ;;
        help|h)  cmd_help ;;
        *)       die "unknown subcommand: $cmd" ;;
    esac
}

main "$@"
