#!/usr/bin/env bats
# Unit tests for hooks/ensure-prereqs.sh — runs the real hook under /bin/sh
# with PATH confined to a scratch bin of fakes, so "missing" tools are really
# missing and every package-manager call is logged instead of executed.

setup() {
    SOURCE_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    BIN="$BATS_TEST_TMPDIR/bin"
    LOG="$BATS_TEST_TMPDIR/calls.log"
    mkdir -p "$BIN"
    for t in dirname mktemp rm cat chmod; do
        ln -s "$(command -v "$t")" "$BIN/$t"
    done
    fake uname 'echo Linux'
    fake id 'echo 0'
    fake tty 'exit 1'
    fake curl 'exit 1'
    # apt-get "installs" by dropping a fake binary for each package it is
    # given, except the names listed in $UNINSTALLABLE.
    fake apt-get '
echo "apt-get $*" >>"'"$LOG"'"
[ "$1" = install ] || exit 0
for p in "$@"; do
    case "$p" in -*|install) continue ;; esac
    case " ${UNINSTALLABLE:-} " in *" $p "*) continue ;; esac
    printf "#!/bin/sh\n" >"'"$BIN"'/$p"; chmod +x "'"$BIN"'/$p"
done'
}

fake() {
    printf '#!/bin/sh\n%s\n' "$2" >"$BIN/$1"
    chmod +x "$BIN/$1"
}

hook() {
    PATH="$BIN" /bin/sh "$SOURCE_DIR/hooks/ensure-prereqs.sh"
}

# --- step 2: only apply/init/update may mutate ------------------------------

@test "chezmoi diff never reaches the package manager" {
    CHEZMOI_COMMAND=diff CHEZMOI_ARGS="chezmoi diff" run hook
    [ "$status" -eq 0 ]
    [ ! -f "$LOG" ]
}

@test "status, verify and managed exit before mutating too" {
    for c in status verify managed; do
        CHEZMOI_COMMAND=$c CHEZMOI_ARGS="chezmoi $c" run hook
        [ "$status" -eq 0 ]
    done
    [ ! -f "$LOG" ]
}

@test "apply --dry-run, -n and a -nv cluster do not mutate" {
    for a in "--dry-run" "-n" "-nv" "--verbose -n"; do
        CHEZMOI_COMMAND=apply CHEZMOI_ARGS="chezmoi apply $a" run hook
        [ "$status" -eq 0 ]
    done
    [ ! -f "$LOG" ]
}

@test "a global -n before the subcommand is a dry run as well" {
    CHEZMOI_COMMAND=apply CHEZMOI_ARGS="chezmoi -n apply" run hook
    [ "$status" -eq 0 ]
    [ ! -f "$LOG" ]
}

@test "apply installs the missing prerequisites" {
    CHEZMOI_COMMAND=apply CHEZMOI_ARGS="chezmoi --no-tty apply" run hook
    [ "$status" -eq 0 ]
    grep -q 'apt-get install .*git' "$LOG"
}

@test "init (the bootstrap path) installs too" {
    CHEZMOI_COMMAND=init CHEZMOI_ARGS="chezmoi init --apply vaintrub" run hook
    [ "$status" -eq 0 ]
    grep -q 'apt-get install' "$LOG"
}

@test "with CHEZMOI_COMMAND unset (run by hand) the hook still installs" {
    run hook
    [ "$status" -eq 0 ]
    grep -q 'apt-get install' "$LOG"
}
