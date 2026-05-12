---
name: save-to-dotfiles
description: Use when the user asks to save, persist, or globally apply any
  configuration change — shell aliases / functions / env vars / PATH (zshrc),
  vim settings / mappings / plugins (vimrc), tmux bindings / colours / settings
  (tmux.conf.local), iTerm2 prefs, p10k tweaks, Claude or Codex rules / agents /
  skills / settings / instructions, new dotbot-managed symlinks, or install-time
  hooks. The skill walks three gates (portability / platform / routing), routes
  the edit to the correct ~/dotfiles/ target, considers OS-conditional wrapping,
  and suggests the reload command. Trigger phrases include "сохрани", "запомни",
  "всегда так делай", "добавь в config", "save this globally", "make this
  permanent", "add to my config", "always do X", "add alias", "add binding",
  "add rule".
---

# save-to-dotfiles

Procedural handler for "make this config change permanent across all my
machines" requests. The goal: ask the right clarifying questions, route the
edit to the correct dotfiles target file, and never write to `~/.claude/<X>`
or `~/.codex/<X>` directly.

## Workflow

```
0. Discover what user actually wants → may need clarifying questions
1. Gate 1 — Portability check       → reject if machine-specific
2. Gate 2 — Platform check          → decide OS-conditional wrapping
3. Gate 3 — Routing                 → which file, which section
4. Verify symlink coverage          → .install.conf.yaml has the live path?
5. Edit dotfiles target file        → never the live symlink path
6. Suggest reload command           → so the change takes effect now
7. Show diff + offer commit         → conventional commit message
```

## Step 0 — Discover

User intent can be vague. Before routing, confirm you have:

- The exact config change (the alias, the setting, the rule text)
- Whether it applies on **every** machine or just current one
- Whether it should work on **macOS, Linux, or both**

If anything is unclear, propose 1-3 reasonable approaches with trade-offs and
let the user pick. Don't guess silently.

## Step 1 — Gate 1: Portability

A change is **machine-specific** and should NOT go in dotfiles when it matches
any row below:

| Marker | Right home instead of dotfiles |
|---|---|
| Absolute local path (`/Users/X/projects/...`, `/home/X/...`) | env var, or local file like `~/.zshrc.local` |
| Specific hostname or SSH alias unique to one machine | `~/.ssh/config` (sometimes per-machine) |
| Hardware-specific (display scaling, physical keyboard mapping) | OS-native preferences, not dotfiles |
| Secret / API key / token / password | 1Password, env var, or `~/.config/<tool>/.env` (gitignored) |
| Per-machine auth state (`~/.claude.json`, `~/.codex/auth.json`) | Already gitignored — don't touch |
| Per-machine permissions allowlist (`~/.claude/settings.local.json`) | Stays per-machine, never synced |

If portability fails: **stop**, tell the user, suggest the alternative home,
and don't write to dotfiles. Examples of how to phrase it:

- "This references `/Users/<name>/projects/myrepo` — that path won't exist on
  other machines. Put it in `~/.zshrc.local` instead, which doesn't sync."
- "This is an API token — never commit. Use `op item get …` (1Password) or
  source from a gitignored `.env`."

## Step 2 — Gate 2: Platform

Detect current platform: `uname -s` → `Darwin` (macOS) or `Linux`.

Categorize the change:

| Category | Examples | Wrap pattern |
|---|---|---|
| **Cross-platform** | zsh aliases that don't call OS-specific tools, vim settings, tmux bindings, Claude/Codex behavioural rules | no wrapping needed |
| **macOS-only** | `brew install …`, `defaults write …`, `pbcopy`, `osascript`, iTerm2 plist edits, `/Applications/...` paths | `[ "$(uname -s)" = "Darwin" ] && …` or `case` |
| **Linux-only** | `apt`/`dnf`/`pacman`, `xsel`/`xclip`/`wl-copy`, `/run/user/$UID/...`, `fc-cache` | `[ "$(uname -s)" = "Linux" ] && …` |
| **Conditional on tool availability** | `fnm`, `zoxide`, `code` (VSCode CLI) | `command -v X >/dev/null 2>&1 && …` |
| **Both but divergent** | clipboard tool (pbcopy on Mac, xsel/xclip/wl-copy on Linux) | `case "$(uname -s)" in Darwin) … ;; Linux) … ;; esac` |

