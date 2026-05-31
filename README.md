# Dotfiles

Personal cross-platform (macOS + Linux) dotfiles managed with [chezmoi](https://www.chezmoi.io/).

- **zsh** — [antidote](https://github.com/mattmc3/antidote) (static-cache) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k); `~/.p10k.zsh` tracked so the prompt is byte-identical everywhere
- **vim** — [vim-plug](https://github.com/junegunn/vim-plug) (auto-bootstrapped on first launch)
- **tmux** — [gpakosz/.tmux](https://github.com/gpakosz/.tmux) vendored as a chezmoi external (SHA-pinned)
- **iTerm2** prefs (macOS, auto-loaded from the repo)
- **AI tooling** — Claude Code + OpenAI Codex CLI (instructions, settings, rules) with tool-mutation-safe `modify_` merging
- **mise** — declarative dev-tool list (Go/Python/Node/Rust + ~30 binaries), profile-tiered
- **3 install profiles** — `core` / `dev` / `workstation`, prompted on init

> **Internals** — chezmoi conventions, secret handling, mise/AI mechanics, full source↔target mapping — live in **[AGENTS.md](AGENTS.md)** (the maintainer/agent guide, also read by Claude Code via the `CLAUDE.md` symlink). This README is the human quick-start.

## Install

One command on a fresh machine (macOS or Linux):

```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply vaintrub
```

`chezmoi init` prompts for a profile (`core` / `dev` / `workstation`, default `core`). A pre-apply hook installs prereqs on first run (Xcode CLT + Homebrew + mise on macOS; `git zsh vim tmux curl` + mise on Linux), then the install scripts pull packages (`brew` / `apt` / `dnf`) plus the mise toolchain for your tier. The repo lands at chezmoi's default source dir, `~/.local/share/chezmoi/` — `chezmoi cd` / `chezmoi edit` work with no per-machine setup.

- **Linux** needs `git curl sudo` first: `sudo apt install -y git curl sudo` (or `dnf`). Supported: Debian 12+, Ubuntu 22.04+, Fedora 40+ (Alpine/Arch print an explicit unsupported message).
- **macOS** — after the first apply, quit + relaunch iTerm2 once ("Don't Save" if prompted); it reads prefs at startup.

Then reload + verify:

```sh
exec zsh
mise ls          # no "(missing)" rows
chezmoi diff     # empty
```

If `mise ls` shows `(missing)` rows, the anonymous GitHub API limit was hit mid-install — see [Recovery](#recovery).

## Install profiles

Prompted on init (the detected env is shown as a hint; you pick). Cached in `~/.config/chezmoi/chezmoi.toml [data].profile` — change later by editing that key then `chezmoi apply`, or re-prompt with `chezmoi init --prompt`.

| Profile | What you get | Use case |
|---|---|---|
| `core` | OS baseline (zsh, vim, tmux, git, curl; Linux also ufw, tcpdump) + Nerd fonts + mise + fzf + zoxide. ~50 MB. | VPS, jetson/SSH first-touch, Codespace, recovery |
| `dev` | core + full CLI toolchain: 4 languages (Go/Python/Node/Rust) + ~30 mise binaries (kubectl/helm/jq/gh/delta/… + `op` + `rtk` + `claude-code` + `codex`) + a few OS-native brews/apts. ~1.9 GB first apply. | Headless dev box |
| `workstation` | dev + GUI apps. macOS casks: iterm2, docker-desktop, visual-studio-code, ngrok, 1password, fonts. | Primary GUI machine |

Exact tool lists are the source of truth in `dot_config/mise/config.toml.tmpl` (mise) and `.chezmoidata/packages.yaml` (brew/apt/dnf). Add a mise tool: `mise registry | grep -i <name>` → add the slug to the config (inside the `$isDev` block unless every tier needs it) → `chezmoi apply` (the install script embeds the mise-config hash, so apply auto-reruns `mise install` — no manual step).

Docker is intentionally not in `dev` (the `docker.io` vs `docker-ce` apt conflict breaks installs) — install it per-machine, or use the macOS Docker Desktop cask in `workstation`.

## Recovery

```sh
# Partial install — GitHub rate-limit hit mid-apply, some mise tools missing:
gh auth login && chezmoi apply        # mise auto-uses gh's token; retries idempotently

# mise shims stale / new tools not on PATH:
mise reshim && exec zsh

# chezmoi warns "config file template has changed":
chezmoi init --promptDefaults

# Touch-ID-for-sudo rolled back by a macOS major update:
chezmoi state delete-bucket --bucket=scriptState && chezmoi apply
```

## Per-machine overrides

Drop an untracked `~/.config/mise/config.local.toml` to skip or pin tools on one box — mise merges it over the tracked config, local wins:

```toml
[tools]
rust = "skip"            # no Rust toolchain on a small VPS
python = "3.11"          # pin older Python here
"aqua:cli/cli" = "skip"  # no gh on this box
```

Then `mise install`. (Mac firewall isn't managed — enable via System Settings → Network → Firewall. Linux `core` ships `ufw`, disabled; `sudo ufw enable` to activate.)

## Day-to-day

```sh
chezmoi cd                          # subshell in the source dir
vim dot_zshrc                       # edit source — never the live $HOME file
chezmoi diff && chezmoi apply
git commit -am '...' && git push
exit
```

On another machine: `chezmoi update` (= git pull + apply).

## Secrets

Three mechanisms, one per concern — full guide in [AGENTS.md](AGENTS.md):

- **Install-time** (GitHub API rate limit): mise reads `gh auth token` via `github.credential_command`, so `gh auth login` once is enough (5000/hr authed vs 60 anon).
- **Render-time** (tokens baked into files like `~/.npmrc`): chezmoi-native `onepasswordRead` against the `.chezmoidata/secrets.yaml` catalog, into a `private_` (0600) target.
- **Runtime CLI auth**: [1Password Shell Plugins](https://developer.1password.com/docs/cli/shell-plugins/) per CLI — `op plugin init gh` / `aws` / `npm`, biometric-gated, no disk exposure.

## tmux

Prefix **`C-a`** (screen-style). Theme/bindings inherit from gpakosz/.tmux; our tweaks live in `dot_tmux.conf.local` — mouse on, vi copy-mode, OSC-52 clipboard, 24-bit colour (so p10k renders identically inside tmux), 50k history. Bump the vendored copy: edit the SHA in `.chezmoiexternal.toml.tmpl` → `chezmoi apply -R` → commit.

Gotcha: needs iTerm2 **≥3.5.11** (older betas drop Nerd Font glyphs inside tmux panes).

## iTerm2 (macOS)

Prefs load straight from the repo via `PrefsCustomFolder` (set by a `run_once_after_*` script) — no symlink layer. GUI edits write directly into `iterm/com.googlecode.iterm2.plist`, so `git status` (from `chezmoi cd`) surfaces them for review + commit. The committed plist ships a `vscode://` Trigger for the flow below.

## VSCode from any terminal

`code <path>` works in any pane; bare `code` opens a `*.code-workspace` in cwd if present, else cwd. Over SSH a zshrc function emits a `vscode://vscode-remote/ssh-remote+<host>/<path>` URL that the iTerm2 Trigger opens on the Mac side (Remote-SSH reuses/opens a window). If the remote's `hostname -s` ≠ your local `~/.ssh/config` Host alias, set `export VSCODE_REMOTE_HOST=my-alias`.

## AI tooling (Claude Code + Codex)

Global config for both CLIs — **only user-curated settings are tracked**; auth tokens, plugin caches, NUX state, project trust-levels stay machine-local. Settings merge tool-safely via `modify_` (jq for Claude `settings.json`, TOML for Codex `config.toml`), rules auto-load from `dot_claude/rules/*.md`, and plugins install from `.chezmoidata/packages.yaml`. Layout, the `modify_` rationale, rules frontmatter, and the full not-tracked list are in [AGENTS.md](AGENTS.md).
