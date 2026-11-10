# Voyager / Moonlander keymap (`wizardstark`)

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

## Moonlander port

Both keyboards use this same keymap directory, so layers, combos, macros,
Achordion, and gaming behavior stay in sync. `layout_adapter.h` translates the
52-key Voyager layout to the Moonlander; the Voyager target is unchanged.

Mapping:

- Four main rows use the outer six columns on each half.
- The two **outer white thumb keys** on each half retain the Voyager bindings,
  in left-to-right order (viewed from above):

  | Thumb key | Base tap | Base hold |
  | --- | --- | --- |
  | Left outer | Space | Symbols layer |
  | Left middle | Backspace | — |
  | Right middle | Enter | — |
  | Right outer | R | Navigation layer |

- Thumb bindings on the other five layers are preserved too.
- All 20 extra keys are `KC_NO` on **every** layer: inner columns, fifth main
  row, red keys, and innermost white thumbs. They do not fall through to another
  layer. Their LEDs are off when custom layer lighting is active.
- Per-key layer colors follow the corresponding Voyager positions rather than
  using the Moonlander's different LED numbering.

### Verified hardware

This port targets **Moonlander revision A**, confirmed by a successful hardware
flash. Its bootloader identifies as **STM Device in DFU Mode** / **STM32 Bootloader**.
The helpers select `zsa/moonlander/reva` with `--moonlander`;
`--moonlander=reva` remains a compatibility alias. Other revisions are not supported.
Do not flash a Voyager image onto the Moonlander.

### Build and flash

The QMK checkout is external to this repository (locally: `/home/juan/qmk_firmware`).
Use an existing recent `zsa/qmk_firmware` checkout, or prepare one:

```sh
git clone --recurse-submodules https://github.com/zsa/qmk_firmware.git ~/qmk_firmware
```

The existing prerequisites and toolchain setup above also apply to Moonlander.
Despite their historical Voyager filenames, both helpers support either keyboard:

```sh
# Safe: link and compile only.
./scripts/voyager-build-and-flash.sh ~/qmk_firmware --moonlander --compile-only

# Build and start zapp; reset ONLY the intended Moonlander when prompted.
./scripts/voyager-build-and-flash.sh ~/qmk_firmware --moonlander
```

You can also link and compile separately:

```sh
./scripts/link-voyager-keymap.sh ~/qmk_firmware --moonlander
qmk compile -kb zsa/moonlander/reva -km wizardstark
```

Firmware is written to `QMK_HOME/zsa_moonlander_reva_wizardstark.bin`.
Flash logs go to `~/.cache/wizardstark-moonlander/logs/`. The QMK CLI and ARM
compiler cache are shared with the existing Voyager workflow.

### Regression tests

```sh
python3 tests/keyboard-port.test.py
```

These hardware-free tests require `cc` and check all six layers, all 20 disabled
keys, thumb order, LED source mapping, target selection, safe linking, and
compile-only / missing-firmware flash guards.

## Safety

The dedicated flash script is the only helper here that performs flashing.
Nothing in my verification steps flashed your keyboard.
