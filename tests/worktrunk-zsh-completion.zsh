#!/usr/bin/env zsh
# Run from any directory: zsh -f tests/worktrunk-zsh-completion.zsh
set -eu

repo_root="${0:A:h:h}"
export HOME="$(mktemp -d)"
trap 'rm -rf "$HOME"' EXIT
export OVERRIDE_ZSH_CUSTOMIZATION=1
require() { return 1 }
compdef() { : }
source "$repo_root/home/.zshrc"
cd "$repo_root"

fixture='{"schema":2,"items":[
  {"branch":"main","worktree":{"current":true}},
  {"branch":"feature/one","worktree":{"current":false}},
  {"branch":"unattached","worktree":null},
  {"branch":null,"worktree":{"current":false}}
]}'
wt() { print -r -- "$fixture" }
_wanted() { shift 3; "$@" }
compadd() { shift; candidates=("$@") }

_git_worktree_branch_names
[[ "${(j:,:)candidates}" == 'main,feature/one' ]] || {
    print -u2 -- "Unexpected completion candidates: ${(j:,:)candidates}"
    exit 1
}

# Pruning should only consider non-current worktrees, not unattached branches.
git() {
    if [[ "$1" == branch ]]; then
        print -l main feature/one unattached
    else
        command git "$@"
    fi
}
prune_output="$(_git_worktree_prune main)"
[[ "$prune_output" == *'Would prune feature/one'* &&
   "$prune_output" != *'Would prune main'* &&
   "$prune_output" != *'Would prune unattached'* ]] || {
    print -u2 -- "Unexpected prune candidates: $prune_output"
    exit 1
}
print -- 'worktrunk schema-2 completion and pruning: OK'
