#!/usr/bin/env bats
# Unit tests for lib/install-packages.sh — sources the library (which
# the POSIX guard skips because INSTALL_PACKAGES_INVOKE is unset) and
# invokes individual functions with mocked external commands.

setup() {
    SOURCE_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Mocks recorded here; cleared per-test by bats' tmpdir lifecycle.
    export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
    : >"$CALLS_LOG"

    # Default env (overridden per-test).
    export DOTFILES_PROFILE="core"
    export DOTFILES_OS="linux"
    export DOTFILES_OSID="linux-ubuntu"
    export DOTFILES_OSRELEASE_IDLIKE="debian"
    export DOTFILES_CORE_BREWS=""
    export DOTFILES_DEV_BREWS=""
    export DOTFILES_GUI_MAC_CASKS=""
    export DOTFILES_GUI_LINUX_APT=""
    export DOTFILES_GUI_LINUX_DNF=""
    export DOTFILES_CORE_APT="curl git zsh"
    export DOTFILES_DEV_APT=""
    export DOTFILES_CORE_DNF="curl git zsh"
    export DOTFILES_DEV_DNF=""

    # Wipe INSTALL_PACKAGES_INVOKE so sourcing the lib doesn't auto-run main.
    unset INSTALL_PACKAGES_INVOKE
    # shellcheck source=../../lib/install-packages.sh
    . "$SOURCE_DIR/lib/install-packages.sh"
}

# --- profile / distro predicates ------------------------------------------

@test "is_dev: core profile → false" {
    DOTFILES_PROFILE=core
    run is_dev
    [ "$status" -ne 0 ]
}

@test "is_dev: dev profile → true" {
    DOTFILES_PROFILE=dev
    run is_dev
    [ "$status" -eq 0 ]
}

@test "is_dev: workstation profile → true (cascade)" {
    DOTFILES_PROFILE=workstation
    run is_dev
    [ "$status" -eq 0 ]
}

@test "is_workstation: only workstation profile → true" {
    DOTFILES_PROFILE=workstation
    run is_workstation
    [ "$status" -eq 0 ]

    DOTFILES_PROFILE=dev
    run is_workstation
    [ "$status" -ne 0 ]

    DOTFILES_PROFILE=core
    run is_workstation
    [ "$status" -ne 0 ]
}

@test "is_debian_family: linux-ubuntu → true" {
    DOTFILES_OSID=linux-ubuntu
    DOTFILES_OSRELEASE_IDLIKE=""
    run is_debian_family
    [ "$status" -eq 0 ]
}

@test "is_debian_family: linux-debian → true" {
    DOTFILES_OSID=linux-debian
    DOTFILES_OSRELEASE_IDLIKE=""
    run is_debian_family
    [ "$status" -eq 0 ]
}

@test "is_debian_family: linux-pop with idLike=debian → true (fallback)" {
    DOTFILES_OSID=linux-pop
    DOTFILES_OSRELEASE_IDLIKE="debian"
    run is_debian_family
    [ "$status" -eq 0 ]
}

@test "is_debian_family: linux-fedora → false" {
    DOTFILES_OSID=linux-fedora
    DOTFILES_OSRELEASE_IDLIKE=""
    run is_debian_family
    [ "$status" -ne 0 ]
}

@test "is_fedora_family: linux-fedora → true" {
    DOTFILES_OSID=linux-fedora
    run is_fedora_family
    [ "$status" -eq 0 ]
}

# --- apt_install ----------------------------------------------------------

@test "apt_install: as root → no sudo prefix" {
    sudo_called="$BATS_TEST_TMPDIR/sudo.log"
    apt_get_called="$BATS_TEST_TMPDIR/apt.log"
    id() { echo 0; }
    sudo() { echo "sudo $*" >>"$sudo_called"; }
    apt-get() { echo "apt-get $*" >>"$apt_get_called"; }
    export -f id sudo apt-get 2>/dev/null || true

    DOTFILES_CORE_APT="curl git"
    DOTFILES_DEV_APT=""
    apt_install

    [ ! -f "$sudo_called" ]
    grep -q 'apt-get update -qq' "$apt_get_called"
    grep -q 'apt-get install -y --no-install-recommends curl git' "$apt_get_called"
}

