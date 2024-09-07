#include QMK_KEYBOARD_H
#include "version.h"
#include "sm_td.h"
#define MOON_LED_LEVEL LED_LEVEL
#define ML_SAFE_RANGE SAFE_RANGE

enum custom_keycodes {
    RGB_SLD = ML_SAFE_RANGE,
    ST_MACRO_0,
    ST_MACRO_1,
    ST_MACRO_2,
    ST_MACRO_3,
    ST_MACRO_4,
    ST_MACRO_5,
    ST_MACRO_6,
    ST_MACRO_7,
    ST_MACRO_8,
    SMTD_KEYCODES_BEGIN,
    SMTD_KEYCODES_END,
};

enum layers {
    BASE,
    SYM,
    NAV,
    GAME,
    MOUSE
};

enum tap_dance_codes {
    DANCE_0,
};

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
  [BASE] = LAYOUT_voyager(
    KC_LGUI,        KC_1,           KC_2,           KC_3,           KC_4,           KC_5,                                           KC_6,           KC_7,           KC_8,           KC_9,           KC_0,           KC_DEL,
    KC_TAB,         KC_X,           KC_W,           KC_M,           ALL_T(KC_G),    KC_J,                                           KC_Z,           KC_DOT,         KC_SLSH,        KC_Q,           KC_QUOT,        KC_MINS,
    MT(MOD_LCTL, KC_ESC),KC_S,      KC_C,           KC_N,           KC_T,           KC_K,                                           KC_COMM,        KC_A,           KC_E,           KC_I,           KC_H,           KC_SCLN,
    KC_LEFT_ALT,    KC_B,           KC_P,           KC_L,           KC_D,           KC_V,                                           TD(DANCE_0),    KC_U,           KC_O,           KC_Y,           KC_F,           KC_ENT,
                                                                    LT(SYM,KC_SPC), MT(MOD_LSFT, KC_BSPC),                          MO(NAV),          KC_R
  ),
  [SYM] = LAYOUT_voyager(
    KC_F1,          KC_F2,          KC_F3,          KC_F4,          KC_F5,          KC_F6,                                          KC_F7,          KC_F8,          KC_F9,          KC_F10,         KC_F11,         KC_F12,
    _______,        KC_PERC,        KC_LABK,        KC_RABK,        KC_DLR,         KC_SLSH,                                        KC_AMPR,        KC_COMM,        KC_LBRC,        KC_RBRC,        KC_QUOT,        _______,
    _______,        KC_EXLM,        KC_MINS,        KC_PLUS,        KC_EQL,         KC_HASH,                                        KC_PIPE,        KC_COLN,        KC_LPRN,        KC_RPRN,        KC_QUES,        _______,
    _______,        KC_CIRC,        KC_DOT,         KC_ASTR,        KC_BSLS,        KC_PIPE,                                        KC_GRV,         KC_DQUO,        KC_LCBR,        KC_RCBR,        KC_AT,          KC_ENT,
                                                                    _______,        _______,                                        MO(NAV),        MT(MOD_LSFT, KC_BSPC)
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

const uint16_t PROGMEM combo0[]  = {LT(1, KC_SPACE), KC_R, COMBO_END};
const uint16_t PROGMEM combo1[]  = {KC_COMMA, KC_K, COMBO_END};
const uint16_t PROGMEM combo2[]  = {KC_A, KC_H, COMBO_END};
const uint16_t PROGMEM combo3[]  = {KC_U, KC_H, COMBO_END};
const uint16_t PROGMEM combo4[]  = {KC_E, KC_H, COMBO_END};
const uint16_t PROGMEM combo5[]  = {KC_O, KC_H, COMBO_END};
const uint16_t PROGMEM combo6[]  = {KC_J, KC_V, COMBO_END};
const uint16_t PROGMEM combo7[]  = {ALL_T(KC_G), KC_D, COMBO_END};
const uint16_t PROGMEM combo8[]  = {ALL_T(KC_G), KC_M, COMBO_END};
const uint16_t PROGMEM combo9[]  = {KC_N, KC_C, COMBO_END};
const uint16_t PROGMEM combo10[] = {KC_X, KC_W, COMBO_END};
const uint16_t PROGMEM combo11[] = {KC_T, KC_N, COMBO_END};
const uint16_t PROGMEM combo12[] = {KC_W, KC_M, COMBO_END};
const uint16_t PROGMEM combo13[] = {KC_M, KC_C, COMBO_END};

// clang-format off
combo_t key_combos[COMBO_COUNT] = {
    COMBO(combo0, KC_ENTER), 
    COMBO(combo1, TO(4)), 
    COMBO(combo2, ST_MACRO_0), 
    COMBO(combo3, ST_MACRO_1), 
    COMBO(combo4, ST_MACRO_2), 
    COMBO(combo5, ST_MACRO_3), 
    COMBO(combo6, LCTL(KC_V)), 
    COMBO(combo7, LCTL(KC_C)), 
    COMBO(combo8, ST_MACRO_4), 
    COMBO(combo9, ST_MACRO_5), 
    COMBO(combo10, ST_MACRO_6), 
    COMBO(combo11, ST_MACRO_7), 
    COMBO(combo12, KC_Z), 
    COMBO(combo13, ST_MACRO_8),
};
// clang-format on

extern rgb_config_t rgb_matrix_config;

void keyboard_post_init_user(void) {
    rgb_matrix_enable();
}

const uint8_t PROGMEM ledmap[][RGB_MATRIX_LED_COUNT][3] = {
    [0] = {{141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}},

    [1] = {{141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}},

    [2] = {{141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}},

    [3] = {{141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {0, 255, 255}, {0, 255, 255}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {0, 255, 255}, {0, 255, 255}},

    [4] = {{141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}, {0, 255, 255}, {27, 255, 255}, {141, 108, 235}, {27, 255, 255}, {0, 255, 255}},

};

void set_layer_color(int layer) {
    for (int i = 0; i < RGB_MATRIX_LED_COUNT; i++) {
        HSV hsv = {
            .h = pgm_read_byte(&ledmap[layer][i][0]),
            .s = pgm_read_byte(&ledmap[layer][i][1]),
            .v = pgm_read_byte(&ledmap[layer][i][2]),
        };
        if (!hsv.h && !hsv.s && !hsv.v) {
            rgb_matrix_set_color(i, 0, 0, 0);
        } else {
            RGB   rgb = hsv_to_rgb(hsv);
            float f   = (float)rgb_matrix_config.hsv.v / UINT8_MAX;
            rgb_matrix_set_color(i, f * rgb.r, f * rgb.g, f * rgb.b);
        }
    }
}

bool rgb_matrix_indicators_user(void) {
    if (rawhid_state.rgb_control) {
        return false;
    }
    if (keyboard_config.disable_layer_led) {
        return false;
    }
    switch (biton32(layer_state)) {
        case 0:
            set_layer_color(0);
            break;
        case 1:
            set_layer_color(1);
            break;
        case 2:
            set_layer_color(2);
            break;
        case 3:
            set_layer_color(3);
            break;
        case 4:
            set_layer_color(4);
            break;
        default:
            if (rgb_matrix_get_flags() == LED_FLAG_NONE) rgb_matrix_set_color_all(0, 0, 0);
            break;
    }
    return true;
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (!process_smtd(keycode, record)) {
        return false;
    }
    switch (keycode) {
        case ST_MACRO_0:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_A) SS_TAP(X_U));
            }
            break;
        case ST_MACRO_1:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_U) SS_TAP(X_A));
            }
            break;
        case ST_MACRO_2:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_E) SS_TAP(X_O));
            }
            break;
        case ST_MACRO_3:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_O) SS_TAP(X_E));
            }
            break;
        case ST_MACRO_4:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_G) SS_TAP(X_L));
            }
            break;
        case ST_MACRO_5:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_Q) SS_TAP(X_U));
            }
            break;
        case ST_MACRO_6:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_X) SS_TAP(X_P) SS_TAP(X_L));
            }
            break;
        case ST_MACRO_7:
            if (record->event.pressed) {
                SEND_STRING(SS_TAP(X_T) SS_TAP(X_I) SS_TAP(X_O) SS_TAP(X_N));
            }
            break;
        case ST_MACRO_8:
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
        SMTD_MT(CKC_A, KC_A, KC_LEFT_GUI)
        SMTD_MT(CKC_S, KC_S, KC_LEFT_ALT)
        SMTD_MT(CKC_D, KC_D, KC_LEFT_CTRL)
        SMTD_MT(CKC_F, KC_F, KC_LSFT)
    }
}

tap_dance_action_t tap_dance_actions[] = {
    [DANCE_0] = ACTION_TAP_DANCE_FN_ADVANCED(on_dance_0, dance_0_finished, dance_0_reset),
};
