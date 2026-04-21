#!/usr/bin/env bash

if [[ $# -eq 1 ]]; then
  selected=$1
else
  selected=$(tmux ls | fzf --layout=reverse --border=none --prompt='sessions > ' 2>/dev/tty)
fi

if [[ -z $selected ]]; then
  exit 0
fi

selected_name="${selected%%:*}"
tmux switch-client -t "$selected_name"
exit 0
