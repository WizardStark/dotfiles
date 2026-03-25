#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/setup_lib.sh"

print_usage() {
  cat <<'EOF'
Usage: ./sync.sh [options]

Options:
  --check           Verify state without making changes
  --verbose         Show exact missing items during checks
  --with-sudo       Update the login shell using sudo-backed chsh
  --bootstrap-brew  Install platform prerequisites and Homebrew if needed
  --adopt           Let stow adopt unmanaged files
  --launch-shell    Exec into a new login shell after syncing
  --help            Show this help text
EOF
}

run_checks() {
  local verbose="$1"
  local issues=0
  local missing

  if brew_bundle_check; then
    printf 'OK   Homebrew packages match Brewfile\n'
  else
    printf 'MISS Homebrew packages are out of sync with Brewfile\n'
    if (( verbose )); then
      missing="$(missing_brewfile_formulae)"
      [[ -n "$missing" ]] && printf '%s\n' "$missing" | while IFS= read -r line; do printf '  - %s\n' "$line"; done
    fi
    issues=$((issues + 1))
  fi

  if check_manifest_npm_packages; then
    printf 'OK   npm packages from manifest are installed\n'
  else
    printf 'MISS npm packages from manifest are missing\n'
    if (( verbose )); then
      missing="$(missing_manifest_npm_packages)"
      [[ -n "$missing" ]] && printf '%s\n' "$missing" | while IFS= read -r line; do printf '  - %s\n' "$line"; done
    fi
    issues=$((issues + 1))
  fi

  if check_manifest_uv_tools; then
    printf 'OK   uv tools from manifest are installed\n'
  else
    printf 'MISS uv tools from manifest are missing\n'
    if (( verbose )); then
      missing="$(missing_manifest_uv_tools)"
      [[ -n "$missing" ]] && printf '%s\n' "$missing" | while IFS= read -r line; do printf '  - %s\n' "$line"; done
    fi
    issues=$((issues + 1))
  fi

  if check_manifest_git_clones; then
    printf 'OK   git-managed extras from manifest are present\n'
  else
    printf 'MISS git-managed extras from manifest are missing\n'
    if (( verbose )); then
      missing="$(missing_manifest_git_clones)"
      [[ -n "$missing" ]] && printf '%s\n' "$missing" | while IFS= read -r line; do printf '  - %s\n' "$line"; done
    fi
    issues=$((issues + 1))
  fi

  if check_bat_theme; then
    printf 'OK   bat theme is present\n'
  else
    printf 'MISS bat theme is missing\n'
    if (( verbose )); then
      printf '  - %s\n' "$(bat --config-dir)/themes/Catppuccin Mocha.tmTheme"
    fi
    issues=$((issues + 1))
  fi

  if check_agent_socket; then
    printf 'OK   ssh agent socket placeholder exists\n'
  else
    printf 'MISS ssh agent socket placeholder is missing\n'
    if (( verbose )); then
      printf '  - %s\n' "$HOME/.ssh/.agent_socket"
    fi
    issues=$((issues + 1))
  fi

  if check_stow_sync; then
    printf 'OK   stow links are up to date\n'
  else
    printf 'MISS stow would still make changes; run ./sync.sh\n'
    if (( verbose )); then
      missing="$(stow_check_output)"
      [[ -n "$missing" ]] && printf '%s\n' "$missing"
    fi
    issues=$((issues + 1))
  fi

  return "$issues"
}

run_apply() {
  local with_sudo="$1"
  local adopt_stow="$2"
  local launch_shell="$3"

  brew_bundle_install
  ensure_manifest_npm_packages
  ensure_manifest_uv_tools
  ensure_base_directories
  ensure_manifest_git_clones
  ensure_bat_theme
  ensure_fzf
  ensure_tmux_plugins
  ensure_agent_socket
  restow_home "$adopt_stow"
  ensure_nvim_plugins

  if (( with_sudo || launch_shell )); then
    ensure_login_shell "$with_sudo"
  fi

  if (( launch_shell )); then
    exec zsh -l
  fi

  printf 'Sync complete.\n'
}

main() {
  local check_only=0
  local verbose=0
  local with_sudo=0
  local bootstrap_brew=0
  local adopt_stow=0
  local launch_shell=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        check_only=1
        ;;
      --verbose)
        verbose=1
        ;;
      --with-sudo)
        with_sudo=1
        ;;
      --bootstrap-brew)
        bootstrap_brew=1
        ;;
      --adopt)
        adopt_stow=1
        ;;
      --launch-shell)
        launch_shell=1
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
  fi

  if (( verbose == 0 )); then
    maybe_delegate_sync_to_mise "$check_only" "$with_sudo" "$bootstrap_brew" "$adopt_stow" "$launch_shell" || true
  fi

  if (( bootstrap_brew )); then
    install_platform_prereqs
    ensure_homebrew_installed
  else
    ensure_homebrew_available
  fi

  if (( check_only )); then
    run_checks "$verbose"
    exit $?
  fi

  run_apply "$with_sudo" "$adopt_stow" "$launch_shell"
}

main "$@"
