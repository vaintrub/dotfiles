# Working in this repo — guide for AI agents (Claude Code, OpenAI Codex CLI)

Auto-loaded by both tools when `cwd` is anywhere under the chezmoi source dir (`~/.local/share/chezmoi/`, optionally symlinked as `~/dotfiles/`):
Claude reads `CLAUDE.md` (symlinked to this file); Codex reads `AGENTS.md` directly.
Everything below is **this repo's** conventions; for general behavioural rules
see the global `~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md`.

## 1. What this repo is

Personal cross-platform (macOS + Linux) dotfiles managed with
[chezmoi](https://www.chezmoi.io/). It is also the source of truth for portable
**Claude Code** + **OpenAI Codex** configs. Single source of truth, single
`chezmoi apply` / `chezmoi update`, identical state on every device.

Bootstrap on a new machine:
```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply vaintrub
```

## 2. Map of the repo

### Editable (user owns — change freely)

| Path | What it is |
|---|---|
| `dot_zshrc`, `dot_zsh_plugins.txt`, `dot_p10k.zsh` | zsh + antidote + Powerlevel10k |
| `dot_vimrc` | vim + vim-plug |
| `symlink_dot_tmux.conf`, `dot_tmux.conf.local` | tmux: symlink to oh-my-tmux external (so gpakosz's shell-as-config trick works) + our customizations |
| `iterm/com.googlecode.iterm2.plist` | real iTerm2 binary plist (chezmoi-ignored). iTerm2 reads + writes here directly via `PrefsCustomFolder` (set by run_once_after script) |
| `dot_claude/` | Claude Code: instructions, settings (modify_), statusline, agents, skills, rules |
| `dot_codex/` | Codex CLI: AGENTS.md, config.toml (modify_), shared skills (symlink) |
| `.chezmoidata/packages.yaml` | single source of truth for all packages (Mac brews/casks, Linux apt/dnf/npm), Claude/Codex plugin lists, AND MCP servers (`mcp:` — one list, into both agents: Claude via `claude mcp add` in 70, Codex declaratively in `codex-config-base.toml`; keyless remote only) |
| `.chezmoiscripts/` | install hooks (run_once_after_*, run_onchange_after_*). Per-OS subdirs: `darwin/`, `linux/`. Numerical prefix (50/70/99) controls ordering — 50 installs packages (+ mise tools + post-installs from lib), 70 installs Claude+Codex plugins + registers Claude MCP servers (Codex MCP is declarative in its config base), 99 prints first-apply hint |
| `hooks/` | hook scripts registered in `.chezmoi.toml.tmpl`. `ensure-prereqs.sh` runs BEFORE source-state read on every apply, installing minimum tools (git/zsh/vim/tmux/curl + brew on Mac) |
| `.chezmoitemplates/` | shared template partials (base configs read by `modify_` scripts via `includeTemplate`, not applied to $HOME) |
| `lib/` | shell libraries sourced by `.chezmoiscripts/*` wrappers via `{{ .chezmoi.sourceDir }}/lib/X.sh`. Pure POSIX `sh`, no template syntax. Chezmoi-ignored so it never deploys to $HOME — also makes the libraries `source`-able by bats unit tests with mocked externals. |
| `tests/files/*.bats` | post-apply asserts (CI: dotfile presence, tool functionality, content sanity). Profile-tagged (`common.bats` covers `core` tier today). |
| `tests/unit/*.bats` | function-level unit tests on `lib/*.sh`. Source the lib with `INSTALL_PACKAGES_INVOKE` unset so `main` doesn't auto-run, then mock externals (`sudo`/`apt-get`/`mise`/`id`) to drive each function's branches. |
| `.github/workflows/ci.yaml` | GitHub Actions: `unit` job (bats `tests/unit/`) → `apply-core` job (chezmoi apply in devcontainer + bats `tests/files/`). Triggers on push (master, chore/**, feat/**, fix/**, docs/**) + PRs. |
| `.chezmoiversion`, `.chezmoiremove.tmpl` | chezmoi-native metadata: minimum-version pin + deprecation-tracking list |
| `.chezmoi*.{toml.tmpl,ignore,external.toml.tmpl}` | chezmoi metadata (templated) |
| `README.md`, `LICENSE` | docs / license |
| `AGENTS.md` (this file), `CLAUDE.md` → `AGENTS.md` (symlink) | repo-level AI guide |

### Vendored / managed (don't edit directly)

| Path | Source | How to influence it |
|---|---|---|
| `~/.config/tmux/` | gpakosz/.tmux archive, pinned by commit SHA in `.chezmoiexternal.toml.tmpl` | bump SHA → `chezmoi apply -R` → commit |
| `dot_claude/skills/.system/` | Codex's built-in skills (written through the codex→claude skills symlink); `.gitignore`d | Codex auto-manages |
| `~/.cache/chezmoi/` | chezmoi external cache (outside repo) | chezmoi-managed |

## 3. Source-state naming (chezmoi conventions)

The mapping from source file name to live `$HOME` path is mechanical and chezmoi-defined:

| Source attribute | Effect |
|---|---|
| `dot_X` | becomes `.X` in target ($HOME) |
| `executable_X` | mode +x |
| `private_X` | mode 0600 (or 0700 dir) |
| `readonly_X` | mode 0400 |
| `symlink_X` | becomes a symbolic link; file content = link target string |
| `modify_X` | runs as a script: stdin = existing file content, stdout = new file content |
| `modify_X` + `#chezmoi:modify-template` annotation | template; `.chezmoi.stdin` = existing; output = new content |
| `.tmpl` suffix | file rendered as Go template before use |
| `.chezmoiscripts/run_*` | scripts that don't create `$HOME` files (bootstrap, install hooks) |

Live ↔ source mapping for our key paths:

| Live ($HOME) | Source (this repo) | Pattern |
|---|---|---|
| `~/.zshrc` | `dot_zshrc` | plain |
| `~/.zsh_plugins.txt` | `dot_zsh_plugins.txt` | plain (antidote static-cache input) |
| `~/.zshrc_local` | `create_dot_zshrc_local` | `create_`: seeded ONCE at first apply with commented stub, then never overwritten. Per-machine override file (sourced last by `~/.zshrc`). |
| `~/.vimrc` | `dot_vimrc` | plain |
| `~/.p10k.zsh` | `dot_p10k.zsh` | plain (generated by `p10k configure`) |
| `~/.tmux.conf` | `symlink_dot_tmux.conf` (body: `.config/tmux/.tmux.conf`) | symlink (gpakosz's shell-as-config trick requires `$TMUX_CONF` to point at gpakosz's file, not a 1-liner wrapper) |
| `~/.tmux.conf.local` | `dot_tmux.conf.local` | plain |
| `~/.gitconfig` | `dot_gitconfig.tmpl` | Go template (renders `[user]` block conditionally; `[core] hooksPath` for gitleaks; `[delta]` + `[credential]` blocks iff delta / gh on PATH at apply time). The `[credential]` block reclaims what `gh auth login` would otherwise write with an absolute gh path that rots on every mise upgrade. |
| `~/.gitignore_global` | `dot_gitignore_global` | plain (referenced by `core.excludesFile` in dot_gitconfig.tmpl; OS junk + editor backups) |
| (no `~/.Brewfile`) | `.chezmoidata/packages.yaml` | rendered inline by install-packages script and piped to `brew bundle --file=/dev/stdin` |
| `~/.claude/CLAUDE.md` | `dot_claude/CLAUDE.md` | plain |
| `~/.claude/settings.json` | `dot_claude/modify_settings.json` + `.chezmoitemplates/claude-settings-base.json` | modify_ jq merge |
| `~/.claude/statusline-command.sh` | `dot_claude/executable_statusline-command.sh` | plain +x |
| `~/.claude/rules/*.md` | `dot_claude/rules/*.md` | plain |
| `~/.claude/skills/save-to-dotfiles/SKILL.md` | `dot_claude/skills/save-to-dotfiles/SKILL.md` | plain |
| `~/.claude/skills/advanced-go/SKILL.md` | `dot_claude/skills/advanced-go/SKILL.md` | plain (pedantic Go reviewer/writer skill; needs an `!` allowlist entry in `.gitignore`) |
| `~/.claude/skills/advanced-typescript/SKILL.md` | `dot_claude/skills/advanced-typescript/SKILL.md` | plain (pedantic TS reviewer/writer skill; needs an `!` allowlist entry in `.gitignore`) |
| `~/.codex/AGENTS.md` | `dot_codex/AGENTS.md.tmpl` | Go template (renders `@{{ .chezmoi.homeDir }}/.codex/RTK.md` to absolute path) |
| `~/.codex/config.toml` | `dot_codex/modify_config.toml` + `.chezmoitemplates/codex-config-base.toml` | modify-template (fromToml / toToml) |
| `~/.codex/skills/save-to-dotfiles/SKILL.md` | `dot_codex/skills/save-to-dotfiles/symlink_SKILL.md` (body: `../../../.claude/skills/save-to-dotfiles/SKILL.md`) | file-level symlink to Claude's copy (one of the chezmoi-managed shared skills) |
| `~/.codex/skills/advanced-go/SKILL.md` | `dot_codex/skills/advanced-go/symlink_SKILL.md` (body: `../../../.claude/skills/advanced-go/SKILL.md`) | file-level symlink to Claude's copy |
| `~/.codex/skills/advanced-typescript/SKILL.md` | `dot_codex/skills/advanced-typescript/symlink_SKILL.md` (body: `../../../.claude/skills/advanced-typescript/SKILL.md`) | file-level symlink to Claude's copy |
| iTerm2 plist | `iterm/com.googlecode.iterm2.plist` (source root, chezmoi-ignored) | iTerm2 reads + writes directly via `PrefsCustomFolder` setting (no chezmoi-managed symlink) |
| `~/.config/tmux/` | `.chezmoiexternal.toml.tmpl` | archive external |
| `~/.config/mise/config.toml` | `dot_config/mise/config.toml.tmpl` | Go template (profile-aware: core tier = fzf+zoxide only; dev/workstation = full toolchain) |
| `~/.config/git/hooks/pre-push` | `dot_config/git/hooks/executable_pre-push` | plain +x. Wired globally via `core.hooksPath = ~/.config/git/hooks` in `dot_gitconfig.tmpl`. Runs `gitleaks git --log-opts=<remote..local>` against outbound commits; fails-open when `gitleaks` not on PATH (core-profile machines without dev toolchain). Per-repo opt-out: `git config --local core.hooksPath ''`. |
| `~/Library/Fonts/MesloLGS NF *.ttf` + `MonaspaceNeon-*.otf` (Mac) or `~/.local/share/fonts/...` (Linux) | `.chezmoiexternal.toml.tmpl` | externals (4 MesloLGS NF files + 4 Monaspace Neon via archive-file from the static release zip; headless-skip) |

**Always edit the source path**, never the live target — the diff stays in source, ready to commit.

Source-of-truth location is `~/.local/share/chezmoi/` — chezmoi's default (XDG_DATA_HOME compliant). No `sourceDir` override in `~/.config/chezmoi/chezmoi.toml`. On my Mac there is a back-compat symlink `~/dotfiles → ~/.local/share/chezmoi/` for muscle memory; not required.

## 4. Per-area conventions

### zsh — `dot_zshrc` / `dot_zsh_plugins.txt` / `dot_p10k.zsh`

- **Section dividers**: `# --- xxx ---`. Each logical section gets its own header.
- **Plugins**: managed by [antidote](https://github.com/mattmc3/antidote) in
  static-cache mode. Add a line to `dot_zsh_plugins.txt`; cache rebuilds on
  next shell start.
- **`dot_p10k.zsh`** is GENERATED by `p10k configure` — don't hand-edit for
  major theme changes. One-line `POWERLEVEL9K_*` overrides in-place are fine.
- **`code()` function** is non-trivial — see comment block in `dot_zshrc` for
  VSCode Remote-SSH IPC-socket sweep and URL-fallback rationale.
- **SSH visual tints** at the bottom of `dot_zshrc` are **coordinated with
  `dot_tmux.conf.local` palette**. See §10.
- **Cross-platform via runtime feature detection** (`command -v X`,
  `case "$(uname -s)"` inside the file). chezmoi templates not used here —
  the file applies as-is on Mac and Linux.

### vim — `dot_vimrc`

- **vim-plug bootstrap** at the top auto-installs on first launch.
- **Plugins** inside the `call plug#begin … call plug#end` block; run
  `:PlugInstall` in vim after adding.
- Comments in English.

### tmux — `dot_tmux.conf` + `dot_tmux.conf.local`

- **`dot_tmux.conf`** is a 1-liner: `source-file ~/.config/tmux/.tmux.conf`.
  That target file comes from the **chezmoi external** (gpakosz/.tmux archive,
  SHA-pinned in `.chezmoiexternal.toml.tmpl`).
- **`dot_tmux.conf.local`** is OUR customization layer (sources after the
  upstream one per oh-my-tmux convention).
- **NEVER edit `~/.config/tmux/.tmux.conf`** directly — it's auto-extracted
  from the upstream archive and re-extracted on every `chezmoi apply -R`.
- Bump cycle: pick newer commit SHA from gpakosz/.tmux, edit URL in
  `.chezmoiexternal.toml.tmpl`, `chezmoi apply -R`, commit.
- Prefix is `C-a` (screen-style), `C-b` unbound.
- Reload after change: `prefix r` in a running tmux session.

### iTerm2 — `iterm/com.googlecode.iterm2.plist`

- **Binary plist**, do NOT hand-edit. Edit via iTerm2 GUI → preferences
  written directly into `~/.local/share/chezmoi/iterm/com.googlecode.iterm2.plist`
  → `git status` (in source) shows the dirty plist for review.
- The path `iterm/` at source root is INTENTIONALLY outside `dot_*` so chezmoi
  doesn't try to apply it (it's in `.chezmoiignore`). iTerm2 reads + writes
  here directly via `PrefsCustomFolder` setting.
- **No symlink in `~/.config/iterm/`** — that would clash visually with
  iTerm2's own `~/.config/iterm2/` (AppSupport + sockets dir).
  `PrefsCustomFolder` is set to `<sourceDir>/iterm/` (renders to
  `/Users/vaintrub/.local/share/chezmoi/iterm/` on this machine), so iTerm2
  operates directly on the source-tracked binary.
- `PrefsCustomFolder` is set on first apply by
  `.chezmoiscripts/darwin/run_once_after_configure-iterm2.sh.tmpl`.
- Reload: quit and relaunch iTerm2 (answer "Don't Save" only if you don't want
  your live edits persisted to source).

### Claude Code — `dot_claude/`

- See **§5 Three gates** for "save this globally" intents.
- `dot_claude/rules/*.md` are auto-loaded by Claude every session. Optional
  `paths:` glob in frontmatter makes a rule load only when matching files
  are open.
- `dot_claude/skills/*/SKILL.md` are discoverable skills, intent-matched via
  the frontmatter `description` field.
- **`dot_claude/modify_settings.json`** uses jq-additive merge to preserve
  keys added by `rtk init`, `claude plugin install`, etc. See §9.
- The curated base lives at `.chezmoitemplates/claude-settings-base.json`
  (canonical chezmoi location for files read by templates but not applied);
  loaded via `includeTemplate "claude-settings-base.json" .`.

### Codex — `dot_codex/`

- `dot_codex/AGENTS.md` is Codex's global instructions (analogue of CLAUDE.md).
- **`dot_codex/modify_config.toml`** uses chezmoi-native `fromToml` / `toToml`
  via `#chezmoi:modify-template` annotation. See §9.
- The curated base lives at `.chezmoitemplates/codex-config-base.toml`
  (canonical chezmoi location); loaded via
  `includeTemplate "codex-config-base.toml" .`.
- `dot_codex/skills/save-to-dotfiles/symlink_SKILL.md` makes the
  `save-to-dotfiles` skill visible to Codex via a FILE-level symlink to
  Claude's copy at `~/.claude/skills/save-to-dotfiles/SKILL.md`. The
  `~/.codex/skills/` directory is otherwise its own dir (NOT a dir-level
  symlink to `~/.claude/skills/`) — earlier dir-symlink design caused
  cross-contamination (skills installed for Codex leaked into Claude's
  scan path → duplicate registrations). Caveman uses Claude's plugin
  install for its Claude side; Codex side is manual (`npx skills add ...
  -a codex` doesn't currently wire per-agent symlinks).

### Claude/Codex — NOT tracked (machine-local; some are secrets — never commit)

Only user-curated config is tracked. These stay out of the repo:

- `~/.claude/settings.local.json` — per-machine permissions allowlist (Anthropic's documented convention is to gitignore it).
- `~/.claude/plugins/{installed_plugins,known_marketplaces}.json` — absolute install paths + per-user marketplace registrations.
- **`~/.claude.json`** — lives at `$HOME`, not `~/.claude/`. Holds OAuth tokens, MCP server credentials, NUX `tipsHistory`. **Never commit.**
- `~/.codex/auth.json`, `installation_id` — secrets + per-machine identifiers.
- `~/.codex/{sessions,cache,log,tmp,history.jsonl,*.sqlite}`, `memories/`, `plugins/` — runtime state / cloned plugin repos.
- `~/.claude/RTK.md`, `~/.codex/RTK.md` — written fresh by `rtk init` (bundled rtk version's content, not ours). `.chezmoiignore`d.

We also deliberately don't manage `~/.claude/commands/` (deprecated by skills upstream) or `~/.claude/hooks/` (not a Claude dir convention — hooks live inline in `settings.json`).

### Bootstrap scripts — `.chezmoiscripts/`

Scripts here don't create `$HOME` files (no `dot_*` sibling). They run as part
of `chezmoi apply`:

- **`run_once_before_*`** — run ONCE per machine, BEFORE file ops. Used for
  hard prereq checks (zsh/vim/tmux), brew install (Mac).
- **`run_onchange_after_*`** — run AFTER all file ops, only when script
  contents change (chezmoi tracks hash). Used for the package installer
  (`50-install-packages`, which also handles mise install + post-install
  funcs like `rtk init` from the lib) and plugin install (`70-install-plugins`).
- **`run_once_after_*`** — run ONCE per machine, AFTER file ops. Used for
  iTerm2 `defaults write PrefsCustomFolder`.

All scripts are templates (`.tmpl`) — OS branching via `{{ if eq .chezmoi.os "darwin" }}`,
runtime feature detection via `command -v X`, etc.

Distro dispatch keys off `.osid` — a composite key derived once in
`.chezmoi.toml.tmpl` from `.chezmoi.os` + `.chezmoi.osRelease.id`:

- `darwin`
- `linux-ubuntu`, `linux-debian`, `linux-fedora`, `linux-pop`, ...

Use as `{{ if eq .osid "linux-ubuntu" "linux-debian" }}` or via a
predicate function in `lib/install-packages.sh::is_debian_family`.
Fall back to `.chezmoi.osRelease.idLike` for derivatives that don't
match the canonical `id` list (Pop!_OS, Mint, Raspbian).

### Bootstrap script split — thin wrapper + `lib/`

The install script (`run_onchange_after_50-install-packages.sh.tmpl`) is
intentionally a thin wrapper (~30 LOC) that:

1. Renders chezmoi facts (profile, osid, osRelease.idLike, every package
   list from `.chezmoidata/packages.yaml`) into `DOTFILES_*` env vars.
2. Sets `INSTALL_PACKAGES_INVOKE=1` and sources
   `{{ .chezmoi.sourceDir }}/lib/install-packages.sh`.

GitHub auth for mise's backend installs is NOT handled here — mise
authenticates itself via `github.credential_command = "gh auth token"`,
rendered into `~/.config/mise/config.toml` when `gh` is on PATH (see
`dot_config/mise/config.toml.tmpl`). Pre-exported `GITHUB_TOKEN` env still
wins; this also covers interactive `mise upgrade`/`install`, not just apply.

Secret-handling architecture (three layers, three mechanisms):

| Concern | Mechanism | Where |
|---|---|---|
| Install-time | mise `github.credential_command = "gh auth token"` + recovery warning if rate-limited | mise config + `mise_install_tools()` |
| Render-time | chezmoi-native `onepasswordRead` via `.chezmoidata/secrets.yaml` `op_refs:` catalog | per-file `private_dot_<X>.tmpl` |
| Runtime CLI | 1Password Shell Plugins (`op plugin init <cli>`) | user-managed, per-CLI |

The library is pure POSIX `sh` with no template syntax — bats unit tests
under `tests/unit/install-packages.bats` `source` it (with the invoke
flag unset so `main` doesn't auto-run) and exercise each function with
mocked `sudo`/`apt-get`/`mise`/`id`. Pattern: shunk031/dotfiles
(https://github.com/shunk031/dotfiles) testable-dotfiles convention.

When adding a new install script that has non-trivial logic, follow the
same split: wrapper renders env, library implements the logic, bats tests
the library.

## 5. Saving portable settings — three gates

When the user asks to **save**, **persist**, or **globally apply** any
configuration change, **run the `save-to-dotfiles` skill** — it walks
through three gates in order, then edits the right file.

The gates, in summary:

### Gate 1 — Portability
*Is this actually meant to apply on every machine?* If it references an
absolute local path, a specific hostname, hardware-specific behaviour,
secrets / tokens, or per-machine auth state — it's **not** for dotfiles.
Suggest a local alternative: `~/.zshrc.local`, an env var, 1Password,
or per-machine `~/.claude/settings.local.json`.

### Gate 2 — Platform
*Cross-platform, macOS-only, or Linux-only?* For shell hooks, wrap macOS-only
logic with `{{ if eq .chezmoi.os "darwin" }}`; Linux-only with `"linux"`;
conditional on tool availability with `command -v X >/dev/null 2>&1`.
If unsure, ask the user explicitly.

### Gate 3 — Routing
*Which file does this belong in?* Use the skill's routing table (alias →
`dot_zshrc`, vim setting → `dot_vimrc`, tmux binding → `dot_tmux.conf.local`,
Claude rule → `dot_claude/rules/<name>.md`, etc.). When multiple targets
are reasonable, propose options, don't guess.

Full procedure including taxonometers and routing table lives in the skill
body: see `dot_claude/skills/save-to-dotfiles/SKILL.md`.

## 6. chezmoi workflow

### Modifying an existing managed file

```sh
chezmoi edit ~/.zshrc        # opens dot_zshrc in $EDITOR; chezmoi knows the mapping
# or:
chezmoi cd                   # opens subshell in source dir (~/.local/share/chezmoi/)
$EDITOR dot_zshrc            # direct edit of source
chezmoi diff                 # preview what would change in $HOME
chezmoi apply                # write changes to $HOME
```

Then commit (still inside the `chezmoi cd` subshell):
```sh
git commit -am '...'
git push
exit                          # leave the chezmoi-cd subshell
```

### Adding a NEW managed file

```sh
chezmoi add ~/.foo            # copy live file → dot_foo in source
chezmoi cd                    # opens shell in source dir
$EDITOR dot_foo               # customize
chezmoi apply                 # write back to $HOME
```

### Adding an install-time hook

1. Create file in `.chezmoiscripts/run_<when>_<name>.sh.tmpl`. Prefix:
   - `run_once_before_` — runs once per machine, before file ops
   - `run_onchange_after_` — runs when content hash changes, after file ops
   - `run_once_after_` — runs once per machine, after file ops
2. POSIX `sh` only (template renders, then runs).
3. OS-branch via `{{ if eq .chezmoi.os "darwin" }}` template directive.
4. Be idempotent — check before mutating, print "Already X" when done.

### Bumping the oh-my-tmux external

```sh
# 1. Find newer SHA: https://github.com/gpakosz/.tmux/commits/master
# 2. Edit .chezmoiexternal.toml.tmpl — replace SHA in URL
# 3. Force refresh + apply:
chezmoi apply -R
# 4. Commit
chezmoi cd && git commit -am 'tmux: bump oh-my-tmux to <SHA>' && exit
```

## 7. Cross-platform conventions

### Hard prerequisites
`git`, `zsh`, `vim`, `tmux`, `curl`. Installed automatically by
`hooks/ensure-prereqs.sh` (registered as `hooks.read-source-state.pre`
in `.chezmoi.toml.tmpl`) on every apply — runs apt/dnf on Linux, brew on Mac.
Hook skips with a warning if non-interactive (sudo prompt would block).

### Soft prerequisites (per-feature, skip with reason if missing)
`brew` on Mac + `mise` cross-platform (both installed by the prereqs hook);
`claude`, `codex`, `code`, `zoxide` — installed by
`run_onchange_after_50-install-packages.sh.tmpl` from `.chezmoidata/packages.yaml`.
Each is guarded with `command -v` in scripts + zshrc — missing → feature skips,
not a hard fail. `mise` then materializes the toolchain per
`dot_config/mise/config.toml.tmpl` (profile-aware: `core` = fzf+zoxide only;
`dev`/`workstation` = full set: Go/Python/Node/Rust + 29 aqua binaries + op (vfox) + rtk (github) + goimports (go) + ssh-audit (pipx)).

### Headless SSH detection (for things like font install)
```sh
[ -n "$SSH_CONNECTION" ] && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]
```

### OS branching pattern in .tmpl files
```
{{ if eq .chezmoi.os "darwin" -}}
  # macOS-only block
{{- else if eq .chezmoi.os "linux" -}}
  # Linux-only block
{{- end }}
```

## 8. Shell conventions

### Dialect by file

| File | Dialect | Notes |
|---|---|---|
| `dot_zshrc`, `dot_p10k.zsh` | **zsh 5+** | Full zsh syntax: `zsocket`, glob qualifiers `(Nom)`, `typeset`, `[[ ]]`, `${var:A}` |
| `.chezmoiscripts/*.sh.tmpl` | **POSIX `sh`** | No bashisms — must work in `dash`. Templates render to `sh` scripts. |
| `dot_claude/executable_statusline-command.sh` | **POSIX `sh`** | `#!/bin/sh`, `jq` allowed (standard here) |
| `dot_claude/modify_settings.json` | **Go template** | `#chezmoi:modify-template` annotation → fromJson/mergeOverwrite/toPrettyJson. `private_` → target mode 0600 (matches rtk init's write mode + secret-ish content). |
| `dot_codex/modify_config.toml` | **Go template** | `#chezmoi:modify-template` annotation, uses chezmoi `fromToml`/`toToml`/`mergeOverwrite` |

### Lint
- `shellcheck` for shell scripts in `.chezmoiscripts/` and `dot_claude/`
- `shellcheck` doesn't support zsh — `dot_zshrc` / `dot_p10k.zsh` not linted

### Style
- **Indent**: 4 spaces
- **Quote variables**: `"$var"` always. Exception: intentional glob expansion.
- **Tests**: `[ "$x" = "y" ]` (POSIX) — never `[ $x == $y ]`
- **Feature detection**: `command -v foo >/dev/null 2>&1`, never `which`
- **Idempotency**: check state first, print "Already X" when there's nothing to do

## 9. Codex runtime-section strip (via chezmoi `modify_`)

Codex auto-writes several sections into `~/.codex/config.toml` after every
session: `[projects."<path>"]` (trust state), `[notice]` (UI dismissals),
`[tui.*]` (theme + NUX counters), `[tool_suggest]` (disabled tools),
top-level `windows_wsl_setup_acknowledged`.

These are per-machine runtime state — we don't sync them across machines.
`dot_codex/modify_config.toml` handles this: on every `chezmoi apply`,
the existing target file is piped in, runtime sections are dropped via
chezmoi's `fromToml` / `unset` template functions, our curated base from
`.chezmoitemplates/codex-config-base.toml` is `mergeOverwrite`-ed on top,
then serialized back via `toToml`. Idempotent — applies don't grow the file.

The annotation `#chezmoi:modify-template` at the top of the file tells
chezmoi to render it as a Go template (not run as a script) and exposes
the existing target file's contents as `.chezmoi.stdin`.

When the **`ConfigEdit` enum** in
[`codex-rs/core/src/config/edit.rs`](https://github.com/openai/codex/tree/main/codex-rs/core/src/config/edit.rs)
gains a new runtime section variant, add it to the `unset` chain in
`dot_codex/modify_config.toml`.

`dot_claude/modify_settings.json` does the analogous thing for Claude
Code, but via shell + jq (instead of pure Go template) — Claude's
`settings.json` is JSON, easier to merge with jq's `*` deep-merge operator.
Both modify_ scripts pull their base from `.chezmoitemplates/` via
`includeTemplate`.

## 10. Visual coordination — SSH cues

Three coordinated signals so I can't type into the wrong machine by accident:

| Cue | Source | Colour | Hex |
|---|---|---|---|
| p10k prompt `❯` | `dot_zshrc` line ~136 | orange 208 | `#ff8700` |
| tmux bar background | `dot_zshrc` lines ~149-151 | dark amber | `#5f2f00` |
| p10k REMOTE context segment | `dot_p10k.zsh` | peach 180 | `#d7af87` |

All three share ~30° hue (orange / amber / peach). When changing any of them,
**preserve the hue family**. The dark amber for tmux bg must keep gpakosz's
grey `#8a8a8a` icons at WCAG AA-Large (3.21:1) — don't darken further without
checking contrast.

The tmux overrides live in `dot_zshrc` (not `dot_tmux.conf.local`) because
gpakosz's `_apply_theme` reads `tmux_conf_*` via `printenv` — values must
be in the env **before** the tmux server starts.

## 11. Git commit conventions (this repo)

Observed prefixes (in `git log`):

| Prefix | Meaning |
|---|---|
| `feat:` | new feature |
| `fix:` | bug fix |
| `docs:` | docs / comments / README |
| `chore:` | housekeeping (whitespace, deps, license) |
| `tweak:` | small adjustment to existing feature |
| `revert:` | undo a previous change |
| area-prefixed (`tmux:`, `iterm:`, `code:`, `chezmoi:`, `zshrc:`) | when the change is scoped to one area |

Rules:
- **Short, lowercase, imperative** — max 72 chars on summary line
- **No AI attribution** (`Co-Authored-By: Claude` / `Codex` etc.)
- **NEW commits**, not amends, unless explicitly requested
- **Body explains WHY** when non-obvious
- **Branch names**: kebab-case, prefix `feature/`, `fix/`, `docs/`, `chore/`

## 12. Externals (replacing submodules)

| External | Source | Pin | Customize via |
|---|---|---|---|
| `~/.config/tmux/` | gpakosz/.tmux archive | commit SHA in URL | `dot_tmux.conf.local` (our file) |

`.chezmoiexternal.toml.tmpl`:
```toml
[".config/tmux"]
    type = "archive"
    url = "https://github.com/gpakosz/.tmux/archive/<sha>.tar.gz"
    exact = true
    stripComponents = 1
    refreshPeriod = "720h"
```

**Never edit `~/.config/tmux/` contents directly** — re-extracted from the
archive on every `chezmoi apply -R`. Customizations go in our own
`dot_tmux.conf.local` (sources after the upstream one per oh-my-tmux
convention).

No git submodules in this repo — chezmoi externals replace them. No
`.gitmodules` file, no `git submodule update --init` step needed for new
clones.
