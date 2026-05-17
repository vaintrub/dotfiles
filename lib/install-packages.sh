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
#
# Post-install funcs (called from main() at dev tier+):
#   post_install_goimports   go install goimports
#   post_install_ssh_audit   uv tool install ssh-audit
#   post_install_rtk_init    rtk init -g for Claude + Codex (rtk binary from mise)
#
# AI CLIs (claude-code, codex) install via mise's aqua backend — no
# npm/Node coupling. See dot_config/mise/config.toml.tmpl dev block.

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
    mise install --yes || echo "mise install had failures — see warnings above." >&2

    # Surface clear recovery hint if any declared tools didn't land. Common
    # cause on a slow link / shared IP: GitHub anonymous 60/hr API limit was
    # exhausted before all 25 aqua tools could resolve their release tag.
    missing_count=$(mise ls 2>/dev/null | grep -c '(missing)' || true)
    if [ "${missing_count:-0}" -gt 0 ]; then
        echo "" >&2
        echo "[install-packages] WARNING: $missing_count mise tool(s) missing." >&2
        echo "  Most common cause: GitHub API rate-limit (60/hr anonymous)." >&2
        echo "  Fix once: gh auth login   # token auto-detected next apply" >&2
        echo "  Or 1Password: create 'op://Personal/GitHub API Token/credential'" >&2
        echo "  Then re-run: chezmoi apply   (or: mise install --yes)" >&2
        echo "" >&2
    fi
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

post_install_rtk_init() {
    # rtk binary itself is installed by mise (see dot_config/mise/config.toml.tmpl
    # dev block: `github:rtk-ai/rtk = latest`). Here we run the init step that
    # wires rtk into Claude Code (PreToolUse hook) + Codex (AGENTS.md).
    if ! command -v rtk >/dev/null 2>&1; then
        echo "rtk not on PATH after install-packages." >&2
        echo "Possible causes:" >&2
        echo "  - mise install failed (rate-limit / no network). Check 'mise ls'." >&2
        echo "  - Shims dir not on PATH. Try 'exec zsh' then re-run 'chezmoi apply'." >&2
        return 0
    fi
    # rtk's Linux arm64 build is dynamically linked against glibc >=2.39
    # (Ubuntu 24.04+); on Ubuntu 22.04 jammy (glibc 2.35) it fails with
    # "version `GLIBC_2.39' not found". No musl/static alternative is shipped
    # upstream as of 2026-05. Skip rtk init gracefully on too-old glibc rather
    # than fail the whole apply — claude/codex still work without the rtk hook.
    if ! rtk --version >/dev/null 2>&1; then
        echo "rtk binary fails to execute on this system (likely glibc too old)." >&2
        echo "Upstream ships glibc-2.39 build only for linux-arm64; needs Ubuntu 24.04+." >&2
        echo "Skipping rtk init. claude/codex still usable without rtk hook." >&2
        return 0
    fi
    # --auto-patch is Claude-specific: writes the PreToolUse hook into
    # ~/.claude/settings.json non-interactively. Codex has no settings-hook
    # analogue (rtk wires Codex via @RTK.md in AGENTS.md), so the codex path
    # doesn't take that flag.
    if command -v claude >/dev/null 2>&1; then
        rtk init -g --auto-patch
    fi
    # `-g --codex` resolves to ~/.codex/{AGENTS.md,RTK.md} via resolve_codex_dir().
    # Without `-g`, rtk init --codex writes to cwd (which is $HOME under chezmoi
    # apply), polluting $HOME with stray AGENTS.md and RTK.md.
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

    if is_dev; then
        post_install_goimports
        post_install_ssh_audit
        post_install_rtk_init
    fi
}

# Auto-run when sourced by the chezmoi wrapper (which sets the flag).
# Bats tests source without setting it → functions defined, main not called.
if [ "${INSTALL_PACKAGES_INVOKE:-0}" = "1" ]; then
    main "$@"
fi
