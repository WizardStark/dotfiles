#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf '%s\n' "$1" >&2
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
      printf 'Using existing tmux window: %s\n' "$target"
    else
      tmux new-window -d -t "$session_name" -n "$window_name" -c "$workdir"
      printf 'Created tmux window: %s\n' "$target"
    fi
  else
    tmux new-session -d -s "$session_name" -n "$window_name" -c "$workdir"
    printf 'Created tmux session: %s\n' "$session_name"
    printf 'Created tmux window: %s\n' "$target"
  fi

  while IFS=' ' read -r pane_id pane_dead pane_command; do
    if [[ -z "$first_pane_id" ]]; then
      first_pane_id="$pane_id"
    fi

    if [[ "$pane_dead" == "0" && "$pane_command" == "opencode" ]]; then
      printf 'Opencode already running in: %s\n' "$target"
      return
    fi
  done < <(tmux list-panes -t "$target" -F '#{pane_id} #{pane_dead} #{pane_current_command}')

  pane_id="$first_pane_id"
  [[ -n "$pane_id" ]] || fail "No tmux pane available in $target"

  read -r _ pane_dead pane_command < <(tmux list-panes -t "$pane_id" -F '#{pane_id} #{pane_dead} #{pane_current_command}')

  if [[ "$pane_dead" == "1" ]]; then
    tmux respawn-pane -k -t "$pane_id" -c "$workdir"
    printf 'Respawned dead tmux pane in: %s\n' "$target"
  fi

  tmux send-keys -t "$pane_id" "opencode --port" C-m
  printf 'Launching opencode in: %s\n' "$target"
}

branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
  fail "Unable to determine current branch"
}

if [[ "$branch_name" == "HEAD" || -z "$branch_name" ]]; then
  fail "Unable to determine git branch"
fi

workdir="$(pwd)"
window_name="$(sanitize_window_name "$branch_name")"

ensure_tmux_window "$workdir" "$window_name"

printf 'Using repository path: %s\n' "$workdir"
printf 'Using tmux session: %s\n' "$session_name"
printf 'Using tmux window: %s\n' "$window_name"
