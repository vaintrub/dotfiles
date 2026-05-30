#!/bin/sh
# Package-install library. Sourced by run_onchange_after_50-install-packages.sh.tmpl
# (renders chezmoi facts into DOTFILES_* env vars first). Bats-sourceable
# standalone — the guard at the bottom only runs main when INSTALL_PACKAGES_INVOKE=1.
#
# Env required:
#   DOTFILES_PROFILE          core | dev | workstation
#   DOTFILES_OS               darwin | linux
#   DOTFILES_OSID             darwin | linux-<id>
#   DOTFILES_OSRELEASE_IDLIKE comma-list (Linux only)
#   DOTFILES_{CORE,DEV}_{BREWS,APT,DNF}
#   DOTFILES_GUI_{MAC_CASKS,LINUX_APT,LINUX_DNF}

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

    {
        for f in $DOTFILES_CORE_BREWS; do echo "brew \"$f\""; done
        if is_dev; then
            for f in $DOTFILES_DEV_BREWS; do echo "brew \"$f\""; done
        fi
        if is_workstation; then
            for c in $DOTFILES_GUI_MAC_CASKS; do echo "cask \"$c\""; done
        fi
    } | brew bundle --file=/dev/stdin || \
        echo "brew bundle had failures — most often a cask needing sudo (non-interactive apply). Re-run from a TTY." >&2

    # libpq is keg-only — force-link to expose psql et al.
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
    mise install --yes || echo "mise install had failures — see warnings above." >&2

    missing_count=$(mise ls 2>/dev/null | grep -c '(missing)' || true)
    if [ "${missing_count:-0}" -gt 0 ]; then
        echo "" >&2
        echo "[install-packages] WARNING: $missing_count mise tool(s) missing." >&2
        echo "  Likely cause: GitHub API rate-limit (60/hr anonymous)." >&2
        echo "  Fix (pick one):" >&2
        echo "    gh auth login                                              # cached token, recommended" >&2
        echo "    export GITHUB_TOKEN=ghp_yourPAT                            # one-off env" >&2
        echo "    export GITHUB_TOKEN=\$(op read 'op://Personal/GitHub API Token/credential')" >&2
        echo "  Then: chezmoi apply" >&2
        echo "" >&2
    fi
}

post_install_rtk_init() {
    if ! command -v rtk >/dev/null 2>&1; then
        echo "rtk not on PATH — check 'mise ls'; if shims dir missing, 'exec zsh' then re-apply." >&2
        return 0
    fi
    # rtk's linux-arm64 build needs glibc >=2.39 (Ubuntu 24.04+); no musl variant shipped.
    if ! rtk --version >/dev/null 2>&1; then
        echo "rtk binary fails to execute (likely glibc too old). Skipping init." >&2
        return 0
    fi
    if command -v claude >/dev/null 2>&1; then
        rtk init -g --auto-patch
    fi
    # -g pins write path to ~/.codex/ (not cwd, which is $HOME under chezmoi apply).
    if command -v codex >/dev/null 2>&1; then
        rtk init -g --codex
    fi
    echo "rtk: $(rtk --version) — initialized"
}

main() {
    echo "[install-packages] profile=$DOTFILES_PROFILE osid=$DOTFILES_OSID"

    case "$DOTFILES_OS" in
        darwin) brew_bundle_install ;;
        linux)  linux_pkg_install   ;;
    esac

    mise_install_tools

    # goimports + ssh-audit are declared in dot_config/mise/config.toml.tmpl
    # (go: / pipx: backends), installed by mise_install_tools above.
    if is_dev; then
        post_install_rtk_init
    fi
}

if [ "${INSTALL_PACKAGES_INVOKE:-0}" = "1" ]; then
    main "$@"
fi
