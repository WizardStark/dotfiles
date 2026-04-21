#!/usr/bin/env bash

if [[ $# -eq 1 ]]; then
  selected=$1
else
  selected=$(tmux list-windows -a -F '#{session_name}:#{window_index}	#{?window_active,*, }#{?window_last_flag,~, } #{session_name}:#{window_index}	#{window_name}' | fzf --delimiter=$'\t' --with-nth=2,3 --layout=reverse --border=none --prompt='windows > ' 2>/dev/tty)
fi

if [[ -z $selected ]]; then
  exit 0
fi

target="${selected%%$'\t'*}"
selected_name="${target%%:*}"

tmux switch-client -t "$selected_name"
tmux select-window -t "$target"
exit 0
