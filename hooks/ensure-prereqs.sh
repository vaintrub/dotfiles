#!/bin/sh
# Pre-source-state hook (registered in .chezmoi.toml.tmpl). Installs minimum
# prereqs so the rest of chezmoi apply can proceed. Plain shell, not a template
# (chezmoi doesn't render hooks). Idempotent.
#
# Mac: brew (+ Xcode CLT as side effect) + mise via brew.
# Linux (Debian/Ubuntu/Fedora): git/zsh/vim/tmux/curl/ca-certificates via
#   apt/dnf + mise via curl-pipe. No Alpine/Arch support.
set -eu

export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC

is_tty=0
tty -s && is_tty=1

case "$(uname -s)" in
    Darwin)
        if ! command -v brew >/dev/null 2>&1; then
            if [ "$is_tty" -eq 0 ]; then
                echo "ERROR: Homebrew not installed; chezmoi apply needs an interactive run first." >&2
                echo "  Run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                echo "  Then re-run: chezmoi apply" >&2
                exit 1
            fi
            echo "Installing Homebrew (Xcode CLT installs as side effect)..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        if ! command -v mise >/dev/null 2>&1; then
            brew install mise 2>&1 || echo "brew install mise failed" >&2
        fi
        ;;
    Linux)
        missing=""
        for tool in git zsh vim tmux curl; do
            command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
        done
        # ca-certificates: system pkg, not a CLI — check cert bundle file.
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
            elif [ "$sudo_usable" -eq 0 ]; then
                echo "WARNING: missing tools:$missing — non-interactive apply, sudo prompt would block." >&2
                echo "  Install manually:$sudo_cmd apt-get install -y$missing  (or dnf install -y$missing)" >&2
            elif command -v apt-get >/dev/null 2>&1; then
                # stdout → /dev/null so hook stays silent during chezmoi diff/verify.
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
