#!/bin/sh
# Library of package-install functions. Pure POSIX shell, no chezmoi
# templating. Sourced by `.chezmoiscripts/run_onchange_after_50-install-
# packages.sh.tmpl` (which renders chezmoi facts into DOTFILES_* env vars
# before sourcing). Sourceable standalone by bats unit tests with mocked
# external commands.
#
# Entry point: `main`. The wrapper sets INSTALL_PACKAGES_INVOKE=1 and
# sources this file; the guard at the bottom calls main only when invoked.
# Bats `setup()` sources without setting the flag → no auto-run.
#
# Required env (set by wrapper):
#   DOTFILES_PROFILE          core | dev | workstation
#   DOTFILES_OS               darwin | linux
#   DOTFILES_OSID             darwin | linux-<id>   (e.g. linux-ubuntu)
#   DOTFILES_OSRELEASE_IDLIKE comma-list, e.g. "debian" (Linux only)
#   DOTFILES_CORE_BREWS       space-separated formula list
#   DOTFILES_DEV_BREWS        space-separated formula list
#   DOTFILES_CORE_APT         space-separated package list
#   DOTFILES_DEV_APT          space-separated package list
#   DOTFILES_CORE_DNF         space-separated package list
#   DOTFILES_DEV_DNF          space-separated package list
#   DOTFILES_GUI_MAC_CASKS    space-separated cask list (Mac workstation only)
#   DOTFILES_GUI_LINUX_APT    space-separated package list (Linux workstation only)
#   DOTFILES_GUI_LINUX_DNF    space-separated package list (Linux workstation only)
#   DOTFILES_DEV_NPM_GLOBAL   space-separated npm package list

# Cascade: dev⊂workstation. workstation gets dev tools too.
is_dev() {
    [ "$DOTFILES_PROFILE" = "dev" ] || [ "$DOTFILES_PROFILE" = "workstation" ]
}

is_workstation() {
    [ "$DOTFILES_PROFILE" = "workstation" ]
}

is_debian_family() {
    case "$DOTFILES_OSID" in
        linux-debian|linux-ubuntu) return 0 ;;
    esac
    case ",${DOTFILES_OSRELEASE_IDLIKE:-}," in
        *,debian,*) return 0 ;;
    esac
    return 1
}

is_fedora_family() {
    [ "$DOTFILES_OSID" = "linux-fedora" ]
}

_ensure_brew_path() {
    if command -v brew >/dev/null 2>&1; then return 0; fi
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        echo "brew not found — ensure-prereqs hook should have installed it." >&2
        return 1
    fi
}

brew_bundle_install() {
    _ensure_brew_path || return 0

    # Compose Brewfile from env-supplied package lists.
    # workstation on Mac → adds casks from packages.gui.mac_casks.
    {
        for f in $DOTFILES_CORE_BREWS; do echo "brew \"$f\""; done
        if is_dev; then
            for f in $DOTFILES_DEV_BREWS; do echo "brew \"$f\""; done
        fi
        if is_workstation; then
            for c in $DOTFILES_GUI_MAC_CASKS; do echo "cask \"$c\""; done
        fi
    } | brew bundle --file=/dev/stdin || {
        echo "brew bundle had failures — some packages may need manual install." >&2
        echo "Most common: a cask trying to adopt a pre-existing /Applications/<app>" >&2
        echo "  needs sudo (non-interactive apply can't supply password). Fix: remove" >&2
        echo "  the app first, run 'chezmoi apply' from a TTY, or 'sudo -v' beforehand." >&2
    }

    # libpq is keg-only (conflicts with `postgresql`). Force-link to expose
    # psql, pg_dump, pg_restore, etc.
    if brew list libpq >/dev/null 2>&1; then
        brew link --force libpq >/dev/null 2>&1 || true
    fi
}

_sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        echo ""
        return 0
    fi
    if command -v sudo >/dev/null 2>&1; then
        echo "sudo -E"
        return 0
    fi
    return 1
}

