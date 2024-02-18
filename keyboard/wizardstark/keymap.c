/* Copyright 2021 Glorious, LLC <salman@pcgamingrace.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include QMK_KEYBOARD_H

#include "rgb_matrix_map.h"
#define NELEMS(x) (sizeof(x) / sizeof((x)[0]))

// clang-format off
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {

    // Qwerty
    [0] = LAYOUT(
        KC_CAPS,   KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,  KC_F10,  KC_F11,  KC_F12, KC_PSCR,          KC_MPLY,
         KC_GRV,    KC_1,    KC_2,    KC_3,    KC_4,    KC_5,    KC_6,    KC_7,    KC_8,    KC_9,    KC_0, KC_MINS,  KC_EQL, KC_BSPC,           KC_DEL,
         KC_TAB,    KC_Q,    KC_W,    KC_E,    KC_R,    KC_T,    KC_Y,    KC_U,    KC_I,    KC_O,    KC_P, KC_LBRC, KC_RBRC, KC_BSLS,          KC_PGUP,
   LT(3,KC_ESC),    KC_A,    KC_S,    KC_D,    KC_F,    KC_G,    KC_H,    KC_J,    KC_K,    KC_L, KC_SCLN, KC_QUOT,           KC_ENT,          KC_PGDN,
        KC_LSFT,    KC_Z,    KC_X,    KC_C,    KC_V,    KC_B,    KC_N,    KC_M, KC_COMM,  KC_DOT, KC_SLSH,                   KC_RSFT,  KC_UP,   KC_END,
        KC_LCTL, KC_LGUI, KC_LALT,                             KC_SPC,                            KC_RALT,   MO(4), KC_RCTL, KC_LEFT,KC_DOWN,  KC_RGHT
    ),
    //Colemak
    [1] = LAYOUT(
    //   KC_ESC,   KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,  KC_F10,  KC_F11,  KC_F12, KC_PSCR,          KC_MUTE,
        KC_CAPS,   KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,  KC_F10,  KC_F11,  KC_F12, KC_PSCR,          KC_MPLY,
         KC_GRV,    KC_1,    KC_2,    KC_3,    KC_4,    KC_5,    KC_6,    KC_7,    KC_8,    KC_9,    KC_0, KC_MINS,  KC_EQL, KC_BSPC,           KC_DEL,
         KC_TAB,    KC_Q,    KC_W,    KC_F,    KC_P,    KC_B,    KC_J,    KC_L,    KC_U,    KC_Y, KC_SCLN, KC_LBRC, KC_RBRC, KC_BSLS,          KC_PGUP,
   LT(3,KC_ESC),    KC_A,    KC_R,    KC_S,    KC_T,    KC_G,    KC_M,    KC_N,    KC_E,    KC_I,    KC_O, KC_QUOT,           KC_ENT,          KC_PGDN,
        KC_LSFT,    KC_X,    KC_C,    KC_D,    KC_V,    KC_Z,    KC_K,    KC_H, KC_COMM,  KC_DOT, KC_SLSH,                   KC_RSFT,  KC_UP,   KC_END,
        KC_LCTL, KC_LGUI, KC_LALT,                             KC_SPC,                            KC_RALT,   MO(4), KC_RCTL, KC_LEFT,KC_DOWN,  KC_RGHT
    ),
    // Numpad Layer
    [2] = LAYOUT(
    //   KC_ESC,   KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,  KC_F10,  KC_F11,  KC_F12, KC_PSCR,          KC_MUTE,
          TG(2),   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,            KC_NO,
          KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO, KC_ASTR, KC_LPRN, KC_RPRN, KC_MINS, KC_PPLS, KC_BSPC,            KC_NO,
          KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,    KC_7,    KC_8,    KC_9,   KC_NO,   KC_NO, KC_PSLS,            KC_NO,
          KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,    KC_4,    KC_5,    KC_6,   KC_NO,            KC_NO,            KC_NO,
          KC_NO,            KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO,    KC_1,    KC_2,    KC_3,            KC_NO,   KC_NO,   KC_NO,
          KC_NO,   KC_NO,   KC_NO,                             KC_ENT,                               KC_0,   KC_NO,   KC_NO,   KC_NO,   KC_NO,   KC_NO
    ),
    // Navigation Layer
    [3] = LAYOUT(
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,          _______,
        _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,          _______,
        _______, _______, _______, _______, _______, _______, _______, _______,    KC_U, _______, _______, _______, _______, _______,          _______,
        _______, _______, _______, KC_LSFT, KC_LALT, _______, _______,    KC_H,    KC_J,    KC_K,    KC_L, _______,          _______,          _______,
        _______,          _______, _______,    KC_D, _______, _______, _______, KC_LEFT, KC_DOWN,   KC_UP, KC_RGHT,          _______, _______, _______,
        _______, _______, _______,                            KC_LCTL,                            _______, _______, _______, _______, _______, _______
    ),
    // Adjust layer
    [4] = LAYOUT(
    //   KC_ESC,   KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,   KC_F6,   KC_F7,   KC_F8,   KC_F9,  KC_F10,  KC_F11,  KC_F12, KC_PSCR,          KC_MUTE,
          TG(2), KC_MYCM, KC_WHOM, KC_CALC, KC_MSEL, KC_MPRV, KC_MNXT, KC_MPLY, KC_MSTP, KC_MUTE, KC_VOLD, KC_VOLU, _______, _______,          _______,
        _______, RGB_TOG, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______,            TO(0),
        _______, _______, RGB_VAI, _______, _______, _______, _______, _______, _______, _______, _______, _______, _______, QK_BOOT,            TO(1),
        _______, _______, RGB_VAD, _______, _______, _______, _______, _______, _______, _______, _______, _______,          _______,          _______,
        _______,          _______, RGB_HUI, _______, _______, _______, NK_TOGG, _______, _______, _______, _______,          _______, RGB_MOD, _______,
        _______, _______, _______,                            _______,                            _______, _______, _______, RGB_SPD, RGB_RMOD, RGB_SPI
    ),

};
// clang-format on

#if defined(ENCODER_MAP_ENABLE)
const uint16_t PROGMEM encoder_map[][NUM_ENCODERS][2] = {
    [0] = { ENCODER_CCW_CW(KC_VOLD, KC_VOLU) },
    [1] = { ENCODER_CCW_CW(KC_VOLD, KC_VOLU) },
    [2] = { ENCODER_CCW_CW(KC_TRNS, KC_TRNS) },
    [3] = { ENCODER_CCW_CW(KC_TRNS, KC_TRNS) },
    [4] = { ENCODER_CCW_CW(KC_MPRV, KC_MNXT) },
};
#endif

uint8_t l4_keys_to_change[] = {6,7,12,14,15,16,18,23,28,34,38,39,44,50,56,61,66,72,75,79,94,95,97};

uint8_t l2_keys_to_change[] = {3,33,46,47,48,49,52,53,54,58,59,60};

bool rgb_matrix_indicators_advanced_user(uint8_t led_min, uint8_t led_max) {

    switch(get_highest_layer(layer_state)){  // special handling per layer
        case 0:
            rgb_matrix_set_color_all(0,0,0);
            for(int i=0;i<NELEMS(LED_OUTER);i++){
                rgb_matrix_set_color(LED_OUTER[i], 135, 206, 235);
            }
            rgb_matrix_set_color(72, 255, 0, 255);
            break;
        case 1:
            rgb_matrix_set_color_all(0,0,0);
            for(int i=0;i<NELEMS(LED_OUTER);i++){
                rgb_matrix_set_color(LED_OUTER[i], 135, 206, 235);
            }
            rgb_matrix_set_color(75, 255, 0, 255);
            break;
        case 2:
            rgb_matrix_set_color_all(0,0,0);
            for(int i=0;i<NELEMS(l2_keys_to_change);i++){
                rgb_matrix_set_color(l2_keys_to_change[i], 255, 0, 255);
            }
            break;
        case 3:
            rgb_matrix_set_color_all(0,0,0);
            for(int i=0;i<NELEMS(LED_OUTER);i++){
                rgb_matrix_set_color(LED_OUTER[i], 135, 206, 235);
            }
            break;
        case 4:
            rgb_matrix_set_color_all(0,0,0);
            for(int i=0;i<NELEMS(l4_keys_to_change);i++){
                rgb_matrix_set_color(l4_keys_to_change[i], 255, 0, 255);
            }
            break;
        default:
            break;
        break;
    }
    return 1;
}
