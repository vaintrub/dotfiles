#!/bin/sh
# Claude Code statusline: the working directory and its git branch.
set -eu

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // ""' 2>/dev/null || true)
[ -z "$cwd" ] && cwd="$PWD"
dir=$(basename "$cwd")

git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)

# An actual ESC byte (POSIX sh has no $'\033'): printf interprets backslash
# escapes only in its format string.
ESC=$(printf '\033')
CYAN="${ESC}[1;36m"
GREEN="${ESC}[0;32m"
BLUE="${ESC}[0;34m"
RESET="${ESC}[0m"

if [ -n "$git_branch" ]; then
    printf "${CYAN}%s${RESET} ${BLUE}git:(${GREEN}%s${BLUE})${RESET}" "$dir" "$git_branch"
else
    printf "${CYAN}%s${RESET}" "$dir"
fi
