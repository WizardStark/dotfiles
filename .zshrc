# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export PATH=$HOME/local/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export LD_LIBRARY_PATH=$HOME/local/lib:$LD_LIBRARY_PATH
export MANPATH=$HOME/local/share/man:$MANPATH
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="jonathan"

CASE_SENSITIVE="true"

HIST_STAMPS="mm/dd/yyyy"

plugins=(git
      zsh-syntax-highlighting
      zsh-autosuggestions
      sudo
      fzf)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='nvim'
alias vim='nvim'

alias cl="printf '\33c\e[3J'"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
