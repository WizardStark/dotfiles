#!/usr/bin/env bash

set -euo pipefail

separator=$'\x1f'
mode="table"
switch_pane_id=""

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: pi_sessions_status.sh [--records] [--switch-pane PANE_ID]

Lists active pi sessions across tmux panes.

Options:
  --records            Output machine-readable records separated by unit separators.
  --switch-pane ID     Switch the current tmux client to the given pane's session/window.
  -h, --help           Show this help.
EOF
}

repeat_char() {
  local char="$1"
  local count="$2"
  local out=""
  local i
  for ((i = 0; i < count; i++)); do
    out+="$char"
  done
  printf '%s' "$out"
}

capture_tail_for_pane() {
  local pane_id="$1"
  tmux capture-pane -p -t "$pane_id" -S -60 2>/dev/null | tail -n 20 || true
}

looks_like_pi_ui() {
  local tail_lines="$1"

  grep -Fq 'Working...' <<<"$tail_lines" \
    || grep -Fq 'Last turn' <<<"$tail_lines" \
    || grep -Eq '^Idle$' <<<"$tail_lines" \
    || grep -Fq 'Cost $' <<<"$tail_lines" \
    || grep -Fq 'Est $' <<<"$tail_lines"
}

command_mentions_pi() {
  local command_text="$1"
  command_text="${command_text//\"/ }"
  command_text="${command_text//\'/ }"
  [[ "$command_text" =~ (^|[[:space:]=])([^[:space:]]*/)?pi([[:space:]]|$) ]]
}

is_pi_pane() {
  local pane_command="$1"
  local pane_start_command="$2"
  local tail_lines="$3"

  if [[ "$pane_command" == "pi" ]]; then
    return 0
  fi

  if command_mentions_pi "$pane_start_command"; then
    return 0
  fi

  if [[ "$pane_command" == "node" || "$pane_command" == "bun" || "$pane_command" == "deno" ]]; then
    looks_like_pi_ui "$tail_lines"
    return $?
  fi

  return 1
}

session_label_for_path() {
  local path="$1"
  local branch_name=""

  if command -v git >/dev/null 2>&1 && git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch_name="$(git -C "$path" branch --show-current 2>/dev/null || true)"
    if [[ -z "$branch_name" ]]; then
      branch_name="$(git -C "$path" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    fi
  fi

  if [[ "$branch_name" == "HEAD" || -z "$branch_name" ]]; then
    basename "$path"
    return 0
  fi

  printf '%s\n' "$branch_name"
}

status_for_tail() {
  local tail_lines="$1"

  if grep -Fq 'Working...' <<<"$tail_lines" || grep -Eq '(^|[[:space:]])Running [0-9]' <<<"$tail_lines"; then
    printf 'working\n'
    return 0
  fi

  printf 'idle\n'
}

switch_to_pane() {
  local pane_id="$1"
  local session_name window_index client_tty

  [[ -n "$pane_id" ]] || fail 'Missing pane id'
  session_name="$(tmux display-message -p -t "$pane_id" '#{session_name}' 2>/dev/null || true)"
  window_index="$(tmux display-message -p -t "$pane_id" '#{window_index}' 2>/dev/null || true)"
  client_tty="$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)"

  [[ -n "$session_name" ]] || fail "Could not resolve tmux session for pane: $pane_id"
  [[ -n "$window_index" ]] || fail "Could not resolve tmux window for pane: $pane_id"
  [[ -n "$client_tty" ]] || fail 'Could not determine the current tmux client'

  tmux switch-client -c "$client_tty" -t "$session_name"
  tmux select-window -t "$session_name:$window_index"
  tmux select-pane -t "$pane_id"
}

collect_rows() {
  local format pane_rows

  rows=()
  status_header='Status'
  name_header='Name'
  max_status=${#status_header}
  max_name=${#name_header}

  format="#{session_name}${separator}#{window_index}${separator}#{pane_id}${separator}#{pane_index}${separator}#{pane_current_path}${separator}#{pane_current_command}${separator}#{pane_start_command}${separator}#{pane_dead}"
  pane_rows="$(tmux list-panes -a -F "$format" 2>/dev/null || true)"

  if [[ -z "$pane_rows" ]]; then
    return 0
  fi

  while IFS="$separator" read -r session_name window_index pane_id pane_index pane_path pane_command pane_start_command pane_dead; do
    [[ -n "$pane_id" ]] || continue
    [[ "$pane_dead" == "1" ]] && continue

    tail_lines="$(capture_tail_for_pane "$pane_id")"
    if ! is_pi_pane "$pane_command" "$pane_start_command" "$tail_lines"; then
      continue
    fi

    if [[ -z "$pane_path" || ! -d "$pane_path" ]]; then
      pane_path="$HOME"
    fi

    name="$(session_label_for_path "$pane_path")"
    status="$(status_for_tail "$tail_lines")"
    display_path="$pane_path"
    if [[ "$display_path" == "$HOME" || "$display_path" == "$HOME/"* ]]; then
      display_path="~${display_path#$HOME}"
    fi

    rows+=("$session_name${separator}$window_index${separator}$pane_id${separator}$pane_index${separator}$status${separator}$name${separator}$display_path")

    if (( ${#status} > max_status )); then
      max_status=${#status}
    fi
    if (( ${#name} > max_name )); then
      max_name=${#name}
    fi
  done <<<"$pane_rows"
}

command -v tmux >/dev/null 2>&1 || fail 'tmux is not installed'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --records)
      mode="records"
      shift
      ;;
    --switch-pane)
      [[ $# -ge 2 ]] || fail '--switch-pane requires a pane id'
      mode="switch"
      switch_pane_id="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if [[ "$mode" == "switch" ]]; then
  switch_to_pane "$switch_pane_id"
  exit 0
fi

collect_rows

if [[ "$mode" == "records" ]]; then
  for row in "${rows[@]}"; do
    printf '%s\n' "$row"
  done
  exit 0
fi

if (( ${#rows[@]} == 0 )); then
  printf 'No active pi sessions\n'
  exit 0
fi

printf '%-*s  %-*s  %s\n' "$max_status" "$status_header" "$max_name" "$name_header" 'Path'
printf '%-*s  %-*s  %s\n' "$max_status" "$(repeat_char '-' "$max_status")" "$max_name" "$(repeat_char '-' "$max_name")" '----'

for row in "${rows[@]}"; do
  IFS="$separator" read -r _session_name _window_index _pane_id _pane_index status name path <<<"$row"
  printf '%-*s  %-*s  %s\n' "$max_status" "$status" "$max_name" "$name" "$path"
done
