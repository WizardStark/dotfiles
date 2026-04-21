#!/usr/bin/env bash

if [[ ! -t 0 && -r /dev/tty ]]; then
  exec </dev/tty >/dev/tty
fi

prefix_key=$(tmux show -gv prefix)

comm -23 <(tmux list-keys | sort) <(tmux -L test -f /dev/null list-keys | sort) |
  awk -v prefix_key="$prefix_key" '
    function join_from(start,    out, idx) {
      out = $start
      for (idx = start + 1; idx <= NF; idx++) {
        out = out " " $idx
      }
      return out
    }

    function clean_command(command) {
      gsub(/\\;/, ";", command)
      gsub(/\/home\/[^ ]+\/\.config\/tmux\/plugins\//, "~/.config/tmux/plugins/", command)
      gsub(/\/home\/[^ ]+\/\.config\/tmux\//, "~/.config/tmux/", command)
      sub(/^display-popup /, "popup ", command)

      if (command ~ /tmux_keys\.sh/) {
        return "popup keys"
      }
      if (command ~ /tmux_sessions\.sh/) {
        return "popup sessions"
      }
      if (command ~ /tmux_windows\.sh/) {
        return "popup windows"
      }
      if (command ~ /source-file .*tmux\.conf/) {
        return "reload config"
      }
      if (command ~ /rename-session/) {
        return "rename session"
      }
      if (command ~ /last-window/) {
        return "last window"
      }
      if (command ~ /kill-session/) {
        return "kill session"
      }
      if (command ~ /kill-window/) {
        return "kill window"
      }

      return command
    }

    function format_key(key,    formatted) {
      formatted = key
      sub(/ \[r\]$/, "", formatted)

      if (formatted == "Space") {
        return "<Space>"
      }
      if (formatted ~ /^(BSpace|Enter|Tab|Up|Down|Left|Right|Home|End|PPage|NPage|Escape)$/) {
        return "<" formatted ">"
      }
      if (formatted ~ /^(C|M|S)-/) {
        return "<" formatted ">"
      }

      return formatted
    }

    {
      table = "prefix"
      repeat = ""
      field = 2

      if ($field == "-r") {
        repeat = " [r]"
        field++
      }

      if ($field == "-T") {
        table = $(field + 1)
        field += 2
      }

      key = $(field) repeat
      command = clean_command(join_from(field + 1))
      label = (table == "prefix") ? format_key(prefix_key) format_key(key) : table " " format_key(key)

      print label "\t" command
    }
  ' |
  fzf --delimiter=$'\t' --with-nth=1,2 --layout=reverse --border=none --prompt='keys > '
