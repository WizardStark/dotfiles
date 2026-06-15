# Voyager keymap (`wizardstark`)

This keymap now uses stock QMK tap-hold keys plus core Achordion. `sm_td` and `qmk-vim` are no longer part of the active build.

## What changed

- migrated ZSA integration to modern community modules via `keymap.json`
  - `zsa/oryx`
  - `zsa/defaults`
- replaced the previous `sm_td`/`qmk-vim` stack with stock QMK `MT()` / `LT()` / `HYPR_T()` keys
- enabled core QMK Achordion for home-row mod / layer-tap chord handling
- kept combos, but disabled them on `GAME` and `GAME2`
- made the `T+A` Caps Word combo tap-only so it does not interfere with using those keys as Shift holds
- removed the old `RGB_MATRIX_CUSTOM_KB` flag that now requires a missing `rgb_matrix_kb.inc`
- compile-tested against a fresh `zsa/qmk_firmware` checkout

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
