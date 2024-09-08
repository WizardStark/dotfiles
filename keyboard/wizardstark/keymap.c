#include QMK_KEYBOARD_H
#include "rgb.h"
#include "version.h"
#define MOON_LED_LEVEL LED_LEVEL
#define ML_SAFE_RANGE SAFE_RANGE

enum custom_keycodes {
  RGB_SLD = ML_SAFE_RANGE,
  MCRO_AU,
  MCRO_UA,
  MCRO_EO,
  MCRO_OE,
  MCRO_GL,
  MCRO_QU,
  MCRO_XPL,
  MCRO_TION,
  MCRO_MPL,
  SMTD_KEYCODES_BEGIN,
  CKC_M,
  CKC_C,
  CKC_N,
  CKC_T,
  CKC_A,
  CKC_E,
  CKC_I,
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

#include "sm_td.h"

enum layers { BASE, SYM, NAV, GAME, MOUSE };

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [BASE] = LAYOUT_voyager(
    KC_LGUI,        KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           KC_DEL,
    KC_TAB,         KC_X,           KC_W,           CKC_M,          CKC_G,          KC_J,                                           KC_Z,           CKC_DOT,        CKC_SLSH,       KC_Q,           KC_QUOT,        KC_MINS,
    KC_ESC,         KC_S,           CKC_C,          CKC_N,          CKC_T,          KC_K,                                           KC_COMM,        CKC_A,          CKC_E,          CKC_I,          KC_H,           KC_SCLN,
    KC_LALT,        KC_B,           KC_P,           KC_L,           KC_D,           KC_V,                                           KC_GRV,         KC_U,           KC_O,           KC_Y,           KC_F,           KC_ENT,
                                                                    CKC_SPC,        KC_BSPC,                                       KC_ENT,         CKC_R
  ),
  [SYM] = LAYOUT_voyager(
    KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,          KC_F6,                                          KC_F7,          KC_F8,          KC_F9,          KC_F10,         KC_F11,         KC_F12,
    _______,        KC_PERC,        KC_LABK,        KC_RABK,        KC_DLR,         KC_SLSH,                                        KC_AMPR,        KC_COMM,        KC_LBRC,        KC_RBRC,        KC_QUOT,        _______,
    _______,        KC_EXLM,        CKC_MINS,       CKC_PLUS,       CKC_EQL,        KC_HASH,                                        KC_PIPE,        CKC_COLN,       CKC_LPRN,       CKC_RPRN,       KC_QUES,        _______,
    _______,        KC_CIRC,        KC_DOT,         KC_ASTR,        KC_BSLS,        KC_PIPE,                                        KC_GRV,         KC_DQUO,        KC_LCBR,        KC_RCBR,        KC_AT,          KC_ENT,
                                                                    _______,        _______,                                        KC_ENT,         MO(NAV)
  ),
  [NAV] = LAYOUT_voyager(
    _______,        _______,        KC_BRID,        KC_BRIU,        _______,        _______,                                        _______,        KC_HOME,        KC_PGDN,        KC_PGUP,        KC_END,         TO(GAME),
    KC_VOLD,        KC_VOLU,        KC_7,           KC_8,           KC_9,           KC_MSTP,                                        _______,        KC_UNDS,        LCTL(KC_D),     LCTL(KC_U),     KC_DLR,         _______,
    KC_MPRV,        KC_MNXT,        KC_4,           KC_5,           KC_6,           KC_MPLY,                                        _______,        KC_H,           KC_J,           KC_K,           KC_L,           _______,
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

const uint16_t PROGMEM combo_SPCR[] = {CKC_SPC, CKC_R, COMBO_END};
const uint16_t PROGMEM combo_COMK[] = {KC_COMM, KC_K, COMBO_END};
const uint16_t PROGMEM combo_AH[] = {CKC_A, KC_H, COMBO_END};
const uint16_t PROGMEM combo_UH[] = {KC_U, KC_H, COMBO_END};
const uint16_t PROGMEM combo_EH[] = {CKC_E, KC_H, COMBO_END};
const uint16_t PROGMEM combo_OH[] = {KC_O, KC_H, COMBO_END};
const uint16_t PROGMEM combo_GM[] = {CKC_G, KC_M, COMBO_END};
const uint16_t PROGMEM combo_NC[] = {CKC_N, CKC_C, COMBO_END};
const uint16_t PROGMEM combo_XW[] = {KC_X, KC_W, COMBO_END};
const uint16_t PROGMEM combo_TN[] = {CKC_T, CKC_N, COMBO_END};
const uint16_t PROGMEM combo_WM[] = {KC_W, CKC_M, COMBO_END};
const uint16_t PROGMEM combo_MC[] = {CKC_M, CKC_C, COMBO_END};
const uint16_t PROGMEM combo_TA[] = {CKC_T, CKC_A, COMBO_END};

// clang-format off
combo_t key_combos[COMBO_COUNT] = {
    COMBO(combo_SPCR, KC_ENT),
    COMBO(combo_COMK, TO(4)),
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
};
// clang-format on

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
  if (!process_smtd(keycode, record)) {
    return false;
  }
  switch (keycode) {
  case MCRO_AU:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_A) SS_TAP(X_U));
    }
    break;
  case MCRO_UA:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_U) SS_TAP(X_A));
    }
    break;
  case MCRO_EO:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_E) SS_TAP(X_O));
    }
    break;
  case MCRO_OE:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_O) SS_TAP(X_E));
    }
    break;
  case MCRO_GL:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_G) SS_TAP(X_L));
    }
    break;
  case MCRO_QU:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_Q) SS_TAP(X_U));
    }
    break;
  case MCRO_XPL:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_X) SS_TAP(X_P) SS_TAP(X_L));
    }
    break;
  case MCRO_TION:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_T) SS_TAP(X_I) SS_TAP(X_O) SS_TAP(X_N));
    }
    break;
  case MCRO_MPL:
    if (record->event.pressed) {
      SEND_STRING(SS_TAP(X_M) SS_TAP(X_P) SS_TAP(X_L));
    }
    break;

  case RGB_SLD:
    if (record->event.pressed) {
      rgblight_mode(1);
    }
    return false;
  }
  return true;
}

