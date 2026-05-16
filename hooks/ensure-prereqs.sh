#!/bin/sh
# Hook: ensure minimum prereqs are present BEFORE chezmoi reads source state.
# Registered in .chezmoi.toml.tmpl as `hooks.read-source-state.pre.command`.
#
# Per chezmoi docs: hooks are PLAIN shell scripts (not templates). Detect OS
# inline. Idempotent: skips when everything is present, skips with warning if
# missing tools would require interactive sudo on a non-TTY apply.
#
# Installs (per OS):
# - macOS: Xcode Command Line Tools + Homebrew (Apple bundles git/zsh/vim/
#   tmux/curl, so no base-tool install needed) + mise (via brew).
# - Linux: base tools (git/zsh/vim/tmux/curl/ca-certificates) via apt/dnf,
#   plus mise via `curl https://mise.run | sh` into ~/.local/bin.
# - No Alpine/Arch support (documented limitation).
set -eu

# Force apt non-interactive — even from a TTY apply, downstream scripts may
# run from a non-TTY chezmoi child, and consistency matters.
export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC

is_tty=0
tty -s && is_tty=1

case "$(uname -s)" in
    Darwin)
        # Homebrew install (if missing) — needs Xcode CLT, which `brew install`
        # script handles. Interactive on first run.
        if ! command -v brew >/dev/null 2>&1; then
            if [ "$is_tty" -eq 0 ]; then
                # Fail loudly: skipping brew install silently leads to all
                # downstream scripts breaking with "brew: command not found".
                # Halt the apply so the user runs the visible install command.
                echo "ERROR: Homebrew not installed; chezmoi apply needs an interactive run first." >&2
                echo "  Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                echo "  Then re-run: chezmoi apply" >&2
                exit 1
            fi
            echo "Installing Homebrew (Xcode CLT will install as a side effect)..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi

        # mise — install via brew (primary dev-tool installer). Idempotent.
        # Must be on PATH before chezmoi reads source state, since the
        # install-packages script runs `mise install` for ~28 tools.
        if ! command -v mise >/dev/null 2>&1; then
            brew install mise 2>&1 || echo "brew install mise failed" >&2
        fi
        ;;
    Linux)
        # --- 1. Base tools -------------------------------------------------
        # git/zsh/vim/tmux/curl: editor + shell + version control baseline.
        # Each is a CLI binary — `command -v` is the right check.
        missing=""
        for tool in git zsh vim tmux curl; do
            command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
        done
        # ca-certificates is a system PACKAGE, not a binary — `command -v`
        # always returns false for it. Check via the canonical cert-bundle
        # file location instead. Linux distros put the bundle in different
        # places; check both Debian-family and RHEL-family paths.
        if [ ! -f /etc/ssl/certs/ca-certificates.crt ] \
            && [ ! -f /etc/pki/tls/certs/ca-bundle.crt ]; then
            missing="$missing ca-certificates"
        fi

        if [ "$(id -u)" -eq 0 ]; then
            sudo_cmd=""
        elif command -v sudo >/dev/null 2>&1; then
            sudo_cmd="sudo -E"
        else
            sudo_cmd=""
        fi

        # Decide whether sudo path is usable (passwordless or TTY).
        sudo_usable=1
        if [ -n "$sudo_cmd" ] && [ "$is_tty" -eq 0 ]; then
            if ! sudo -n true 2>/dev/null; then
                sudo_usable=0
            else
                sudo_cmd="sudo -nE"
            fi
        fi

        if [ -n "$missing" ]; then
            if [ -z "$sudo_cmd" ] && [ "$(id -u)" -ne 0 ]; then
                echo "WARNING: missing tools:$missing — neither root nor sudo available." >&2
                echo "  Install manually as root." >&2
            elif [ "$sudo_usable" -eq 0 ]; then
                echo "WARNING: missing tools:$missing — non-interactive apply, sudo prompt would block." >&2
                echo "  Install manually:$sudo_cmd apt-get install -y$missing  (or dnf install -y$missing)" >&2
            elif command -v apt-get >/dev/null 2>&1; then
                # Redirect stdout → /dev/null so the hook stays silent during
                # chezmoi diff / verify (their stdout becomes chezmoi's). apt
                # errors still surface on stderr and via $?.
                $sudo_cmd apt-get update -qq >/dev/null
                # shellcheck disable=SC2086
                $sudo_cmd apt-get install -y --no-install-recommends $missing >/dev/null
            elif command -v dnf >/dev/null 2>&1; then
                # shellcheck disable=SC2086
                $sudo_cmd dnf install -y $missing >/dev/null
            else
                echo "WARNING: missing tools:$missing — neither apt-get nor dnf found." >&2
                exit 0
            fi
        fi

        # --- 2. mise — install via curl-pipe to ~/.local/bin ----------------
        # mise must be on PATH before chezmoi reads source state (the install-
        # packages script calls `mise install` for ~28 tools).
        #
        # Why curl-pipe and not signed apt/dnf repo: simplicity. mise has
        # `mise self-update` for ongoing upgrades, so we don't need apt's
        # tracking. Trade-off: one curl-pipe = ~5 LOC vs ~35 LOC repo logic.
        if ! command -v mise >/dev/null 2>&1; then
            curl -fsSL https://mise.run | sh
            export PATH="$HOME/.local/bin:$PATH"
            hash -r
        fi
        ;;
    *)
        echo "WARNING: unsupported OS $(uname -s) — repo supports macOS + Debian/Ubuntu + Fedora only." >&2
        exit 0
        ;;
esac