If unsure which category the user wants: **ask**. Don't pick silently.

## Step 3 — Gate 3: Routing

Map intent → file → reload:

| Intent | Target file (in `~/dotfiles/`) | Reload after |
|---|---|---|
| Shell alias / function | `zshrc` → `# --- Aliases ---` (alias) or near existing functions (function) | new shell or `exec zsh` |
| Env var | `zshrc` → `# --- Locale ---` (LANG-class) or `# --- Environment ---` or create new section | new shell |
| PATH addition | `zshrc` → `# --- PATH ---` | new shell |
| zsh plugin | `zsh_plugins.txt` (add line; antidote rebuilds on next shell start) | new shell |
| Vim setting / mapping | `vimrc` (matching section) | re-open vim or `:source $MYVIMRC` |
| Vim plugin | `vimrc` inside `call plug#begin … call plug#end`, then `:PlugInstall` | next vim start |
| Tmux setting / binding / colour | `tmux/tmux.conf.local` (NEVER `tmux/oh-my-tmux/`) | `prefix r` in running tmux |
| iTerm2 preference | edit via GUI → `cp ~/Library/Preferences/com.googlecode.iterm2.plist iterm/` ; OR `defaults write com.googlecode.iterm2 <key> <value>` for surgical edits | quit + relaunch iTerm2 |
| p10k tweak (one-line override) | `p10k.zsh` in-place | new shell |
| p10k major theme change | run `p10k configure` (it rewrites `p10k.zsh`) | (done by p10k itself) |
| Claude global rule | `claude/rules/<name>.md` with frontmatter (see below) | next Claude session |
| Claude setting / statusline / plugin enable | `claude/settings.json` | next Claude session |
| Claude custom agent | `claude/agents/<name>/...` | next Claude session |
| Claude custom skill | `claude/skills/<name>/SKILL.md` | next Claude session |
| Codex behavioural rule / global instruction | `codex/AGENTS.md` (inline section) | next Codex session |
| Codex setting (model, reasoning effort, plugin) | `codex/config.toml` | next Codex session |
| Codex skill | `codex/skills/<name>/SKILL.md` (or symlink to a Claude skill) | next Codex session |
| New dotbot-managed symlink | `.install.conf.yaml` `link:` entry + `cd ~/dotfiles && ./install` | symlink active immediately |
| Install-time hook | `.install.conf.yaml` `shell:` entry | next `./install` |

If multiple targets are reasonable (e.g. "make this an alias OR a function?"),
**propose options** with trade-offs.

## Step 4 — Verify symlink coverage

For files NOT at dotfiles root (i.e. inside `claude/`, `codex/`, or new
locations), confirm a `link:` entry exists in `.install.conf.yaml` mapping
the live path to the dotfiles path:

```sh
rg -n '~/.claude|~/.codex' ~/dotfiles/.install.conf.yaml
```

If the target is NOT yet symlinked (a new file type or live path):

1. Create the file at `~/dotfiles/<area>/<new>`.
2. Add a `link:` entry to `.install.conf.yaml`:
   ```yaml
   ~/.claude/<X>:
     path: claude/<X>
     force: true
   ```
3. Run `cd ~/dotfiles && ./install` so the symlink is created.

## Step 5 — Edit the dotfiles target

**Always** edit `~/dotfiles/<path>`, never `~/.claude/<X>` or `~/.codex/<X>`.
Edits via the symlink resolve to the same file but obscure the source of
truth in diffs and reviews.

### Per-area specifics

**zshrc** — pick the matching `# --- xxx ---` section. If a new logical
section, add one with a clear header. Maintain 4-space indent inside any
multi-line constructs.

**Claude rules** — frontmatter is required. Universal rule (every session):

```yaml
---
name: <kebab-name>
description: Universal — <one-line summary>
---
```

Conditional rule (loads only on matching file types):

```yaml
---
name: <kebab-name>
description: <one-line summary>
paths:
  - "**/*.tsx"
  - "**/*.css"
---
```

Ask the user: universal or path-conditional? If conditional, which file globs?

**Codex AGENTS.md additions** — Codex has no `claude/rules/`-style
auto-discovery. Behavioural rules go inline into `codex/AGENTS.md` as a
new section or appended to an existing one. Keep concise — context budget
matters.