apt_install() {
    sudo_cmd=$(_sudo_cmd) || {
        echo "Neither root nor sudo available — skipping apt install." >&2
        return 0
    }

    pkgs="$DOTFILES_CORE_APT"
    if is_dev; then
        pkgs="$pkgs $DOTFILES_DEV_APT"
    fi
    if is_workstation; then
        pkgs="$pkgs $DOTFILES_GUI_LINUX_APT"
    fi
    # shellcheck disable=SC2086
    $sudo_cmd apt-get update -qq
    # shellcheck disable=SC2086
    $sudo_cmd apt-get install -y --no-install-recommends $pkgs || \
        echo "apt-get install had failures — re-run interactively." >&2
}

dnf_install() {
    sudo_cmd=$(_sudo_cmd) || {
        echo "Neither root nor sudo available — skipping dnf install." >&2
        return 0
    }

    pkgs="$DOTFILES_CORE_DNF"
    if is_dev; then
        pkgs="$pkgs $DOTFILES_DEV_DNF"
    fi
    if is_workstation; then
        pkgs="$pkgs $DOTFILES_GUI_LINUX_DNF"
    fi
    # shellcheck disable=SC2086
    $sudo_cmd dnf install -y $pkgs || \
        echo "dnf install had failures — re-run interactively." >&2
}

linux_pkg_install() {
    if is_debian_family; then
        apt_install
    elif is_fedora_family; then
        dnf_install
    else
        echo "Unsupported Linux distro (osid=$DOTFILES_OSID) — targets Debian/Ubuntu/Fedora only." >&2
    fi
}

mise_install_tools() {
    if ! command -v mise >/dev/null 2>&1; then
        echo "mise not on PATH — ensure-prereqs hook should have installed it. Skipping." >&2
        return 0
    fi
    mise trust "$HOME/.config/mise/config.toml" >/dev/null 2>&1 || true
    mise install --yes || echo "mise install had failures — re-run interactively." >&2
}

post_install_goimports() {
    if command -v go >/dev/null 2>&1 && ! command -v goimports >/dev/null 2>&1; then
        GOBIN="$HOME/.local/bin" go install golang.org/x/tools/cmd/goimports@latest \
            || echo "goimports install failed" >&2
    fi
}

post_install_ssh_audit() {
    if command -v uv >/dev/null 2>&1 && ! command -v ssh-audit >/dev/null 2>&1; then
        uv tool install ssh-audit --quiet || echo "ssh-audit install failed" >&2
    fi
}

_resolve_npm() {
    # Prefer mise's npm — avoids stale fnm/nvm shims.
    if command -v mise >/dev/null 2>&1; then
        mise_node_root="$(mise where node 2>/dev/null || true)"
        if [ -n "$mise_node_root" ] && [ -x "$mise_node_root/bin/npm" ]; then
            echo "$mise_node_root/bin/npm"
            return 0
        fi
    fi
    command -v npm 2>/dev/null && return 0
    return 1
}

npm_install_ai_globals() {
    npm_bin=$(_resolve_npm) || return 0

    # Defang any stale prefix from a decommissioned version manager.
    "$npm_bin" config delete prefix --global 2>/dev/null || true
    "$npm_bin" config delete prefix 2>/dev/null || true

    if [ "$DOTFILES_OS" = "linux" ]; then
        "$npm_bin" config set prefix "$HOME/.local"
    fi
    for pkg in $DOTFILES_DEV_NPM_GLOBAL; do
        "$npm_bin" install -g "$pkg" || echo "npm -g $pkg failed" >&2
    done
}

linux_fd_symlink_fallback() {
    # Distro fd-find → fd symlink. Relevant when mise's fd hasn't installed
    # yet (first apply mid-download) or at core profile (no fd in mise.toml).
    [ "$DOTFILES_OS" = "linux" ] || return 0
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
}

main() {
    echo "[install-packages] profile=$DOTFILES_PROFILE osid=$DOTFILES_OSID"

    case "$DOTFILES_OS" in
        darwin) brew_bundle_install ;;
        linux)  linux_pkg_install   ;;
    esac

    mise_install_tools

    if is_dev; then
        post_install_goimports
        post_install_ssh_audit
        npm_install_ai_globals
    fi

    linux_fd_symlink_fallback
}

# Auto-run when sourced by the chezmoi wrapper (which sets the flag).
# Bats tests source without setting it → functions defined, main not called.
if [ "${INSTALL_PACKAGES_INVOKE:-0}" = "1" ]; then
    main "$@"
fi
