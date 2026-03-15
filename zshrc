# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- Antidote Plugin Manager ---
DISABLE_MAGIC_FUNCTIONS=true

if [[ ! -d ${ZDOTDIR:-$HOME}/.antidote ]]; then
    git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-$HOME}/.antidote
fi
source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load

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
