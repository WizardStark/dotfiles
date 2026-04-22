#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/setup_lib.sh"

print_usage() {
  cat <<'EOF'
Usage: ./macsetup.sh

Applies the macOS defaults this repo keeps intentionally:
  - faster key repeat and shorter delay
  - faster window and Mission Control animations
  - full keyboard navigation with Tab
  - higher Bluetooth audio bitpool
  - trackpad and mouse speed
  - Finder hidden files, extensions, and status bar
  - clear Dock icons, set Dock size, enable auto-hide, remove hide delay
EOF
}

require_macos() {
  if [[ "$OSTYPE" != darwin* ]]; then
    printf 'macsetup.sh only supports macOS.\n' >&2
    exit 1
  fi
}

apply_defaults() {
  log_step "Configuring keyboard repeat rate and delay"
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  defaults write NSGlobalDomain KeyRepeat -int 1
  defaults write NSGlobalDomain InitialKeyRepeat -int 10

  log_step "Configuring keyboard navigation"
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

  log_step "Configuring animation speed"
  defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
  defaults write com.apple.dock expose-animation-duration -float 0.1

  log_step "Improving Bluetooth audio bitrate"
  defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

  log_step "Configuring trackpad and mouse speed"
  defaults write -g com.apple.trackpad.scaling -float 2
  defaults write -g com.apple.mouse.scaling -float 2.5

  log_step "Configuring Finder"
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder ShowStatusBar -bool true

  log_step "Configuring Dock"
  defaults write com.apple.dock persistent-apps -array
  defaults write com.apple.dock persistent-others -array
  defaults write com.apple.dock tilesize -int 36
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0
}

restart_services() {
  log_step "Restarting affected services"
  for app in cfprefsd Dock Finder SystemUIServer; do
    killall "$app" >/dev/null 2>&1 || true
  done
}

main() {
  if [[ "${1:-}" == "--help" ]]; then
    print_usage
    exit 0
  fi

  require_macos
  apply_defaults
  restart_services

  printf 'macOS defaults updated. Some changes may still require logout or restart.\n'
}

main "$@"