void on_smtd_action(uint16_t keycode, smtd_action action, uint8_t tap_count) {
  switch (keycode) {
    SMTD_MT(CKC_M, KC_M, KC_LGUI, 2, true)
    SMTD_MTE(CKC_C, KC_C, KC_LALT, 2, true)
    SMTD_MTE(CKC_N, KC_N, KC_LCTL, 2, true)
    SMTD_MTE(CKC_T, KC_T, KC_LSFT, 2, true)
    SMTD_MTE(CKC_A, KC_A, KC_RSFT, 2, true)
    SMTD_MTE(CKC_E, KC_E, KC_LCTL, 2, true)
    SMTD_MTE(CKC_I, KC_I, KC_LALT, 2, true)
    SMTD_MT(CKC_G, KC_G, KC_HYPR, 2, false)
    SMTD_LT(CKC_R, KC_R, NAV, 2, true)
    SMTD_MT(CKC_SLSH, KC_SLSH, KC_LGUI, 2)
    SMTD_MT(CKC_DOT, KC_DOT, KC_HYPR, 2)
    SMTD_LT(CKC_SPC, KC_SPC, SYM, 2, true)
    SMTD_MTE(CKC_MINS, KC_MINS, KC_LALT, 2, true)
    SMTD_MTE(CKC_PLUS, KC_PLUS, KC_LCTL, 2, true)
    SMTD_MTE(CKC_EQL, KC_EQL, KC_LSFT, 2, true)
    SMTD_MTE(CKC_COLN, KC_COLN, KC_RSFT, 2, true)
    SMTD_MTE(CKC_LPRN, KC_LPRN, KC_LCTL, 2, true)
    SMTD_MTE(CKC_RPRN, KC_RPRN, KC_LALT, 2, true)
  }
}
