# Dotfiles

Personal macOS dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot).

Includes:
- **zsh** with [antidote](https://github.com/mattmc3/antidote) plugin manager (static-cache mode) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme
- **vim** with [vim-plug](https://github.com/junegunn/vim-plug) (auto-bootstrapped on first launch)
- **tmux** with [gpakosz/.tmux](https://github.com/gpakosz/.tmux) ("oh-my-tmux") vendored as a submodule
- **iTerm2** preferences (manual import — see below)

## Install

Prerequisites: `zsh`, `vim`, `git`, `python3`, and (recommended) [Homebrew](https://brew.sh).

```sh
git clone https://github.com/vaintrub/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install
```

The installer will:
1. Initialise the `dotbot` and `oh-my-tmux` submodules.
2. Symlink `vimrc`, `zshrc`, `zsh_plugins.txt`, `.tmux.conf`, and `.tmux.conf.local` into `$HOME`.
3. Install the **MesloLGS Nerd Font** Homebrew cask (recommended by Powerlevel10k).

On first `vim` launch, vim-plug will fetch and install the configured plugins automatically.

## tmux

Prefix is **`C-a`** (screen-style). All other key bindings, status bar, and behaviour inherit from gpakosz/.tmux unchanged — see their [docs](https://github.com/gpakosz/.tmux#bindings). Useful defaults out of the box: `prefix h/j/k/l` for pane navigation, `prefix -` / `prefix _` for splits, `prefix e` to edit `.tmux.conf.local`, `prefix r` to reload.

Customizations live in `tmux/tmux.conf.local` (symlinked to `~/.tmux.conf.local`) and are intentionally minimal:

- **macOS clipboard**: yank in copy-mode (`y` after selecting with `v`) writes to `pbcopy` automatically (gpakosz native, no plugin).
- **24-bit true color**: forced on so Powerlevel10k renders identically inside tmux (override of gpakosz's default `auto`, which depends on `$COLORTERM` propagation that can drop over SSH).

No plugin manager is used. [TPM](https://github.com/tmux-plugins/tpm) has been dormant since Feb 2023, and the only plugin feature we needed (`tmux-yank` for `pbcopy`) is already provided by gpakosz natively.

If Powerlevel10k complains about an *instant-prompt* warning inside tmux, add `typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet` to `~/.p10k.zsh`.

## iTerm2

Import `iterm/com.googlecode.iterm2.plist` manually via *Preferences → General → Preferences → Load preferences from a custom folder*.

## TODO

- Automate iTerm2 preference import
- Add a `Brewfile` for one-shot dependency install (`brew bundle`)
- Add `git` and `ssh` configs
- Cross-OS support (Linux)
