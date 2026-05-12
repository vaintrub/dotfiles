# Dotfiles

Personal cross-platform (macOS + Linux) dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot).

Includes:
- **zsh** with [antidote](https://github.com/mattmc3/antidote) (static-cache) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) — `~/.p10k.zsh` tracked in the repo so the prompt is byte-identical everywhere
- **vim** with [vim-plug](https://github.com/junegunn/vim-plug) (auto-bootstrapped on first launch)
- **tmux** with [gpakosz/.tmux](https://github.com/gpakosz/.tmux) ("oh-my-tmux") vendored as a submodule
- **iTerm2** preferences (macOS only, auto-configured to load from the repo)
- **AI tooling** (Claude Code + OpenAI Codex CLI) — global instructions, settings, rules, AGENTS.md

`./install` is OS-aware: a single config file branches on `uname -s` for the few OS-divergent steps (font install, brew casks, iTerm2 wiring). Same repo, same script, both platforms.

## Install

### macOS

Prerequisites: `zsh`, `vim`, `tmux`, `git`, `python3`, [Homebrew](https://brew.sh), [iTerm2](https://iterm2.com).

```sh
git clone https://github.com/vaintrub/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install
```

The installer:
- Installs **MesloLGS Nerd Font** and **Visual Studio Code** via Homebrew cask (skipped if already installed).
- Points iTerm2 at `iterm/com.googlecode.iterm2.plist` in the repo (sets `PrefsCustomFolder`) — your terminal config travels with the repo.
- Symlinks `~/.p10k.zsh` to the repo so your Powerlevel10k prompt is byte-identical on every machine.

After the first `./install`, **quit iTerm2 once and relaunch** (choose "Don't Save" if prompted) — iTerm2 reads its prefs at startup. Re-runs are idempotent.

> Hard prerequisites are `git` and `python3` only — if either is missing, `./install` exits immediately with a clear `brew install …` / `apt install …` suggestion. Everything else (Homebrew, curl, fontconfig, zsh, vim, tmux, iTerm2) is checked per-feature: missing tools cause that feature to skip with a printed reason, not a hard fail.

### Linux

Prerequisites: `zsh git vim tmux curl fontconfig python3` (python3 is required by dotbot — preinstalled on most distros but absent on minimal Alpine/distroless images). Optional for tmux yank-to-clipboard: `xsel` (X11) or `wl-clipboard` (Wayland).

```sh
sudo apt install zsh git vim tmux curl fontconfig python3 xsel   # Debian/Ubuntu
# or: sudo dnf install zsh git vim tmux curl fontconfig python3 xsel  # Fedora
chsh -s "$(command -v zsh)"

git clone https://github.com/vaintrub/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install
```

The installer downloads MesloLGS NF (4 `.ttf` files from the official p10k media repo) into `~/.local/share/fonts/` and runs `fc-cache`. No root needed.

**Headless SSH servers**: the font install is skipped automatically (`$SSH_CONNECTION` is set and no `$DISPLAY`/`$WAYLAND_DISPLAY`). Glyphs render on the local terminal emulator — the remote machine never sees them.

## Tools

### tmux

Prefix is **`C-a`** (screen-style). Status bar, bindings, theme inherit from gpakosz/.tmux unchanged — see their [docs](https://github.com/gpakosz/.tmux#bindings). Useful defaults out of the box: `prefix h/j/k/l` for pane navigation, `prefix -` / `prefix _` for splits, `prefix e` to edit `.tmux.conf.local`, `prefix r` to reload, `prefix m` to toggle mouse.

Customizations in `tmux/tmux.conf.local`:

- **Prefix `C-a`** as the sole prefix (verbatim from gpakosz's documented snippet)
- **`mouse on`** — wheel scrolls tmux scrollback, drag-resizes panes, click selects
- **`mode-keys vi`** — copy-mode uses vim navigation (gpakosz ships vi-bindings; this activates them)
- **`set-clipboard on`** (OSC 52) — vim/nvim `"+y` inside tmux reaches the system clipboard
- **`tmux_conf_24b_colour=true`** — forces 24-bit colour so Powerlevel10k renders identically inside tmux
- **`COLORTERM=truecolor`** propagated to inner shells
- **`history-limit 50000`** — gpakosz default 5000 is small

No plugin manager. [TPM](https://github.com/tmux-plugins/tpm) has been dormant since Feb 2023; the only plugin feature we needed (`tmux-yank` for OS clipboard) is already covered by gpakosz natively.

**Gotchas**:

- iTerm2 **≥3.5.11** required — `3.5.0beta6`–`3.5.0beta10` had a regression where Nerd Font glyphs disappear inside tmux panes ([iTerm2 #10879](https://gitlab.com/gnachman/iterm2/-/issues/10879)).
- If Nerd Font glyphs render oddly inside tmux, enable iTerm2 → *Preferences → Profiles → Text → "Use built-in Powerline glyphs"*.
- If Powerlevel10k complains about an *instant-prompt* warning inside tmux, add `typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet` to `~/.p10k.zsh`.
- Linux without `xsel`/`xclip`/`wl-clipboard`: tmux copy-mode `y` saves to the tmux paste buffer only, not the system clipboard. The installer prints a one-line notice.
- Linux X11 vim — `clipboard^=unnamed,unnamedplus` writes to both `*` (PRIMARY/middle-click) and `+` (CLIPBOARD/Ctrl-V).

### iTerm2 (macOS)

The committed `iterm/com.googlecode.iterm2.plist` is loaded by iTerm2 via `PrefsCustomFolder` (configured by `./install`). After the first install, quit and relaunch iTerm2 once to apply.

Two iTerm2 stores aren't synced today because they're empty:

- **`~/Library/Application Support/iTerm2/DynamicProfiles/`** — JSON files that iTerm2 loads as additional profiles at startup. If you start using dynamic profiles, mirror them under `iterm/DynamicProfiles/` in this repo and symlink via dotbot.
- **`~/Library/Application Support/iTerm2/Scripts/`** — iTerm2 Python automation scripts. Same idea: mirror under `iterm/Scripts/` if you write any.

Everything else iTerm2 stores (`chatdb.sqlite`, `iTermServer-*`, `parsers/`, `SavedState/`, the auto-generated `*.plist.bak`, and `com.googlecode.iterm2.private.plist` which is explicitly `NoSync`-keyed) is runtime/transient/personal state — never sync.

**Trigger setup** — the committed plist ships a `vscode://` Trigger pre-installed on the default profile (used by the [VSCode-from-any-terminal](#open-vscode-from-any-terminal) flow). If for any reason it disappears, re-add via *iTerm2 → Settings → Profiles → Default → Advanced → Triggers → Edit → +*:

- **Regular Expression**: `vscode://[^[:space:]]+`
- **Action**: Run Command…
- **Parameters**: `open \0`
- **Instant**: ✗ (unchecked — fire on full line so it doesn't trigger on shell completion echoes)

> **Gotcha** — iTerm2's plist stores trigger actions as bare Objective-C class names, **not** the human-readable labels you see in the GUI dropdown. "Run Command…" in the UI maps to `"ScriptTrigger"` in the plist, not `"RunCommandAction"`. iTerm2 calls `NSClassFromString(action)` at load time and **silently drops the trigger if the class doesn't exist** ([`Trigger.m`](https://github.com/gnachman/iTerm2/blob/master/sources/Triggers/Trigger.m) `+triggerFromUntrustedDict:`). The canonical list of action names lives in iTerm2's Python API at [`api/library/python/iterm2/iterm2/triggers.py`](https://github.com/gnachman/iTerm2/blob/master/api/library/python/iterm2/iterm2/triggers.py). When seeding a trigger programmatically, the safest path is to add it once via the iTerm2 GUI, then `cp ~/Library/Preferences/com.googlecode.iterm2.plist iterm/com.googlecode.iterm2.plist`.

## Integrations

### AI tooling (Claude Code + OpenAI Codex)

Global, cross-machine config for both CLIs. **Only user-curated settings are tracked**; auth tokens, marketplace registrations, plugin caches, NUX state, project trust-levels — all stay machine-local.

Both tools store under `~/.claude/` and `~/.codex/` on macOS *and* Linux (neither follows XDG, [tracked upstream](https://github.com/anthropics/claude-code/issues/1455)), so no OS conditionals are needed.

> **Tooling setup** — when editing settings, agents, skills, rules, or `CLAUDE.md`/`AGENTS.md` themselves, edit the **dotfiles target path** (`~/dotfiles/claude/<file>` or `~/dotfiles/codex/<file>`), not the live symlink path. After adding NEW files that need linking, update `.install.conf.yaml` and re-run `./install`.

#### Layout

| Repo path | Symlinked to | Purpose |
|---|---|---|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | global user instructions (bootstrap + TL;DR rule index) |
| `claude/settings.json` | `~/.claude/settings.json` | global settings (status line, permissions mode, plugin enables) |
| `claude/statusline-command.sh` | `~/.claude/statusline-command.sh` | custom status-line renderer |
| `claude/agents/` | `~/.claude/agents/` | custom subagents (empty for now) |
| `claude/skills/` | `~/.claude/skills/` | custom skills (directory-per-skill with `SKILL.md`) |
| `claude/rules/` | `~/.claude/rules/` | markdown rules auto-loaded by Claude Code (see below) |
| `codex/AGENTS.md` | `~/.codex/AGENTS.md` | global user instructions for Codex (its equivalent of `CLAUDE.md`) |
| `codex/config.toml` | `~/.codex/config.toml` | model, personality, plugin enables (runtime sections stripped — see implementation notes) |
| `codex/skills/` | `~/.codex/skills/` | custom Codex skills (Codex's built-in `.system/` is gitignored) |

We deliberately don't symlink `~/.claude/commands/` (deprecated by skills per upstream docs) or `~/.claude/hooks/` (not a Claude convention — hooks live inline in `settings.json`).

#### Rules architecture (claude/rules/)

Files under `claude/rules/*.md` are **auto-discovered by Claude Code at session start** (the rules directory is a [documented Claude location](https://code.claude.com/docs/en/memory.md), symlinks supported). Each rule file is a small markdown doc with YAML frontmatter:

```yaml
---
name: my-rule
description: One-line summary surfaced in the rule index.
paths:                            # OPTIONAL — conditional loading
  - "**/*.tsx"
  - "**/*.css"
---
```

- **Universal rules** (no `paths:`) load on every session.
- **Conditional rules** (with `paths:` glob array) only load when Claude is reading/editing files matching one of the globs — perfect for "frontend-only" or "Python-only" guidance that shouldn't pollute backend sessions.

Current set: three universal rules (`read-codebase-first`, `no-code-without-go`, `verify-before-fix`) and two frontend-only rules (`frontend-spec-first-workflow`, `visual-audit-mcp-gotchas`). Codex doesn't have an auto-discovery equivalent — `codex/AGENTS.md` references the rule files as advisory reading material.

#### Not tracked (intentionally)

- `~/.claude/settings.local.json` — per-machine permissions allowlist; Anthropic's documented convention is to gitignore it. Re-curate `/permissions` per machine.
- `~/.claude/plugins/{installed_plugins,known_marketplaces}.json` — contain absolute install paths and per-user marketplace registrations.
- `~/.claude.json` — **lives at `$HOME`, not in `~/.claude/`** — holds OAuth tokens, MCP server credentials, NUX `tipsHistory` counters, marketplace registrations. **Never commit it.**
- `~/.codex/auth.json`, `installation_id` — secrets and per-machine identifiers.
- `~/.codex/{sessions,cache,log,tmp,history.jsonl,*.sqlite}` — runtime state.
- `~/.codex/memories/`, `~/.codex/plugins/` — runtime state / cloned plugin repos.

#### Per-machine after `./install` — plugins

Neither tool auto-installs plugins from the synced config (the enable flags only activate already-installed plugins). After first install on a new machine, manually run:

**Claude Code** (via `/plugin install <plugin>@<marketplace>` in the TUI):
- `gopls-lsp@claude-plugins-official`
- `figma@claude-plugins-official`
- `frontend-design@claude-plugins-official`

**Codex** (via `codex plugin install <plugin>` or `/plugins` in the TUI):
- `github@openai-curated`
- `google-drive@openai-curated`

#### Prerequisites

The `claude` and `codex` CLIs are **soft prereqs** — `./install` runs without them and will link the configs anyway, but the linked files do nothing until the binaries are present. The installer prints a notice with install instructions.

Recommended install:
- macOS: `brew install --cask claude-code codex`
- Linux: see https://claude.com/code and https://github.com/openai/codex

### Open VSCode from any terminal

`code <path>` works the same in any iTerm2 pane. Calling `code` **without arguments** opens the `*.code-workspace` file in the current directory if one exists, otherwise opens the current directory itself.

- **Local Mac**: opens VSCode at that path. Works after `./install` (brew cask + PATH addition; no Command Palette "Install in PATH" step needed).
- **Remote SSH** (iTerm2/tmux into a Linux box): a zshrc function (active when `$SSH_CONNECTION` is set) decides what to do:
  1. If you're already in VSCode's *integrated* Remote-SSH terminal — calls the real `code` via the injected env.
  2. Otherwise tries to discover a live Remote-SSH IPC socket on the remote — if found, dispatches to the existing Mac-side VSCode window.
  3. Else prints a `vscode://vscode-remote/ssh-remote+<host>/<path>` URL. The iTerm2 Trigger (see [iTerm2 setup](#iterm2-macos)) matches the URL and runs `open <url>` → macOS launches Mac-side VSCode → it connects to the host via Remote-SSH and opens the folder.

If the remote's `hostname -s` doesn't match the Host alias in your **local** `~/.ssh/config`, override per-host:

```sh
export VSCODE_REMOTE_HOST=my-ssh-alias
```

The Remote-SSH IPC socket exists only after VSCode has connected to that host at least once — the first `code .` on a fresh remote box goes through the URL path.

## Implementation notes

### OS conditionals

Single `.install.conf.yaml`. Shell hooks branch on `case "$(uname -s)"` for the OS-divergent steps (Nerd Font install, Homebrew casks, iTerm2 prefs wiring, Linux clipboard-tool notice). Everything else is OS-neutral — zsh sees the OMZ `macos` plugin define harmless aliases/functions on Linux that simply never get invoked there.

### Codex auto-rewrite — the git clean filter

Codex auto-writes several sections into `~/.codex/config.toml` at runtime (see [openai/codex#15433](https://github.com/openai/codex/issues/15433), [#14601](https://github.com/openai/codex/issues/14601), [#5160](https://github.com/openai/codex/issues/5160)):

- `[projects."<absolute-path>"] trust_level = "trusted"` — added on each "trust this directory" prompt
- `[notice]` / `[notice.*]` — one-time UI dismissals + migration prompts
- `[tui.*]` — theme, keymap, NUX counters (`tui.model_availability_nux`)
- `[tool_suggest].disabled_tools`
- `windows_wsl_setup_acknowledged`

A git **clean filter** at `codex/scripts/strip-runtime-sections.awk` (registered per-clone by `./install` via `git config --local filter.codex-strip.{clean,smudge,required}`) strips these on `git add`. The smudge half is `cat` (identity passthrough on checkout) — the [gitattributes](https://git-scm.com/docs/gitattributes#_long_running_filter_process) `required=true` flag demands both halves of the filter pair exist, even when only `clean` does work. Working tree keeps whatever Codex wrote; the index gets only portable parts. Canonical list of mutable sections is the `ConfigEdit` enum in [`codex-rs/core/src/config/edit.rs`](https://github.com/openai/codex/tree/main/codex-rs/core/src/config/edit.rs).

> **TODO**: when [openai/codex#15433](https://github.com/openai/codex/issues/15433) lands (separates project trust state from config), delete `codex/scripts/` and the filter registration.

If `git diff codex/config.toml` ever shows lines like `[projects.…]` reappearing, the filter isn't registered on this clone (check `git config --local --get-all filter.codex-strip.clean`). Re-run `./install` to re-register.

## TODO

- Add a `Brewfile` (macOS) / `apt`/`dnf` bootstrapping (Linux) for one-shot dep install
- Add `git` and `ssh` configs
