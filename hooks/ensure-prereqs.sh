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

# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$(dirname "$0")/../lib/common.sh"

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
        # The installer only prints the shellenv line, so brew is not yet on PATH.
        dotfiles_ensure_brew_path || {
            echo "ERROR: Homebrew installed but brew is not on PATH." >&2
            exit 1
        }
        if ! command -v mise >/dev/null 2>&1; then
            brew install mise || echo "WARNING: brew install mise failed." >&2
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

        if [ -n "$missing" ]; then
            # No TTY: a password prompt would hang the apply.
            if [ "$is_tty" -eq 0 ]; then
                sudo_mode=noninteractive
            else
                sudo_mode=interactive
            fi

            if sudo_cmd=$(dotfiles_sudo_cmd "$sudo_mode"); then
                # stdout → /dev/null so the hook stays silent during diff/verify.
                # shellcheck disable=SC2086
                dotfiles_pkg_install auto "$sudo_cmd" quiet $missing
            else
                echo "WARNING: missing tools:$missing — cannot escalate privileges." >&2
                echo "  Non-interactive run without passwordless sudo, or sudo absent." >&2
                echo "  Install manually: sudo apt-get install -y$missing  (or dnf install -y$missing)" >&2
            fi

            # These are hard prerequisites: the rest of the apply reads the
            # source state with them (dot_gitconfig.tmpl shells out to git).
            # dotfiles_pkg_install never fails the caller, so check the
            # postcondition and stop here rather than somewhere confusing.
            still_missing=""
            for tool in git zsh vim tmux curl; do
                command -v "$tool" >/dev/null 2>&1 || still_missing="$still_missing $tool"
            done
            if [ -n "$still_missing" ]; then
                echo "ERROR: hard prerequisites still missing after install:$still_missing" >&2
                exit 1
            fi
        fi

        if ! command -v mise >/dev/null 2>&1; then
            # Staged, not `curl … | sh`: a pipe reports sh's status, so a failed
            # download would look like success and leave mise silently absent.
            installer=$(mktemp)
            if command -v curl >/dev/null 2>&1 \
                && curl -fsSL https://mise.run -o "$installer"; then
                sh "$installer"
            else
                echo "WARNING: could not fetch https://mise.run — mise not installed." >&2
            fi
            rm -f "$installer"
        fi
        ;;
    *)
        echo "WARNING: unsupported OS $(uname -s) — repo supports macOS + Debian/Ubuntu + Fedora only." >&2
        exit 0
        ;;
esac
