#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: link-voyager-keymap.sh [QMK_HOME] [--moonlander] [--force]

Symlinks this repo's shared keymap into a ZSA QMK checkout.
Defaults to Voyager; --moonlander selects the verified Moonlander revision A.
--moonlander=reva is also accepted.

Examples:
  link-voyager-keymap.sh ~/src/qmk_firmware
  QMK_HOME=~/src/qmk_firmware link-voyager-keymap.sh
  link-voyager-keymap.sh ~/src/qmk_firmware --force
EOF
}

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
keymap_src="$repo_root/keyboard/wizardstark"
qmk_home=""
force=0
keyboard="voyager"
compile_keyboard="zsa/voyager"

resolve_path() {
  python3 - "$1" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

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

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    --force)
      force=1
      ;;
    --moonlander|--moonlander=reva)
      keyboard="moonlander"
      compile_keyboard="zsa/moonlander/reva"
      ;;
    --*)
      echo "Unknown option: $arg" >&2
      exit 1
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

if [[ -z "$qmk_home" && -n "${QMK_HOME:-}" ]]; then
  qmk_home="$QMK_HOME"
fi

if [[ -z "$qmk_home" ]] && command -v qmk >/dev/null 2>&1; then
  qmk_home=$(qmk config user.qmk_home 2>/dev/null | awk -F'=' 'NF >= 2 {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}' | tail -1)
fi

if [[ -z "$qmk_home" ]]; then
  for ini_path in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/qmk/qmk.ini" \
    "$HOME/Library/Application Support/qmk/qmk.ini"
  do
    qmk_home=$(read_qmk_home_from_ini "$ini_path" || true)
    [[ -n "$qmk_home" ]] && break
  done
fi

if [[ -z "$qmk_home" ]]; then
  echo "Could not determine QMK home. Pass it explicitly or set QMK_HOME." >&2
  exit 1
fi

qmk_home=$(normalize_path "$qmk_home")
qmk_home=$(cd "$qmk_home" && pwd)
target_dir="$qmk_home/keyboards/zsa/$keyboard/keymaps"
target_link="$target_dir/wizardstark"

if [[ ! -d "$qmk_home/keyboards/zsa/$keyboard" ]]; then
  echo "Not a ZSA QMK checkout: $qmk_home" >&2
  exit 1
fi

mkdir -p "$target_dir"

if [[ -e "$target_link" || -L "$target_link" ]]; then
  if [[ -L "$target_link" ]]; then
    existing=$(resolve_path "$target_link")
    if [[ "$existing" == "$keymap_src" ]]; then
      echo "Already linked: $target_link -> $keymap_src"
      exit 0
    fi
    if [[ "$force" -ne 1 ]]; then
      echo "Refusing to replace existing symlink: $target_link -> $existing" >&2
      echo "Re-run with --force if you want to replace it." >&2
      exit 1
    fi
    rm -f "$target_link"
  elif [[ "$force" -eq 1 ]]; then
    rm -rf "$target_link"
  else
    echo "Refusing to replace existing non-symlink path: $target_link" >&2
    echo "Re-run with --force if you want to replace it." >&2
    exit 1
  fi
fi

ln -s "$keymap_src" "$target_link"

echo "Linked: $target_link -> $keymap_src"
echo "Compile with: qmk compile -kb $compile_keyboard -km wizardstark"
echo "No flash step is performed by this script."
