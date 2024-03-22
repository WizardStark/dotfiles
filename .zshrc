export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="catpuccin"

pathmunge() {
  if ! echo $PATH | /usr/bin/env egrep -q "(^|:)$1($|:)"; then
    if [ "$2" = "after" ]; then
      PATH=$PATH:$1
    else
      PATH=$1:$PATH
    fi
  fi
}

[ -f ~/.lcl.zsh ] && source ~/.lcl.zsh

pathmunge $HOME/local/bin
pathmunge $HOME/.local/bin
pathmunge $HOME/local/lib
CASE_SENSITIVE="true"
HIST_STAMPS="mm/dd/yyyy"

plugins=(git
  zsh-syntax-highlighting
  zsh-autosuggestions
  sudo
  fzf
  ssh-agent)

source $ZSH/oh-my-zsh.sh
export EDITOR='nvim'
alias vim="nvim"
alias cl="printf '\33c\e[3J'"
alias src='source ~/.zshrc'
alias erc='vim ~/.zshrc'
alias pls='sudo $(fc -ln -1)'
alias tmux='tmux -2'
alias ta='tmux a || tmux'
alias gpff='git pull --ff-only'
alias gs='git pull --ff-only || git pull --rebase --autostash'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$0]=1; printf(((NR==1) ?"" : ":") $0) }}')"
