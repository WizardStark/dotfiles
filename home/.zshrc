if [[ ! -v OVERRIDE_ZSH_CUSTOMIZATION ]]; then
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
      source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi

    ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

    if [ ! -d "$ZINIT_HOME" ]; then
       mkdir -p "$(dirname $ZINIT_HOME)"
       git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    fi

    source "${ZINIT_HOME}/zinit.zsh"

    zinit ice depth=1; zinit light romkatv/powerlevel10k

    zinit light zsh-users/zsh-syntax-highlighting
    zinit light zsh-users/zsh-completions
    zinit light zsh-users/zsh-autosuggestions
    zinit light Aloxaf/fzf-tab

    zinit snippet OMZP::git
    zinit snippet OMZP::sudo
    zinit snippet OMZP::ssh-agent
    zinit snippet OMZP::command-not-found

    zstyle :omz:plugins:ssh-agent quiet yes
    zstyle :omz:plugins:ssh-agent lazy yes

    autoload -Uz compinit
    for dump in ~/.zcompdump(N.mh+24); do
      compinit
    done
    compinit -C

    zinit cdreplay -q

    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

    # Keybindings
    # bindkey -e
    bindkey '^p' history-search-backward
    bindkey '^n' history-search-forward
    bindkey '^[w' kill-region

    # History
    HISTSIZE=50000
    HISTFILE=~/.zsh_history
    SAVEHIST=$HISTSIZE
    HISTDUP=erase
    setopt appendhistory
    setopt sharehistory
    setopt hist_ignore_space
    setopt hist_ignore_all_dups
    setopt hist_save_no_dups
    setopt hist_ignore_dups
    setopt hist_find_no_dups

    # Completion styling
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*' menu no
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -A --color $realpath'
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls -A --color $realpath'

    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    if [ -x "$(command -v zoxide)" ]; then
      eval "$(zoxide init zsh)"
    fi
fi

show_blame() {
  git ls-files | while read f; do git blame -w --line-porcelain -- "$f" | grep -I '^author '; done | sort -f | uniq -ic | sort -n
}

export EDITOR='nvim'
alias vim="nvim"
alias cl="printf '\33c\e[3J'"
alias ls='ls --color'
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
alias gfc="git add . && gc --amend --no-edit"

[ -f ~/.lcl.zshrc ] && source ~/.lcl.zshrc

if [ -d ~/dotfile-shards/ ]; then
  for f in ~/dotfile-shards/*; do
    source $f
  done
fi

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$1]=1; printf(((NR==1) ?"" : ":") $0) }}')"
