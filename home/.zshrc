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

    _venv_completion() {
        local -a venvs
        venvs=($HOME/.virtualenvs/*(/:t))
        compadd -a venvs
    }

    compdef _venv_completion venv rmvenv

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

git_worktree() {
    if [ $# -ne 2 ]; then
        echo "Usage: git_worktree <create|delete> <branch-name>"
        return 1
    fi

    local action="$1"
    local branch_name="$2"
    local git_common_dir repo_name worktree_root worktree_path

    git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
        echo "Not in a git repository"
        return 1
    }

    repo_name="${git_common_dir:h:t}"
    worktree_root="$HOME/projects/worktrees/$repo_name"
    worktree_path="$worktree_root/$branch_name"

    case "$action" in
        create)
            if [ -e "$worktree_path" ]; then
                echo "Worktree path already exists: $worktree_path"
                return 1
            fi

            mkdir -p "${worktree_path:h}" || return 1

            if git show-ref --verify --quiet "refs/heads/$branch_name"; then
                git worktree add "$worktree_path" "$branch_name" || return 1
            else
                git worktree add -b "$branch_name" "$worktree_path" || return 1
            fi
            ;;
        delete)
            if [ -d "$worktree_path" ] || [ -f "$worktree_path/.git" ]; then
                git worktree remove "$worktree_path" || return 1
            else
                echo "Worktree path not found: $worktree_path"
            fi

            git branch -d "$branch_name"
            ;;
        *)
            echo "Usage: git_worktree <create|delete> <branch-name>"
            return 1
            ;;
    esac
}

gwtc() {
    git_worktree create "$@"
}

gwtd() {
    git_worktree delete "$@"
}

gwtcd() {
    if [ $# -ne 1 ]; then
        echo "Usage: gwtcd <branch-name>"
        return 1
    fi

    local branch_name="$1"
    local git_common_dir repo_name worktree_path

    git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
        echo "Not in a git repository"
        return 1
    }

    repo_name="${git_common_dir:h:t}"
    worktree_path="$HOME/projects/worktrees/$repo_name/$branch_name"

    if [ ! -d "$worktree_path" ]; then
        echo "Worktree path not found: $worktree_path"
        return 1
    fi

    cd "$worktree_path"
}

gwtm() {
    local git_common_dir main_repo_dir

    git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
        echo "Not in a git repository"
        return 1
    }

    main_repo_dir="${git_common_dir:h}"

    if [ ! -d "$main_repo_dir" ]; then
        echo "Main repo path not found: $main_repo_dir"
        return 1
    fi

    cd "$main_repo_dir"
}

_git_worktree_prune() {
    local apply_changes=0
    if [[ "$1" == "--apply" ]]; then
        apply_changes=1
        shift
    fi

    local base_ref="${1:-origin/main}"
    local git_common_dir repo_name worktree_root current_dir remote_name

    git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
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

    repo_name="${git_common_dir:h:t}"
    worktree_root="$HOME/projects/worktrees/$repo_name"
    current_dir="$PWD"

    if [ ! -d "$worktree_root" ]; then
        echo "No worktree directory found: $worktree_root"
        return 0
    fi

    local -a gitdirs
    gitdirs=("$worktree_root"/**/.git(N))

    if (( ${#gitdirs[@]} == 0 )); then
        echo "No linked worktrees found under $worktree_root"
        return 0
    fi

    local found_candidates=0
    local gitdir worktree_path branch_name status_output

    for gitdir in "${gitdirs[@]}"; do
        worktree_path="${gitdir:h}"
        branch_name="${gitdir#$worktree_root/}"
        branch_name="${branch_name%/.git}"

        if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
            echo "Skipping $branch_name (local branch missing)"
            continue
        fi

        if ! git merge-base --is-ancestor "$branch_name" "$base_ref"; then
            continue
        fi

        if [[ "$current_dir" == "$worktree_path" || "$current_dir" == "$worktree_path"/* ]]; then
            echo "Skipping $branch_name (currently inside worktree)"
            continue
        fi

        status_output=$(git -C "$worktree_path" status --porcelain 2>/dev/null)
        if [ -n "$status_output" ]; then
            echo "Skipping $branch_name (worktree has uncommitted changes)"
            continue
        fi

        found_candidates=1
        if (( apply_changes )); then
            echo "Pruning $branch_name"
            git worktree remove "$worktree_path" || continue
            git branch -d "$branch_name" || continue
        else
            echo "Would prune $branch_name"
        fi
    done

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
    local git_common_dir repo_name worktree_root
    git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
    repo_name="${git_common_dir:h:t}"
    worktree_root="$HOME/projects/worktrees/$repo_name"

    local -a gitdirs branch_names
    gitdirs=("$worktree_root"/**/.git(N))
    branch_names=("${gitdirs[@]#$worktree_root/}")
    branch_names=("${branch_names[@]%/.git}")

    (( ${#branch_names[@]} )) || return 0
    compadd -- "${branch_names[@]}"
}

_git_worktree_completion() {
    _arguments \
        '1:action:(create delete)' \
        '2:branch name:->branch_name'

    case "$state" in
        branch_name)
            if [[ "${words[2]}" == "delete" ]]; then
                _git_worktree_branch_names
            fi
            ;;
    esac
}

compdef _git_worktree_completion git_worktree
compdef _git_worktree_branch_names gwtd gwtcd

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
alias vup='nvim --headless "+Lazy! sync" +qa'

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
