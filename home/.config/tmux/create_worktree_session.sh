#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found on PATH: $1"
}

require_command git
require_command tmux
require_command opencode

git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  fail "Not in a git repository"
}

repo_name="$(basename "$(dirname "$git_common_dir")")"
session_name="$repo_name"

sanitize_window_name() {
  printf '%s' "$1" | tr '/:.' '-'
}

ensure_tmux_window() {
  local workdir="$1"
  local window_name="$2"
  local target="$session_name:$window_name"
  local pane_id=""
  local first_pane_id=""
  local pane_dead=""
  local pane_command=""

  if tmux has-session -t "$session_name" 2>/dev/null; then
    if tmux list-windows -t "$session_name" -F '#W' | grep -Fx "$window_name" >/dev/null 2>&1; then
      echo "Using existing tmux window: $target"
    else
      tmux new-window -d -t "$session_name" -n "$window_name" -c "$workdir"
      echo "Created tmux window: $target"
    fi
  else
    tmux new-session -d -s "$session_name" -n "$window_name" -c "$workdir"
    echo "Created tmux session: $session_name"
    echo "Created tmux window: $target"
  fi

  while IFS=' ' read -r pane_id pane_dead pane_command; do
    if [[ -z "$first_pane_id" ]]; then
      first_pane_id="$pane_id"
    fi

    if [[ "$pane_dead" == "0" && "$pane_command" == "opencode" ]]; then
      echo "Opencode already running in: $target"
      return
    fi
  done < <(tmux list-panes -t "$target" -F '#{pane_id} #{pane_dead} #{pane_current_command}')

  pane_id="$first_pane_id"
  [[ -n "$pane_id" ]] || fail "No tmux pane available in $target"

  read -r _ pane_dead pane_command < <(tmux list-panes -t "$pane_id" -F '#{pane_id} #{pane_dead} #{pane_current_command}')

  if [[ "$pane_dead" == "1" ]]; then
    tmux respawn-pane -k -t "$pane_id" -c "$workdir"
    echo "Respawned dead tmux pane in: $target"
  fi

  tmux send-keys -t "$pane_id" "opencode --port" C-m
  echo "Launching opencode in: $target"
}

if [[ $# -eq 0 ]]; then
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    fail "Unable to determine current branch"
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
  fail "Usage: create_worktree_session.sh [branch-name] [window-name]"
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
