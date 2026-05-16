---
name: save-to-dotfiles
description: Use when the user asks to save, persist, or globally apply any
  configuration change — shell aliases / functions / env vars / PATH (zshrc),
  vim settings / mappings / plugins (vimrc), tmux bindings / colours / settings
  (tmux.conf.local), iTerm2 prefs, p10k tweaks, Claude or Codex rules / agents /
  skills / settings / instructions, new chezmoi-managed dotfiles, install-time
  hooks. The skill walks three gates (portability / platform / routing), routes
  the edit to the correct path in the chezmoi source dir, considers
  OS-conditional wrapping, and suggests the reload command. Trigger phrases
  include "сохрани", "запомни", "всегда так делай", "добавь в config",
  "save this globally", "make this permanent", "add to my config",
  "always do X", "add alias", "add binding", "add rule".
---

# save-to-dotfiles

Procedural handler for "make this config change permanent across all my
machines" requests. The dotfiles repo is managed by **chezmoi**; the source
dir lives at `~/.local/share/chezmoi/` by default (`chezmoi cd` to navigate
there). Source files use the `dot_X` naming convention; `chezmoi apply`
materializes them into `$HOME`.

## Workflow

```
0. Discover what user actually wants → may need clarifying questions
1. Gate 1 — Portability check       → reject if machine-specific
2. Gate 2 — Platform check          → decide OS-conditional wrapping
3. Gate 3 — Routing                 → which source file, which section
4. Edit dotfiles source path        → never the live $HOME path
5. chezmoi apply (preview with diff first)
6. Suggest reload command           → so the change takes effect now
7. Show diff + offer commit         → conventional commit message
```

## Step 0 — Discover

User intent can be vague. Before routing, confirm:

- The exact config change (the alias, the setting, the rule text)
- Whether it applies on **every** machine or just current one
- Whether it should work on **macOS, Linux, or both**

If anything is unclear, propose 1-3 reasonable approaches with trade-offs and
let the user pick. Don't guess silently.

## Step 1 — Gate 1: Portability

A change is **machine-specific** and should NOT go in dotfiles when:

| Marker | Right home instead of dotfiles |
|---|---|
| Absolute local path (`/Users/X/projects/...`, `/home/X/...`) | env var, or local file like `~/.zshrc.local` |
| Specific hostname or SSH alias unique to one machine | `~/.ssh/config` (sometimes per-machine) |
| Hardware-specific (display scaling, physical keyboard mapping) | OS-native preferences, not dotfiles |
| Secret / API key / token / password | 1Password, env var, or `~/.config/<tool>/.env` (gitignored) |
| Per-machine auth state (`~/.claude.json`, `~/.codex/auth.json`) | Already gitignored — don't touch |
| Per-machine permissions allowlist (`~/.claude/settings.local.json`) | Stays per-machine; chezmoi can manage as `private_` but typically left local |

If portability fails: **stop**, tell user, suggest the alternative home, don't
write to dotfiles.

## Step 2 — Gate 2: Platform

Detect current platform: `uname -s` → `Darwin` (macOS) or `Linux`.

| Category | Examples | How to wrap |
|---|---|---|
| **Cross-platform** | zsh aliases, vim settings, tmux bindings, Claude/Codex rules | no wrapping; if a CLI may be missing on some machines, use runtime `command -v X` checks |
| **macOS-only** | `brew install …`, `defaults write …`, `pbcopy`, `osascript`, iTerm2 plist | shell file: `case "$(uname -s)" in Darwin) … ;; esac`. For `.chezmoiscripts/*.sh.tmpl`: `{{ if eq .chezmoi.os "darwin" }} … {{ end }}` |
| **Linux-only** | `apt`/`dnf`, `xsel`/`xclip`/`wl-copy`, `/run/user/$UID/...` | analogous: `linux` |
| **Conditional on tool availability** | `mise`, `zoxide`, `code` | `command -v X >/dev/null 2>&1 && …` |

If unsure: ask. Don't pick silently.

## Step 3 — Gate 3: Routing

Map intent → source file (in the chezmoi source dir; `chezmoi cd` to navigate) → reload command:

