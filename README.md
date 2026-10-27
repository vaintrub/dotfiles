# Dotfiles

Personal dotfiles for macOS and Ubuntu, managed with [chezmoi](https://www.chezmoi.io/).

- **zsh** — [antidote](https://github.com/mattmc3/antidote) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k); antidote and every plugin pinned to a commit
- **vim** — [vim-plug](https://github.com/junegunn/vim-plug), `plug.vim` SHA-pinned
- **tmux** — [gpakosz/.tmux](https://github.com/gpakosz/.tmux), SHA-pinned; ours is `dot_tmux.conf.local`
- **iTerm2** prefs, loaded straight from the repo (macOS)
- **Claude Code + Codex CLI** — instructions, rules, skills, settings merged without clobbering what the tools write
- **mise** — the CLI toolchain (Go/Python/Node/Rust + ~30 tools)

Maintainer and agent guide: **[AGENTS.md](AGENTS.md)**.

## Install

```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --use-builtin-git=true vaintrub
```

- **macOS** — run it in a terminal: the first apply installs Homebrew, which asks for the sudo password. `--use-builtin-git` lets the clone work before the Xcode CLT exists. Afterwards quit and relaunch iTerm2 once ("Don't Save").
- **Ubuntu** — needs only `curl`. The apply installs the OS packages through apt (sudo, or as root) and the toolchain through mise.

`chezmoi init` asks for a profile once:

| Profile | Gets | Machine |
|---|---|---|
| `core` | Linux: zsh, vim, tmux, git, curl, ufw, tcpdump; macOS: tmux, mise. Both: mise with fzf, zoxide, jq | VPS |
| `dev` | core + the full mise toolchain (languages, kubectl/helm/gh/delta/…, claude, codex, op) + a few OS packages | Jetson |
| `workstation` | dev + macOS casks (iTerm2, Docker Desktop, VS Code, ngrok, 1Password) | MacBook |

Change it later with `chezmoi init --prompt`. Then:

```sh
exec zsh
chezmoi apply    # once more: converges what the plugin CLI wrote on the first pass
mise ls          # no "(missing)" rows
```

## Day-to-day

```sh
chezmoi cd                          # subshell in the source dir
vim dot_zshrc                       # edit the source, never the live file
chezmoi diff && chezmoi apply
git add dot_zshrc && git commit -m '...' && git push
exit
```

On another machine: `chezmoi update`. After a change to `.chezmoi.toml.tmpl`, use `chezmoi git pull && chezmoi init && chezmoi apply` instead.

`czs` is `chezmoi status` minus the permanent `MM .codex/config.toml` line (Codex rewrites that file in its own order; see AGENTS.md §9).

## Recovery

```sh
# mise tools missing — often a GitHub rate limit on a fresh box:
gh auth login && mise install       # mise uses gh's token from then on
# no gh yet (it is a mise tool itself): mise install aqua:cli/cli first,
# or run `GITHUB_TOKEN=<token> mise install` once

# a tool has no build for this box — skip it here:
cat >> ~/.config/mise/config.local.toml <<'EOF'
[settings]
disable_tools = ["rust"]            # any tool name, backend-qualified for aqua (e.g. "aqua:cli/cli")
EOF

# an install step failed and is now fixed — re-run that one script
# (50-packages-darwin, 50-packages-linux or 70-install-plugins):
chezmoi state delete --bucket=entryState --key="$HOME/.chezmoiscripts/50-packages-darwin.sh" && chezmoi apply

# "config file template has changed":
chezmoi init
```

`~/.config/mise/config.local.toml` is untracked and merges over the tracked config; `disable_tools` is the only way to drop an inherited tool (a `"skip"` version would 404 and stay `(missing)`).

## Secrets

Nothing in the repo is secret.

- **GitHub API auth for installs:** mise reads `gh auth token`.
- **SSH:** 1Password's SSH agent for a local login. Inside an SSH session a forwarded agent (`ssh -A`) wins over the box's own 1Password, and `~/.zshrc` pins it behind `~/.ssh/agent.sock` so tmux panes outlive the login that started them.
- **CLI tokens:** [1Password Shell Plugins](https://developer.1password.com/docs/cli/shell-plugins/).

There are no global git hooks: `core.hooksPath` would disable every repository's own hooks.

## VSCode from any terminal

`code <path>` works in any pane. Over SSH it prints a `vscode://vscode-remote/ssh-remote+<host>/<path>` URL; ⌘-click it and Remote-SSH opens the remote folder on the Mac. If the remote's `hostname -s` is not your `~/.ssh/config` alias, set `VSCODE_REMOTE_HOST` in `~/.zshrc_local`.
