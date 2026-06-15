#pragma once

#define BASE_M LGUI_T(KC_M)
#define BASE_S LALT_T(KC_S)
#define BASE_N LCTL_T(KC_N)
#define BASE_T LSFT_T(KC_T)
#define BASE_A RSFT_T(KC_A)
#define BASE_E LCTL_T(KC_E)
#define BASE_H LALT_T(KC_H)
#define BASE_R LT(NAV, KC_R)
#define BASE_SLSH LGUI_T(KC_SLSH)
#define BASE_SPC LT(SYM, KC_SPC)
#define BASE_G HYPR_T(KC_G)
#define BASE_DOT HYPR_T(KC_DOT)

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
};

enum layers { BASE, SYM, NAV, GAME, GAME2, MOUSE };

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [BASE] = LAYOUT_voyager(
    KC_LGUI,        KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           KC_DEL,
    KC_TAB,         KC_X,           KC_W,           BASE_M,         BASE_G,         KC_J,                                           KC_Z,           BASE_DOT,       BASE_SLSH,      KC_Q,           KC_QUOT,        KC_MINS,
    KC_ESC,         BASE_S,         KC_C,           BASE_N,         BASE_T,         KC_K,                                           KC_COMM,        BASE_A,         BASE_E,         KC_I,           BASE_H,         KC_SCLN,
    KC_LALT,        KC_B,           KC_P,           KC_L,           KC_D,           KC_V,                                           KC_GRV,         KC_U,           KC_O,           KC_Y,           KC_F,           KC_ENT,
                                                                    BASE_SPC,       KC_BSPC,                                        KC_ENT,         BASE_R
  ),
  [SYM] = LAYOUT_voyager(
    KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,          KC_F6,                                          KC_F7,          KC_F8,          KC_F9,          KC_F10,         KC_F11,         KC_F12,
    _______,        KC_PERC,        KC_LABK,        KC_RABK,        KC_DLR,         KC_SLSH,                                        KC_AMPR,        KC_COMM,        KC_LBRC,        KC_RBRC,        KC_QUOT,        _______,
    _______,        KC_EXLM,        KC_MINS,        KC_PLUS,        KC_EQL,         KC_HASH,                                        KC_PIPE,        KC_COLN,        KC_LPRN,        KC_RPRN,        KC_QUES,        _______,
    _______,        KC_CIRC,        KC_DOT,         KC_ASTR,        KC_BSLS,        KC_PIPE,                                        KC_GRV,         KC_DQUO,        KC_LCBR,        KC_RCBR,        KC_AT,          KC_ENT,
                                                                    _______,        _______,                                        KC_ENT,         MO(NAV)
  ),
  [NAV] = LAYOUT_voyager(
    _______,        _______,        KC_BRID,        KC_BRIU,        _______,        _______,                                        _______,        KC_HOME,        KC_PGDN,        KC_PGUP,        KC_END,         _______,
    KC_VOLD,        KC_VOLU,        KC_7,           KC_8,           KC_9,           _______,                                        _______,        KC_UNDS,        LCTL(KC_D),     LCTL(KC_U),     KC_DLR,         _______,
    KC_MPRV,        KC_MNXT,        KC_4,           KC_5,           KC_6,           _______,                                        _______,        KC_H,           KC_J,           KC_K,           KC_L,           _______,
    KC_MUTE,        KC_0,           KC_1,           KC_2,           KC_3,           KC_BSLS,                                        _______,        KC_LEFT,        KC_DOWN,        KC_UP,          KC_RIGHT,       _______,
                                                                    KC_MPLY,        KC_MSTP,                                        _______,        _______
  ),
  [GAME] = LAYOUT_voyager(
    _______,        KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_K,           KC_Y,           KC_J,           KC_P,           RALT(KC_F10),   TO(BASE),
    KC_GRV,         KC_TAB,         KC_Q,           KC_W,           KC_E,           KC_R,                                           KC_L,           KC_O,           KC_UP,          KC_N,           KC_VOLD,        KC_VOLU,
    KC_ESC,         KC_LSFT,        KC_A,           KC_S,           KC_D,           KC_F,                                           KC_U,           KC_LEFT,        KC_DOWN,        KC_RGHT,        KC_MPRV,        KC_MNXT,
    KC_LALT,        KC_LCTL,        KC_Z,           KC_X,           KC_C,           KC_V,                                           KC_M,           KC_T,           KC_G,           KC_B,           KC_MUTE,        KC_H,
                                                                    KC_SPC,         MO(GAME2),                                      KC_MSTP,        KC_MPLY
  ),
  [GAME2] = LAYOUT_voyager(
    _______,        KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_K,           KC_Y,           KC_UP,          KC_P,           RALT(KC_F10),   TO(BASE),
    KC_GRV,         KC_Z,           KC_H,           KC_M,           KC_G,           KC_J,                                           KC_L,           KC_DOT,         KC_UP,          KC_N,           KC_VOLD,        KC_VOLU,
    KC_ESC,         KC_Y,           KC_O,           KC_N,           KC_T,           KC_K,                                           KC_LEFT,        KC_LEFT,        KC_DOWN,        KC_RGHT,        KC_SCLN,        KC_MNXT,
    KC_LALT,        KC_B,           KC_P,           KC_L,           KC_U,           KC_U,                                           KC_M,           KC_U,           KC_G,           KC_B,           KC_MUTE,        KC_H,
                                                                    _______,        _______,                                        KC_MSTP,        KC_MPLY
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
