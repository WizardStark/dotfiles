#include QMK_KEYBOARD_H
#include "keymap.h"
#include "qmk-vim/src/vim.h"
#include "rgb.h"
#include "sm_td/sm_td.h"
#include "sm_td_user.h"

#ifdef STATUS_LED_1
void vim_mode_active(bool active) { STATUS_LED_1(active); }
#endif

#ifdef STATUS_LED_3
void vim_mac_mode_active(bool active) { STATUS_LED_3(active); }
#endif

bool IS_MAC = false;

const uint16_t PROGMEM combo_SPCR[] = {CKC_SPC, CKC_R, COMBO_END};
const uint16_t PROGMEM combo_COMK[] = {KC_COMM, KC_K, COMBO_END};
const uint16_t PROGMEM combo_AH[] = {CKC_A, CKC_H, COMBO_END};
const uint16_t PROGMEM combo_UH[] = {KC_U, CKC_H, COMBO_END};
const uint16_t PROGMEM combo_EH[] = {CKC_E, CKC_H, COMBO_END};
const uint16_t PROGMEM combo_OH[] = {KC_O, CKC_H, COMBO_END};
const uint16_t PROGMEM combo_GM[] = {CKC_G, CKC_M, COMBO_END};
const uint16_t PROGMEM combo_NC[] = {CKC_N, KC_C, COMBO_END};
const uint16_t PROGMEM combo_XW[] = {KC_X, KC_W, COMBO_END};
const uint16_t PROGMEM combo_TN[] = {CKC_T, CKC_N, COMBO_END};
const uint16_t PROGMEM combo_WM[] = {KC_W, CKC_M, COMBO_END};
const uint16_t PROGMEM combo_MC[] = {CKC_M, KC_C, COMBO_END};
const uint16_t PROGMEM combo_TA[] = {CKC_T, CKC_A, COMBO_END};
const uint16_t PROGMEM combo_RDEL[] = {CKC_R, KC_DEL, COMBO_END};

// clang-format off
combo_t key_combos[COMBO_COUNT] = {
    COMBO(combo_SPCR, KC_ENT),
    COMBO(combo_COMK, TO(MOUSE)),
    COMBO(combo_AH, MCRO_AU),
    COMBO(combo_UH, MCRO_UA),
    COMBO(combo_EH, MCRO_EO),
    COMBO(combo_OH, MCRO_OE),
    COMBO(combo_GM, MCRO_GL),
    COMBO(combo_NC, MCRO_QU),
    COMBO(combo_XW, MCRO_XPL),
    COMBO(combo_TN, MCRO_TION),
    COMBO(combo_WM, KC_Z),
    COMBO(combo_MC, MCRO_MPL),
    COMBO(combo_TA, CW_TOGG),
    COMBO(combo_RDEL, TO(GAME)),
};
// clang-format on

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
    if (record->event.pressed) {
      tap_code16(KC_A);
      tap_code16(KC_U);
    }
    break;
  case MCRO_UA:
    if (record->event.pressed) {
      tap_code16(KC_U);
      tap_code16(KC_A);
    }
    break;
  case MCRO_EO:
    if (record->event.pressed) {
      tap_code16(KC_E);
      tap_code16(KC_O);
    }
    break;
  case MCRO_OE:
    if (record->event.pressed) {
      tap_code16(KC_O);
      tap_code16(KC_E);
    }
    break;
  case MCRO_GL:
    if (record->event.pressed) {
      tap_code16(KC_G);
      tap_code16(KC_L);
    }
    break;
  case MCRO_QU:
    if (record->event.pressed) {
      tap_code16(KC_Q);
      tap_code16(KC_U);
    }
    break;
  case MCRO_XPL:
    if (record->event.pressed) {
      tap_code16(KC_X);
      tap_code16(KC_P);
      tap_code16(KC_L);
    }
    break;
  case MCRO_TION:
    if (record->event.pressed) {
      tap_code16(KC_T);
      tap_code16(KC_I);
      tap_code16(KC_O);
      tap_code16(KC_N);
    }
    break;
  case MCRO_MPL:
    if (record->event.pressed) {
      tap_code16(KC_M);
      tap_code16(KC_P);
      tap_code16(KC_L);
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
