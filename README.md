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

Prefix is **`C-a`** (screen-style). Status bar, bindings, and overall theme inherit from gpakosz/.tmux unchanged — see their [docs](https://github.com/gpakosz/.tmux#bindings). Useful defaults out of the box: `prefix h/j/k/l` for pane navigation, `prefix -` / `prefix _` for splits, `prefix e` to edit `.tmux.conf.local`, `prefix r` to reload, `prefix m` to toggle mouse.

Customizations live in `tmux/tmux.conf.local` (symlinked to `~/.tmux.conf.local`):

- **Prefix `C-a`** as the sole prefix (verbatim from gpakosz's documented `set -g prefix C-a` snippet)
- **Mouse on** — wheel scrolls tmux scrollback, drag-resizes panes, click selects
- **`mode-keys vi`** — copy-mode uses vim navigation (gpakosz ships vi-bindings; this setting activates them)
- **`set-clipboard on`** (OSC 52) — vim/nvim `"+y` inside tmux reaches the macOS pasteboard
- **`tmux_conf_copy_to_os_clipboard=true`** — explicit copy-mode `y` writes to `pbcopy`
- **`tmux_conf_24b_colour=true`** — forces 24-bit colour so Powerlevel10k renders identically inside tmux (gpakosz default `auto` depends on `$COLORTERM`, which drops over SSH)
- **`COLORTERM=truecolor` propagated** to inner shells via `set-environment -g`
- **`history-limit 50000`** — gpakosz default 5000 is small

No plugin manager. [TPM](https://github.com/tmux-plugins/tpm) has been dormant since Feb 2023; the only plugin feature we needed (`tmux-yank` for `pbcopy`) is already covered by gpakosz natively.

### Gotchas

- iTerm2 **≥3.5.11** required — `3.5.0beta6`–`3.5.0beta10` had a regression where Nerd Font glyphs disappear inside tmux panes ([iTerm2 #10879](https://gitlab.com/gnachman/iterm2/-/issues/10879)).
- If Nerd Font glyphs still render oddly, enable iTerm2 → *Preferences → Profiles → Text → "Use built-in Powerline glyphs"*.
- If Powerlevel10k complains about an *instant-prompt* warning inside tmux, add `typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet` to `~/.p10k.zsh`.

## iTerm2

Import `iterm/com.googlecode.iterm2.plist` manually via *Preferences → General → Preferences → Load preferences from a custom folder*.

## TODO

- Automate iTerm2 preference import
- Add a `Brewfile` for one-shot dependency install (`brew bundle`)
- Add `git` and `ssh` configs
- Cross-OS support (Linux)
