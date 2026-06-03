#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE_PATH="$DOTFILES_ROOT/Brewfile"
MISE_CONFIG_PATH="$DOTFILES_ROOT/mise.toml"
MANIFEST_PATH="$DOTFILES_ROOT/scripts/manifest.tsv"
PI_SETTINGS_PATH="$DOTFILES_ROOT/home/.pi/agent/settings.json"
BAT_THEME_URL="https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme"
BREW_USABLE_PATH="$DOTFILES_ROOT/home/.local/bin/brew-usable"

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

log_step() {
  printf '==> %s\n' "$1"
}

manifest_entries() {
  local entry_type="$1"
  while IFS=$'\t' read -r type field1 field2 field3; do
    [[ -z "$type" || "$type" == \#* ]] && continue
    [[ "$type" == "$entry_type" ]] || continue
    printf '%s\t%s\t%s\n' "$field1" "$field2" "$field3"
  done <"$MANIFEST_PATH"
}

expand_manifest_value() {
  eval "printf '%s' \"$1\""
}

setup_brew_env() {
  if require_cmd brew; then
    return 0
  fi

  if [[ "$OSTYPE" == linux-gnu* ]]; then
    if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  elif [[ "$OSTYPE" == darwin* ]]; then
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  require_cmd brew
}

ensure_sudo() {
  sudo -v
}

install_platform_prereqs() {
  if [[ "$OSTYPE" != linux-gnu* ]]; then
    return 0
  fi

  if require_cmd apt; then
    log_step "Installing Linux prerequisites with apt"
    sudo apt update
    sudo apt-get install -y build-essential procps curl file git
  elif require_cmd yum; then
    log_step "Installing Linux prerequisites with yum"
    sudo yum groupinstall -y 'Development Tools'
    sudo yum install -y procps-ng curl file git
  fi
}

ensure_homebrew_installed() {
  if setup_brew_env; then
    return 0
  fi

  log_step "Installing Homebrew"
  export NONINTERACTIVE=1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  setup_brew_env
}

brew_usable_cmd() {
  if [[ -x "$BREW_USABLE_PATH" ]]; then
    printf '%s\n' "$BREW_USABLE_PATH"
    return 0
  fi

  if require_cmd brew-usable; then
    command -v brew-usable
    return 0
  fi

  return 1
}

homebrew_is_usable() {
  local brew_usable_bin

  if ! setup_brew_env; then
    return 1
  fi

  if brew_usable_bin="$(brew_usable_cmd 2>/dev/null)"; then
    "$brew_usable_bin" --quiet >/dev/null 2>&1
    return $?
  fi

  brew --version >/dev/null 2>&1
}

ensure_homebrew_available() {
  local brew_usable_bin
  local status

  if ! setup_brew_env; then
    printf 'Homebrew not found or not executable. Run ./sync.sh --bootstrap-brew first or continue without Brewfile-managed steps.\n' >&2
    return 1
  fi

  if homebrew_is_usable; then
    return 0
  fi

  status=$?
  if [[ "$status" -eq 2 ]]; then
    printf 'Homebrew is executable but not usable by the current user; skipping Brewfile-managed steps.\n' >&2
    if brew_usable_bin="$(brew_usable_cmd 2>/dev/null)"; then
      "$brew_usable_bin" >&2 || true
    fi
    return 1
  fi

  printf 'Homebrew not found or not executable. Run ./sync.sh --bootstrap-brew first or continue without Brewfile-managed steps.\n' >&2
  return 1
}

brew_bundle_install() {
  log_step "Installing Homebrew packages from Brewfile"
  brew bundle install --file "$BREWFILE_PATH"
}

brew_bundle_check() {
  brew bundle check --file "$BREWFILE_PATH" >/dev/null 2>&1
}

brewfile_formulae() {
  local line
  while IFS= read -r line; do
    if [[ "$line" == brew* ]]; then
      line="${line#brew }"
      line="${line#\"}"
      line="${line%%\"*}"
      printf '%s\n' "$line"
    fi
  done <"$BREWFILE_PATH"
}

missing_brewfile_formulae() {
  local formula_name
  while IFS= read -r formula_name; do
    [[ -z "$formula_name" ]] && continue
    brew list "$formula_name" >/dev/null 2>&1 || printf '%s\n' "$formula_name"
  done < <(brewfile_formulae)
}

ensure_homebrew_formula() {
  local formula_name="$1"
  if brew list "$formula_name" >/dev/null 2>&1; then
    return 0
  fi

  log_step "Installing Homebrew formula $formula_name"
  brew install "$formula_name"
}

trust_mise_config() {
  if ! require_cmd mise; then
    return 1
  fi

  mise trust "$MISE_CONFIG_PATH" >/dev/null 2>&1 || true
}

run_mise_task() {
  local task_name="$1"
  shift
  trust_mise_config
  exec mise run "$task_name" "$@"
}

sync_task_for_args() {
  local check_only="$1"
  local with_sudo="$2"
  local bootstrap_brew="$3"
  local adopt_stow="$4"
  local launch_shell="$5"

  if [[ "$check_only" == "1" && "$with_sudo" == "0" && "$bootstrap_brew" == "0" && "$adopt_stow" == "0" && "$launch_shell" == "0" ]]; then
    printf 'check\n'
    return 0
  fi

  if [[ "$check_only" == "0" && "$with_sudo" == "0" && "$bootstrap_brew" == "0" && "$adopt_stow" == "0" && "$launch_shell" == "0" ]]; then
    printf 'sync\n'
    return 0
  fi

  if [[ "$check_only" == "0" && "$with_sudo" == "1" && "$bootstrap_brew" == "0" && "$adopt_stow" == "0" && "$launch_shell" == "0" ]]; then
    printf 'sync-sudo\n'
    return 0
  fi

  if [[ "$check_only" == "0" && "$with_sudo" == "0" && "$bootstrap_brew" == "0" && "$adopt_stow" == "1" && "$launch_shell" == "0" ]]; then
    printf 'sync-adopt\n'
    return 0
  fi

  if [[ "$check_only" == "0" && "$with_sudo" == "1" && "$bootstrap_brew" == "0" && "$adopt_stow" == "1" && "$launch_shell" == "0" ]]; then
    printf 'sync-adopt-sudo\n'
    return 0
  fi

  if [[ "$check_only" == "0" && "$with_sudo" == "1" && "$bootstrap_brew" == "1" && "$adopt_stow" == "1" && "$launch_shell" == "1" ]]; then
    printf 'bootstrap\n'
    return 0
  fi

  return 1
}

maybe_delegate_sync_to_mise() {
  local check_only="$1"
  local with_sudo="$2"
  local bootstrap_brew="$3"
  local adopt_stow="$4"
  local launch_shell="$5"
  local task_name

  if [[ -n "${MISE_TASK_NAME:-}" ]] || [[ "${DOTFILES_SKIP_MISE_DELEGATION:-0}" == "1" ]]; then
    return 1
  fi

  if ! require_cmd mise; then
    return 1
  fi

  if ! task_name="$(sync_task_for_args "$check_only" "$with_sudo" "$bootstrap_brew" "$adopt_stow" "$launch_shell")"; then
    return 1
  fi

  trust_mise_config
  exec mise run "$task_name"
}

npm_package_installed() {
  npm list -g --depth=0 "$1" >/dev/null 2>&1
}

refresh_npm_global_bin_path() {
  local npm_prefix npm_bin_dir

  npm_prefix="$(npm prefix -g 2>/dev/null || true)"
  [[ -n "$npm_prefix" ]] || return 0

  npm_bin_dir="$npm_prefix/bin"
  case ":$PATH:" in
    *":$npm_bin_dir:"*) ;;
    *)
      export PATH="$npm_bin_dir:$PATH"
      ;;
  esac
}

