#!/bin/sh
# Claude Code statusline — extends the default cwd/branch view with rtk +
# caveman health indicators so wired-up state is visible at a glance.
#
# Render budget: <50ms (Claude polls frequently). Measured: ~30ms with
# two jq probes on ~1KB settings.json. No cache layer needed at this
# scale; revisit if probes grow.
set -eu

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] && cwd="$PWD"
dir=$(basename "$cwd")

git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null || true)

# rtk health: wired if hooks.PreToolUse[*].hooks[*].command contains
# "rtk hook claude" (what `rtk init -g --auto-patch` writes).
settings="$HOME/.claude/settings.json"
if [ -r "$settings" ] && \
    jq -e '[.hooks.PreToolUse[]?.hooks[]?.command | select(. and contains("rtk hook claude"))] | length > 0' \
    "$settings" >/dev/null 2>&1; then
    rtk_state="ok"
else
    rtk_state="bad"
fi

# caveman health: enabled flag in enabledPlugins. The plugin's own
# SessionStart/UserPromptSubmit hooks fire from plugin.json (not
# settings.json), so the enable flag is the source of truth.
if [ -r "$settings" ] && \
    jq -e '.enabledPlugins["caveman@caveman"] == true' \
    "$settings" >/dev/null 2>&1; then
    caveman_state="ok"
else
    caveman_state="bad"
fi

# Colors — actual ESC byte (POSIX sh; `$'\033'` would be bashism).
# Needed so badges can be composed in variables AND passed via printf %s
# (printf only interprets backslash escapes in the format string, not args).
ESC=$(printf '\033')
CYAN="${ESC}[1;36m"
GREEN="${ESC}[0;32m"
RED="${ESC}[0;31m"
BLUE="${ESC}[0;34m"
GREY="${ESC}[0;90m"
RESET="${ESC}[0m"

if [ "$rtk_state" = "ok" ]; then
    rtk_badge="${GREY}rtk:${GREEN}✓${RESET}"
else
    rtk_badge="${GREY}rtk:${RED}✗${RESET}"
fi
if [ "$caveman_state" = "ok" ]; then
    cave_badge="${GREY}cave:${GREEN}✓${RESET}"
else
    cave_badge="${GREY}cave:${RED}✗${RESET}"
fi

if [ -n "$git_branch" ]; then
    printf "${CYAN}%s${RESET} ${BLUE}git:(${GREEN}%s${BLUE})${RESET} %s %s" \
        "$dir" "$git_branch" "$rtk_badge" "$cave_badge"
else
    printf "${CYAN}%s${RESET} %s %s" "$dir" "$rtk_badge" "$cave_badge"
fi
