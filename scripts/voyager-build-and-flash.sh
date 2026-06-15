#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: voyager-build-and-flash.sh [QMK_HOME] [--compile-only]

Builds the wizardstark Voyager keymap and flashes it with zapp.

Examples:
  voyager-build-and-flash.sh ~/src/qmk_firmware
  voyager-build-and-flash.sh --compile-only
  QMK_HOME=~/src/qmk_firmware voyager-build-and-flash.sh

Notes:
  - The keymap is symlinked into keyboards/zsa/voyager/keymaps/wizardstark.
  - If qmk is not installed, this script bootstraps it with uv into:
      ~/.cache/wizardstark-voyager/qmk-venv
  - zapp waits for the keyboard in bootloader mode before flashing.
EOF
}

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
keyboard="zsa/voyager"
keymap="wizardstark"
target_name="zsa_voyager_wizardstark"
compile_only=0
qmk_home=""

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    --compile-only)
      compile_only=1
      ;;
    *)
      if [[ -z "$qmk_home" ]]; then
        qmk_home="$arg"
      else
        echo "Unexpected argument: $arg" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

normalize_path() {
  case "$1" in
    '~')
      printf '%s\n' "$HOME"
      ;;
    '~/'*)
      printf '%s/%s\n' "$HOME" "${1#~/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

read_qmk_home_from_ini() {
  local ini_path="$1"
  [[ -f "$ini_path" ]] || return 1

  awk '
    BEGIN { in_user = 0 }
    /^\[user\]$/ { in_user = 1; next }
    /^\[/ { in_user = 0 }
    in_user {
      split($0, parts, /=/)
      key = parts[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (key == "qmk_home") {
        value = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
      }
    }
  ' "$ini_path" | tail -1
}

read_qmk_home_from_cli() {
  command -v qmk >/dev/null 2>&1 || return 1

  qmk config user.qmk_home 2>/dev/null \
    | sed -n 's/^[^=]*=[[:space:]]*//p' \
    | sed 's/[[:space:]]*(.*)$//' \
    | tail -1
}

find_qmk_home() {
  if [[ -n "$qmk_home" ]]; then
    return
  fi

  if [[ -n "${QMK_HOME:-}" ]]; then
    qmk_home="$QMK_HOME"
    return
  fi

  for ini_path in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/qmk/qmk.ini" \
    "$HOME/Library/Application Support/qmk/qmk.ini"
  do
    qmk_home=$(read_qmk_home_from_ini "$ini_path" || true)
    [[ -n "$qmk_home" ]] && break
  done

  if [[ -z "$qmk_home" ]]; then
    qmk_home=$(read_qmk_home_from_cli || true)
  fi

  if [[ -z "$qmk_home" ]]; then
    echo "Could not determine QMK home. Pass it explicitly or set QMK_HOME." >&2
    exit 1
  fi
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    if [[ $# -gt 1 ]]; then
      echo "$2" >&2
    fi
    exit 1
  fi
}

maybe_prepend_toolchain() {
  local candidates=()

  if [[ -n "${ARM_GCC_BIN_DIR:-}" ]]; then
    candidates+=("$ARM_GCC_BIN_DIR")
  fi
  if [[ -n "${XPACK_ARM_GCC_DIR:-}" ]]; then
    candidates+=("$XPACK_ARM_GCC_DIR/bin" "$XPACK_ARM_GCC_DIR")
  fi
  candidates+=(
    "$HOME/.cache/wizardstark-voyager/xpack-arm-none-eabi-gcc/bin"
  )

  for dir in "${candidates[@]}"; do
    if [[ -x "$dir/arm-none-eabi-gcc" ]]; then
      export PATH="$dir:$PATH"
      return
    fi
  done
}

ensure_qmk_cli() {
  if command -v qmk >/dev/null 2>&1; then
    QMK_BIN=$(command -v qmk)
    return
  fi

  need_cmd uv "Install uv first, or install qmk manually."

  local qmk_venv="$HOME/.cache/wizardstark-voyager/qmk-venv"
  if [[ ! -x "$qmk_venv/bin/qmk" ]]; then
    echo "Bootstrapping qmk CLI with uv into $qmk_venv"
    uv venv "$qmk_venv"
    uv pip install --python "$qmk_venv/bin/python" qmk
  fi

  QMK_BIN="$qmk_venv/bin/qmk"
}

find_qmk_home
qmk_home=$(normalize_path "$qmk_home")
qmk_home=$(cd "$qmk_home" && pwd)

if [[ ! -d "$qmk_home/keyboards/zsa/voyager" ]]; then
  echo "Not a ZSA QMK checkout: $qmk_home" >&2
  exit 1
fi

need_cmd git
need_cmd make
need_cmd dfu-suffix "Install it with: brew install dfu-util"

if [[ "$compile_only" -ne 1 ]]; then
  need_cmd zapp "Install it with: brew install zapp"
  need_cmd script "Install it with your system util-linux package if missing."
fi

maybe_prepend_toolchain
need_cmd arm-none-eabi-gcc "Install a working ARM toolchain. If Homebrew's arm-none-eabi-gcc is insufficient on Linux, install xPack and set XPACK_ARM_GCC_DIR."

ensure_qmk_cli

"$repo_root/scripts/link-voyager-keymap.sh" "$qmk_home"

firmware_bin="$qmk_home/$target_name.bin"

rm -f "$firmware_bin"

echo "Compiling $keyboard:$keymap"
(
  cd "$qmk_home"
  "$QMK_BIN" compile -kb "$keyboard" -km "$keymap"
)

if [[ ! -f "$firmware_bin" ]]; then
  echo "Compile finished, but firmware was not found at: $firmware_bin" >&2
  exit 1
fi

echo "Built firmware: $firmware_bin"

if [[ "$compile_only" -eq 1 ]]; then
  echo "Compile-only mode: skipping flash."
  exit 0
fi

echo "Starting zapp..."
echo "When zapp says it is waiting for the keyboard, put the Voyager into bootloader mode."

auto_log_dir="$HOME/.cache/wizardstark-voyager/logs"
mkdir -p "$auto_log_dir"
zapp_log="$auto_log_dir/zapp-$(date +%Y%m%d-%H%M%S).log"
set +e
script -qefc "zapp flash '$firmware_bin'" "$zapp_log"
zapp_status=$?
set -e

if [[ "$zapp_status" -ne 0 ]]; then
  if grep -q 'errno 13' "$zapp_log"; then
    cat >&2 <<'EOF'

zapp could not open the bootloader device due to Linux USB permissions.
Install udev rules, then unplug/replug the keyboard and try again:

  curl -L https://raw.githubusercontent.com/zsa/zapp/main/udev/50-zsa.rules \
    | sudo tee /etc/udev/rules.d/50-zsa.rules >/dev/null
  sudo udevadm control --reload-rules
  sudo udevadm trigger

If that still does not help, log out and back in (or reboot) before retrying.
EOF
  fi
  echo "zapp output saved to: $zapp_log" >&2
  exit "$zapp_status"
fi

echo "zapp output saved to: $zapp_log"
