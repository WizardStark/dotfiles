#include QMK_KEYBOARD_H
#include "keymap.h"
#include "rgb.h"

typedef enum {
  GAME_SOCD_NONE,
  GAME_SOCD_LEFT,
  GAME_SOCD_RIGHT,
  GAME_SOCD_UP,
  GAME_SOCD_DOWN,
} game_socd_key_t;

typedef struct {
  bool negative_held;
  bool positive_held;
  int8_t active_direction;
  uint16_t negative_keycode;
  uint16_t positive_keycode;
} game_socd_axis_t;

static game_socd_axis_t game_socd_horizontal = {
    .negative_keycode = KC_A,
    .positive_keycode = KC_D,
};

static game_socd_axis_t game_socd_vertical = {
    .negative_keycode = KC_W,
    .positive_keycode = KC_S,
};

static uint8_t get_resolved_layer(keypos_t pos) {
  for (int8_t i = (int8_t)(sizeof(keymaps) / sizeof(keymaps[0])) - 1; i >= 0;
       --i) {
    if (layer_state_is(i)) {
      uint16_t keycode = keymap_key_to_keycode(i, pos);
      if (keycode != KC_TRNS) {
        return i;
      }
    }
  }

  return 0;
}

static game_socd_key_t game_socd_key_for_position(keypos_t pos) {
  switch (keymap_key_to_keycode(GAME, pos)) {
  case KC_A:
    return GAME_SOCD_LEFT;
  case KC_D:
    return GAME_SOCD_RIGHT;
  case KC_W:
    return GAME_SOCD_UP;
  case KC_S:
    return GAME_SOCD_DOWN;
  default:
    return GAME_SOCD_NONE;
  }
}

static bool game_socd_key_is_held(game_socd_key_t key) {
  switch (key) {
  case GAME_SOCD_LEFT:
    return game_socd_horizontal.negative_held;
  case GAME_SOCD_RIGHT:
    return game_socd_horizontal.positive_held;
  case GAME_SOCD_UP:
    return game_socd_vertical.negative_held;
  case GAME_SOCD_DOWN:
    return game_socd_vertical.positive_held;
  default:
    return false;
  }
}

static void process_game_socd_axis(game_socd_axis_t *axis, bool negative,
                                   bool pressed) {
  int8_t direction = negative ? -1 : 1;
  uint16_t current_keycode =
      negative ? axis->negative_keycode : axis->positive_keycode;
  uint16_t opposite_keycode =
      negative ? axis->positive_keycode : axis->negative_keycode;
  bool *current_held = negative ? &axis->negative_held : &axis->positive_held;
  bool *opposite_held = negative ? &axis->positive_held : &axis->negative_held;

  if (pressed) {
    *current_held = true;

    if (axis->active_direction == direction) {
      return;
    }

    if (axis->active_direction == -direction) {
      unregister_code16(opposite_keycode);
    }

    register_code16(current_keycode);
    axis->active_direction = direction;
    return;
  }

  *current_held = false;

  if (axis->active_direction != direction) {
    return;
  }

  unregister_code16(current_keycode);

  if (*opposite_held) {
    register_code16(opposite_keycode);
    axis->active_direction = -direction;
  } else {
    axis->active_direction = 0;
  }
}

static bool process_game_socd(keyrecord_t *record) {
  game_socd_key_t socd_key = game_socd_key_for_position(record->event.key);

  if (socd_key == GAME_SOCD_NONE) {
    return false;
  }

  if (record->event.pressed) {
    if (get_resolved_layer(record->event.key) != GAME) {
      return false;
    }
  } else if (!game_socd_key_is_held(socd_key)) {
    return false;
  }

  switch (socd_key) {
  case GAME_SOCD_LEFT:
    process_game_socd_axis(&game_socd_horizontal, true, record->event.pressed);
    break;
  case GAME_SOCD_RIGHT:
    process_game_socd_axis(&game_socd_horizontal, false, record->event.pressed);
    break;
  case GAME_SOCD_UP:
    process_game_socd_axis(&game_socd_vertical, true, record->event.pressed);
    break;
  case GAME_SOCD_DOWN:
    process_game_socd_axis(&game_socd_vertical, false, record->event.pressed);
    break;
  default:
    return false;
  }

  return true;
}

