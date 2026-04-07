#!/usr/bin/env bash

set -euo pipefail

git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  echo "Not in a git repository" >&2
  exit 1
}

repo_name="$(basename "$(dirname "$git_common_dir")")"
session_name="$repo_name"

sanitize_window_name() {
  printf '%s' "$1" | tr '/:.' '-'
}

ensure_tmux_window() {
  local workdir="$1"
  local window_name="$2"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    if tmux list-windows -t "$session_name" -F '#W' | grep -Fx "$window_name" >/dev/null 2>&1; then
      echo "Tmux window already exists: $session_name:$window_name" >&2
    else
      tmux new-window -d -t "$session_name" -n "$window_name" -c "$workdir"
    fi
  else
    tmux new-session -d -s "$session_name" -n "$window_name" -c "$workdir"
  fi

  tmux send-keys -t "$session_name:$window_name" "opencode --port" C-m
}

if [[ $# -eq 0 ]]; then
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    echo "Unable to determine current branch" >&2
    exit 1
  }

  workdir="$(pwd)"
  window_name="$(sanitize_window_name "$current_branch")"

  ensure_tmux_window "$workdir" "$window_name"

  echo "Using repository path: $workdir"
  echo "Using tmux session: $session_name"
  echo "Created tmux window: $window_name"
  exit 0
fi

if [[ $# -gt 2 ]]; then
  echo "Usage: create_worktree_session.sh [branch-name] [window-name]" >&2
  exit 1
fi

branch_name="$1"
requested_window_name="${2:-}"
worktree_root="$HOME/projects/worktrees/$repo_name"
worktree_path="$worktree_root/$branch_name"
default_window_name="$(sanitize_window_name "$branch_name")"
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

ensure_tmux_window "$worktree_path" "$window_name"

echo "Created worktree: $worktree_path"
echo "Using tmux session: $session_name"
echo "Created tmux window: $window_name"
