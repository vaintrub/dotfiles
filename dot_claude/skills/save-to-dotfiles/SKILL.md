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
there). Source files use the `dot_<X>` naming convention; `chezmoi apply`
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
| Absolute local path (`/Users/X/projects/...`, `/home/X/...`) | env var, or `~/.zshrc_local` (per-machine, edited in place — see Don'ts) |
| Specific hostname or SSH alias unique to one machine | `~/.ssh/config` (sometimes per-machine) |
| Hardware-specific (display scaling, physical keyboard mapping) | OS-native preferences, not dotfiles |
| Secret / API key / token / password | 1Password, env var, or `~/.config/<tool>/.env` (unmanaged — never `chezmoi add` it) |
| Per-machine auth state (`~/.claude.json`, `~/.codex/auth.json`) | Unmanaged — don't touch, never `chezmoi add` |
| Per-machine permissions allowlist (`~/.claude/settings.local.json`) | Never tracked; edit it in place. Claude reads it only for sessions started in `$HOME` |

If portability fails: **stop**, tell user, suggest the alternative home, don't
write to dotfiles.

## Step 2 — Gate 2: Platform

Detect current platform: `uname -s` → `Darwin` (macOS) or `Linux`.

| Category | Examples | How to wrap |
|---|---|---|
| **Cross-platform** | zsh aliases, vim settings, tmux bindings, Claude/Codex rules | no wrapping; if a CLI may be missing on some machines, use runtime `command -v X` checks |
| **macOS-only** | `brew install …`, `defaults write …`, `pbcopy`, `osascript`, iTerm2 plist | shell file: `case "$(uname -s)" in Darwin) … ;; esac`. For `.chezmoiscripts/*.sh.tmpl`: `{{ if eq .chezmoi.os "darwin" }} … {{ end }}` |
| **Linux-only** | `apt`, `/run/user/$UID/...` | analogous: `linux` |
| **Conditional on tool availability** | `mise`, `zoxide`, `code` | `command -v X >/dev/null 2>&1 && …` |

If unsure: ask. Don't pick silently.

## Step 3 — Gate 3: Routing

Map intent → source file (in the chezmoi source dir; `chezmoi cd` to navigate) → reload command:

| Intent | Source path | Reload after |
|---|---|---|
| Shell alias / function | `dot_zshrc` → `# --- Aliases ---` section (alias) or near existing functions | new shell or `exec zsh` |
| Env var | `dot_zshrc` → `# --- Locale ---` (LANG-class) or create a new `# --- xxx ---` section | new shell |
| PATH addition | `dot_zshrc` → `# --- PATH ---` | new shell |
| zsh plugin | `dot_zsh_plugins.txt`, one line ending in `pin:<full 40-char SHA>` (the repo's current HEAD unless asked otherwise; an unpinned line fails `repo-invariants.bats`). `antidote load` rebuilds the cache on the next shell | new shell |
| Vim setting / mapping | `dot_vimrc` (matching section) | re-open vim or `:source $MYVIMRC` |
| Vim plugin | `dot_vimrc` inside `call plug#begin … call plug#end`, then `:PlugInstall` | next vim start |
| Tmux setting / binding / colour | `dot_tmux.conf.local` (NEVER `~/.config/tmux/.tmux.conf` — that's the external) | `prefix r` in running tmux |
| iTerm2 preference | change it in iTerm2's GUI, then make iTerm2 write `iterm/com.googlecode.iterm2.plist` (it reads and writes there via `PrefsCustomFolder`; auto-save is off): **Save Now** in Settings → General → Settings, the red `(!)` badge, or **Copy** at quit. Never `defaults write com.googlecode.iterm2 …` — that writes `~/Library/Preferences/`, a different store that never reaches git. A save rewrites the whole file: commit it alone as `iterm:`. | quit + relaunch iTerm2 |
| p10k tweak (one-line override) | `dot_p10k.zsh` in-place | new shell |
| p10k major theme change | run `p10k configure` (answer **Quiet** at the instant-prompt question) — it rewrites the live `~/.p10k.zsh`, not the source — then `chezmoi re-add ~/.p10k.zsh`, put back `POWERLEVEL9K_TERM_SHELL_INTEGRATION=true` and both rationale comments (`repo-invariants.bats` fails until they are back), commit | new shell |
| Brew formula or cask (Mac) / apt package (Linux) | `.chezmoidata/packages.yaml` under `packages.{darwin,linux}.{core,dev}` (tier cascade core ⊂ dev ⊂ workstation) or `packages.darwin.casks` (workstation only) | `chezmoi apply` re-runs that OS's packages script |
| Claude global rule | `dot_claude/rules/<name>.md` with frontmatter | next Claude session |
| Claude setting / statusline | `.chezmoitemplates/claude-settings-base.json` (curated base; `dot_claude/modify_settings.json` merges tool-added keys) | next Claude session |
| Claude or Codex plugin | `.chezmoidata/packages.yaml` → `plugins.claude` / `plugins.codex`, plus `plugins.claude_marketplaces` (entries `<name>:<owner>/<repo>#<tag>`, tag required — see `AGENTS.md` §9) / `plugins.codex_marketplaces` (plain source) for a new marketplace. An install baseline, not enable state: a Claude plugin disabled on a machine stays disabled, while Codex re-enables listed plugins on every apply. Removing a line uninstalls nothing — retiring a Claude plugin is the three-step procedure in `AGENTS.md` §9 | `chezmoi apply` (script 70 re-runs for a Claude change; a Codex change lands through the config merge), then next session |
| MCP server (keyless remote only) | `.chezmoidata/packages.yaml` → `mcp:` (`name` + `url`); reaches both agents — Claude via `claude mcp add` in script 70, Codex via `.chezmoitemplates/codex-config-base.toml`. A server that needs an API key fails Gate 1: `<agent> mcp add` by hand on each machine | `chezmoi apply`, then next session |
| Claude custom agent | `dot_claude/agents/<name>.md` (directory doesn't exist yet — create it) | next Claude session |
| Claude custom skill | `dot_claude/skills/<name>/SKILL.md` | next Claude session |
| Rule for BOTH agents (git, stack, style, workflow) | `.chezmoitemplates/ai-common.md` — included by `dot_claude/CLAUDE.md.tmpl` and `dot_codex/AGENTS.md.tmpl` | next session of either |
| Codex-only behavioural rule | `dot_codex/AGENTS.md.tmpl` (inline, outside the shared include) | next Codex session |
| Codex setting (never `model` / `model_reasoning_effort` — Codex owns those from its TUI) | `.chezmoitemplates/codex-config-base.toml` (`dot_codex/modify_private_config.toml` merges) | next Codex session |
| Codex skill | `dot_claude/skills/<name>/SKILL.md` PLUS `dot_agents/skills/symlink_<name>` whose body is `../../.claude/skills/<name>` — a directory symlink in Codex's user skills dir `~/.agents/skills`; Codex skips file symlinks | next Codex session |
| New file to manage (new `~/.<X>` to track) | `chezmoi add ~/.<X>` (copies live → `dot_<X>` in source) | already applied |
| New install script | `.chezmoiscripts/run_onchange_after_<name>.sh.tmpl` (or `run_once_after_`), POSIX sh, OS-guarded — but first name the machine that needs it (`AGENTS.md` §12) | next `chezmoi apply` |
| New external (vendored archive/repo) | `.chezmoiexternal.toml.tmpl` entry, pinned by SHA or tag in the URL, with `checksum.sha256` for single files | `chezmoi apply` |

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
auto-discovery. A rule that should reach BOTH agents goes in
`.chezmoitemplates/ai-common.md`, which both instruction files include.
Codex-only wording goes inline into `dot_codex/AGENTS.md.tmpl`, outside the
include. Never edit the rendered `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md`.

**New skills come in pairs.** A skill is only usable by both agents if it has
BOTH files, and `tests/unit/repo-invariants.bats` fails if they drift:

```sh
dot_claude/skills/<name>/SKILL.md                 # the skill itself
dot_agents/skills/symlink_<name>                  # body, verbatim, one line:
                                                  # ../../.claude/skills/<name>
```

Then `git add` both and confirm with `git status` that neither is ignored — a
tracked symlink pointing at an untracked SKILL.md materializes as a dangling
`~/.agents/skills/<name>` on every other machine.

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
  `tweak:` small adjustment, an area prefix when scoped to one area (`zshrc:`,
  `tmux:`, `iterm:`, `vim:`, `git:`, `chezmoi:`, `claude:`, `codex:`, `ci:`),
  or a type with a scope (`fix(zshrc):`) — the list in `AGENTS.md` §11.
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
  (answer **Quiet** at the instant-prompt question), which rewrites the target
  `~/.p10k.zsh`, then `chezmoi re-add ~/.p10k.zsh` to bring it into source and
  restore the hand-written lines it drops (`AGENTS.md` §4). Skip the re-add and
  the next apply reverts the wizard.
- **Don't put bashisms in `.chezmoiscripts/*.sh.tmpl` scripts.** They render
  to POSIX `sh` (dash-compatible on Ubuntu).
- **Don't put absolute local paths, hostnames, secrets, or per-machine state
  in dotfiles.** Those break on other machines. Use the alternatives from
  Step 1.
- **Don't write to `~/.claude/settings.local.json`** through chezmoi —
  it's per-machine permission state, never tracked.
- **`~/.zshrc_local` is the one target you edit in place.** It is `create_`:
  written when missing, never overwritten, so edits never show in
  `chezmoi status`. To undo an override, comment lines out. Don't empty or
  delete the file: chezmoi treats an empty file as removed, shows `MD`/`DA`, and
  the next non-interactive apply stops on it.
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
- **Gate 2**: cross-platform via `.chezmoidata/packages.yaml`. Pick the tier
  first (`core` = every machine, `dev` = CLI toolchain, casks = workstation).
  If `<X>` exists on both Mac and Linux, add it to `packages.darwin.<tier>`
  and `packages.linux.<tier>` (apt names may differ — e.g. `fd` →
  `fd-find`). A Mac GUI app goes in `packages.darwin.casks`. Prefer mise
  (`dot_config/mise/config.toml.tmpl`) for anything with a registry entry.
- **Gate 3**: target = `.chezmoidata/packages.yaml` under the right subkey.
- Edit, `chezmoi apply` → that OS's `run_onchange_after_50-packages-*` script
  re-runs (the list renders into it) and brew bundle / apt install the new
  package idempotently.
- Commit: `feat: add <X> to packages`
