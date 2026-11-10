#!/usr/bin/env python3
"""Hardware-free layout and build-helper regression tests (requires cc)."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
KEYMAP = ROOT / "keyboard/wizardstark"
BUILD = ROOT / "scripts/voyager-build-and-flash.sh"
LINK = ROOT / "scripts/link-voyager-keymap.sh"


def arguments(text):
    """Split macro arguments without splitting LT()/MT() expressions."""
    result, start, depth = [], 0, 0
    for i, char in enumerate(text):
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            result.append(re.sub(r"\s+", "", text[start:i]))
            start = i + 1
    result.append(re.sub(r"\s+", "", text[start:]))
    return result


def preprocess(moonlander, rgb=False):
    source = '#define LAYOUT_moonlander(...) {__VA_ARGS__}\n'
    if moonlander:
        source += '#define KEYBOARD_zsa_moonlander\n'
    else:
        source += '#define LAYOUT_voyager(...) {__VA_ARGS__}\n'
    source += '#include "keymap.h"\n'
    if rgb:
        source += '#define QMK_KEYBOARD_H "empty.h"\n#include "rgb.h"\n'
    with tempfile.TemporaryDirectory() as temp:
        Path(temp, "empty.h").touch()
        return subprocess.run(
            ["cc", "-E", "-P", "-x", "c", "-I", str(KEYMAP), "-I", temp, "-"],
            input=source, text=True, capture_output=True, check=True,
        ).stdout


# Native Moonlander LAYOUT positions occupied by the 52 Voyager arguments.
DESTINATIONS = [
    *range(0, 6), *range(8, 14),
    *range(14, 20), *range(22, 28),
    *range(28, 34), *range(36, 42),
    *range(42, 48), *range(48, 54),
    66, 67, 70, 71,
]


class LayoutTests(unittest.TestCase):
    def test_all_six_layers_preserve_every_key_and_disable_twenty_extras(self):
        pattern = r"\[(BASE|SYM|NAV|GAME|GAME2|MOUSE)\]\s*=\s*\{([^{}]+)\}"
        voyager = dict(re.findall(pattern, preprocess(False)))
        moonlander = dict(re.findall(pattern, preprocess(True)))
        self.assertEqual(len(voyager), 6)
        self.assertEqual(voyager.keys(), moonlander.keys())
        for layer in voyager:
            with self.subTest(layer=layer):
                original = arguments(voyager[layer])
                actual = arguments(moonlander[layer])
                self.assertEqual(len(original), 52)
                self.assertEqual(len(actual), 72)
                self.assertEqual([actual[i] for i in DESTINATIONS], original)
                extras = [v for i, v in enumerate(actual) if i not in DESTINATIONS]
                self.assertEqual(extras, ["KC_NO"] * 20)

    def test_rgb_sources_follow_the_same_physical_mapping(self):
        output = preprocess(True, rgb=True)
        match = re.search(r"voyager_led_indices\[.*?=\s*\{([^{}]+)\}", output, re.S)
        self.assertIsNotNone(match)
        values = arguments(match[1])
        expected = ["KC_NO"] * 72
        sources = []
        for row in range(4):
            sources += list(range(row * 6 + 1, row * 6 + 7))
            sources += list(range(row * 6 + 27, row * 6 + 33))
        sources += [25, 26, 51, 52]
        for destination, source in zip(DESTINATIONS, sources):
            expected[destination] = str(source)
        self.assertEqual(values, expected)


class HelperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.qmk = self.home / "qmk with spaces"
        for board in ("voyager", "moonlander/reva"):
            (self.qmk / "keyboards/zsa" / board).mkdir(parents=True)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), QMK_HOME=str(self.qmk),
                        PATH=f"{self.bin}:{os.environ['PATH']}",
                        ARM_GCC_BIN_DIR=str(self.bin))
        # Resolve the current interpreter directly, avoiding HOME-sensitive shims.
        self.stub("python3", f'exec "{sys.executable}" "$@"\n')
        for command in ("make", "dfu-suffix", "arm-none-eabi-gcc"):
            self.stub(command, "exit 0\n")
        # Fail loudly if compile-only accidentally invokes a flasher.
        for command in ("zapp", "script"):
            self.stub(command, 'touch "$HOME/flash-invoked"; exit 99\n')
        self.stub("qmk", '''
if [[ "$1" != compile ]]; then exit 90; fi
keyboard=""; keymap=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -kb) keyboard="$2"; shift ;;
    -km) keymap="$2"; shift ;;
  esac
  shift
done
printf '%s:%s\\n' "$keyboard" "$keymap" > "$HOME/compiled-target"
if [[ ! -e "$HOME/omit-firmware" ]]; then
  touch "${keyboard//\\//_}_${keymap}.bin"
fi
''')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -eu\n" + body)
        path.chmod(0o755)

    def run_helper(self, script, *args):
        return subprocess.run([str(script), *args], env=self.env,
                              text=True, capture_output=True)

    def test_compile_only_targets_each_board_without_flashing(self):
        for option, target in ((None, "zsa/voyager"),
                               ("--moonlander=reva", "zsa/moonlander/reva"),
                               ("--moonlander", "zsa/moonlander/reva")):
            with self.subTest(target=target):
                args = ([option] if option else []) + ["--compile-only"]
                result = self.run_helper(BUILD, *args)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.home / "compiled-target").read_text().strip(),
                                 f"{target}:wizardstark")
                board = "moonlander" if option else "voyager"
                link = self.qmk / f"keyboards/zsa/{board}/keymaps/wizardstark"
                self.assertEqual(link.resolve(), KEYMAP)
                self.assertFalse((self.home / "flash-invoked").exists())

    def test_unsupported_revisions_are_rejected(self):
        for script in (BUILD, LINK):
            for option in ("--moonlander=revb", "--moonlander=revc"):
                result = self.run_helper(script, option)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Unknown option", result.stderr)
        self.assertFalse((self.home / "compiled-target").exists())

    def test_link_does_not_replace_existing_keymap(self):
        existing = self.qmk / "keyboards/zsa/moonlander/keymaps/wizardstark"
        existing.mkdir(parents=True)
        marker = existing / "keep.txt"
        marker.write_text("keep")
        result = self.run_helper(LINK, "--moonlander=reva")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(marker.read_text(), "keep")

    def test_missing_firmware_blocks_flash_and_does_not_accept_stale_binary(self):
        stale = self.qmk / "zsa_moonlander_reva_wizardstark.bin"
        stale.touch()
        (self.home / "omit-firmware").touch()
        result = self.run_helper(BUILD, "--moonlander=reva")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("firmware was not found", result.stderr)
        self.assertFalse(stale.exists())
        self.assertFalse((self.home / "flash-invoked").exists())


if __name__ == "__main__":
    unittest.main()
