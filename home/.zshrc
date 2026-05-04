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

    if ! [[ -n "$NVIM" ]]; then
        zinit ice depth=1; zinit light jeffreytse/zsh-vi-mode
        zvm_after_init_commands+=('[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh')
    fi

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
    zstyle ':fzf-tab:complete:lsd:*' fzf-preview $dir_preview
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
        export|unset) fzf --preview "eval 'echo ${}'"          "$@" ;;
        ssh)          fzf --preview 'dig {}'                   "$@" ;;
        *)            fzf --preview "$fzf_file_or_dir_preview" "$@" ;;
      esac
    }

    #Allow matching of . files to allow for smoother fzf-tabbing
    setopt globdots

    # Allow comments in commandline
    setopt interactivecomments

    if require eza; then
        alias ls="eza --color=always -1 -a --icons=always"
    fi

    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    eval "$(zoxide init --cmd cd zsh)"
fi

show_blame() {
  git ls-files | while read f; do git blame -w --line-porcelain -- "$f" | grep -I '^author '; done | sort -f | uniq -ic | sort -n
}

lsd() { (
    cd "${1:-$HOME}" &&
        echo $(pwd) &&
        ls
); }

git_grep_all() {
    if [ $# -eq 0 ]; then
        echo "Usage: git_grep_all <pattern>"
        return 1
    fi
    
    local pattern="$1"
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Not in a git repository"
        return 1
    fi
    
    for branch in $(git branch --format="%(refname:short)" 2>/dev/null); do
        local matches=$(git grep -F "$pattern" "$branch" -- 2>/dev/null)
        if [ -n "$matches" ]; then
            echo "Branch: $branch"
            echo "$matches" | sed 's/^/  /'
            echo
        fi
    done
    
    return 0
}

if [ -v NVIM ]; then
    export GIT_EDITOR='nvr --remote-wait'
    alias nvim="nvim --server $NVIM --remote"
else
    export GIT_EDITOR='nvim'
fi

wt() {
    local wt_bin
    wt_bin="$(whence -p wt)"

    if [[ -z "$wt_bin" ]]; then
        echo "wt is not installed or not on PATH"
        return 1
    fi

    local directive_cd_file directive_exec_file
    directive_cd_file="$(mktemp)" || return 1
    directive_exec_file="$(mktemp)" || {
        rm -f "$directive_cd_file"
        return 1
    }

    WORKTRUNK_SHELL=zsh \
    WORKTRUNK_DIRECTIVE_CD_FILE="$directive_cd_file" \
    WORKTRUNK_DIRECTIVE_EXEC_FILE="$directive_exec_file" \
    "$wt_bin" "$@"
    local exit_code=$?

    if [[ -s "$directive_exec_file" ]]; then
        source "$directive_exec_file"
    fi

    if [[ -s "$directive_cd_file" ]]; then
        local target_dir
        target_dir="$(<"$directive_cd_file")"
        [[ -n "$target_dir" ]] && builtin cd "$target_dir"
    fi

    rm -f "$directive_cd_file" "$directive_exec_file"
    return $exit_code
}

gwtc() {
    if [ $# -ne 1 ]; then
        echo "Usage: gwtc <branch-name>"
        return 1
    fi

    wt switch --create "$1"
}

gwtcs() {
    if [ $# -gt 1 ]; then
        echo "Usage: gwtcs [branch-name]"
        return 1
    fi

    if [ $# -eq 1 ]; then
        wt switch --create "$1" || wt switch "$1" || return 1
    fi

    ~/.config/tmux/ensure_opencode_tmux_session.sh
}

gwtd() {
    if [ $# -ne 1 ]; then
        echo "Usage: gwtd <branch-name>"
        return 1
    fi

    wt remove "$1"
}

gwtcd() {
    if [ $# -ne 1 ]; then
        echo "Usage: gwtcd <branch-name>"
        return 1
    fi

    wt switch "$1"
}

gwtm() {
    wt switch ^
}

_git_worktree_prune() {
    local apply_changes=0
    if [[ "$1" == "--apply" ]]; then
        apply_changes=1
        shift
    fi

    local base_ref="${1:-origin/main}"
    local remote_name

    git rev-parse --path-format=absolute --git-common-dir >/dev/null 2>&1 || {
        echo "Not in a git repository"
        return 1
    }

    remote_name="${base_ref%%/*}"
    if [[ "$base_ref" == */* ]] && git remote get-url "$remote_name" >/dev/null 2>&1; then
        echo "Fetching $remote_name..."
        git fetch "$remote_name" || return 1
    fi

    if ! git rev-parse --verify --quiet "$base_ref" >/dev/null; then
        echo "Base ref not found: $base_ref"
        echo "Try: git fetch origin"
        return 1
    fi

    local merged_branches worktree_branches
    merged_branches="$(git branch --format='%(refname:short)' --merged "$base_ref")"
    worktree_branches="$(wt list --format=json | jq -r '.[] | select(.kind == "worktree" and .branch != null and (.is_current | not)) | .branch')"

    if [[ -z "$merged_branches" || -z "$worktree_branches" ]]; then
        echo "No merged worktrees eligible for pruning against $base_ref"
        return 0
    fi

    local found_candidates=0
    local branch_name
    while IFS= read -r branch_name; do
        [[ -z "$branch_name" ]] && continue

        if ! printf '%s\n' "$merged_branches" | grep -Fx -- "$branch_name" >/dev/null 2>&1; then
            continue
        fi

        found_candidates=1
        if (( apply_changes )); then
            echo "Pruning $branch_name"
            wt remove "$branch_name" || continue
        else
            echo "Would prune $branch_name"
        fi
    done <<< "$worktree_branches"

    if (( ! found_candidates )); then
        echo "No merged worktrees eligible for pruning against $base_ref"
        return 0
    fi

    if (( ! apply_changes )); then
        echo
        echo "Run 'gwtprune_apply $base_ref' to delete the worktrees listed above"
    fi
}

gwtprune() {
    _git_worktree_prune "$@"
}

gwtprune_apply() {
    _git_worktree_prune --apply "$@"
}

_git_worktree_branch_names() {
    git rev-parse --path-format=absolute --git-common-dir >/dev/null 2>&1 || return 1

    local -a branch_names
    local expl
    branch_names=("${(@f)$(wt list --format=json | jq -r '.[] | select(.branch != null) | .branch')}" )

    (( ${#branch_names[@]} )) || return 0
    _wanted worktrees expl 'git worktree' compadd -- "${branch_names[@]}"
}

compdef _git gwtc=git-checkout
compdef _git gwtcs=git-checkout
compdef _git_worktree_branch_names gwtd
compdef _git_worktree_branch_names gwtcd

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
alias gst='git status -s'
alias gsgp='gs && gp'
alias gsbl=show_blame
alias gfc="git add . && gc --amend --no-edit"
alias glc="gwip && gunwip"
alias vup='nvim --headless "+PackUpdate" +qa'

if require mise && require usage; then
    eval "$(mise completion zsh)"
fi

[ -f ~/.lcl.zshrc ] && source ~/.lcl.zshrc

if [ -d ~/dotfile-shards/ ]; then
  for f in ~/dotfile-shards/*; do
    source $f
  done
fi

export PATH="$(echo "$PATH" | /usr/bin/env awk 'BEGIN { RS=":"; } { sub(sprintf("%c$", 10), ""); if (A[$0]) {} else { A[$1]=1; printf(((NR==1) ?"" : ":") $0) }}')"