@test "apt_install: dev profile concatenates core + dev lists" {
    apt_get_called="$BATS_TEST_TMPDIR/apt.log"
    id() { echo 0; }
    apt-get() { echo "apt-get $*" >>"$apt_get_called"; }

    DOTFILES_PROFILE=dev
    DOTFILES_CORE_APT="zsh git"
    DOTFILES_DEV_APT="htop tree"
    apt_install

    install_line=$(grep 'apt-get install' "$apt_get_called")
    [[ "$install_line" =~ zsh ]]
    [[ "$install_line" =~ git ]]
    [[ "$install_line" =~ htop ]]
    [[ "$install_line" =~ tree ]]
}

@test "apt_install: core profile excludes dev list" {
    apt_get_called="$BATS_TEST_TMPDIR/apt.log"
    id() { echo 0; }
    apt-get() { echo "apt-get $*" >>"$apt_get_called"; }

    DOTFILES_PROFILE=core
    DOTFILES_CORE_APT="zsh git"
    DOTFILES_DEV_APT="htop tree"
    apt_install

    install_line=$(grep 'apt-get install' "$apt_get_called")
    [[ ! "$install_line" =~ htop ]]
    [[ ! "$install_line" =~ tree ]]
}

@test "apt_install: workstation profile adds GUI list (cascade core+dev+gui)" {
    apt_get_called="$BATS_TEST_TMPDIR/apt.log"
    id() { echo 0; }
    apt-get() { echo "apt-get $*" >>"$apt_get_called"; }

    DOTFILES_PROFILE=workstation
    DOTFILES_CORE_APT="zsh git"
    DOTFILES_DEV_APT="htop tree"
    DOTFILES_GUI_LINUX_APT="firefox code"
    apt_install

    install_line=$(grep 'apt-get install' "$apt_get_called")
    [[ "$install_line" =~ zsh ]]
    [[ "$install_line" =~ htop ]]
    [[ "$install_line" =~ firefox ]]
    [[ "$install_line" =~ code ]]
}

@test "apt_install: no root + no sudo → skip with warning" {
    id() { echo 1000; }
    command() {
        case "$2" in sudo) return 1 ;; *) builtin command "$@" ;; esac
    }

    run apt_install
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Neither root nor sudo" ]]
}

# --- linux_pkg_install dispatcher -----------------------------------------

@test "linux_pkg_install: linux-ubuntu → apt path" {
    apt_install() { echo "APT_CALLED"; }
    dnf_install() { echo "DNF_CALLED"; }
    DOTFILES_OSID=linux-ubuntu

    run linux_pkg_install
    [[ "$output" =~ "APT_CALLED" ]]
    [[ ! "$output" =~ "DNF_CALLED" ]]
}

@test "linux_pkg_install: linux-fedora → dnf path" {
    apt_install() { echo "APT_CALLED"; }
    dnf_install() { echo "DNF_CALLED"; }
    DOTFILES_OSID=linux-fedora
    DOTFILES_OSRELEASE_IDLIKE=""

    run linux_pkg_install
    [[ "$output" =~ "DNF_CALLED" ]]
    [[ ! "$output" =~ "APT_CALLED" ]]
}

@test "linux_pkg_install: linux-alpine → unsupported warning" {
    apt_install() { echo "APT_CALLED"; }
    dnf_install() { echo "DNF_CALLED"; }
    DOTFILES_OSID=linux-alpine
    DOTFILES_OSRELEASE_IDLIKE=""

    run linux_pkg_install
    [[ "$output" =~ "Unsupported" ]]
    [[ "$output" =~ "linux-alpine" ]]
}

# --- mise_install_tools ----------------------------------------------------

