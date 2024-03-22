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
alias gs='git pull --rebase --autostash'
alias gsgp='gs && gp'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$0]=1; printf(((NR==1) ?"" : ":") $0) }}')"
