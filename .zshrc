export ZSH="$HOME/.oh-my-zsh"

pathmunge() {
  if ! echo $PATH | /usr/bin/env egrep -q "(^|:)$1($|:)"; then
    if [ "$2" = "after" ]; then
      PATH=$PATH:$1
    else
      PATH=$1:$PATH
    fi
  fi
}

pathmunge $HOME/local/bin
pathmunge $HOME/.local/bin
pathmunge $HOME/local/lib
ZSH_THEME="jonathan"
CASE_SENSITIVE="true"
HIST_STAMPS="mm/dd/yyyy"

VI_MODE_SET_CURSOR=true
bindkey -M viins 'jf' vi-cmd-mode

plugins=(git
  vi-mode
  zsh-syntax-highlighting
  zsh-autosuggestions
  sudo
  fzf)

source $ZSH/oh-my-zsh.sh
export EDITOR='nvim'
alias vim="nvim"
alias cl="printf '\33c\e[3J'"
alias src='source ~/.zshrc'
alias erc='vim ~/.zshrc'
alias pls='sudo $(fc -ln -1)'
alias ta='tmux a || tmux'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.lcl.zsh ] && source ~/.lcl.zsh

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$0]=1; printf(((NR==1) ?"" : ":") $0) }}')"