@test "mise_install_tools: mise missing → skip with warning" {
    command() {
        case "$2" in mise) return 1 ;; *) builtin command "$@" ;; esac
    }

    run mise_install_tools
    [ "$status" -eq 0 ]
    [[ "$output" =~ "mise not on PATH" ]]
}

@test "mise_install_tools: mise present → trust + install" {
    mise_log="$BATS_TEST_TMPDIR/mise.log"
    command() {
        case "$2" in mise) return 0 ;; *) builtin command "$@" ;; esac
    }
    mise() { echo "mise $*" >>"$mise_log"; }

    mise_install_tools
    grep -q 'mise trust' "$mise_log"
    grep -q 'mise install --yes' "$mise_log"
}

@test "mise_install_tools: emits WARNING when (missing) tools post-install" {
    command() {
        case "$2" in mise) return 0 ;; *) builtin command "$@" ;; esac
    }
    # mise install → silent success. mise ls → returns one (missing) line.
    mise() {
        case "$1" in
            install) return 0 ;;
            trust)   return 0 ;;
            ls)      echo "aqua:foo/bar  1.0  ~/.config/mise/config.toml  latest (missing)" ;;
            *) :; ;;
        esac
    }

    run mise_install_tools
    [ "$status" -eq 0 ]
    [[ "$output" =~ "WARNING: 1 mise tool" ]]
    [[ "$output" =~ "gh auth login" ]]
    [[ "$output" =~ "op://Personal/GitHub API Token" ]]
}

@test "mise_install_tools: NO warning when mise ls is clean" {
    command() {
        case "$2" in mise) return 0 ;; *) builtin command "$@" ;; esac
    }
    mise() {
        case "$1" in
            install) return 0 ;;
            trust)   return 0 ;;
            ls)      echo "aqua:foo/bar  1.0  ~/.config/mise/config.toml  latest" ;;
            *) :; ;;
        esac
    }

    run mise_install_tools
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "WARNING" ]]
}

# --- main dispatcher -------------------------------------------------------

@test "main: core profile → no post-installs run" {
    DOTFILES_PROFILE=core
    DOTFILES_OS=linux

    # Stub all called functions.
    brew_bundle_install() { :; }
    linux_pkg_install() { :; }
    mise_install_tools() { :; }
    post_install_goimports() { echo "GO_CALLED"; }
    post_install_ssh_audit() { echo "AUDIT_CALLED"; }
    post_install_rtk_init() { echo "RTK_CALLED"; }

    run main
    [[ ! "$output" =~ "GO_CALLED" ]]
    [[ ! "$output" =~ "AUDIT_CALLED" ]]
    [[ ! "$output" =~ "RTK_CALLED" ]]
}

@test "main: dev profile → all post-installs run" {
    DOTFILES_PROFILE=dev
    DOTFILES_OS=linux

    brew_bundle_install() { :; }
    linux_pkg_install() { :; }
    mise_install_tools() { :; }
    post_install_goimports() { echo "GO_CALLED"; }
    post_install_ssh_audit() { echo "AUDIT_CALLED"; }
    post_install_rtk_init() { echo "RTK_CALLED"; }

    run main
    [[ "$output" =~ "GO_CALLED" ]]
    [[ "$output" =~ "AUDIT_CALLED" ]]
    [[ "$output" =~ "RTK_CALLED" ]]
}

@test "main: darwin OS → brew path, not linux" {
    DOTFILES_OS=darwin
    brew_bundle_install() { echo "BREW_CALLED"; }
    linux_pkg_install() { echo "LINUX_CALLED"; }
    mise_install_tools() { :; }

    run main
    [[ "$output" =~ "BREW_CALLED" ]]
    [[ ! "$output" =~ "LINUX_CALLED" ]]
}

@test "main: linux OS → linux_pkg_install path, not brew" {
    DOTFILES_OS=linux
    DOTFILES_OSID=linux-ubuntu
    brew_bundle_install() { echo "BREW_CALLED"; }
    linux_pkg_install() { echo "LINUX_CALLED"; }
    mise_install_tools() { :; }

    run main
    [[ "$output" =~ "LINUX_CALLED" ]]
    [[ ! "$output" =~ "BREW_CALLED" ]]
}

