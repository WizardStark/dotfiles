#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ensure_pi_tmux_session.sh [--cwd PATH] [--session-file PATH] [--json]

Ensures there is a dedicated Pi tmux window for the current repo/worktree.
When --session-file is provided, the tmux Pi agent is (re)started on that exact session.
Otherwise it starts a fresh interactive `pi` session in that pane.
EOF
}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found on PATH: $1"
}

json_escape() {
  python - <<'PY' "$1"
import json, sys
print(json.dumps(sys.argv[1]))
PY
}

cwd="$(pwd)"
session_file=""
json_output=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cwd)
      [[ $# -ge 2 ]] || fail "--cwd requires a value"
      cwd="$2"
      shift 2
      ;;
    --session-file)
      [[ $# -ge 2 ]] || fail "--session-file requires a value"
      session_file="$2"
      shift 2
      ;;
    --json)
      json_output=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

require_command git
require_command tmux
require_command pi
pi_bin="$(command -v pi)"

[[ -d "$cwd" ]] || fail "Working directory does not exist: $cwd"
cwd="$(cd "$cwd" && pwd)"

git_common_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
  fail "Not in a git repository: $cwd"
}

worktree_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || {
  fail "Unable to determine worktree root for: $cwd"
}

repo_root="$(dirname "$git_common_dir")"
cwd="$worktree_root"
repo_name="$(basename "$repo_root")"
session_name="$repo_name"

sanitize_window_name() {
  printf '%s' "$1" | tr '/:.' '-'
}

branch_name="$(git -C "$worktree_root" branch --show-current 2>/dev/null || true)"
if [[ -z "$branch_name" ]]; then
  branch_name="$(git -C "$worktree_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
fi
if [[ "$branch_name" == "HEAD" || -z "$branch_name" ]]; then
  branch_name="$(basename "$worktree_root")"
fi

window_name="$(sanitize_window_name "$branch_name")"
target="$session_name:$window_name"

if tmux has-session -t "$session_name" 2>/dev/null; then
  if tmux list-windows -t "$session_name" -F '#W' | grep -Fx "$window_name" >/dev/null 2>&1; then
    :
  else
    tmux new-window -d -t "$session_name" -n "$window_name" -c "$cwd"
  fi
else
  tmux new-session -d -s "$session_name" -n "$window_name" -c "$cwd"
fi

pane_id="$(tmux list-panes -t "$target" -F '#{pane_id}' | head -n 1)"
[[ -n "$pane_id" ]] || fail "No tmux pane available in $target"

pane_dead="$(tmux display-message -p -t "$pane_id" '#{pane_dead}')"
pane_command="$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')"
pane_start_command="$(tmux display-message -p -t "$pane_id" '#{pane_start_command}')"
stored_session_file="$(tmux show-options -v -t "$target" @pi_session_file 2>/dev/null || true)"
stored_workdir="$(tmux show-options -v -t "$target" @pi_workdir 2>/dev/null || true)"

launch_command=(env PI_NVIM_TMUX=1 PI_NVIM_WORKDIR="$cwd")
if [[ -n "$session_file" ]]; then
  launch_command+=(PI_NVIM_SESSION_FILE="$session_file" "$pi_bin" --session "$session_file")
else
  launch_command+=("$pi_bin")
fi

quoted_launch_command=()
for part in "${launch_command[@]}"; do
  quoted_launch_command+=("$(printf '%q' "$part")")
done
joined_launch_command="exec ${quoted_launch_command[*]}"

pane_is_pi=0
if [[ "$pane_command" == "pi" ]]; then
  pane_is_pi=1
elif [[ "$pane_command" == "node" || "$pane_command" == "bun" ]]; then
  case "$pane_start_command" in
    pi|pi\ *|\"pi\"|\"pi\"\ *|*" pi"*|*"/pi"*|*"/pi\""*)
      pane_is_pi=1
      ;;
  esac
fi

restart_reason=""
if [[ "$pane_dead" == "1" ]]; then
  restart_reason="pane-dead"
elif [[ "$pane_is_pi" != "1" ]]; then
  restart_reason="pane-not-pi"
fi

active_session_file="$stored_session_file"
active_workdir="$stored_workdir"

if [[ -n "$restart_reason" ]]; then
  tmux respawn-pane -k -t "$pane_id" -c "$cwd" "$joined_launch_command"
  active_session_file="$session_file"
  active_workdir="$cwd"
  tmux set-option -q -t "$target" @pi_session_file "$active_session_file"
  tmux set-option -q -t "$target" @pi_workdir "$active_workdir"
elif [[ -z "$active_workdir" ]]; then
  active_workdir="$cwd"
  tmux set-option -q -t "$target" @pi_workdir "$active_workdir"
fi

tmux select-window -t "$target" >/dev/null 2>&1 || true

if [[ "$json_output" == "1" ]]; then
  restarted=false
  if [[ -n "$restart_reason" ]]; then
    restarted=true
  fi

  printf '{"cwd":%s,"repo":%s,"tmuxSession":%s,"tmuxWindow":%s,"tmuxTarget":%s,"paneId":%s,"sessionFile":%s,"restarted":%s,"restartReason":%s}\n' \
    "$(json_escape "${active_workdir:-$cwd}")" \
    "$(json_escape "$repo_name")" \
    "$(json_escape "$session_name")" \
    "$(json_escape "$window_name")" \
    "$(json_escape "$target")" \
    "$(json_escape "$pane_id")" \
    "$(json_escape "$active_session_file")" \
    "$restarted" \
    "$(json_escape "$restart_reason")"
  exit 0
fi

printf 'Using repository path: %s\n' "${active_workdir:-$cwd}"
printf 'Using tmux session: %s\n' "$session_name"
printf 'Using tmux window: %s\n' "$window_name"
printf 'Using tmux pane: %s\n' "$pane_id"
if [[ -n "$active_session_file" ]]; then
  printf 'Using Pi session file: %s\n' "$active_session_file"
else
  printf 'Using Pi session selection: fresh interactive session (pi)\n'
fi
if [[ -n "$restart_reason" ]]; then
  printf 'Restarted Pi pane: %s\n' "$restart_reason"
fi
