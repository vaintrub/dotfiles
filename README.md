# Dotfiles

Personal cross-platform (macOS + Linux) dotfiles managed with [chezmoi](https://www.chezmoi.io/).

Includes:
- **zsh** with [antidote](https://github.com/mattmc3/antidote) (static-cache) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) — `~/.p10k.zsh` tracked in the repo so the prompt is byte-identical everywhere
- **vim** with [vim-plug](https://github.com/junegunn/vim-plug) (auto-bootstrapped on first launch)
- **tmux** with [gpakosz/.tmux](https://github.com/gpakosz/.tmux) ("oh-my-tmux") vendored as a chezmoi external (pinned by commit SHA)
- **iTerm2** preferences (macOS only, auto-configured to load from the repo)
- **AI tooling** (Claude Code + OpenAI Codex CLI) — global instructions, settings, rules, AGENTS.md, with tool-mutation-safe merging via `modify_` scripts
- **mise** (cross-platform) — declarative dev-tool list (4 language toolchains: Go/Python/Node/Rust, plus 29 aqua binaries + `op` (vfox) + `rtk` (github) + `goimports` (go) + `ssh-audit` (pipx) — `claude-code` and `codex` install as native binaries via aqua) in `dot_config/mise/config.toml.tmpl`, tier-aware so `core`-profile machines only pull what dotfiles need
- **3-tier install profiles** — `core` (dotfile baseline) / `dev` (+ CLI toolchain) / `workstation` (+ GUI apps per OS); always prompted on init with detected-env hint
- **rtk** auto-installed via mise; `rtk init` runs as a post-install step wiring Claude Code + Codex hooks

## Install

### macOS

Supported: Intel + Apple Silicon, macOS recent versions.

One command:

```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply vaintrub
```

That's it. `chezmoi init` prompts you for profile (`core` / `dev` / `workstation` — default `core` for safety; pick `workstation` for full Mac install with casks). `hooks/ensure-prereqs.sh` (registered via `hooks.read-source-state.pre`) installs Xcode CLT + Homebrew + mise on first run. Then `run_onchange_after_50-install-packages.sh.tmpl` reads `.chezmoidata/packages.yaml`, `brew bundle`s `packages.dev.brews` (htop, tree, nmap, libpq, wireguard-tools — OS-native C-deps only, no formula in mise registry) + `packages.gui.mac_casks` if `workstation` (iterm2, docker-desktop, vscode, ngrok, 1password desktop, fonts), then runs `mise install` for the full dev toolchain — including `op`, `rtk`, `claude-code`, and `codex` as cross-platform native binaries. The only post-install step is `rtk init` (Claude+Codex hooks); `goimports` (`go:` backend) and `ssh-audit` (`pipx:` backend) install as part of the mise toolchain. Plugins + caveman install automatically afterward.

The repo lands at chezmoi's default source location: `~/.local/share/chezmoi/`. No `--source` flag, no install.sh, no convention overrides — `chezmoi cd` and `chezmoi edit` work seamlessly without per-machine setup.

After the first apply, **quit iTerm2 once and relaunch** (choose "Don't Save" if prompted) — iTerm2 reads its prefs at startup.

### Linux (Debian / Ubuntu / Fedora)

Supported: Debian 12+, Ubuntu 22.04+, Fedora 40+. Not supported: Alpine, Arch (the install-packages script's distro branch prints an explicit "unsupported, install manually" message in that case).

Bootstrap — install just enough to run chezmoi:

```sh
sudo apt install -y git curl sudo                    # Debian/Ubuntu
# or
sudo dnf install -y git curl sudo                    # Fedora
```

Then the canonical one-liner:

```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply vaintrub
```

The repo lands at `~/.local/share/chezmoi/` (chezmoi's default source location). `chezmoi init` ALWAYS prompts for profile (Codespaces / non-interactive runs fall back to `core` via `--promptDefaults`). From there chezmoi takes over:

1. `hooks/ensure-prereqs.sh` apt/dnf installs `git zsh vim tmux curl ca-certificates` if not present + curl-pipes mise into `~/.local/bin/` (runs BEFORE chezmoi reads source state).
2. `run_onchange_after_50-install-packages.sh.tmpl` runs tier-cascade via `lib/install-packages.sh`: (a) `apt-get`/`dnf install` core packages always; if `dev`, also dev packages; (b) `mise install` from `~/.config/mise/config.toml` — at `core` just fzf+zoxide, at `dev` the full toolchain (which now includes `op`, `rtk`, `claude-code` and `codex` as native binaries via mise's aqua/github/vfox backends); (c) `dev`-only post-install: `rtk init -g` for Claude+Codex hooks (`goimports` and `ssh-audit` now install in step b via mise's `go:`/`pipx:` backends).
3. `70-install-plugins` registers Claude Code + Codex plugins listed in `packages.yaml` (caveman included — installed via canonical `claude plugin install caveman@caveman`, no bespoke installer).
4. `linux/run_once_after_install-fonts.sh.tmpl` runs `fc-cache` after MesloLGS NF + Monaspace fonts are downloaded by `.chezmoiexternal.toml.tmpl`. Skipped on headless boxes (SSH with no `$DISPLAY`/`$WAYLAND_DISPLAY`).
5. `linux/run_once_after_chsh.sh.tmpl` sets `zsh` as your login shell. Skipped if `chsh` would block on non-interactive password prompt.

## Install profile

`chezmoi init` ALWAYS prompts for the install profile (no silent auto-decision). It detects the environment and shows it as a HINT in the prompt; you pick explicitly. The default is `core` (safe fallback for CI / non-interactive runs / accidental enter). Value cached in `~/.config/chezmoi/chezmoi.toml [data].profile`. Three tiers, use-case-driven:

| Profile | What you get | Use case |
|---|---|---|
| `core` | OS-native baseline (`zsh`, `vim`, `tmux`, `git`, `curl`, `ca-certificates`; Linux only: `ufw`, `tcpdump`) + MesloLGS NF + Monaspace Neon fonts + `mise` + `fzf` + `zoxide`. ~50 MB total. | Hetzner VPS, DigitalOcean droplet, jetson over SSH first-touch, Codespace, recovery. |
| `dev` | core + CLI dev toolchain: 4 language toolchains (Go/Python/Node/Rust) + 27 dev-tier aqua binaries (kubectl/helm/k9s/kustomize/stern/argocd/opentofu/awscli/rclone/jq/gh/delta/fd/yq/shellcheck/buf/golangci-lint/goreleaser/gotestsum/protoc-gen-go/pnpm/uv/cloudflared/websocat/gitleaks/claude-code/codex) + `op` (vfox) + `rtk` (github). Linux apt: `htop`, `tree`, `wget`, `nmap`, `telnet`, `wireguard-tools`, `postgresql-client`, `build-essential`, `xsel`/`wl-clipboard` (docker not installed — pick distro repo or `workstation` Docker Desktop). Mac brews (only tools without mise registry entry): `htop`, `tree`, `wget`, `nmap`, `telnet`, `libpq`, `wireguard-tools`. Also via mise: `goimports` (`go:`) + `ssh-audit` (`pipx:`). Post-install: `rtk init`. ~1.9 GB first apply. | Headless dev box (jetson, Linux VM, VPS for real work, Mac SSH'd into headless). |
| `workstation` | dev + GUI apps. Mac: casks (`iterm2`, `docker-desktop`, `visual-studio-code`, `ngrok`, `font-meslo-lg-nerd-font`, `font-monaspace`). Linux: placeholder (empty for now — populate when I run a Linux desktop). | Primary GUI machine (Mac laptop, Linux desktop). |

**Hint format in prompt**: `Install profile [detected env: workstation (GUI=true, SSH=false, ephemeral=false)] — you pick (core/dev/workstation, default core)?`. Detected env helps you pick; doesn't pre-select.

**To change later**: edit `[data].profile` in `~/.config/chezmoi/chezmoi.toml` directly (value: `"core"`, `"dev"`, or `"workstation"`), then `chezmoi apply`. The install script's rendered output changes → `run_onchange` re-fires automatically. The mise config (`~/.config/mise/config.toml`) also re-renders profile-aware: switching to `core` removes language toolchains from mise; switching to `dev` or `workstation` adds them.

**To force re-prompt**: `chezmoi init --prompt`.

**Mac firewall (ufw equivalent)**: not managed by dotfiles. Enable manually via
System Settings → Network → Firewall. Linux core tier installs `ufw` (disabled
by default — `sudo ufw enable` to activate).

## First-time bootstrap checklist

For a fresh machine (Mac or Linux), step-by-step:

```sh
# 1. Bootstrap one-liner — installs chezmoi, clones source, runs apply.
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply vaintrub

# 2. At the prompt, pick your profile (default core; pick workstation on
#    Mac laptop, dev on jetson / Linux server, core elsewhere).

# 3. After apply finishes, reload your shell so mise shims land on PATH:
exec zsh

# 4. Verify the install:
mise ls                         # all rows should be without "(missing)"
chezmoi diff                    # should be empty
```

If step 4 shows any `(missing)` rows OR command-not-found errors, the
anonymous GitHub API rate limit was likely exhausted mid-install. Jump to
the Recovery section below.

## Recovery (broken / partial first apply)

```sh
# Anonymous GitHub rate-limit ran out → some mise tools missing.
# Pick one (see §"1Password integration → Install-time" for full options):
gh auth login                   # cache token (mise then auto-uses it via credential_command)
chezmoi apply                   # picks up token, retries missing tools idempotently

# mise shims out of date / new tools not yet symlinked:
mise reshim
exec zsh

# `chezmoi.toml` cache has stale keys (old `personal`/`headless`):
chezmoi init --promptDefaults   # rewrites from current template
chezmoi apply

# Touch ID for sudo accidentally rolled back by a macOS major update:
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply                   # re-runs run_once_after_* scripts (incl. pam_tid)
```

## Per-machine override (skip heavy tools on a small VPS)

Drop a `~/.config/mise/config.local.toml` (untracked, never overwritten) to
override specific tools per machine:

```toml
[tools]
# Skip Rust on a 2 GB VPS — no need for ~300 MB toolchain.
rust = "skip"
# Use older Python on this box (mise resolves to latest 3.11.x).
python = "3.11"
# Don't install gh on a box where you only need kubectl + jq.
"aqua:cli/cli" = "skip"
```

`mise` merges `config.toml` (chezmoi-managed) and `config.local.toml` (user-
owned) at runtime — local wins on key conflicts. After editing, `mise install`
to apply.

## 1Password integration

Three distinct secret-handling concerns; each uses its own mechanism.

### Install-time (e.g. `GITHUB_TOKEN` for mise rate limit)

No prereq normally required — anonymous 60/hr GH API limit usually fits a
cold install on a fast link. mise authenticates itself via
`github.credential_command = "gh auth token"` (rendered into
`~/.config/mise/config.toml` when `gh` is on PATH) — so once `gh auth
login` is done, every mise install/upgrade is authed (5000/hr), both at
`chezmoi apply` time and interactively. Pre-exported `GITHUB_TOKEN` env
wins over it; gh unauthed falls through to anonymous.

mise reads gh's token via this bridge because gh stores it in the OS
keyring (macOS Keychain) on most machines, which mise can't read directly
— but `gh auth token` can.

If you hit the rate limit (slow link, shared IP, multiple rebuilds in
one hour), `mise_install_tools()` surfaces a partial-install warning
with three recovery options:

```sh
gh auth login                                             # cached token, recommended
export GITHUB_TOKEN=ghp_yourPAT                           # one-off env
export GITHUB_TOKEN=$(op read 'op://Personal/GitHub API Token/credential')
```

Then `chezmoi apply` — mise retries missing tools idempotently. After
`gh auth login` no manual env-export is needed on subsequent applies.

### Render-time (auth tokens that must live in target files)

Tools that read credentials from on-disk files (npm, aws, rclone, docker,
git HTTP creds) need the secret baked into the target. Use chezmoi-native
render-time funcs against a single catalog at `.chezmoidata/secrets.yaml`.

Workflow when a new render-time secret is needed:

1. Add the 1Password reference to the catalog:

   ```yaml
   # .chezmoidata/secrets.yaml
   op_refs:
     npm_token: "op://Personal/NPM Registry/token"
   ```

2. Create a `private_dot_<file>.tmpl` referencing it:

   ```
   //registry.npmjs.org/:_authToken={{ onepasswordRead .op_refs.npm_token }}
   ```

3. `chezmoi apply` — file lands at `~/.npmrc` mode 0600 with the secret
   baked in. Touch ID prompts once per apply (1Password CLI 10-minute
   session covers subsequent reads).

### Runtime CLI auth (gh, aws, npm CLIs themselves)

Use [1Password Shell Plugins](https://developer.1password.com/docs/cli/shell-plugins/)
per CLI — biometric-gated, lazy, no disk exposure:

```sh
op plugin init gh
op plugin init aws
op plugin init npm
```

Not in any catalog — `op` manages auth per CLI internally.

### `op` install + auth

`op` itself is installed cross-platform by mise (Mac + Linux arm64/amd64)
at the `dev` / `workstation` profile — see `dot_config/mise/config.toml.tmpl`
dev block (unqualified `op` shortname → mise's vfox backend,
`vfox:mise-plugins/vfox-1password`).

Mac `workstation` additionally installs the 1Password desktop app cask,
which enables Touch ID biometric unlock so `op read` works without `op signin`.
Linux headless boxes use `OP_SERVICE_ACCOUNT_TOKEN` instead of biometric.

## Tools managed by mise (cross-platform via aqua + github + vfox backends)

Defined declaratively in `dot_config/mise/config.toml.tmpl` (profile-aware — rendered to `~/.config/mise/config.toml`). Same tools install identically on Mac + Linux.

`core` profile installs only what dotfile integrations need:

| Category | Tools |
|---|---|
| Shell integrations | `fzf` (zshrc Ctrl-R, Ctrl-T bindings), `zoxide` (zshrc `z`/`zi`) |

`dev` profile adds the full dev toolchain (`workstation` cascades — includes everything in `dev`):

| Category | Tools |
|---|---|
| Languages | `node` (LTS), `go` (latest), `python` (3.12), `rust` (stable) |
| CLI utilities | `jq`, `gh`, `delta`, `shellcheck`, `fd`, `yq`, `gitleaks` |
| Cloud + K8s | `helm`, `kubectl`, `k9s`, `kustomize`, `stern`, `argocd`, `tofu` (opentofu), `aws` (awscli), `rclone`, `cloudflared` |
| Networking | `websocat` |
| Go ecosystem | `buf`, `golangci-lint`, `goreleaser`, `gotestsum`, `protoc-gen-go` |
| Package managers | `pnpm`, `uv` |
| Auth + secrets | `op` (1Password CLI, `vfox:mise-plugins/vfox-1password`) |
| Token-saving proxy | `rtk` (`github:rtk-ai/rtk`, native binary) |
| AI CLIs | `claude-code` (`aqua:anthropics/claude-code`, native), `codex` (`aqua:openai/codex`, native rust) |
| Post-install (after mise install) | `rtk init` (Claude+Codex hooks) — `goimports` (`go:`) and `ssh-audit` (`pipx:`) now install via mise |

**Adding a tool**: `mise registry | grep -i <name>` → use the aqua slug → add line to `dot_config/mise/config.toml.tmpl` (inside the `$isDev` block unless every tier needs it) → `chezmoi apply` (or `mise install`).

**Removing a tool**: delete line, optionally `mise uninstall <name>`.

## OS-native packages (via brew / apt / dnf)

Tools NOT in mise's aqua registry — C apps with libpcap/curses/PAM deps, system services, or platform-specific. Defined in `.chezmoidata/packages.yaml` under `packages.{core,dev,gui}` sections, installed cascade-style by `run_onchange_after_50-install-packages.sh.tmpl`.

| Tier | OS | Packages |
|---|---|---|
| core | Linux apt/dnf | `zsh`, `vim`, `tmux`, `git`, `curl`, `ca-certificates`, `ufw`, `tcpdump` |
| core | Mac brew | (none — Apple bundles zsh/vim/tmux/git/curl + system `/usr/sbin/tcpdump`; no Mac equivalent for ufw — use `pfctl`) |
| dev | Mac brew | `htop`, `tree`, `wget`, `nmap`, `telnet`, `libpq` (psql, force-linked), `wireguard-tools` |
| dev | Linux apt | `build-essential`, `xsel`, `wl-clipboard`, `htop`, `tree`, `wget`, `nmap`, `inetutils-telnet`, `wireguard-tools`, `postgresql-client` |
| dev | Linux dnf | (same as apt, modulo Fedora naming) |
| workstation | Mac casks | `iterm2`, `docker-desktop`, `visual-studio-code`, `ngrok`, `1password` (desktop), `font-meslo-lg-nerd-font`, `font-monaspace` |

**Docker is intentionally NOT in the `dev` tier**: `docker.io` (Ubuntu repo) and `docker-ce` (Docker's official apt repo) can't coexist, and a pre-existing install would break `apt-get install`. Pick the flavour that fits the machine: `sudo apt install docker.io` (simple), Docker's official repo for `docker-ce` (production), or `workstation` profile on Mac (Docker Desktop cask).

**Ad-hoc installs**: brew/apt/dnf still primary on each platform. Want `mongosh`? `brew install mongosh` (Mac) or follow MongoDB's apt repo (Linux). Want `kubectl` debug version? `mise use kubectl@1.34.2` (per-project) or edit the global config.

**First-apply latency** at `dev` or `workstation`: cold install downloads ~1.9 GB (4 language toolchains × ~300 MB + ~30 binaries via mise). Realistic ranges: 5-10 min on fast link, 15-30 min on residential, 30-60+ min on slow links / jetson. `core` profile only pulls fzf+zoxide (~5 MB).

**GitHub API rate limit**: mise's aqua + github backends hit `api.github.com` ~30-50 times during a cold dev install. Anonymous limit is 60/hr — usually fits. If hit, the install-packages partial-install warning surfaces; see §"1Password integration → Install-time" above for recovery options.

**Troubleshooting slow zsh prompt**: `MISE_TIMINGS=1 exec zsh` — total < 50ms per prompt is healthy. If consistently above, switch to mise shim mode in `dot_zshrc`:
```zsh
command -v mise > /dev/null && eval "$(mise activate --shims zsh)"
```

**Per-machine mise overrides**: skip a heavy toolchain (e.g. Rust on jetson) by creating untracked `~/.config/mise/config.local.toml` with a `[tools]` block that overrides specific entries. mise auto-merges later files over earlier — don't commit, it's per-machine.

## How it's managed (chezmoi essentials)

Source files in this repo use chezmoi's naming convention. The mapping is mechanical:

| Source name | Becomes in `$HOME` |
|---|---|
| `dot_zshrc` | `~/.zshrc` |
| `dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` |
| `dot_codex/AGENTS.md` | `~/.codex/AGENTS.md` |
| `executable_X` | mode +x |
| `private_X` | mode 0600 |
| `symlink_X.tmpl` | symbolic link (body = target) |
| `modify_X` | script: stdin = existing file, stdout = new contents |
| `modify_X` + `#chezmoi:modify-template` | template: `.chezmoi.stdin` = existing; output = new contents |
| `.chezmoiscripts/run_*` | scripts that don't create `$HOME` files (per-OS subdirs `darwin/` + `linux/`; root scripts use `50/70/99-` numerical prefix for ordering — 50 installs packages, 70 installs plugins, 99 prints post-install hint) |
| `hooks/*` | hook scripts registered in `.chezmoi.toml.tmpl` (e.g. `read-source-state.pre`) |
| `.chezmoiexternal.toml.tmpl` | vendored externals (archives, file downloads) |
| `.chezmoiignore` | exclude target paths from apply |
| `.chezmoiversion`, `.chezmoiremove.tmpl` | minimum-version pin + deprecation-tracking list |

**Source of truth** is `~/.local/share/chezmoi/` (chezmoi's default — XDG_DATA_HOME compliant). On my Mac there's also a back-compat symlink `~/dotfiles → ~/.local/share/chezmoi` for muscle memory; not required.

### Editing `.chezmoi.toml.tmpl` (the config template)

Changes to `.chezmoi.toml.tmpl` (prompts, hooks, [data] keys) make the rendered local config drift from the cached template hash. On the next apply chezmoi prints:

    chezmoi: warning: config file template has changed, run chezmoi init to regenerate config file

Clear it with:

```sh
chezmoi init --promptDefaults
```

`chezmoi init` rewrites `~/.config/chezmoi/chezmoi.toml` from the template. With no custom `sourceDir` override to lose, this is now idempotent — nothing manual to restore.

**Day-to-day flow** (use `chezmoi cd` instead of remembering the source path):
```sh
chezmoi cd                     # opens subshell in source dir
vim dot_zshrc                  # edit source
chezmoi diff                   # preview what would change in $HOME
chezmoi apply                  # apply to $HOME
git commit -am '...' && git push
exit                           # leave the chezmoi-cd subshell
```

On another machine: `chezmoi update` (= git pull + apply).

## Tools

### tmux

Prefix is **`C-a`** (screen-style). Status bar, bindings, theme inherit from gpakosz/.tmux unchanged — see their [docs](https://github.com/gpakosz/.tmux#bindings).

oh-my-tmux is vendored via `.chezmoiexternal.toml.tmpl` — pinned to a specific commit SHA (gpakosz/.tmux has no tagged releases). Bump cycle: edit SHA in URL → `chezmoi apply -R` → commit.

Customizations in `dot_tmux.conf.local` (becomes `~/.tmux.conf.local`):

- **Prefix `C-a`** as the sole prefix (verbatim from gpakosz's documented snippet)
- **`mouse on`** — wheel scrolls tmux scrollback, drag-resizes panes, click selects
- **`mode-keys vi`** — copy-mode uses vim navigation
- **`set-clipboard on`** (OSC 52) — vim/nvim `"+y` inside tmux reaches the system clipboard
- **`tmux_conf_copy_to_os_clipboard=true`** — copy-mode `y` writes to OS clipboard. gpakosz default is `false`.
- **`tmux_conf_24b_colour=true`** — forces 24-bit colour so Powerlevel10k renders identically inside tmux
- **`COLORTERM=truecolor`** propagated to inner shells
- **`history-limit 50000`** — gpakosz default 5000 is small

**Gotchas**:

- iTerm2 **≥3.5.11** required — `3.5.0beta6`–`3.5.0beta10` had a regression where Nerd Font glyphs disappear inside tmux panes ([iTerm2 #10879](https://gitlab.com/gnachman/iterm2/-/issues/10879)).
- If Powerlevel10k complains about an *instant-prompt* warning inside tmux, add `typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet` to `~/.p10k.zsh`.
- Linux without `xsel`/`xclip`/`wl-clipboard`: tmux copy-mode `y` saves to the tmux paste buffer only, not the system clipboard.

### iTerm2 (macOS)

The committed `iterm/com.googlecode.iterm2.plist` is loaded via `PrefsCustomFolder`. A `run_once_after_*` script tells iTerm2 to load prefs directly from the chezmoi source tree (`~/.local/share/chezmoi/iterm/`) — no `~/.config/iterm/` symlink layer.

**GUI edits flow through to git**: when you change settings in iTerm2 and quit (answer "Save" if prompted), iTerm2 writes directly into `~/.local/share/chezmoi/iterm/com.googlecode.iterm2.plist`. `git status` (from `chezmoi cd`) shows the dirty plist — review and commit.

**Trigger setup** — the committed plist ships a `vscode://` Trigger pre-installed on the default profile (used by the [VSCode-from-any-terminal](#open-vscode-from-any-terminal) flow).

> **Gotcha** — iTerm2's plist stores trigger actions as bare Objective-C class names. "Run Command…" in the UI maps to `"ScriptTrigger"` in the plist, not `"RunCommandAction"`. iTerm2 silently drops triggers whose action class doesn't exist.

## Integrations

### AI tooling (Claude Code + OpenAI Codex)

Global, cross-machine config for both CLIs. **Only user-curated settings are tracked**; auth tokens, marketplace registrations, plugin caches, NUX state, project trust-levels — all stay machine-local.

#### Layout

| Source path | Becomes in `$HOME` | Pattern | Purpose |
|---|---|---|---|
| `dot_claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | plain | global instructions (bootstrap + TL;DR rule index) |
| `dot_claude/modify_settings.json` | `~/.claude/settings.json` | `modify_` (jq merge) | global settings, preserves tool-added keys |
| `.chezmoitemplates/claude-settings-base.json` | (not applied) | template partial | curated base, loaded via `includeTemplate` from `modify_` |
| `dot_claude/executable_statusline-command.sh` | `~/.claude/statusline-command.sh` | plain +x | custom status-line renderer |
| `dot_claude/agents/` | `~/.claude/agents/` | plain dir | custom subagents |
| `dot_claude/skills/` | `~/.claude/skills/` | plain dir | custom skills (one dir per skill, `SKILL.md` inside) |
| `dot_claude/rules/*.md` | `~/.claude/rules/*.md` | plain | auto-loaded rules (optional `paths:` frontmatter for conditional load) |
| `dot_codex/AGENTS.md` | `~/.codex/AGENTS.md` | plain | global instructions for Codex |
| `dot_codex/modify_config.toml` | `~/.codex/config.toml` | `modify_` (toml merge) | model + plugin enables, drops runtime sections |
| `.chezmoitemplates/codex-config-base.toml` | (not applied) | template partial | curated base, loaded via `includeTemplate` from `modify_` |
| `dot_codex/skills/save-to-dotfiles/symlink_SKILL.md` | `~/.codex/skills/save-to-dotfiles/SKILL.md` | file-level symlink | → `~/.claude/skills/save-to-dotfiles/SKILL.md` (single source for the only chezmoi-managed skill shared between both AI tools) |

We deliberately don't manage `~/.claude/commands/` (deprecated by skills per upstream docs) or `~/.claude/hooks/` (not a Claude directory convention — hooks live inline in `settings.json`).

#### Why `modify_` for settings.json / config.toml

Both files are mutated at runtime by tools:
- `~/.claude/settings.json` — `rtk init -g` adds a `PreToolUse` hook entry; `claude plugin install` adds entries to `enabledPlugins`
- `~/.codex/config.toml` — Codex auto-writes `[projects."<path>"]`, `[notice]`, `[tui.*]`, `[tool_suggest]` runtime sections

The `modify_` pattern handles both gracefully:
- **settings.json**: jq additive merge between `.chezmoitemplates/claude-settings-base.json` (our curated base) and the existing file. Our base sets canonical permissions/statusLine/etc.; tool-added keys (`hooks.PreToolUse`, extra `enabledPlugins`) get UNION-preserved.
- **config.toml**: chezmoi-native template via `fromToml`/`toToml`. Parse existing → drop runtime sections → `mergeOverwrite` with `.chezmoitemplates/codex-config-base.toml` (our curated base) → serialize. Idempotent.

Both bases live in `.chezmoitemplates/` — chezmoi's canonical location for shared template partials, automatically excluded from `$HOME`. They're loaded via `includeTemplate "name" .` from the respective `modify_` scripts.

This replaces a previous git-clean-filter mechanism (`.gitattributes` + per-clone `git config filter.codex-strip.{clean,smudge,required}`) — that was always-on for the entire source repo, fragile across clones, and required `required=true` + `smudge=cat` setup. `modify_` is local to one file, no per-clone setup.

#### Rules architecture (`dot_claude/rules/`)

Files under `dot_claude/rules/*.md` are **auto-discovered by Claude Code at session start**. Each rule file is a small markdown doc with YAML frontmatter:

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
- **Conditional rules** (with `paths:` glob array) only load when Claude is reading/editing files matching one of the globs.

Current set: three universal (`read-codebase-first`, `no-code-without-go`, `verify-before-fix`), two frontend-only (`frontend-spec-first-workflow`, `visual-audit-mcp-gotchas`). Codex doesn't have an auto-discovery equivalent — `dot_codex/AGENTS.md` references the rule files as advisory reading.

#### Not tracked (intentionally)

- `~/.claude/settings.local.json` — per-machine permissions allowlist; Anthropic's documented convention is to gitignore it.
- `~/.claude/plugins/{installed_plugins,known_marketplaces}.json` — contain absolute install paths and per-user marketplace registrations.
- `~/.claude.json` — **lives at `$HOME`, not in `~/.claude/`** — holds OAuth tokens, MCP server credentials, NUX `tipsHistory` counters, marketplace registrations. **Never commit it.**
- `~/.claude/RTK.md`, `~/.codex/RTK.md` — written fresh by `rtk init -g` / `rtk init -g --codex` (bundled rtk version's content, not ours to track).
- `~/.codex/auth.json`, `installation_id` — secrets and per-machine identifiers.
- `~/.codex/{sessions,cache,log,tmp,history.jsonl,*.sqlite}` — runtime state.
- `~/.codex/memories/`, `~/.codex/plugins/` — runtime state / cloned plugin repos.

#### Plugin install (automated)

Plugins listed in `.chezmoidata/packages.yaml` under `plugins.{claude,codex}` are installed automatically by `.chezmoiscripts/run_onchange_after_70-install-plugins.sh.tmpl`. The same YAML drives the enable flags in `.chezmoitemplates/{claude-settings-base.json,codex-config-base.toml}` — single source of truth, no drift between install and enable state.

Mechanics:
- Claude: `claude plugin install <plugin>@<marketplace> --scope user` (idempotent), then `claude plugin update <plugin>` (auto-upgrade). The `claude-plugins-official` marketplace is auto-added defensively (it's the implicit default but Claude only auto-registers it on first interactive launch). Non-default marketplaces (listed under `plugins.claude_marketplaces` in `packages.yaml`) are registered via `claude plugin marketplace add` before the install loop.
- Codex: built-in `openai-curated` marketplace is reserved — only the `[plugins."x@y"] enabled = true` table in `config.toml` is needed (generated from the YAML). Non-reserved marketplaces (listed under `plugins.codex_marketplaces`) are registered via `codex plugin marketplace add`.

`caveman` is just another entry in `plugins.claude` (caveman@caveman) + `plugins.claude_marketplaces` (caveman:JuliusBrussee/caveman). Per its [INSTALL.md](https://github.com/JuliusBrussee/caveman/blob/main/INSTALL.md) per-agent table, that's the canonical Claude install path. The plugin self-registers its `SessionStart` + `UserPromptSubmit` hooks via `plugin.json` (no settings.json mutation). Caveman for Codex is a manual step (`npx -y skills add JuliusBrussee/caveman -a codex`) — the skills CLI doesn't currently create the per-agent symlinks Codex needs.

#### rtk install + init

`rtk` is installed by mise as `github:rtk-ai/rtk = "latest"` — cross-platform, single source. On every `chezmoi apply`, mise refreshes its registry and pulls a newer rtk if upstream released one. The `post_install_rtk_init` function in `lib/install-packages.sh` runs `rtk init -g --auto-patch` (Claude PreToolUse hook) and `rtk init -g --codex` (Codex AGENTS.md reference) — both idempotent. `RTK.md` awareness files (`~/.claude/RTK.md`, `~/.codex/RTK.md`) are bundled inside the binary and rewritten on each init.

Ubuntu 22.04 jammy (glibc 2.35) skips the init step gracefully — upstream ships glibc-2.39 builds only for linux-arm64 (Ubuntu 24.04+); claude/codex still work without the rtk hook.

### Open VSCode from any terminal

`code <path>` works the same in any iTerm2 pane. Calling `code` **without arguments** opens the `*.code-workspace` file in cwd if one exists, otherwise opens cwd itself.

- **Local Mac**: opens VSCode at that path. Works after Brewfile installs the cask + zshrc adds it to PATH.
- **Remote SSH** (iTerm2/tmux into a Linux box): a zshrc function (active when `$SSH_CONNECTION` is set) decides what to do:
  1. If you're already in VSCode's *integrated* Remote-SSH terminal — calls the real `code` via the injected env.
  2. Else prints a `vscode://vscode-remote/ssh-remote+<host>/<path>` URL. The iTerm2 Trigger matches the URL and runs `open <url>` → macOS launches Mac-side VSCode → it connects via Remote-SSH and opens the folder.

If the remote's `hostname -s` doesn't match the Host alias in your **local** `~/.ssh/config`, override per-host:

```sh
export VSCODE_REMOTE_HOST=my-ssh-alias
```

## Implementation notes

### Cross-platform via templates

Top-level dotfiles (`dot_zshrc`, `dot_vimrc`, etc.) are plain — they handle platform differences via runtime feature-detection (`command -v X`, `case "$(uname -s)"` in shell). Where chezmoi templates are used:

- `.chezmoiexternal.toml.tmpl` is templated for headless detection (skip fonts) + per-OS font destination
- `.chezmoiscripts/{darwin,linux}/` hold per-OS scripts; root holds cross-platform scripts with numerical prefix (`50-`, `70-`, `99-`) for ordering within the `run_onchange_after_` / `run_once_after_` groups
- `.chezmoiscripts/run_onchange_after_50-install-packages.sh.tmpl` branches on `.chezmoi.os` (Mac brew bundle vs Linux apt/dnf) + `.chezmoi.osRelease.id` (Debian vs Fedora)
- `hooks/ensure-prereqs.sh` is NOT a template (chezmoi doesn't template hooks) — it detects OS inline via `case "$(uname -s)"`

### Headless SSH detection

Used by Linux font install (which is skipped on remote machines):

```sh
[ -n "$SSH_CONNECTION" ] && [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]
```

Glyphs render on the local terminal emulator — remote box doesn't need the font.

### Externals (vendored)

`tmux/oh-my-tmux` is pulled by chezmoi from `.chezmoiexternal.toml.tmpl`:

```toml
[".config/tmux"]
    type = "archive"
    url = "https://github.com/gpakosz/.tmux/archive/<commit-sha>.tar.gz"
    exact = true
    stripComponents = 1
    refreshPeriod = "720h"
```

Pinning is via commit SHA in the URL (gpakosz/.tmux has no tagged releases). To bump: pick newer SHA from gpakosz commits, edit URL, `chezmoi apply -R`, commit.

Cache lives in `~/Library/Caches/chezmoi/` (Mac) — outside the source repo, so `git status` stays clean.

## TODO

### Done (recent milestones)

- **mise-as-primary-installer migration (2026-05)** — replaced bundle-based
  install (1200 LOC) with mise.toml declarative tool list + slim OS-glue
  install (~250 LOC). Cross-platform parity: same 28 dev tools install
  identically on Mac + Linux via mise's aqua backend.
- **Linux bundle support** — superseded by mise migration. Bundle scripts
  + helpers all deleted.

### New tracked configs (deferred — surface too small for current workflow)

- **`dot_ssh/config.tmpl`**: 5 portable lines (`AddKeysToAgent`, `UseKeychain`,
  `HashKnownHosts`, `ServerAliveInterval/CountMax`). Per-host blocks stay in
  untracked `~/.ssh/config.d/*.conf`.
- **`dot_kube/config.tmpl`**: kubectl config + krew. Per-cluster credentials
  machine-local.
- **`dot_aws/config.tmpl`**: AWS CLI v2 named profiles + SSO sessions.
  Credentials machine-local.

### Soft hardening (review-flagged, not blocking)

- Renovate config for `dot_config/mise/config.toml` — auto-PR bumps for
  pinned tool versions (replaces "track latest" with deterministic
  upgrades).
- CI smoke tests (Docker matrix over Ubuntu 22.04 + Debian 12 arm64).
- `dot_p10k.zsh` top-of-file generation note.
