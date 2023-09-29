# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="jonathan"

CASE_SENSITIVE="true"

HIST_STAMPS="mm/dd/yyyy"

plugins=(git
      zsh-syntax-highlighting
      sudo
      fzf)

source $ZSH/oh-my-zsh.sh

# User configuration

export EDITOR='nvim'

alias cl="printf '\33c\e[3J'"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