enum combo_events {
  COMBO_SPCR,
  COMBO_COMK,
  COMBO_AH,
  COMBO_UH,
  COMBO_EH,
  COMBO_OH,
  COMBO_GM,
  COMBO_NC,
  COMBO_XW,
  COMBO_TN,
  COMBO_WM,
  COMBO_MC,
  COMBO_TA,
  COMBO_RDEL,
};

const uint16_t PROGMEM combo_SPCR[] = {BASE_SPC, BASE_R, COMBO_END};
const uint16_t PROGMEM combo_COMK[] = {KC_COMM, KC_K, COMBO_END};
const uint16_t PROGMEM combo_AH[] = {BASE_A, BASE_H, COMBO_END};
const uint16_t PROGMEM combo_UH[] = {KC_U, BASE_H, COMBO_END};
const uint16_t PROGMEM combo_EH[] = {BASE_E, BASE_H, COMBO_END};
const uint16_t PROGMEM combo_OH[] = {KC_O, BASE_H, COMBO_END};
const uint16_t PROGMEM combo_GM[] = {BASE_G, BASE_M, COMBO_END};
const uint16_t PROGMEM combo_NC[] = {BASE_N, KC_C, COMBO_END};
const uint16_t PROGMEM combo_XW[] = {KC_X, KC_W, COMBO_END};
const uint16_t PROGMEM combo_TN[] = {BASE_T, BASE_N, COMBO_END};
const uint16_t PROGMEM combo_WM[] = {KC_W, BASE_M, COMBO_END};
const uint16_t PROGMEM combo_MC[] = {BASE_M, KC_C, COMBO_END};
const uint16_t PROGMEM combo_TA[] = {BASE_T, BASE_A, COMBO_END};
const uint16_t PROGMEM combo_RDEL[] = {BASE_R, KC_DEL, COMBO_END};

// clang-format off
combo_t key_combos[COMBO_COUNT] = {
    [COMBO_SPCR] = COMBO_ACTION(combo_SPCR),
    [COMBO_COMK] = COMBO_ACTION(combo_COMK),
    [COMBO_AH]   = COMBO_ACTION(combo_AH),
    [COMBO_UH]   = COMBO_ACTION(combo_UH),
    [COMBO_EH]   = COMBO_ACTION(combo_EH),
    [COMBO_OH]   = COMBO_ACTION(combo_OH),
    [COMBO_GM]   = COMBO_ACTION(combo_GM),
    [COMBO_NC]   = COMBO_ACTION(combo_NC),
    [COMBO_XW]   = COMBO_ACTION(combo_XW),
    [COMBO_TN]   = COMBO_ACTION(combo_TN),
    [COMBO_WM]   = COMBO_ACTION(combo_WM),
    [COMBO_MC]   = COMBO_ACTION(combo_MC),
    [COMBO_TA]   = COMBO_ACTION(combo_TA),
    [COMBO_RDEL] = COMBO_ACTION(combo_RDEL),
};
// clang-format on

bool combo_should_trigger(uint16_t combo_index, combo_t *combo,
                          uint16_t keycode, keyrecord_t *record) {
  (void)combo_index;
  (void)combo;
  (void)keycode;
  (void)record;
  uint8_t layer = get_highest_layer(layer_state);
  return layer != GAME && layer != GAME2;
}

static void emit_macro(uint16_t keycode) {
  switch (keycode) {
  case MCRO_AU:
    tap_code16(KC_A);
    tap_code16(KC_U);
    break;
  case MCRO_UA:
    tap_code16(KC_U);
    tap_code16(KC_A);
    break;
  case MCRO_EO:
    tap_code16(KC_E);
    tap_code16(KC_O);
    break;
  case MCRO_OE:
    tap_code16(KC_O);
    tap_code16(KC_E);
    break;
  case MCRO_GL:
    tap_code16(KC_G);
    tap_code16(KC_L);
    break;
  case MCRO_QU:
    tap_code16(KC_Q);
    tap_code16(KC_U);
    break;
  case MCRO_XPL:
    tap_code16(KC_X);
    tap_code16(KC_P);
    tap_code16(KC_L);
    break;
  case MCRO_TION:
    tap_code16(KC_T);
    tap_code16(KC_I);
    tap_code16(KC_O);
    tap_code16(KC_N);
    break;
  case MCRO_MPL:
    tap_code16(KC_M);
    tap_code16(KC_P);
    tap_code16(KC_L);
    break;
  }
}