| Intent | Source path | Reload after |
|---|---|---|
| Shell alias / function | `dot_zshrc` → `# --- Aliases ---` section (alias) or near existing functions | new shell or `exec zsh` |
| Env var | `dot_zshrc` → `# --- Locale ---` (LANG-class) or create a new `# --- xxx ---` section | new shell |
| PATH addition | `dot_zshrc` → `# --- PATH ---` | new shell |
| zsh plugin | `dot_zsh_plugins.txt` (antidote rebuilds cache on next shell start) | new shell |
| Vim setting / mapping | `dot_vimrc` (matching section) | re-open vim or `:source $MYVIMRC` |
| Vim plugin | `dot_vimrc` inside `call plug#begin … call plug#end`, then `:PlugInstall` | next vim start |
| Tmux setting / binding / colour | `dot_tmux.conf.local` (NEVER `~/.config/tmux/.tmux.conf` — that's the external) | `prefix r` in running tmux |
| iTerm2 preference (simple) | `defaults write com.googlecode.iterm2 <key> <value>` — iTerm2 reads/writes directly from `<chezmoi-source>/iterm/` via `PrefsCustomFolder` | quit + relaunch iTerm2 |
| iTerm2 preference (complex GUI) | edit via GUI → iTerm2 writes directly to `<chezmoi-source>/iterm/com.googlecode.iterm2.plist` → check `git status` after `chezmoi cd` | quit + relaunch iTerm2 |
| p10k tweak (one-line override) | `dot_p10k.zsh` in-place | new shell |
| p10k major theme change | run `p10k configure` (rewrites `dot_p10k.zsh`) | (done by p10k itself) |
| Brew formula or cask (Mac) / apt/dnf package (Linux) | `.chezmoidata/packages.yaml` under `common.brews` / `darwin.casks` / `linux.{apt,dnf}` | `chezmoi apply` runs install-packages script |
| Claude global rule | `dot_claude/rules/<name>.md` with frontmatter | next Claude session |
| Claude setting / statusline / plugin enable | `.chezmoitemplates/claude-settings-base.json` (curated base; `dot_claude/modify_settings.json.tmpl` merges tool-added keys) | next Claude session |
| Claude custom agent | `dot_claude/agents/<name>/...` | next Claude session |
| Claude custom skill | `dot_claude/skills/<name>/SKILL.md` | next Claude session |
| Codex behavioural rule | `dot_codex/AGENTS.md` (inline section) | next Codex session |
| Codex setting (model, plugin) | `.chezmoitemplates/codex-config-base.toml` (`dot_codex/modify_config.toml` merges) | next Codex session |
| Codex skill | `dot_claude/skills/<name>/SKILL.md` — `~/.codex/skills` is a symlink to `~/.claude/skills`, so both tools see it | next Codex session |
| New file to manage (new `~/.<X>` to track) | `chezmoi add ~/.<X>` (copies live → `dot_<X>` in source) | already applied |
| New install-time hook | `.chezmoiscripts/run_<once_before|onchange_after|once_after>_<name>.sh.tmpl` | next `chezmoi apply` |
| New external (vendored archive/repo) | `.chezmoiexternal.toml.tmpl` entry | `chezmoi apply -R` (force refresh) |

If multiple targets are reasonable (e.g. "make this an alias OR a function?"),
**propose options** with trade-offs.

## Step 4 — Edit the source

**Always** edit the chezmoi source, never `~/.claude/<X>` etc. directly.
Two equivalent flows:

- `chezmoi edit ~/.zshrc` — opens `dot_zshrc` in `$EDITOR` (chezmoi knows the mapping)
- `chezmoi cd` then `$EDITOR dot_zshrc` — open a subshell in the source dir for direct multi-file editing

### Per-area specifics

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

Ask user: universal or path-conditional? If conditional, which file globs?

**Codex AGENTS.md additions** — Codex has no `dot_claude/rules/`-style
auto-discovery. Behavioural rules go inline into `dot_codex/AGENTS.md`.

**Tool-mutated files** (`~/.claude/settings.json`, `~/.codex/config.toml`):
- Edit the **base** file in `.chezmoitemplates/`:
  `claude-settings-base.json` / `codex-config-base.toml`
- The `modify_` script loads the base via `includeTemplate` and merges
  base + existing-with-tool-keys on each apply
- DO NOT edit `~/.claude/settings.json` directly in `$HOME` — your edit
  becomes "tool-added", merged but not authoritative. To make a permanent
  change, edit the base.

**`.chezmoiscripts/*.sh.tmpl`** — **POSIX `sh` only** (templates render to `sh`
scripts; we keep them dash-compatible). No bashisms: no `[[ ]]`, no arrays,
no `${var^^}`, no `<()`, no `local`. OS-branch via `{{ if eq .chezmoi.os "darwin" }}`
TEMPLATE directive. Be idempotent.

## Step 5 — Apply

```sh
chezmoi diff       # preview
chezmoi apply      # commit to $HOME
```

For a single target: `chezmoi apply ~/.zshrc`.

## Step 6 — Reload

Tell the user the exact command to apply the change now (see Step 3 table).
For most cases this is just opening a new shell; tmux / iTerm2 / etc. need
specific reload commands.

## Step 7 — Commit

Show the diff. Suggest a conventional commit message (see repo conventions
in `AGENTS.md` §11 at the source-dir root):

- `feat:` new feature, `fix:` bug fix, `docs:` docs, `chore:` housekeeping,
  `tweak:` small adjustment, plus area prefixes (`zshrc:`, `tmux:`, `iterm:`,
  `code:`, `chezmoi:`) when scoped to one area.
- Short, lowercase, imperative, max 72 chars on summary line.
- No AI attribution.
- Body explains WHY when non-obvious.

Ask before committing — user may want to test the reload first.

## Don'ts

- **Don't edit `~/.claude/<X>` or `~/.codex/<X>` directly.** Edit the source
  via `chezmoi cd` then `dot_claude/<X>` / `dot_codex/<X>`. Exception:
  tool-managed mutations (rtk init writing hook entries, claude plugin
  install) — those land in target and our `modify_` scripts preserve them
  on apply.
- **Don't edit `~/.config/tmux/`** — it's auto-extracted from the chezmoi
  external (gpakosz/.tmux archive). Customize via `dot_tmux.conf.local`.
- **Don't hand-edit `dot_p10k.zsh` for major theme changes.** Run `p10k configure`
  and let it regenerate the file.
- **Don't put bashisms in `.chezmoiscripts/*.sh.tmpl` scripts.** They render
  to POSIX `sh` (dash-compatible on Ubuntu).
- **Don't put absolute local paths, hostnames, secrets, or per-machine state
  in dotfiles.** Those break on other machines. Use the alternatives from
  Step 1.
- **Don't write to `~/.claude/settings.local.json`** through chezmoi —
  it's per-machine permission state, gitignored.
- **Don't look for the base files in `$HOME`** — they live in source at
  `.chezmoitemplates/{claude-settings-base.json,codex-config-base.toml}`
  and are automatically excluded from apply (chezmoi's canonical location
  for template partials).

## Test the skill mentally

**If user says "сохрани, чтобы в zsh всегда был алиас `ll='ls -la'`":**
- **Gate 1**: portable ✓
- **Gate 2**: cross-platform — `ls -la` works on Mac and Linux ✓
- **Gate 3**: target = `dot_zshrc` `# --- Aliases ---` section
- `chezmoi cd && $EDITOR dot_zshrc`, add `alias ll='ls -la'`
- `chezmoi apply ~/.zshrc` → reload: `exec zsh`
- Commit: `feat: add ll alias for ls -la`

**If user says "запомни, что Claude должен всегда писать комменты по-русски":**
- **Gate 1**: portable ✓
- **Gate 2**: cross-platform ✓
- **Gate 3**: target = `dot_claude/rules/<name>.md` (new file)
  - Ask: universal or path-conditional? Likely universal
  - Name: `comments-in-russian`
- Create with universal frontmatter + Rule / Why / How sections
- `chezmoi apply` → reload: next Claude session
- Commit: `feat: add claude rule for Russian comments`

**If user says "сохрани, что я хочу всегда `brew install <X>` после клона":**
- **Gate 1**: portable in intent (per-package, no path/host) ✓
- **Gate 2**: cross-platform via `.chezmoidata/packages.yaml`. If `<X>` exists
  on both Mac and Linux, add to `common.brews` (Mac via brew) + `linux.apt`
  and `linux.dnf` (Linux distro names may differ — e.g. `fd` → `fd-find`).
  If Mac GUI app, add to `darwin.casks`.
- **Gate 3**: target = `.chezmoidata/packages.yaml` under the right subkey.
- Edit, `chezmoi apply` → `run_onchange_after_50-install-packages.sh.tmpl`
  re-runs (script content embeds YAML, hash changed) and brew bundle / apt /
  dnf install the new package idempotently.
- Commit: `feat(packages): add <X>`
