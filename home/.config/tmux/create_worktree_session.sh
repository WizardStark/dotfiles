#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: create_worktree_session.sh <branch-name> [window-name]" >&2
  exit 1
fi

branch_name="$1"
requested_window_name="${2:-}"

git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  echo "Not in a git repository" >&2
  exit 1
}

repo_name="$(basename "$(dirname "$git_common_dir")")"
worktree_root="$HOME/projects/worktrees/$repo_name"
worktree_path="$worktree_root/$branch_name"
session_name="$repo_name"
default_window_name="$(printf '%s' "$branch_name" | tr '/:.' '-')"
window_name="${requested_window_name:-$default_window_name}"

mkdir -p "$worktree_root"

if [[ -e "$worktree_path" ]]; then
  echo "Using existing worktree: $worktree_path"
else
  if git show-ref --verify --quiet "refs/heads/$branch_name"; then
    git worktree add "$worktree_path" "$branch_name"
  else
    git worktree add -b "$branch_name" "$worktree_path"
  fi
fi

if tmux has-session -t "$session_name" 2>/dev/null; then
  if tmux list-windows -t "$session_name" -F '#W' | grep -Fx "$window_name" >/dev/null 2>&1; then
    echo "Tmux window already exists: $session_name:$window_name" >&2
    echo "Created worktree: $worktree_path"
    exit 0
  fi

  tmux new-window -d -t "$session_name" -n "$window_name" -c "$worktree_path"
else
  tmux new-session -d -s "$session_name" -n "$window_name" -c "$worktree_path"
fi

echo "Created worktree: $worktree_path"
echo "Using tmux session: $session_name"
echo "Created tmux window: $window_name"
