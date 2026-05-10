# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Antidote Plugin Manager (static-cache mode) ---
DISABLE_MAGIC_FUNCTIONS=true

if [[ ! -d ${ZDOTDIR:-$HOME}/.antidote ]]; then
    git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-$HOME}/.antidote
fi

zsh_plugins=${ZDOTDIR:-$HOME}/.zsh_plugins
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
    (
        source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
        antidote bundle <${zsh_plugins}.txt >${zsh_plugins}.zsh
    )
fi
source ${zsh_plugins}.zsh

# --- `code` from any terminal ---
# No-args default: if a *.code-workspace file exists in cwd, open it; else cwd.
# In an SSH session ($SSH_CONNECTION set), three further tiers bridge back to
# the local Mac's VSCode:
#   1. VSCode integrated terminal: env is already wired → pass through.
#   2. A Remote-SSH IPC socket exists: forward to it (any iTerm2/tmux pane).
#   3. Bootstrap: print `vscode://…` URL; iTerm2 Trigger runs `open` on it.
# Glob qualifiers: (N) = null on no-match, (om) = sort by mtime newest-first,
# (.) = files only. Override the SSH-config alias with
# `export VSCODE_REMOTE_HOST=<alias>` when the short hostname differs.
code() {
    # Smart no-args default — applies on both local and SSH.
    if (( $# == 0 )); then
        local -a ws=( *.code-workspace(N) )
        (( ${#ws} )) && set -- ${ws[1]} || set -- .
    fi

    # Local Mac: real `code` on PATH.
    if [[ -z $SSH_CONNECTION ]]; then
        command code "$@"
        return
    fi

    # SSH tier 1.
    if [[ -n $VSCODE_IPC_HOOK_CLI ]] && command -v code >/dev/null 2>&1; then
        command code "$@"
        return
    fi

    # SSH tier 2.
    local -a sock=( /run/user/$UID/vscode-ipc-*.sock(Nom) ${TMPDIR:-/tmp}/vscode-ipc-*.sock(Nom) )
    local -a shim=( $HOME/.vscode-server/cli/servers/*/server/bin/remote-cli/code(Nom.) )
    if [[ -n ${sock[1]} && -x ${shim[1]} ]]; then
        VSCODE_IPC_HOOK_CLI=${sock[1]} ${shim[1]} "$@"
        return
    fi

    # SSH tier 3 bootstrap. URL-encode spaces (iTerm2 regex stops at whitespace).
    # ${HOST%%.*} strips FQDN suffix (e.g. "host.local" → "host") via zsh builtin
    # — no subprocess, no PATH dependency.
    local path=${1:A}
    printf 'vscode://vscode-remote/ssh-remote+%s%s\n' \
        "${VSCODE_REMOTE_HOST:-${HOST%%.*}}" "${path// /%20}"
}

# VSCode `code` CLI on macOS: `brew install --cask` doesn't add it to PATH.
[[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]] \
    && export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

# --- Aliases ---
alias zshconfig="vim ~/.zshrc"

# --- Environment ---
export LANG=${LANG:-en_US.UTF-8}

# Node version manager
command -v fnm > /dev/null && eval "$(fnm env)"

# Smart cd
command -v zoxide > /dev/null && eval "$(zoxide init zsh)"

# PATH
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/go/bin"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
