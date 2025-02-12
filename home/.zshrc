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
    zinit snippet OMZP::command-not-found

    autoload -Uz compinit
    for dump in ~/.zcompdump(N.mh+24); do
      compinit
    done
    compinit -C

    zinit cdreplay -q

    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

    # Keybindings
    bindkey '^p' history-search-backward
    bindkey '^n' history-search-forward
    bindkey '^[w' kill-region

    # History
    HISTSIZE=500000
    HISTFILE=~/.zsh_history
    SAVEHIST=$HISTSIZE
    HISTDUP=erase
    setopt bang_hist
    setopt appendhistory
    setopt sharehistory
    setopt hist_ignore_space
    setopt hist_ignore_all_dups
    setopt hist_save_no_dups
    setopt hist_ignore_dups
    setopt hist_find_no_dups

    # Completion styling
    fzf_file_or_dir_preview="if [ -d {} ]; then eza -1 -a --color=always {} | head -200; else bat --style=header-filename,grid --color=always --line-range :500 {}; fi"
    dir_or_file_preview='if [ -d $realpath ]; then eza -1 -a --color=always $realpath | head -200; else bat --style=header-filename,grid --color=always --line-range :500 $realpath; fi'
    dir_preview='eza --color=always -1 -a --icons=always $realpath'

    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
    zstyle ':completion:*' menu no
    zstyle ':fzf-tab:complete:cd:*' fzf-preview $dir_preview
    zstyle ':fzf-tab:complete:bat:*' fzf-preview $dir_or_file_preview
    zstyle ':fzf-tab:complete:cat:*' fzf-preview $dir_or_file_preview
    zstyle ':fzf-tab:complete:eza:*' fzf-preview $dir_or_file_preview
    zstyle ':fzf-tab:complete:nvim:*' fzf-preview $dir_or_file_preview
    zstyle ':fzf-tab:complete:less:*' fzf-preview $dir_or_file_preview
    zstyle ':fzf-tab:complete:head:*' fzf-preview $dir_or_file_preview
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview $dir_preview

    export FZF_CTRL_T_OPTS="--preview '$fzf_file_or_dir_preview'"
    export FZF_ALT_C_OPTS="--preview 'eza --color=always {} | head -200'"

    _fzf_comprun() {
      local command=$1
      shift

      case "$command" in
        export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
        ssh)          fzf --preview 'dig {}'                   "$@" ;;
        *)            fzf --preview "$fzf_file_or_dir_preview" "$@" ;;
      esac
    }

    #Allow matching of . files to allow for smoother fzf-tabbing
    setopt globdots

    # Allow comments in commandline
    setopt interactivecomments

    alias ls="eza --color=always -1 -a --icons=always"

    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    eval "$(zoxide init --cmd cd zsh)"

    if [ -z "$(pgrep ssh-agent)" ] ; then
        eval $(ssh-agent) > /dev/null 2>&1
        echo $SSH_AUTH_SOCK > ~/.ssh/.agent_socket
    else
        export SSH_AUTH_SOCK=$(cat ~/.ssh/.agent_socket)
    fi
fi

show_blame() {
  git ls-files | while read f; do git blame -w --line-porcelain -- "$f" | grep -I '^author '; done | sort -f | uniq -ic | sort -n
}

export EDITOR='nvim'
alias vim="nvim"
alias cl="printf '\33c\e[3J'"
alias src='source ~/.zshrc'
alias srcall='source ~/.zshenv; source ~/.zprofile; source ~/.zshrc'
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
alias vup='nvim --headless "+Lazy! sync" +qa'

[ -f ~/.lcl.zshrc ] && source ~/.lcl.zshrc

if [ -d ~/dotfile-shards/ ]; then
  for f in ~/dotfile-shards/*; do
    source $f
  done
fi

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$1]=1; printf(((NR==1) ?"" : ":") $0) }}')"