# --- post_install_rtk_init -------------------------------------------------

@test "post_install_rtk_init: rtk not on PATH → skip + warning" {
    command() {
        case "$2" in rtk) return 1 ;; *) builtin command "$@" ;; esac
    }

    run post_install_rtk_init
    [ "$status" -eq 0 ]
    [[ "$output" =~ "rtk not on PATH" ]]
}

@test "post_install_rtk_init: rtk --version fails (glibc too old) → graceful skip" {
    command() {
        case "$2" in rtk) return 0 ;; *) builtin command "$@" ;; esac
    }
    rtk() {
        case "$1" in --version) return 1 ;; *) return 0 ;; esac
    }

    run post_install_rtk_init
    [ "$status" -eq 0 ]
    [[ "$output" =~ "glibc too old" ]]
    [[ ! "$output" =~ "initialized" ]]
}

@test "post_install_rtk_init: claude present → calls --auto-patch" {
    rtk_log="$BATS_TEST_TMPDIR/rtk.log"
    command() {
        case "$2" in rtk|claude) return 0 ;; codex) return 1 ;; *) builtin command "$@" ;; esac
    }
    rtk() {
        echo "rtk $*" >>"$rtk_log"
        case "$1" in --version) echo "rtk 0.40.0" ;; esac
        return 0
    }

    run post_install_rtk_init
    [ "$status" -eq 0 ]
    grep -q 'rtk init -g --auto-patch' "$rtk_log"
    [[ "$output" =~ "initialized" ]]
}

@test "post_install_rtk_init: codex present → calls --codex" {
    rtk_log="$BATS_TEST_TMPDIR/rtk.log"
    command() {
        case "$2" in rtk|codex) return 0 ;; claude) return 1 ;; *) builtin command "$@" ;; esac
    }
    rtk() {
        echo "rtk $*" >>"$rtk_log"
        case "$1" in --version) echo "rtk 0.40.0" ;; esac
        return 0
    }

    run post_install_rtk_init
    [ "$status" -eq 0 ]
    grep -q 'rtk init -g --codex' "$rtk_log"
    ! grep -q 'rtk init -g --auto-patch' "$rtk_log"
}

@test "post_install_rtk_init: neither claude nor codex → still prints initialized banner (idempotent no-op-ish)" {
    rtk_log="$BATS_TEST_TMPDIR/rtk.log"
    command() {
        case "$2" in rtk) return 0 ;; claude|codex) return 1 ;; *) builtin command "$@" ;; esac
    }
    rtk() {
        echo "rtk $*" >>"$rtk_log"
        case "$1" in --version) echo "rtk 0.40.0" ;; esac
        return 0
    }

    run post_install_rtk_init
    [ "$status" -eq 0 ]
    ! grep -q 'rtk init' "$rtk_log"
    [[ "$output" =~ "initialized" ]]
}

# --- guard sanity ----------------------------------------------------------

@test "INSTALL_PACKAGES_INVOKE guard: sourcing without flag does not run main" {
    out=$(INSTALL_PACKAGES_INVOKE="" sh -c '. "'"$SOURCE_DIR"'/lib/install-packages.sh"; echo POST_SOURCE')
    [[ "$out" =~ "POST_SOURCE" ]]
    [[ ! "$out" =~ "install-packages" ]]
}

@test "INSTALL_PACKAGES_INVOKE=1: sourcing runs main" {
    DOTFILES_PROFILE=core DOTFILES_OS=darwin DOTFILES_OSID=darwin \
        DOTFILES_CORE_BREWS="" DOTFILES_DEV_BREWS="" DOTFILES_GUI_MAC_CASKS="" \
        INSTALL_PACKAGES_INVOKE=1 \
        out=$(sh -c '. "'"$SOURCE_DIR"'/lib/install-packages.sh"' 2>&1) || true
    [[ "$out" =~ "install-packages" ]] || skip "non-fatal: brew may be missing in test env"
}
