#include QMK_KEYBOARD_H
#include "keymap.h"
#include "sm_td/sm_td.h"

void on_smtd_action(uint16_t keycode, smtd_action action, uint8_t tap_count) {
  switch (keycode) {
    SMTD_MT(CKC_M, KC_M, KC_LGUI, 2, true)
    SMTD_MT(CKC_S, KC_S, KC_LALT, 2, true)
    SMTD_MT(CKC_N, KC_N, KC_LCTL, 2, true)
    SMTD_MTE(CKC_T, KC_T, KC_LSFT, 2, true)
    SMTD_MTE(CKC_A, KC_A, KC_RSFT, 2, true)
    SMTD_MT(CKC_E, KC_E, KC_LCTL, 2, true)
    SMTD_MT(CKC_H, KC_H, KC_LALT, 2, true)
    SMTD_LT(CKC_R, KC_R, NAV, 2, true)
    SMTD_MT(CKC_SLSH, KC_SLSH, KC_LGUI, 2)
    SMTD_LT(CKC_SPC, KC_SPC, SYM, 2, true)
    SMTD_MT(CKC_EXLM, KC_EXLM, KC_LALT, 2, true)
    SMTD_MT(CKC_PLUS, KC_PLUS, KC_LCTL, 2, true)
    SMTD_MTE(CKC_EQL, KC_EQL, KC_LSFT, 2, true)
    SMTD_MTE(CKC_COLN, KC_COLN, KC_RSFT, 2, true)
    SMTD_MT(CKC_LPRN, KC_LPRN, KC_LCTL, 2, true)
    SMTD_MT(CKC_QUES, KC_QUES, KC_LALT, 2, true)

  case CKC_G: {
    switch (action) {
    case SMTD_ACTION_TOUCH:
      break;

    case SMTD_ACTION_TAP:
      SMTD_TAP_16(true, KC_G);
      break;

    case SMTD_ACTION_HOLD:
      switch (tap_count) {
      case 0:
      case 1:
        register_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) | MOD_BIT(KC_LGUI) |
                      MOD_BIT(KC_LSFT));
        break;
      default:
        SMTD_REGISTER_16(true, KC_G);
        break;
      }
      break;

    case SMTD_ACTION_RELEASE:
      switch (tap_count) {
      case 0:
      case 1:
        unregister_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) | MOD_BIT(KC_LGUI) |
                        MOD_BIT(KC_LSFT));
        break;
      default:
        SMTD_UNREGISTER_16(true, KC_G);
        break;
      }
      break;
    }
    break;
  }

  case CKC_DOT: {
    switch (action) {
    case SMTD_ACTION_TOUCH:
      break;

    case SMTD_ACTION_TAP:
      tap_code16(KC_DOT);
      break;

    case SMTD_ACTION_HOLD:
      switch (tap_count) {
      case 0:
      case 1:
        register_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) | MOD_BIT(KC_LGUI) |
                      MOD_BIT(KC_LSFT));
        break;
      default:
        register_code16(KC_DOT);
        break;
      }
      break;

    case SMTD_ACTION_RELEASE:
      switch (tap_count) {
      case 0:
      case 1:
        unregister_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) | MOD_BIT(KC_LGUI) |
                        MOD_BIT(KC_LSFT));
        break;
      default:
        unregister_code16(KC_DOT);
        break;
      }
      break;
    }
    break;
  }
  }
}
