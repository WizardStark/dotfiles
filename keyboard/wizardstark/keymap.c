#include QMK_KEYBOARD_H
#include "keymap.h"
#include "qmk-vim/src/vim.h"
#include "rgb.h"
#include "sm_td/sm_td/sm_td.h"
#include "sm_td_user.h"

#ifdef STATUS_LED_1
void vim_mode_active(bool active) { STATUS_LED_1(active); }
#endif

#ifdef STATUS_LED_3
void vim_mac_mode_active(bool active) { STATUS_LED_3(active); }
#endif

bool IS_MAC = false;

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

const uint16_t PROGMEM combo_SPCR[] = {KC_SPC, KC_R, COMBO_END};
const uint16_t PROGMEM combo_COMK[] = {KC_COMM, KC_K, COMBO_END};
const uint16_t PROGMEM combo_AH[] = {KC_A, KC_H, COMBO_END};
const uint16_t PROGMEM combo_UH[] = {KC_U, KC_H, COMBO_END};
const uint16_t PROGMEM combo_EH[] = {KC_E, KC_H, COMBO_END};
const uint16_t PROGMEM combo_OH[] = {KC_O, KC_H, COMBO_END};
const uint16_t PROGMEM combo_GM[] = {KC_G, KC_M, COMBO_END};
const uint16_t PROGMEM combo_NC[] = {KC_N, KC_C, COMBO_END};
const uint16_t PROGMEM combo_XW[] = {KC_X, KC_W, COMBO_END};
const uint16_t PROGMEM combo_TN[] = {KC_T, KC_N, COMBO_END};
const uint16_t PROGMEM combo_WM[] = {KC_W, KC_M, COMBO_END};
const uint16_t PROGMEM combo_MC[] = {KC_M, KC_C, COMBO_END};
const uint16_t PROGMEM combo_TA[] = {KC_T, KC_A, COMBO_END};
const uint16_t PROGMEM combo_RDEL[] = {KC_R, KC_DEL, COMBO_END};

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
  if (!process_smtd(keycode, record)) {
    return false;
  }

  if (!process_vim_mode(keycode, record)) {
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
  case TOG_VIM:
    if (record->event.pressed) {
      toggle_vim_mode();
      vim_mode_active(vim_mode_enabled());
    }
  case VIM_MAC:
    if (record->event.pressed) {
      if (IS_MAC) {
        disable_vim_for_mac();
      } else {
        enable_vim_for_mac();
      }

      IS_MAC = !IS_MAC;
      vim_mac_mode_active(vim_mode_enabled() && vim_for_mac_enabled());
    }
    return false;
  }

  if (caps_word_active) {
    unregister_mods(MOD_BIT(KC_LSFT));
  }

  return true;
}

bool caps_word_press_user(uint16_t keycode) {
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
