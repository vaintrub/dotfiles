#!/usr/bin/env bats
# Unit tests for lib/common.sh — the helpers shared by the pre-source-state
# hook (hooks/ensure-prereqs.sh) and the installer (lib/install-packages.sh).
# Externals (id/sudo/apt-get/dnf/command) are mocked per test.

setup() {
    SOURCE_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # shellcheck source=../../lib/common.sh
    . "$SOURCE_DIR/lib/common.sh"
}

# --- dotfiles_sudo_cmd -----------------------------------------------------

@test "dotfiles_sudo_cmd: root → empty prefix, success" {
    id() { echo 0; }
    run dotfiles_sudo_cmd
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "dotfiles_sudo_cmd: non-root with sudo → 'sudo -E'" {
    id() { echo 1000; }
    # Mock the lookup: the result must not depend on the host having sudo.
    command() {
        case "$2" in sudo) return 0 ;; *) builtin command "$@" ;; esac
    }
    run dotfiles_sudo_cmd
    [ "$status" -eq 0 ]
    [ "$output" = "sudo -E" ]
}

@test "dotfiles_sudo_cmd: non-root without sudo → failure" {
    id() { echo 1000; }
    command() {
        case "$2" in sudo) return 1 ;; *) builtin command "$@" ;; esac
    }
    run dotfiles_sudo_cmd
    [ "$status" -ne 0 ]
}

@test "dotfiles_sudo_cmd: noninteractive with passwordless sudo → 'sudo -nE'" {
    id() { echo 1000; }
    command() {
        case "$2" in sudo) return 0 ;; *) builtin command "$@" ;; esac
    }
    sudo() { return 0; }   # `sudo -n true` succeeds
    run dotfiles_sudo_cmd noninteractive
    [ "$status" -eq 0 ]
    [ "$output" = "sudo -nE" ]
}

@test "dotfiles_sudo_cmd: noninteractive when sudo would prompt → failure" {
    id() { echo 1000; }
    command() {
        case "$2" in sudo) return 0 ;; *) builtin command "$@" ;; esac
    }
    sudo() { return 1; }   # `sudo -n true` fails → password needed
    run dotfiles_sudo_cmd noninteractive
    [ "$status" -ne 0 ]
}

@test "dotfiles_sudo_cmd: root ignores noninteractive and still succeeds" {
    id() { echo 0; }
    run dotfiles_sudo_cmd noninteractive
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- dotfiles_pkg_manager --------------------------------------------------

@test "dotfiles_pkg_manager: apt-get wins when both exist" {
    command() {
        case "$2" in apt-get|dnf) return 0 ;; *) builtin command "$@" ;; esac
    }
    run dotfiles_pkg_manager
    [ "$output" = "apt-get" ]
}

@test "dotfiles_pkg_manager: dnf when apt-get absent" {
    command() {
        case "$2" in apt-get) return 1 ;; dnf) return 0 ;; *) builtin command "$@" ;; esac
    }
    run dotfiles_pkg_manager
    [ "$output" = "dnf" ]
}

@test "dotfiles_pkg_manager: empty when neither exists" {
    command() {
        case "$2" in apt-get|dnf) return 1 ;; *) builtin command "$@" ;; esac
    }
    run dotfiles_pkg_manager
    [ -z "$output" ]
}

# --- dotfiles_pkg_install --------------------------------------------------

@test "dotfiles_pkg_install: apt path runs update then install with the sudo prefix" {
    log="$BATS_TEST_TMPDIR/apt.log"
    command() {
        case "$2" in apt-get) return 0 ;; dnf) return 1 ;; *) builtin command "$@" ;; esac
    }
    sudo() { echo "sudo $*" >>"$log"; }

    dotfiles_pkg_install apt-get "sudo -E" verbose curl git
    grep -q 'sudo -E apt-get update -qq' "$log"
    grep -q 'sudo -E apt-get install -y --no-install-recommends curl git' "$log"
}

@test "dotfiles_pkg_install: empty sudo prefix does not inject an empty argument" {
    log="$BATS_TEST_TMPDIR/apt.log"
    command() {
        case "$2" in apt-get) return 0 ;; dnf) return 1 ;; *) builtin command "$@" ;; esac
    }
    apt-get() { echo "apt-get $*" >>"$log"; }

    dotfiles_pkg_install apt-get "" verbose curl
    grep -q '^apt-get update -qq$' "$log"
    grep -q '^apt-get install -y --no-install-recommends curl$' "$log"
}

@test "dotfiles_pkg_install: failing update still runs install and warns" {
    log="$BATS_TEST_TMPDIR/apt.log"
    command() {
        case "$2" in apt-get) return 0 ;; dnf) return 1 ;; *) builtin command "$@" ;; esac
    }
    apt-get() {
        echo "apt-get $*" >>"$log"
        case "$1" in update) return 1 ;; *) return 0 ;; esac
    }

    run dotfiles_pkg_install apt-get "" verbose curl
    [ "$status" -eq 0 ]
    [[ "$output" =~ "apt-get update failed" ]]
    grep -q 'apt-get install' "$log"
}

@test "dotfiles_pkg_install: dnf path" {
    log="$BATS_TEST_TMPDIR/dnf.log"
    command() {
        case "$2" in apt-get) return 1 ;; dnf) return 0 ;; *) builtin command "$@" ;; esac
    }
    dnf() { echo "dnf $*" >>"$log"; }

    dotfiles_pkg_install dnf "" verbose htop
    grep -q '^dnf install -y htop$' "$log"
}

@test "dotfiles_pkg_install: no package manager → warn, do not fail" {
    command() {
        case "$2" in apt-get|dnf) return 1 ;; *) builtin command "$@" ;; esac
    }
    run dotfiles_pkg_install auto "" verbose curl
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Neither apt-get nor dnf" ]]
}

@test "dotfiles_pkg_install: empty package list is a no-op" {
    command() { builtin command "$@"; }
    run dotfiles_pkg_install apt-get "" verbose
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "dotfiles_pkg_install: quiet mode silences stdout but keeps warnings" {
    command() {
        case "$2" in apt-get) return 0 ;; dnf) return 1 ;; *) builtin command "$@" ;; esac
    }
    apt-get() {
        echo "NOISE on stdout"
        case "$1" in update) return 1 ;; *) return 0 ;; esac
    }

    run dotfiles_pkg_install apt-get "" quiet curl
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "NOISE" ]]
    [[ "$output" =~ "apt-get update failed" ]]
}

@test "dotfiles_pkg_install: explicit dnf is not overridden by a present apt-get" {
    log="$BATS_TEST_TMPDIR/mgr.log"
    # A Fedora box may well have apt-get installed; auto-detection prefers it.
    command() {
        case "$2" in apt-get|dnf) return 0 ;; *) builtin command "$@" ;; esac
    }
    apt-get() { echo "apt-get $*" >>"$log"; }
    dnf() { echo "dnf $*" >>"$log"; }

    dotfiles_pkg_install dnf "" verbose htop
    grep -q '^dnf install -y htop$' "$log"
    ! grep -q apt-get "$log"
}

@test "dotfiles_pkg_install: auto resolves the manager itself" {
    log="$BATS_TEST_TMPDIR/mgr.log"
    command() {
        case "$2" in apt-get) return 1 ;; dnf) return 0 ;; *) builtin command "$@" ;; esac
    }
    dnf() { echo "dnf $*" >>"$log"; }

    dotfiles_pkg_install auto "" verbose htop
    grep -q '^dnf install -y htop$' "$log"
}