ensure_npm_package() {
  local package_name="$1"
  if npm_package_installed "$package_name"; then
    refresh_npm_global_bin_path
    return 0
  fi

  log_step "Installing npm package $package_name"
  npm install -g "$package_name"
  refresh_npm_global_bin_path
}

check_npm_package() {
  npm_package_installed "$1"
}

ensure_manifest_npm_packages() {
  local package_name _unused1 _unused2
  while IFS=$'\t' read -r package_name _unused1 _unused2; do
    ensure_npm_package "$package_name"
  done < <(manifest_entries npm)
}

check_manifest_npm_packages() {
  local package_name _unused1 _unused2
  while IFS=$'\t' read -r package_name _unused1 _unused2; do
    if ! check_npm_package "$package_name"; then
      return 1
    fi
  done < <(manifest_entries npm)

  return 0
}

missing_manifest_npm_packages() {
  local package_name _unused1 _unused2
  while IFS=$'\t' read -r package_name _unused1 _unused2; do
    check_npm_package "$package_name" || printf '%s\n' "$package_name"
  done < <(manifest_entries npm)
}

pi_settings_packages() {
  local settings_path="${1:-$PI_SETTINGS_PATH}"

  [[ -f "$settings_path" ]] || return 0
  require_cmd node || return 1

  node - "$settings_path" <<'NODE'
const fs = require('node:fs');

const settingsPath = process.argv[2];

try {
  const parsed = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  const packages = Array.isArray(parsed.packages) ? parsed.packages : [];
  for (const pkg of packages) {
    if (typeof pkg === 'string' && pkg.trim()) {
      console.log(pkg.trim());
    }
  }
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Failed to parse ${settingsPath}: ${message}`);
  process.exit(1);
}
NODE
}

pi_package_installed() {
  local package_name="$1"

  require_cmd pi || return 1
  pi list 2>/dev/null | awk '/^  [^ ]/ { print $1 }' | grep -Fx -- "$package_name" >/dev/null 2>&1
}

ensure_pi_package() {
  local package_name="$1"

  if pi_package_installed "$package_name"; then
    return 0
  fi

  log_step "Installing Pi package $package_name"
  pi install "$package_name"
}

ensure_pi_packages_from_settings() {
  local settings_path="${1:-$PI_SETTINGS_PATH}"
  local package_name package_list

  [[ -f "$settings_path" ]] || return 0
  require_cmd pi || return 1

  package_list="$(pi_settings_packages "$settings_path")" || return 1
  [[ -n "$package_list" ]] || return 0

  while IFS= read -r package_name; do
    [[ -n "$package_name" ]] || continue
    ensure_pi_package "$package_name"
  done <<< "$package_list"
}

check_pi_packages_from_settings() {
  local settings_path="${1:-$PI_SETTINGS_PATH}"
  local package_name package_list

  [[ -f "$settings_path" ]] || return 0
  require_cmd pi || return 1

  package_list="$(pi_settings_packages "$settings_path")" || return 1
  [[ -n "$package_list" ]] || return 0

  while IFS= read -r package_name; do
    [[ -n "$package_name" ]] || continue
    if ! pi_package_installed "$package_name"; then
      return 1
    fi
  done <<< "$package_list"

  return 0
}

missing_pi_packages_from_settings() {
  local settings_path="${1:-$PI_SETTINGS_PATH}"
  local package_name package_list

  [[ -f "$settings_path" ]] || return 0
  require_cmd pi || return 1

  package_list="$(pi_settings_packages "$settings_path")" || return 1
  [[ -n "$package_list" ]] || return 0

  while IFS= read -r package_name; do
    [[ -n "$package_name" ]] || continue
    pi_package_installed "$package_name" || printf '%s\n' "$package_name"
  done <<< "$package_list"
}

ensure_uv_tool() {
  local executable_name="$1"
  local package_name="$2"

  if require_cmd "$executable_name"; then
    return 0
  fi

  log_step "Installing uv tool $package_name"
  uv tool install "$package_name"
}

check_uv_tool() {
  require_cmd "$1"
}

ensure_manifest_uv_tools() {
  local executable_name package_name _unused
  while IFS=$'\t' read -r executable_name package_name _unused; do
    ensure_uv_tool "$executable_name" "$package_name"
  done < <(manifest_entries uv)
}

check_manifest_uv_tools() {
  local executable_name package_name _unused
  while IFS=$'\t' read -r executable_name package_name _unused; do
    if ! check_uv_tool "$executable_name"; then
      return 1
    fi
  done < <(manifest_entries uv)

  return 0
}

missing_manifest_uv_tools() {
  local executable_name package_name _unused
  while IFS=$'\t' read -r executable_name package_name _unused; do
    check_uv_tool "$executable_name" || printf '%s (%s)\n' "$executable_name" "$package_name"
  done < <(manifest_entries uv)
}

ensure_git_clone() {
  local repo_url="$1"
  local target_dir="$2"
  shift 2

  if [[ -d "$target_dir" ]]; then
    return 0
  fi

  log_step "Cloning $repo_url into $target_dir"
  git clone "$@" "$repo_url" "$target_dir"
}

ensure_bat_theme() {
  local theme_dir theme_file

  if ! require_cmd bat; then
    log_step "Skipping bat theme setup because bat is unavailable"
    return 0
  fi

  theme_dir="$(bat --config-dir)/themes"
  theme_file="$theme_dir/Catppuccin Mocha.tmTheme"

  mkdir -p "$theme_dir"
  if [[ ! -f "$theme_file" ]]; then
    if require_cmd wget; then
      log_step "Installing bat theme"
      wget -O "$theme_file" "$BAT_THEME_URL"
    elif require_cmd curl; then
      log_step "Installing bat theme"
      curl -fsSL "$BAT_THEME_URL" -o "$theme_file"
    else
      log_step "Skipping bat theme install because neither wget nor curl is available"
      return 0
    fi
  fi

  bat cache --build
}

check_bat_theme() {
  local theme_file

  if ! require_cmd bat; then
    return 1
  fi

  theme_file="$(bat --config-dir)/themes/Catppuccin Mocha.tmTheme"
  [[ -f "$theme_file" ]]
}

ensure_manifest_git_clones() {
  local repo_url target_dir clone_arg
  while IFS=$'\t' read -r repo_url target_dir clone_arg; do
    target_dir="$(expand_manifest_value "$target_dir")"
    if [[ -n "$clone_arg" ]]; then
      ensure_git_clone "$repo_url" "$target_dir" "$clone_arg"
    else
      ensure_git_clone "$repo_url" "$target_dir"
    fi
  done < <(manifest_entries git)
}

check_manifest_git_clones() {
  local repo_url target_dir clone_arg
  while IFS=$'\t' read -r repo_url target_dir clone_arg; do
    target_dir="$(expand_manifest_value "$target_dir")"
    if [[ ! -d "$target_dir" ]]; then
      return 1
    fi
  done < <(manifest_entries git)

  return 0
}

missing_manifest_git_clones() {
  local repo_url target_dir clone_arg
  while IFS=$'\t' read -r repo_url target_dir clone_arg; do
    target_dir="$(expand_manifest_value "$target_dir")"
    [[ -d "$target_dir" ]] || printf '%s -> %s\n' "$repo_url" "$target_dir"
  done < <(manifest_entries git)
}

ensure_pi_runtime_directories() {
  mkdir -p \
    "$HOME/.pi" \
    "$HOME/.pi/agent" \
    "$HOME/.pi/context-mode" \
    "$HOME/.pi/agent/bin" \
    "$HOME/.pi/agent/extensions" \
    "$HOME/.pi/agent/npm" \
    "$HOME/.pi/agent/sessions"
}

ensure_base_directories() {
  mkdir -p "$HOME/.config" "$HOME/.ssh"
  ensure_pi_runtime_directories
}

backup_existing_zshrc() {
  local target="$HOME/.zshrc"
  local backup="$HOME/.zshrc_old"
  local managed="$DOTFILES_ROOT/home/.zshrc"

  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$managed" ]]; then
    return 0
  fi

  if [[ -e "$target" ]] && [[ ! -e "$backup" ]]; then
    log_step "Backing up existing ~/.zshrc to ~/.zshrc_old"
    mv "$target" "$backup"
  fi
}

restow_home() {
  local adopt_flag="$1"
  log_step "Restowing dotfiles"
  if [[ "$adopt_flag" == "1" ]]; then
    stow -v -R --adopt -t "$HOME" -d "$DOTFILES_ROOT" home
  else
    stow -v -R -t "$HOME" -d "$DOTFILES_ROOT" home
  fi
}

check_stow_sync() {
  local output
  output="$(stow_check_output)"
  [[ -z "$output" ]]
}

stow_check_output() {
  local output
  output="$(stow -n -v -t "$HOME" -d "$DOTFILES_ROOT" home 2>&1 || true)"
  output="$(printf '%s\n' "$output" | grep -v '^WARNING: in simulation mode so not modifying filesystem\.$' || true)"
  printf '%s' "$output"
}

ensure_tmux_plugins() {
  if [[ -x "$HOME/.config/tmux/plugins/tpm/bin/install_plugins" ]]; then
    log_step "Installing tmux plugins"
    "$HOME/.config/tmux/plugins/tpm/bin/install_plugins"
  fi
}

ensure_fzf() {
  if [[ ! -x "$HOME/.fzf/install" ]]; then
    log_step "Skipping fzf shell integration because ~/.fzf/install is unavailable"
    return 0
  fi

  log_step "Ensuring fzf shell integration"
  "$HOME/.fzf/install" --key-bindings --completion --update-rc
}

ensure_nvim_plugins() {
  if require_cmd nvim; then
    log_step "Syncing Neovim plugins"
    nvim --headless "+PackUpdate" +qa
  fi
}

ensure_agent_socket() {
  touch "$HOME/.ssh/.agent_socket"
}

check_agent_socket() {
  [[ -e "$HOME/.ssh/.agent_socket" ]]
}

ensure_login_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "$1" == "1" ]]; then
    printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    sudo chsh -s "$zsh_path" "$(whoami)"
  else
    chsh -s "$zsh_path" "$USER"
  fi
}
