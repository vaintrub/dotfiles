ZSH_BASE=$HOME/.zsh # Base directory for ZSH configuration

source $ZSH_BASE/.antigen/antigen.zsh # Load Antigen
antigen use oh-my-zsh

# Terminal stuff
antigen bundle git
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-history-substring-search
antigen bundle zsh-users/zsh-autosuggestions

case `uname` in
  Darwin)
    antigen bundle osx
  ;;
  Linux)
  # Stuff for linux
  ;;
esac

if [[ -n $SSH_CONNECTION ]]; then
    antigen theme kafeitu
else
    antigen theme robbyrussell
fi

antigen apply

alias zshconfig="vim ~/.zshrc"


