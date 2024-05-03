autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit

if [[ ! -v OVERRIDE_OMZ_SETUP ]]; then
  plugins=(git
    zsh-syntax-highlighting
    zsh-autosuggestions
    sudo
    fzf
    per-directory-history
    ssh-agent)

  source $ZSH/oh-my-zsh.sh
fi

show_blame() {
  git ls-files | while read f; do git blame -w --line-porcelain -- "$f" | grep -I '^author '; done | sort -f | uniq -ic | sort -n
}

kill_all_but_last() {
  process="$1"
  last_pid=$(pgrep -f "$process" | tail -1)
  for pid in $(pgrep -f "$process"); do
    if [ "$pid" != "$last_pid" ]; then
      kill "$pid"
    fi
  done
}

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
alias gst='git status -suall'
alias gsgp='gs && gp'
alias gsbl=show_blame
alias nkc="kill_all_but_last nvim"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f ~/.lcl.zshrc ] && source ~/.lcl.zshrc

if [ -x "$(command -v zoxide)" ]; then
  eval "$(zoxide init zsh)"
fi

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$1]=1; printf(((NR==1) ?"" : ":") $0) }}')"