**iTerm2 plist** — binary format, can't hand-edit. Either:
- Surgical key edit: `defaults write com.googlecode.iterm2 <Key> -type <value>`
- Multiple changes via GUI: edit prefs → `cp ~/Library/Preferences/com.googlecode.iterm2.plist iterm/`

**`.install.conf.yaml` shell hooks** — **POSIX `sh` only** (runs under
`dash` on Ubuntu). No bashisms: no `[[ ]]`, no arrays, no `${var^^}`, no
`<()`, no `local`. OS-branch with `case "$(uname -s)" in`. Be idempotent —
check state first, print "Already X" when there's nothing to do.

## Step 6 — Reload

Tell the user the exact command to apply the change now (see Step 3 table).
For most cases this is just opening a new shell, but tmux / iTerm2 / etc.
need specific reload commands.

## Step 7 — Commit

Show the diff. Suggest a conventional commit message (see repo conventions
in `~/dotfiles/AGENTS.md` §11):

- `feat:` new feature, `fix:` bug fix, `docs:` docs, `chore:` housekeeping,
  `tweak:` small adjustment, plus area prefixes (`zshrc:`, `tmux:`, `iterm:`,
  `code:`, `install:`) when scoped to one area.
- Short, lowercase, imperative, max 72 chars on summary line.
- No AI attribution.
- Body explains WHY when non-obvious.

Ask before committing — user may want to test the reload first.

## Don'ts

- **Don't edit `~/.claude/<X>` or `~/.codex/<X>` directly.** Always go through
  `~/dotfiles/`. Edits via the symlink resolve to the same file under the hood,
  but obscure the source of truth.
- **Don't edit `tmux/oh-my-tmux/`** — gpakosz submodule, customize via
  `tmux/tmux.conf.local`.
- **Don't edit `.dotbot/`** — anishathalye submodule, upstream only.
- **Don't edit `codex/skills/.system/`** — Codex auto-managed, gitignored.
- **Don't hand-edit `p10k.zsh` for major theme changes.** Run `p10k configure`
  and let it regenerate the file.
- **Don't put bashisms in `.install.conf.yaml` shell hooks.** They run under
  `dash` on Ubuntu.
- **Don't put absolute local paths, hostnames, secrets, or per-machine state
  in dotfiles.** Those break on other machines. Use the alternatives from
  Step 1.
- **Don't write to `~/.claude/settings.local.json`** through dotfiles —
  it's per-machine permission state, gitignored.

## Test the skill mentally

If the user says "сохрани, чтобы в zsh всегда был алиас `ll='ls -la'`":
- **Gate 1**: portable (no path / host / secret). ✓
- **Gate 2**: cross-platform — `ls -la` is the same on macOS and Linux. ✓
- **Gate 3**: target = `zshrc` `# --- Aliases ---` section.
- Edit `~/dotfiles/zshrc`, add `alias ll='ls -la'` under Aliases.
- Reload: `exec zsh` or open new shell.
- Commit: `feat: add ll alias for ls -la`.

If the user says "запомни, что Claude должен всегда писать комменты по-русски":
- **Gate 1**: portable. ✓
- **Gate 2**: cross-platform — applies to any Claude session. ✓
- **Gate 3**: target = `claude/rules/<name>.md` (new file).
  - Ask: universal or path-conditional? Likely universal.
  - Name suggestion: `comments-in-russian` or similar.
- Create `~/dotfiles/claude/rules/comments-in-russian.md` with frontmatter
  (no `paths:` — universal) + Rule / Why / How sections.
- Reload: next Claude session.
- Commit: `feat: add claude rule for Russian comments`.

If the user says "сохрани, что я хочу всегда `brew install <X>` после клона":
- **Gate 1**: portable in intent, but `brew` is macOS-only. ✓
- **Gate 2**: macOS-only → wrap in `case "$(uname -s)" in Darwin) … ;; esac`.
- **Gate 3**: target = `.install.conf.yaml` `shell:` hook.
- Add a new `shell:` entry with `Darwin` branch and idempotent `brew list
  --formula <X> >/dev/null || brew install <X>`.
- Reload: `./install`.
- Commit: `install: auto-install <X> via Homebrew (macOS)`.
