# Dotfiles

Personal cross-platform (macOS + Linux) dotfiles managed with [dotbot](https://github.com/anishathalye/dotbot).

Includes:
- **zsh** with [antidote](https://github.com/mattmc3/antidote) (static-cache) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **vim** with [vim-plug](https://github.com/junegunn/vim-plug) (auto-bootstrapped on first launch)
- **tmux** with [gpakosz/.tmux](https://github.com/gpakosz/.tmux) ("oh-my-tmux") vendored as a submodule
- **iTerm2** preferences (macOS only, manual import)

`./install` is OS-aware via dotbot's native `if:` directive — same repo, same script, both platforms.

## Install — macOS

Prerequisites: `zsh`, `vim`, `tmux`, `git`, `python3`, [Homebrew](https://brew.sh).

```sh
git clone https://github.com/vaintrub/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install
```

Installs **MesloLGS Nerd Font** via Homebrew cask. Idempotent on re-run.

## Install — Linux

Prerequisites: `zsh git vim tmux curl fontconfig python3` (python3 is required by dotbot — preinstalled on most distros but absent on minimal Alpine/distroless images). Optional for tmux yank-to-clipboard: `xsel` (X11) or `wl-clipboard` (Wayland).

```sh
sudo apt install zsh git vim tmux curl fontconfig python3 xsel   # Debian/Ubuntu
# or: sudo dnf install zsh git vim tmux curl fontconfig python3 xsel  # Fedora
chsh -s "$(command -v zsh)"

git clone https://github.com/vaintrub/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install
```

The installer downloads MesloLGS NF (4 `.ttf` files from the official p10k media repo) into `~/.local/share/fonts/` and runs `fc-cache`. No root needed.

**Headless SSH servers**: the font install is skipped automatically (`$SSH_CONNECTION` is set and no `$DISPLAY`/`$WAYLAND_DISPLAY`). Glyphs render on the local terminal emulator — the remote machine never sees them.

## tmux

Prefix is **`C-a`** (screen-style). Status bar, bindings, theme inherit from gpakosz/.tmux unchanged — see their [docs](https://github.com/gpakosz/.tmux#bindings). Useful defaults out of the box: `prefix h/j/k/l` for pane navigation, `prefix -` / `prefix _` for splits, `prefix e` to edit `.tmux.conf.local`, `prefix r` to reload, `prefix m` to toggle mouse.

Customizations in `tmux/tmux.conf.local`:

- **Prefix `C-a`** as the sole prefix (verbatim from gpakosz's documented snippet)
- **`mouse on`** — wheel scrolls tmux scrollback, drag-resizes panes, click selects
- **`mode-keys vi`** — copy-mode uses vim navigation (gpakosz ships vi-bindings; this activates them)
- **`set-clipboard on`** (OSC 52) — vim/nvim `"+y` inside tmux reaches the system clipboard
- **`tmux_conf_copy_to_os_clipboard=true`** — explicit copy-mode `y` writes to the OS clipboard (`pbcopy` on macOS; `xsel`/`xclip`/`wl-copy` on Linux, auto-detected by gpakosz)
- **`tmux_conf_24b_colour=true`** — forces 24-bit colour so Powerlevel10k renders identically inside tmux
- **`COLORTERM=truecolor`** propagated to inner shells
- **`history-limit 50000`** — gpakosz default 5000 is small

No plugin manager. [TPM](https://github.com/tmux-plugins/tpm) has been dormant since Feb 2023; the only plugin feature we needed (`tmux-yank` for OS clipboard) is already covered by gpakosz natively.

### Gotchas

- iTerm2 **≥3.5.11** required — `3.5.0beta6`–`3.5.0beta10` had a regression where Nerd Font glyphs disappear inside tmux panes ([iTerm2 #10879](https://gitlab.com/gnachman/iterm2/-/issues/10879)).
- If Nerd Font glyphs render oddly inside tmux, enable iTerm2 → *Preferences → Profiles → Text → "Use built-in Powerline glyphs"*.
- If Powerlevel10k complains about an *instant-prompt* warning inside tmux, add `typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet` to `~/.p10k.zsh`.
- Linux without `xsel`/`xclip`/`wl-clipboard`: tmux copy-mode `y` saves to the tmux paste buffer only, not the system clipboard. The installer prints a one-line notice.
- Linux X11 vim — `clipboard^=unnamed,unnamedplus` writes to both `*` (PRIMARY/middle-click) and `+` (CLIPBOARD/Ctrl-V).

## iTerm2 (macOS only)

Import `iterm/com.googlecode.iterm2.plist` manually via *Preferences → General → Preferences → Load preferences from a custom folder*.

## How OS conditionals work

Single `.install.conf.yaml`. The shell hook contains `case "$(uname -s)"` for the only OS-divergent step (font install: Homebrew cask on macOS, `curl` + `fc-cache` on Linux). Everything else is OS-neutral — zsh sees the OMZ `macos` plugin define harmless aliases/functions on Linux that simply never get invoked there.

## TODO

- Automate iTerm2 preference import
- Add a `Brewfile` (macOS) / `apt`/`dnf` bootstrapping (Linux) for one-shot dep install
- Add `git` and `ssh` configs
