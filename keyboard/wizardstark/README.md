# Voyager keymap (`wizardstark`)

This keymap is updated to build against a current ZSA QMK checkout without flashing the keyboard.

## What changed

- migrated ZSA integration to modern community modules via `keymap.json`
  - `zsa/oryx`
  - `zsa/defaults`
- updated `sm_td` integration for the current package API
- migrated combos to `COMBO_ACTION` handling for compatibility with the current `sm_td` behavior
- removed the old `RGB_MATRIX_CUSTOM_KB` flag that now requires a missing `rgb_matrix_kb.inc`
- kept `qmk-vim` as direct source files from the bundled submodule
- compile-tested against a fresh `zsa/qmk_firmware` checkout

## Repo dependencies

Initialize the bundled dependencies first:

```sh
git submodule update --init --recursive keyboard/wizardstark/qmk-vim keyboard/wizardstark/sm_td
```

## Link into QMK

```sh
./scripts/link-voyager-keymap.sh /path/to/qmk_firmware
```

If `QMK_HOME` or `~/.config/qmk/qmk.ini` is already set, the path argument is optional.

## Compile

```sh
qmk compile -kb zsa/voyager -km wizardstark
```

## Build + flash with `zapp`

Prerequisites:

```sh
brew install zapp dfu-util
```

Also ensure one of these is true:

- `qmk` is already installed, or
- `uv` is installed so the script can bootstrap `qmk` automatically

Then use the helper script:

```sh
./scripts/voyager-build-and-flash.sh /path/to/qmk_firmware
```

Typical flow:

1. Edit the keymap in this repo.
2. Run `./scripts/voyager-build-and-flash.sh ...`.
3. After the compile succeeds, `zapp` starts automatically.
4. When `zapp` says it is waiting for the keyboard, put the Voyager into bootloader mode.

The script will:

- ensure the keymap is symlinked into the QMK checkout
- compile `zsa/voyager:wizardstark`
- immediately start `zapp`
- flash the resulting `.bin` with `zapp`
- save full `zapp` output under `~/.cache/wizardstark-voyager/logs/`

If `qmk` is not already installed, the script bootstraps it with `uv` into a local cache.
If `zapp` fails with `errno 13` on Linux, install the ZSA udev rules and then unplug/replug the keyboard before retrying:

```sh
curl -L https://raw.githubusercontent.com/zsa/zapp/main/udev/50-zsa.rules \
  | sudo tee /etc/udev/rules.d/50-zsa.rules >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger
```

For a safe dry run, use:

```sh
./scripts/voyager-build-and-flash.sh /path/to/qmk_firmware --compile-only
```

## Safety

The dedicated flash script is the only helper here that performs flashing.
Nothing in my verification steps flashed your keyboard.
