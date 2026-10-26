# Working in this repo — guide for AI agents (Claude Code, OpenAI Codex CLI)

Auto-loaded by both tools when `cwd` is anywhere under the chezmoi source dir (`~/.local/share/chezmoi/`, optionally symlinked as `~/dotfiles/`):
Claude reads `CLAUDE.md` (symlinked to this file); Codex reads `AGENTS.md` directly.
Everything below is **this repo's** conventions; for general behavioural rules
see the global `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md`.

## 1. What this repo is

Personal dotfiles for four machines, managed with [chezmoi](https://www.chezmoi.io/),
and the source of truth for portable **Claude Code** + **OpenAI Codex** configs.

| Machine | OS / arch | Profile |
|---|---|---|
| MacBook | macOS, arm64 | workstation |
| Mac mini | macOS | picked at init |
| Jetson | Ubuntu 22.04 (L4T), arm64, sudo user | dev |
| VPS | Ubuntu, x86_64 | core |

Profiles cascade `core` ⊂ `dev` ⊂ `workstation`, prompted once by `chezmoi init`
and cached in `~/.config/chezmoi/chezmoi.toml`. Bootstrap (README has the
per-OS prerequisites):
```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --use-builtin-git=true vaintrub
```

## 2. Map of the repo

| Path | What it is |
|---|---|
| `dot_zshrc`, `dot_zsh_plugins.txt`, `dot_p10k.zsh` | zsh + antidote + Powerlevel10k |
| `dot_vimrc` | vim + vim-plug |
| `symlink_dot_tmux.conf`, `dot_tmux.conf.local` | tmux: symlink to the oh-my-tmux external (gpakosz's shell-as-config trick needs `$TMUX_CONF` to be his file) + our customizations |
| `dot_gitconfig.tmpl`, `dot_gitignore_global` | git |
| `iterm/com.googlecode.iterm2.plist` | the live iTerm2 plist, XML so it diffs; chezmoi-ignored, read and written by iTerm2 itself (§4) |
| `dot_claude/`, `dot_codex/` | Claude Code and Codex: instructions, rules, skills, settings via `modify_` merges (§9) |
| `.chezmoitemplates/` | partials read through `includeTemplate`: the two merge bases and `ai-common.md`, the body both agents' instruction files share |
| `.chezmoidata/packages.yaml` | OS packages per OS and tier, Claude/Codex plugins, MCP servers |
| `dot_config/mise/config.toml.tmpl` | the cross-platform CLI toolchain (core: fzf, zoxide, jq; dev: the rest) |
| `.chezmoiscripts/` | install scripts (§6) |
| `.chezmoiexternal.toml.tmpl` | SHA-pinned externals: oh-my-tmux, `plug.vim`; macOS fonts (§12) |
| `.chezmoi.toml.tmpl`, `.chezmoiignore`, `.chezmoiversion` | chezmoi metadata: the profile prompt, non-target paths, the minimum chezmoi version (2.73.1, for `shellQuote` without doubled backslashes) |
| `tests/unit/repo-invariants.bats` | source-tree invariants, no apply needed |
| `tests/files/*.bats` | post-apply smoke tests: `common` at every profile, then `core` or `dev` |
| `.github/workflows/ci.yaml` | lint job, then one apply leg per machine class (§7) |
| `AGENTS.md` (this file), `CLAUDE.md` → `AGENTS.md`, `README.md` | docs |

**Never edit these targets; change the pin instead:** `~/.config/tmux/` (bump
the SHA, then `chezmoi apply`) and `~/.vim/autoload/plug.vim` (bump the SHA
and its checksum, never `:PlugUpgrade`: it rewrites a managed file, and the next
non-interactive apply exits 1 on the conflict).

## 3. Source-state naming

| Source attribute | Effect |
|---|---|
| `dot_X` | `.X` in `$HOME` |
| `executable_X` | mode +x |
| `private_X` | 0600 file / 0700 dir |
| `readonly_X` | clears the write bits: 0444 at a 022 umask, not 0400. For 0400 use `private_readonly_X`, in that order — `readonly_private_X` lands a file literally named `private_X` |
| `symlink_X` | a symlink; the file body is the link target |
| `create_X` | written whenever missing; an existing file is never overwritten |
| `modify_X` + `#chezmoi:modify-template` | a template whose `.chezmoi.stdin` is the current target; its output is the new file. Order matters: `modify_private_X`, never `private_modify_X` (a literal file named `modify_X`) |
| `.tmpl` | rendered as a Go template |

Targets worth knowing beyond the obvious `dot_X` ↔ `~/.X`:

| Live | Source | Note |
|---|---|---|
| `~/.zshrc_local` | `create_dot_zshrc_local` | per-machine overrides, sourced after p10k and the SSH tints. chezmoi holds an entry for it: comment lines out, never empty or delete it (an empty file counts as removed: `MD` or `DA`, and a non-interactive apply fails) |
| `~/.gitconfig` | `dot_gitconfig.tmpl` | a template only for the macOS plist driver. delta and the gh credential helper sit behind runtime `command -v` guards. No `core.hooksPath`: it replaces a repo's own hooks instead of adding to them |
| `~/.config/1Password/ssh/agent.toml` | `dot_config/private_1Password/private_ssh/private_agent.toml` | `private_` at every level. Items are matched by item, never by vault |
| `~/.claude/settings.json` | `dot_claude/modify_settings.json` + `.chezmoitemplates/claude-settings-base.json` | §9. No `private_`: Claude writes it 0644 |
| `~/.codex/config.toml` | `dot_codex/modify_private_config.toml` + `.chezmoitemplates/codex-config-base.toml` | §9. `private_`: Codex writes it 0600 |
| `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` | `dot_claude/CLAUDE.md.tmpl`, `dot_codex/AGENTS.md.tmpl` | both `includeTemplate` `ai-common.md` |
| `~/.agents/skills/<name>` | `dot_agents/skills/symlink_<name>` | Codex's user skills dir; directory symlinks into `~/.claude/skills/`. Not `~/.codex/skills` (deprecated) and not file symlinks, which Codex skips. One link per skill: a whole-dir link leaked Codex-installed skills into Claude |

Always edit the source path, never the live target. The source dir is
chezmoi's default `~/.local/share/chezmoi/`; `~/dotfiles` is only a symlink.

## 4. Per-area notes

### zsh
- Section dividers `# --- xxx ---`. Plugins: one line in `dot_zsh_plugins.txt`,
  pinned with `pin:<full SHA>` (`repo-invariants.bats` rejects an unpinned one);
  `antidote load` rebuilds the static file on the next shell. antidote itself is
  an external (§12). No templates: the file is cross-platform through
  `command -v` and `uname`.
- `dot_p10k.zsh` is wizard output, but the wizard rewrites the *target*. For a
  theme change: run `p10k configure`, answer **Quiet** at the instant-prompt
  question (it recommends Verbose), `chezmoi re-add ~/.p10k.zsh`, then put back
  `POWERLEVEL9K_TERM_SHELL_INTEGRATION=true` and both rationale comments —
  `repo-invariants.bats` fails until they are back.
- `code()` and the SSH-agent block carry their rationale inline; read it before
  touching them. The SSH tints are coordinated with tmux (§10).

### vim
- `plug.vim` is an external (§12). At launch `dot_vimrc` installs every `Plug`
  whose directory is missing, so a line added on one machine installs itself
  on the others.

### tmux
- Prefix `C-a`. Never edit `~/.config/tmux/` (re-extracted from the archive);
  ours is `dot_tmux.conf.local`. Reload with `prefix r`.

### iTerm2
- iTerm2 reads and writes `iterm/com.googlecode.iterm2.plist` directly, through
  `PrefsCustomFolder` (set once by `darwin/run_once_after_configure-iterm2`).
  It writes only when told: **Save Now** (Settings → General → Settings), the
  red `(!)` badge, or **Copy** at quit.
- A save rewrites the whole file: commit it alone, as an `iterm:` commit —
  never in a `git commit -a`.
- Quit iTerm2 before `chezmoi update` or a revert that touches the plist: it
  compares against a launch-time snapshot at quit, so **Copy** overwrites what
  git wrote meanwhile.
- `.gitattributes` gives `*.plist` a `plutil` textconv (macOS only, from
  `dot_gitconfig.tmpl`); a no-op while the file is XML.

### Claude Code and Codex
- `dot_claude/rules/*.md` auto-load each session (`paths:` frontmatter narrows
  one to matching files). Skills live in `dot_claude/skills/*/SKILL.md`, shared
  with Codex through the symlinks in §3.
- **Never tracked** (machine-local, some secret): `~/.claude.json` (OAuth
  tokens), `~/.claude/settings.local.json` (which Claude reads only for sessions
  started in `$HOME` itself), `~/.claude/plugins/*.json`,
  `~/.codex/auth.json`, `installation_id`, Codex's sessions/cache/log/sqlite,
  `RTK.md` (written by `rtk init`, `.chezmoiignore`d).

## 5. Saving portable settings

When the user asks to save, persist or globally apply a setting, **run the
`save-to-dotfiles` skill**. It walks three gates — portable to every machine?
which platform? which file? — and routes the edit. Anything with a local path,
hostname, secret or auth state belongs in `~/.zshrc_local`, an env var,
1Password, or `~/.claude/settings.local.json`, not here.

## 6. Scripts and installs

Scripts run in the order of their target names: every root script first (50,
then 70), then `darwin/` and `linux/`. They run after every file is written.

| Script | Does |
|---|---|
| `run_onchange_after_50-packages-darwin` | Homebrew (first run), `brew bundle` from packages.yaml, `mise install` |
| `run_onchange_after_50-packages-linux` | `apt-get install` for the packages dpkg reports missing, mise via mise.run, `mise install` |
| `run_onchange_after_70-install-plugins` | Claude plugins, marketplaces and MCP servers through the CLI; Codex marketplaces; `rtk init` |
| `darwin/run_once_after_configure-iterm2`, `darwin/run_once_after_enable-touchid-sudo` | iTerm2 prefs folder; Touch ID for sudo |
| `linux/run_once_after_chsh` | zsh as login shell |

- **Failure.** Mandatory steps (Homebrew, apt, chsh, Touch ID) exit non-zero:
  the apply stops, chezmoi records nothing, and the next apply retries. Bulk
  steps (`brew bundle`, `mise install`) only warn with a recovery hint, so one
  broken formula or a tool without a build for the box cannot block the rest.
  Script 70 likewise only warns without claude, and its rendered text records
  whether claude's shim exists, so it re-runs on the first apply after mise
  provides it.
- **Re-runs.** `run_onchange_` scripts re-run when their rendered text changes.
  Both 50s embed the mise config's hash, 70 embeds it and the profile, and the
  package lists render inline, so editing a list re-runs the right script. To
  re-run one by hand: `chezmoi state delete --bucket=entryState
  --key="$HOME/.chezmoiscripts/<name>.sh" && chezmoi apply`. `run_onchange_`
  state lives in `entryState`, `run_once_` in `scriptState`. Never delete a
  whole bucket: `entryState` also holds every file's record, and without it an
  apply overwrites local edits without asking.
- **PATH.** chezmoi execs each script fresh. Any script that calls claude,
  codex or rtk must export `~/.local/share/mise/shims` itself
  (`repo-invariants.bats` checks).
- **Adding things:** an OS package → `packages.{darwin,linux}.{core,dev}` or
  `packages.darwin.casks`; a CLI tool → the mise config (inside the dev block
  unless every tier needs it); a Claude plugin, marketplace or MCP server →
  `plugins:` / `mcp:` in packages.yaml; a Codex plugin → `plugins.codex`.
- A new script: POSIX `sh`, idempotent, OS-guarded with
  `{{ if eq .chezmoi.os "darwin" }}`, and prefer `run_onchange_after_`.

## 7. Testing and rolling out

**Testing.** Before pushing a script change: render and lint (§8), then run a
fresh install in a container from the working tree.
- **VPS-like:** amd64, root, core.
- **Jetson-like:** arm64, add a sudo user first, to test the sudo path.
```sh
docker run --rm --platform linux/amd64 -v "$PWD:/src:ro" ubuntu:24.04 sh -c '
  apt-get update -qq && apt-get install -y -qq curl ca-certificates sudo >/dev/null
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
  mkdir -p ~/.local/share && cp -r /src ~/.local/share/chezmoi
  chezmoi init --apply --promptChoice "Install profile=core" && chezmoi status'
```
CI runs the same on `ubuntu-22.04-arm` (dev), `ubuntu-24.04` (core) and
`macos-latest` (dev, no casks), then `tests/files/`.

**Rolling out.**
- A normal change reaches another machine with `chezmoi update`. When
  `.chezmoiversion` rises, run `chezmoi upgrade` first: an older chezmoi
  refuses every source-state command, `init` included.
- A change to `.chezmoi.toml.tmpl` reaches it only through a re-init. Use
  `chezmoi git pull && chezmoi init && chezmoi apply`: `chezmoi update --init`
  applies in the same process with the *old* config, which breaks whenever the
  old config points at something the pull removed.
- The first apply on a fresh box needs a terminal (sudo prompts) and a second
  apply to converge what `rtk init` writes into `settings.json`.

## 8. Shell conventions

| File | Dialect |
|---|---|
| `dot_zshrc`, `dot_p10k.zsh` | zsh 5+ (not linted) |
| `.chezmoiscripts/**/*.sh.tmpl`, `dot_claude/executable_statusline-command.sh` | POSIX `sh` — must run under dash |
| `dot_claude/modify_settings.json`, `dot_codex/modify_private_config.toml` | Go template |

- 4-space indent; `"$var"` always, except deliberate word splitting;
  `[ "$x" = y ]`; `command -v foo >/dev/null 2>&1`, never `which`.
- **Lint** a script template by rendering it first — shellcheck dies on `{{`:
  ```sh
  set -o pipefail
  chezmoi execute-template --source . < f.sh.tmpl | shellcheck -x -s sh -
  ```
  `-s sh` because an OS-guarded script renders empty on the other OS;
  `pipefail` or a render failure passes silently; `--override-data
  '{"chezmoi":{"os":"linux"}}'` for the other OS. CI runs this for every
  script × both OSes × three profiles.

## 9. Tool-written config: the two `modify_` merges

Codex and Claude Code both rewrite their own config files, so each is a
`modify_` template that pulls its curated base from `.chezmoitemplates/`.

**Codex.** `dot_codex/modify_private_config.toml` parses the live file,
`mergeOverwrite`s `codex-config-base.toml` on top (the base wins for the keys
it declares) and serialises with `toToml`. Everything else Codex writes passes
through: trust rows, marketplaces, `[tui.*]`, `[notice]`, `[features]` and the
rest. That state never reaches git — apply writes only the target, and
`chezmoi re-add` skips a `modify_` entry — except through
`chezmoi add ~/.codex/config.toml`, which deletes the template and writes the
live file, trust rows included, into the source — one commit away from a
public repo. Never run it; edit the base.
`model` and `model_reasoning_effort` stay out of the base: Codex writes both
from its TUI.

After any Codex session `chezmoi status` shows `MM .codex/config.toml` for
good (Codex's key order and quoting never equal `toToml`'s). It is not drift.
`czs` (in `dot_zshrc`) is `chezmoi status` without that line.

**Claude Code.** `dot_claude/modify_settings.json` merges in two steps so the
base stays authoritative for its keys while tool-written keys (rtk's hook,
iTerm2's integration) survive; see the header comment. The CLI and iTerm2
reorder the file, so compare an `MM` on it with `jq -S` before calling it
drift.

`enabledPlugins` is a union: script 70 installs every missing `plugins.claude`
entry, the base enables it, and a value already in the live file wins — a plugin
disabled with `claude plugin disable -s user` stays off (except across a tag
bump of its third-party marketplace, whose re-pin reinstalls it enabled). The
base's `permissions.deny` is merged the same way, as a union. So the list is an
install baseline, not enable state. Codex is the opposite: `plugins.codex`
entries are re-enabled on every apply. Retiring a Claude plugin takes three
steps on each machine: drop the line, `claude plugin uninstall <plugin>`, and
delete its `enabledPlugins` entry from `~/.claude/settings.json`. For a
third-party marketplace, `claude plugin marketplace remove <name>` does all of
it in one step (plugins, `enabledPlugins`, the marketplace record).

Third-party marketplaces are entries `<name>:<owner>/<repo>#<tag>` in
`plugins.claude_marketplaces`; the tag is required (the template fails
without it). They are pinned to a tag —
Claude Code refuses a commit — because their code runs inside the agent
(caveman's hooks fire every session). To bump one, read the diff between the
tags (`plugin.json` hooks, commands' `allowed-tools`, skills), then change the
tag. Script 70 sees the recorded ref differ, removes the marketplace (which
uninstalls its plugins), re-adds it at the new tag and reinstalls. Never run
caveman's `/caveman-init`: it pipes unpinned code from that repo's `main` into
node.

## 10. Visual coordination — SSH cues

| Cue | Source | Colour |
|---|---|---|
| p10k prompt `❯` | `dot_zshrc`, SSH branch | orange 208 `#ff8700` |
| tmux bar background | `dot_zshrc`, same branch (`tmux_conf_theme_*`) | dark amber `#5f2f00` |
| p10k context under SSH | `dot_p10k.zsh` | peach 180 `#d7af87` |

Keep the ~30° hue family. The amber must keep gpakosz's grey `#8a8a8a` icons
at WCAG AA-Large (3.21:1). The tmux overrides live in `dot_zshrc` because
gpakosz reads `tmux_conf_*` from the environment before the server starts.

## 11. Git commit conventions (this repo)

- Prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `tweak:`, `revert:`, an area
  (`tmux:`, `iterm:`, `zshrc:`, `vim:`, `git:`, `chezmoi:`, `claude:`, `codex:`,
  `ci:`), or a type with a scope (`fix(zshrc):`).
- Short, lowercase, imperative, ≤ 72 chars; the body explains why.
- No AI attribution. New commits, not amends. Stage paths explicitly
  (`git add <paths>`), never `git commit -a` — the iTerm2 plist is often dirty.
- Branches: kebab-case with `feature/`, `fix/`, `docs/`, `chore/`.

## 12. Externals and the complexity rule

| External | Pin | Customize via |
|---|---|---|
| `~/.config/tmux/` (gpakosz/.tmux) | commit SHA in the URL | `dot_tmux.conf.local` |
| `~/.vim/autoload/plug.vim` (junegunn/vim-plug) | commit SHA in the URL | the `plug#begin … plug#end` block |
| `~/.antidote/` (mattmc3/antidote) | commit SHA in the URL | `dot_zsh_plugins.txt`, each bundle `pin:`-ned |
| `~/Library/Fonts/` MesloLGS NF ×4, Monaspace Neon ×4 (macOS) | MesloLGS by commit SHA, Monaspace by release tag; both checksummed | — (iTerm2 uses MesloLGS, VS Code Monaspace) |

plug.vim and the fonts carry `checksum.sha256`: bump the URL and the sum
together. The tmux archive has none, since GitHub doesn't keep archive bytes
stable.

No git submodules; externals replace them.

**Complexity rule.** This repo once spent more lines on setup machinery than
on settings, and most of its fixes went to that machinery. Before adding a
script, guard, test or template branch, name the machine in §1 that needs it.
Prefer deleting a component to guarding it, and fix a bug by removing its
cause before adding a check for it.
