# Dotfiles

Personal macOS dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot).

Includes:
- **zsh** with [antidote](https://github.com/mattmc3/antidote) plugin manager (static-cache mode) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme
- **vim** with [vim-plug](https://github.com/junegunn/vim-plug) (auto-bootstrapped on first launch)
- **iTerm2** preferences (manual import — see below)

## Install

Prerequisites: `zsh`, `vim`, `git`, `python3`, and (recommended) [Homebrew](https://brew.sh).

```sh
git clone https://github.com/vaintrub/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install
```

The installer will:
1. Symlink `vimrc`, `zshrc`, and `zsh_plugins.txt` into `$HOME`.
2. Initialise the `dotbot` submodule.
3. Install the **MesloLGS Nerd Font** Homebrew cask (recommended by Powerlevel10k).

On first `vim` launch, vim-plug will fetch and install the configured plugins automatically.

## iTerm2

Import `iterm/com.googlecode.iterm2.plist` manually via *Preferences → General → Preferences → Load preferences from a custom folder*.

## TODO

- Automate iTerm2 preference import
- Add a `Brewfile` for one-shot dependency install (`brew bundle`)
- Add `git`, `tmux`, and `ssh` configs
- Cross-OS support (Linux)
