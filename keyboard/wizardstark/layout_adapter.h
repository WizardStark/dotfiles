#pragma once

// Keep the Voyager's four rows in the outer six columns of each half.
// Use the two outer white thumb keys on each side, in left-to-right order.
// Every extra key (inner columns, fifth row, red keys, inner thumbs) is inert.
#ifdef KEYBOARD_zsa_moonlander
#define LAYOUT_voyager( \
    L00, L01, L02, L03, L04, L05, R00, R01, R02, R03, R04, R05, \
    L10, L11, L12, L13, L14, L15, R10, R11, R12, R13, R14, R15, \
    L20, L21, L22, L23, L24, L25, R20, R21, R22, R23, R24, R25, \
    L30, L31, L32, L33, L34, L35, R30, R31, R32, R33, R34, R35, \
    LT0, LT1, RT0, RT1 \
) LAYOUT_moonlander( \
    L00, L01, L02, L03, L04, L05, KC_NO, KC_NO, R00, R01, R02, R03, R04, R05, \
    L10, L11, L12, L13, L14, L15, KC_NO, KC_NO, R10, R11, R12, R13, R14, R15, \
    L20, L21, L22, L23, L24, L25, KC_NO, KC_NO, R20, R21, R22, R23, R24, R25, \
    L30, L31, L32, L33, L34, L35,               R30, R31, R32, R33, R34, R35, \
    KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, KC_NO, \
    LT0, LT1, KC_NO, KC_NO, RT0, RT1 \
)
#endif
