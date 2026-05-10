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
# Vs the stock VSCode CLI, this function changes one thing: bare `code`
# (no args) opens a *.code-workspace in cwd if one exists, else opens
# cwd. Any explicit args pass through unchanged.
#
# In an SSH session ($SSH_CONNECTION set):
#   • Inside VSCode's *integrated* terminal — the env is already wired,
#     so dispatch to the real `code` shim and we're done.
#   • From any other terminal (iTerm2, tmux pane) — emit a
#     `vscode://vscode-remote/ssh-remote+<host>/<path>` URL. The iTerm2
#     Trigger turns it into `open <url>`, macOS routes it to VSCode, and
#     VSCode reuses an existing Remote-SSH window (or opens a new one).
#
# We deliberately do NOT try to find and forward to a Remote-SSH IPC
# socket ourselves: VSCode Server's `vscode-ipc-*.sock` files outlive
# the windows that created them (upstream bug — microsoft/vscode#153311
# and friends), and a live `connect()` is not the same as "the listener
# is actually still reachable on the Mac side". Half-dead sockets
# accept connections silently, give back rc=0, and lose the message.
# Letting VSCode resolve the URL itself avoids that whole class of
# zombie-socket guesswork.
#
# Housekeeping: while we're here, sweep VSCode's stale leftover sockets
# (cheap via zsh's built-in zsocket).
#
# Override host with `export VSCODE_REMOTE_HOST=<alias>` when the short
# hostname doesn't match your local ~/.ssh/config Host entry.
# Glob qualifiers: (N) null on no-match, (om) order by mtime newest-first,
# (.) regular files only.
code() {
    if (( $# == 0 )); then
        local -a ws=( *.code-workspace(N) )
        (( ${#ws} )) && set -- ${ws[1]} || set -- .
    fi

    # Local Mac: pass through to the real `code` binary verbatim.
    if [[ -z $SSH_CONNECTION ]]; then
        command code "$@"
        return
    fi

    # VSCode integrated Remote-SSH terminal: env is wired, dispatch directly.
    if [[ -n $VSCODE_IPC_HOOK_CLI ]] && command -v code >/dev/null 2>&1; then
        command code "$@"
        return
    fi

    # Housekeeping: sweep stale `vscode-ipc-*.sock` files VSCode Server
    # leaves behind on disconnect/crash. zsocket connect()s; ECONNREFUSED
    # on a dead UNIX socket is instant, so this costs ~one syscall per file.
    zmodload zsh/net/socket 2>/dev/null
    local s
    for s in /run/user/$UID/vscode-ipc-*.sock(Nom) ${TMPDIR:-/tmp}/vscode-ipc-*.sock(Nom); do
        if zsocket "$s" 2>/dev/null; then
            exec {REPLY}<&-                       # close probe fd
        else
            rm -f -- "$s"                          # dead socket — sweep
        fi
    done

    # Hand off to the local Mac's VSCode via vscode-remote URL. The iTerm2
    # Trigger fires `open <url>` and VSCode reuses an existing Remote-SSH
    # window (or opens a new one) — predictable, no socket guesswork.
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
export LANG=en_US.UTF-8

# Node version manager
command -v fnm > /dev/null && eval "$(fnm env)"

# Smart cd
command -v zoxide > /dev/null && eval "$(zoxide init zsh)"

# PATH
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/go/bin"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
