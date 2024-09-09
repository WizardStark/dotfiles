#include QMK_KEYBOARD_H
#include "qmk-vim/src/vim.h"
#include "rgb.h"
#include "version.h"
#define MOON_LED_LEVEL LED_LEVEL

enum custom_keycodes {
  RGB_SLD = SAFE_RANGE,
  MCRO_AU,
  MCRO_UA,
  MCRO_EO,
  MCRO_OE,
  MCRO_GL,
  MCRO_QU,
  MCRO_XPL,
  MCRO_TION,
  MCRO_MPL,
  TOG_VIM,
  VIM_MAC,
  SMTD_KEYCODES_BEGIN,
  CKC_M,
  CKC_S,
  CKC_H,
  CKC_N,
  CKC_T,
  CKC_A,
  CKC_E,
  CKC_SLSH,
  CKC_R,
  CKC_G,
  CKC_SPC,
  CKC_DOT,
  CKC_EQL,
  CKC_PLUS,
  CKC_MINS,
  CKC_COLN,
  CKC_LPRN,
  CKC_RPRN,
  SMTD_KEYCODES_END,
};

#include "sm_td/sm_td.h"

enum layers { BASE, SYM, NAV, GAME, MOUSE };

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [BASE] = LAYOUT_voyager(
    KC_LGUI,        KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           KC_DEL,
    KC_TAB,         KC_X,           KC_W,           CKC_M,          CKC_G,          KC_J,                                           KC_Z,           CKC_DOT,        CKC_SLSH,       KC_Q,           KC_QUOT,        KC_MINS,
    KC_ESC,         CKC_S,          KC_C,           CKC_N,          CKC_T,          KC_K,                                           KC_COMM,        CKC_A,          CKC_E,          KC_I,           CKC_H,          KC_SCLN,
    KC_LALT,        KC_B,           KC_P,           KC_L,           KC_D,           KC_V,                                           KC_GRV,         KC_U,           KC_O,           KC_Y,           KC_F,           KC_ENT,
                                                                    CKC_SPC,        KC_BSPC,                                        KC_ENT,         CKC_R
  ),
  [SYM] = LAYOUT_voyager(
    KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,          KC_F6,                                          KC_F7,          KC_F8,          KC_F9,          KC_F10,         KC_F11,         KC_F12,
    _______,        KC_PERC,        KC_LABK,        KC_RABK,        KC_DLR,         KC_SLSH,                                        KC_AMPR,        KC_COMM,        KC_LBRC,        KC_RBRC,        KC_QUOT,        _______,
    _______,        KC_EXLM,        CKC_MINS,       CKC_PLUS,       CKC_EQL,        KC_HASH,                                        KC_PIPE,        CKC_COLN,       CKC_LPRN,       CKC_RPRN,       KC_QUES,        _______,
    _______,        KC_CIRC,        KC_DOT,         KC_ASTR,        KC_BSLS,        KC_PIPE,                                        KC_GRV,         KC_DQUO,        KC_LCBR,        KC_RCBR,        KC_AT,          KC_ENT,
                                                                    _______,        _______,                                        KC_ENT,         MO(NAV)
  ),
  [NAV] = LAYOUT_voyager(
    _______,        _______,        KC_BRID,        KC_BRIU,        _______,        _______,                                        _______,        KC_HOME,        KC_PGDN,        KC_PGUP,        KC_END,         _______,
    KC_VOLD,        KC_VOLU,        KC_7,           KC_8,           KC_9,           KC_MSTP,                                        VIM_MAC,        KC_UNDS,        LCTL(KC_D),     LCTL(KC_U),     KC_DLR,         _______,
    KC_MPRV,        KC_MNXT,        KC_4,           KC_5,           KC_6,           KC_MPLY,                                        TOG_VIM,        KC_H,           KC_J,           KC_K,           KC_L,           _______,
    KC_MUTE,        KC_0,           KC_1,           KC_2,           KC_3,           KC_BSLS,                                        _______,        KC_LEFT,        KC_DOWN,        KC_UP,          KC_RIGHT,       _______,
                                                                    _______,        _______,                                        _______,        _______
  ),
  [GAME] = LAYOUT_voyager(
    _______,        KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           _______,        _______,        _______,        _______,        RALT(KC_F10),   TO(BASE),
    KC_GRV,         KC_TAB,         KC_Q,           KC_W,           KC_E,           KC_R,                                           KC_MSTP,        _______,        KC_UP,          _______,        KC_VOLD,        KC_VOLU,
    KC_ESC,         KC_LSFT,        KC_A,           KC_S,           KC_D,           KC_F,                                           KC_MPLY,        KC_LEFT,        KC_DOWN,        KC_RGHT,        KC_MPRV,        KC_MNXT,
    KC_I,           KC_LCTL,        KC_Z,           KC_X,           KC_C,           KC_V,                                           _______,        KC_B,           KC_J,           KC_T,           KC_MUTE,        _______,
                                                                    KC_SPC,         KC_LALT,                                        _______,        _______
  ),
  [MOUSE] = LAYOUT_voyager(
    _______,        _______,        _______,        _______,        _______,        _______,                                        _______,        _______,        _______,        _______,        _______,        _______,
    _______,        _______,        _______,        _______,        _______,        _______,                                        _______,        LALT(KC_LEFT),  KC_MS_WH_DOWN,  KC_MS_WH_UP,    LALT(KC_RIGHT), _______,
    _______,        KC_LCTL,        KC_MS_ACCEL0,   KC_MS_ACCEL1,   KC_MS_ACCEL2,   _______,                                        _______,        KC_MS_LEFT,     KC_MS_DOWN,     KC_MS_UP,       KC_MS_RIGHT,    _______,
    _______,        TO(BASE),       _______,        _______,        _______,        _______,                                        _______,        _______,        _______,        _______,        _______,        _______,
                                                                  KC_MS_BTN2,     _______,                                        KC_MS_BTN3,     KC_MS_BTN1
  ),
};
// clang-format on

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

  switch (keycode) {
  case MCRO_AU:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_A);
        tap_code16(KC_U);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_A);
        tap_code16(KC_U);
      }
    }
    break;
  case MCRO_UA:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_U);
        tap_code16(KC_A);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_U);
        tap_code16(KC_A);
      }
    }
    break;
  case MCRO_EO:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_E);
        tap_code16(KC_O);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_E);
        tap_code16(KC_O);
      }
    }
    break;
  case MCRO_OE:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_O);
        tap_code16(KC_E);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_O);
        tap_code16(KC_E);
      }
    }
    break;
  case MCRO_GL:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_G);
        tap_code16(KC_L);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_G);
        tap_code16(KC_L);
      }
    }
    break;
  case MCRO_QU:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_Q);
        tap_code16(KC_U);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_Q);
        tap_code16(KC_U);
      }
    }
    break;
  case MCRO_XPL:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_X);
        tap_code16(KC_P);
        tap_code16(KC_L);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_X);
        tap_code16(KC_P);
        tap_code16(KC_L);
      }
    }
    break;
  case MCRO_TION:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_T);
        tap_code16(KC_I);
        tap_code16(KC_O);
        tap_code16(KC_N);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_T);
        tap_code16(KC_I);
        tap_code16(KC_O);
        tap_code16(KC_N);
      }
    }
    break;
  case MCRO_MPL:
    if (record->event.pressed) {
      if (caps_word_active) {
        register_mods(MOD_BIT(KC_LSFT));
        tap_code16(KC_M);
        tap_code16(KC_P);
        tap_code16(KC_L);
        unregister_mods(MOD_BIT(KC_LSFT));
      } else {
        tap_code16(KC_M);
        tap_code16(KC_P);
        tap_code16(KC_L);
      }
    }
    break;
  case RGB_SLD:
    if (record->event.pressed) {
      rgblight_mode(1);
    }
  case TOG_VIM:
    if (record->event.pressed) {
      toggle_vim_mode();
      if (!IS_MAC) {
        disable_vim_for_mac();
      }
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
    SMTD_MTE(CKC_MINS, KC_MINS, KC_LALT, 2, true)
    SMTD_MTE(CKC_PLUS, KC_PLUS, KC_LCTL, 2, true)
    SMTD_MTE(CKC_EQL, KC_EQL, KC_LSFT, 2, true)
    SMTD_MTE(CKC_COLN, KC_COLN, KC_RSFT, 2, true)
    SMTD_MTE(CKC_LPRN, KC_LPRN, KC_LCTL, 2, true)
    SMTD_MTE(CKC_RPRN, KC_RPRN, KC_LALT, 2, true)

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
