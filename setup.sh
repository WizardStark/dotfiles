#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/setup_lib.sh"

print_usage() {
  cat <<'EOF'
Usage: ./setup.sh [options]

Options:
  --post-brew       Skip Homebrew bootstrap and assume brew is already installed
  --no-sudo         Do not request sudo or update login shell via sudo
  --no-adopt        Restow without --adopt
  --no-launch-shell Do not exec into a new login shell at the end
  --help            Show this help text

Examples:
  ./setup.sh
  ./setup.sh --post-brew
  ./setup.sh --post-brew --no-sudo
EOF
}

main() {
  local post_brew=0
  local with_sudo=1
  local adopt=1
  local launch_shell=1
  local -a sync_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --post-brew)
        post_brew=1
        ;;
      --no-sudo)
        with_sudo=0
        ;;
      --no-adopt)
        adopt=0
        ;;
      --no-launch-shell)
        launch_shell=0
        ;;
      --help)
        print_usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        print_usage >&2
        exit 1
        ;;
    esac
    shift
  done

  if (( with_sudo )); then
    ensure_sudo
  elif (( post_brew == 0 )); then
    printf '--no-sudo is only supported together with --post-brew\n' >&2
    exit 1
  fi

  backup_existing_zshrc

  if (( post_brew )); then
    ensure_homebrew_available
  else
    install_platform_prereqs
    ensure_homebrew_installed
    sync_args+=(--bootstrap-brew)
  fi

  ensure_homebrew_formula mise

  if (( with_sudo )); then
    sync_args+=(--with-sudo)
  fi

  if (( adopt )); then
    sync_args+=(--adopt)
  fi

  if (( launch_shell )); then
    sync_args+=(--launch-shell)
  fi

  exec "$SCRIPT_DIR/sync.sh" "${sync_args[@]}"
}

main "$@"
