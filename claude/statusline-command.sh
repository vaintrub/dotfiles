#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd')
dir=$(basename "$cwd")

# Get git branch (skip optional locks)
git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# Colors
CYAN='\033[1;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Build prompt similar to robbyrussell theme
if [ -n "$git_branch" ]; then
    printf "${CYAN}%s${RESET} ${BLUE}git:(${GREEN}%s${BLUE})${RESET}" "$dir" "$git_branch"
else
    printf "${CYAN}%s${RESET}" "$dir"
fi
