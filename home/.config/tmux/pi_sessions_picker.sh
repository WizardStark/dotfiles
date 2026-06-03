#!/usr/bin/env bash

set -euo pipefail

script_path="$HOME/.config/tmux/pi_sessions_status.sh"
separator=$'\x1f'

if [[ ! -f "$script_path" ]]; then
  printf 'Missing script: %s\n' "$script_path" >&2
  exit 1
fi

records="$(bash "$script_path" --records)"

if [[ -z "$records" ]]; then
  printf 'No active pi sessions\n' >&2
  sleep 1
  exit 0
fi

selected="$({
  while IFS="$separator" read -r session_name window_index pane_id pane_index status name path; do
    status_icon='○'
    if [[ "$status" == 'working' ]]; then
      status_icon='●'
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$pane_id" "$status_icon" "$name" "$session_name:$window_index.$pane_index" "$path"
  done <<<"$records"
} | fzf \
  --delimiter=$'\t' \
  --with-nth=2,3,4,5 \
  --layout=reverse \
  --border=none \
  --prompt='pi > ' \
  --header=$'status\tname\ttarget\tpath' \
  2>/dev/tty)"

if [[ -z "$selected" ]]; then
  exit 0
fi

pane_id="${selected%%$'\t'*}"
bash "$script_path" --switch-pane "$pane_id"
