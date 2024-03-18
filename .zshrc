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
ZSH_THEME="catpuccin"
CASE_SENSITIVE="true"
HIST_STAMPS="mm/dd/yyyy"

VI_MODE_SET_CURSOR=true
bindkey -M viins 'jf' vi-cmd-mode

source ~/.zsh-catpuccin/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh

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

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS=" \
    --color=bg+:#313244,bg:#11111b,spinner:#f5e0dc,hl:#f38ba8 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

[ -f ~/.lcl.zsh ] && source ~/.lcl.zsh

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$0]=1; printf(((NR==1) ?"" : ":") $0) }}')"
