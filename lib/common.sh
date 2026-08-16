#!/bin/sh
# Shared helpers for hooks/ensure-prereqs.sh and lib/install-packages.sh.
# Pure POSIX sh, no chezmoi data: the hook runs before the source state is read.
# Defines functions only — sourcing has no side effects.
#
# POSIX sh has no `local`, so every variable here is prefixed `_dotfiles_` to
# keep it out of the callers' namespace.

# Echo the prefix for a privileged command ("" as root); return 1 when
# escalation is impossible, so callers choose between skipping and failing.
#   $1  "noninteractive" — demand passwordless sudo (a prompt would hang).
dotfiles_sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        echo ""
        return 0
    fi
    command -v sudo >/dev/null 2>&1 || return 1
    if [ "${1:-}" = noninteractive ]; then
        sudo -n true 2>/dev/null || return 1
        echo "sudo -nE"
        return 0
    fi
    echo "sudo -E"
}

# Echo apt-get, dnf, or nothing. Alpine/Arch are out of scope.
dotfiles_pkg_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo apt-get
    elif command -v dnf >/dev/null 2>&1; then
        echo dnf
    fi
}

# Run "$2..." with stdout silenced when $1 is "quiet". Branching beats a
# variable redirect target — `>"$out"` with out=/dev/stdout misbehaves.
_dotfiles_run() {
    _dotfiles_quiet=$1
    shift
    if [ "$_dotfiles_quiet" = quiet ]; then
        "$@" >/dev/null
    else
        "$@"
    fi
}

# Install packages.
#   $1   apt-get | dnf | auto — pass the manager when the caller already knows
#        it (a Fedora box may well have apt-get installed too, and guessing
#        would then install dnf package names through apt)
#   $2   sudo prefix (may be empty; expanded unquoted so it word-splits)
#   $3   "quiet" to silence stdout
#   $4+  package names
# Never fails the caller: callers run under `set -e`, where a flaky mirror
# would otherwise abort the whole apply. Verify the postcondition instead if
# the packages are mandatory.
dotfiles_pkg_install() {
    _dotfiles_mgr=$1
    _dotfiles_sudo=$2
    _dotfiles_q=$3
    shift 3
    [ "$#" -gt 0 ] || return 0

    if [ "$_dotfiles_mgr" = auto ]; then
        _dotfiles_mgr=$(dotfiles_pkg_manager)
    fi

    case "$_dotfiles_mgr" in
        apt-get)
            # shellcheck disable=SC2086
            _dotfiles_run "$_dotfiles_q" $_dotfiles_sudo apt-get update -qq || \
                echo "apt-get update failed — continuing with the existing index." >&2
            # shellcheck disable=SC2086
            _dotfiles_run "$_dotfiles_q" $_dotfiles_sudo \
                apt-get install -y --no-install-recommends "$@" || \
                echo "apt-get install had failures — re-run interactively." >&2
            ;;
        dnf)
            # shellcheck disable=SC2086
            _dotfiles_run "$_dotfiles_q" $_dotfiles_sudo dnf install -y "$@" || \
                echo "dnf install had failures — re-run interactively." >&2
            ;;
        *)
            echo "Neither apt-get nor dnf found — skipping install of: $*" >&2
            ;;
    esac
}

# Homebrew's installer only PRINTS the shellenv line, so brew is not on a
# non-login shell's PATH. Returns 1 when brew is genuinely absent.
dotfiles_ensure_brew_path() {
    command -v brew >/dev/null 2>&1 && return 0
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        return 1
    fi
}