bool get_combo_must_tap(uint16_t combo_index, combo_t *combo) {
  (void)combo;

  switch (combo_index) {
  case COMBO_TA:
    return true;
  default:
    return false;
  }
}

void process_combo_event(uint16_t combo_index, bool pressed) {
  if (!pressed) {
    return;
  }

  switch (combo_index) {
  case COMBO_SPCR:
    tap_code16(KC_ENT);
    break;
  case COMBO_COMK:
    layer_move(MOUSE);
    break;
  case COMBO_AH:
    emit_macro(MCRO_AU);
    break;
  case COMBO_UH:
    emit_macro(MCRO_UA);
    break;
  case COMBO_EH:
    emit_macro(MCRO_EO);
    break;
  case COMBO_OH:
    emit_macro(MCRO_OE);
    break;
  case COMBO_GM:
    emit_macro(MCRO_GL);
    break;
  case COMBO_NC:
    emit_macro(MCRO_QU);
    break;
  case COMBO_XW:
    emit_macro(MCRO_XPL);
    break;
  case COMBO_TN:
    emit_macro(MCRO_TION);
    break;
  case COMBO_WM:
    tap_code16(KC_Z);
    break;
  case COMBO_MC:
    emit_macro(MCRO_MPL);
    break;
  case COMBO_TA:
    caps_word_toggle();
    break;
  case COMBO_RDEL:
    layer_move(GAME);
    break;
  }
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  if (process_game_socd(record)) {
    return false;
  }

  if (!process_achordion(keycode, record)) {
    return false;
  }

  bool caps_word_active = is_caps_word_on();
  if (caps_word_active) {
    register_mods(MOD_BIT(KC_LSFT));
  }

  switch (keycode) {
  case MCRO_AU:
  case MCRO_UA:
  case MCRO_EO:
  case MCRO_OE:
  case MCRO_GL:
  case MCRO_QU:
  case MCRO_XPL:
  case MCRO_TION:
  case MCRO_MPL:
    if (record->event.pressed) {
      emit_macro(keycode);
    }
    break;
  case RGB_SLD:
    if (record->event.pressed) {
      rgblight_mode(1);
    }
    break;
  }

  if (caps_word_active) {
    unregister_mods(MOD_BIT(KC_LSFT));
  }

  return true;
}

void matrix_scan_user(void) {
  achordion_task();
}

uint16_t achordion_timeout(uint16_t tap_hold_keycode) {
  (void)tap_hold_keycode;
  return TAPPING_TERM;
}

bool achordion_eager_mod(uint8_t mod) {
  uint8_t normalized = mod_config(mod);

  if (normalized & (MOD_MASK_CTRL | MOD_MASK_SHIFT)) {
    return true;
  }

  return (normalized & MOD_MASK_ALT) && (normalized & MOD_MASK_GUI);
}

bool achordion_chord(uint16_t tap_hold_keycode, keyrecord_t *tap_hold_record,
                     uint16_t other_keycode, keyrecord_t *other_record) {
  (void)other_keycode;

  switch (tap_hold_keycode) {
  case BASE_R:
  case BASE_SPC:
    return true;

  default:
    return achordion_opposite_hands(tap_hold_record, other_record);
  }
}

bool caps_word_press_user(uint16_t keycode) {
  if (IS_QK_MOD_TAP(keycode)) {
    keycode = QK_MOD_TAP_GET_TAP_KEYCODE(keycode);
  } else if (IS_QK_LAYER_TAP(keycode)) {
    keycode = QK_LAYER_TAP_GET_TAP_KEYCODE(keycode);
  }

  switch (keycode) {
  // Keycodes that continue Caps Word, with shift applied.
  case KC_A ... KC_Z:
  case KC_MINS:
  case MCRO_AU:
  case MCRO_UA:
  case MCRO_EO:
  case MCRO_OE:
  case MCRO_GL:
  case MCRO_QU:
  case MCRO_XPL:
  case MCRO_TION:
  case MCRO_MPL:
    add_weak_mods(MOD_BIT(KC_LSFT));
    return true;

  // Keycodes that continue Caps Word, without shifting.
  case KC_1 ... KC_0:
  case KC_BSPC:
  case KC_DEL:
  case KC_UNDS:
    return true;

  default:
    return false;
  }
}
