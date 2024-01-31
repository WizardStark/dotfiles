#!/usr/bin/env bash

if [[ $# -eq 1 ]]; then
  selected=$1
else
  selected=$(tmux list-windows -a | fzf 2>/dev/tty)
fi

if [[ -z $selected ]]; then
  exit 0
fi
selected_index="${selected#*:}"
selected_index="${selected_index%%:*}"
selected_name="${selected%%:*}"
tmux switch -t $selected_name
tmux select-window -t $selected_index
exit 0
