#include QMK_KEYBOARD_H
#include "keymap.h"
#include "sm_td/sm_td/sm_td.h"

int threshold = 2;

typedef struct {
  uint16_t keycode;
  uint8_t layer;
  bool active;
} smtd_key_layer_state_t;

static smtd_key_layer_state_t smtd_key_layers[] = {
    {KC_M, BASE, false},    {KC_S, BASE, false},    {KC_N, BASE, false},
    {KC_T, BASE, false},    {KC_A, BASE, false},    {KC_E, BASE, false},
    {KC_H, BASE, false},    {KC_R, BASE, false},    {KC_SLSH, BASE, false},
    {KC_SPC, BASE, false},  {KC_G, BASE, false},    {KC_DOT, BASE, false},
    {KC_EXLM, SYM, false},  {KC_PLUS, SYM, false},  {KC_EQL, SYM, false},
    {KC_COLN, SYM, false},  {KC_LPRN, SYM, false},  {KC_QUES, SYM, false},
};

static smtd_key_layer_state_t *find_smtd_key_layer(uint16_t keycode) {
  for (uint8_t i = 0; i < sizeof(smtd_key_layers) / sizeof(smtd_key_layers[0]); ++i) {
    if (smtd_key_layers[i].keycode == keycode) {
      return &smtd_key_layers[i];
    }
  }
  return NULL;
}

static uint8_t smtd_action_layer(uint16_t keycode, smtd_action action) {
  smtd_key_layer_state_t *entry = find_smtd_key_layer(keycode);
  uint8_t current_layer = get_highest_layer(layer_state);

  if (!entry) {
    return current_layer;
  }

  if (action == SMTD_ACTION_TOUCH) {
    entry->layer = current_layer;
    entry->active = true;
    return entry->layer;
  }

  if (entry->active) {
    return entry->layer;
  }

  return current_layer;
}

static void smtd_finish_action(uint16_t keycode, smtd_action action) {
  if (action != SMTD_ACTION_TAP && action != SMTD_ACTION_RELEASE) {
    return;
  }

  smtd_key_layer_state_t *entry = find_smtd_key_layer(keycode);
  if (entry) {
    entry->active = false;
  }
}

smtd_resolution on_smtd_action(uint16_t keycode, smtd_action action,
                               uint8_t tap_count) {
  uint8_t layer = smtd_action_layer(keycode, action);

  switch (layer) {
  case BASE:
    switch (keycode) {
      SMTD_MT(KC_M, KC_LGUI, threshold, true)
      SMTD_MT(KC_S, KC_LALT, threshold, true)
      SMTD_MT(KC_N, KC_LCTL, threshold, true)
      SMTD_MT(KC_T, KC_LSFT, threshold, true)
      SMTD_MT(KC_A, KC_RSFT, threshold, true)
      SMTD_MT(KC_E, KC_LCTL, threshold, true)
      SMTD_MT(KC_H, KC_LALT, threshold, true)
      SMTD_LT(KC_R, NAV, threshold, true)
      SMTD_MT(KC_SLSH, KC_LGUI, threshold)
      SMTD_LT(KC_SPC, SYM, threshold, true)

    case KC_G:
      switch (action) {
      case SMTD_ACTION_TOUCH:
        return SMTD_RESOLUTION_UNCERTAIN;

      case SMTD_ACTION_TAP:
        SMTD_TAP_16(true, KC_G);
        smtd_finish_action(keycode, action);
        return SMTD_RESOLUTION_DETERMINED;

      case SMTD_ACTION_HOLD:
        if (tap_count < threshold) {
          register_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) |
                        MOD_BIT(KC_LGUI) | MOD_BIT(KC_LSFT));
        } else {
          SMTD_REGISTER_16(true, KC_G);
        }
        return SMTD_RESOLUTION_DETERMINED;

      case SMTD_ACTION_RELEASE:
        if (tap_count < threshold) {
          unregister_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) |
                          MOD_BIT(KC_LGUI) | MOD_BIT(KC_LSFT));
        } else {
          SMTD_UNREGISTER_16(true, KC_G);
        }
        smtd_finish_action(keycode, action);
        return SMTD_RESOLUTION_DETERMINED;
      }
      return SMTD_RESOLUTION_UNHANDLED;

    case KC_DOT:
      switch (action) {
      case SMTD_ACTION_TOUCH:
        return SMTD_RESOLUTION_UNCERTAIN;

      case SMTD_ACTION_TAP:
        tap_code16(KC_DOT);
        smtd_finish_action(keycode, action);
        return SMTD_RESOLUTION_DETERMINED;

      case SMTD_ACTION_HOLD:
        if (tap_count < threshold) {
          register_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) |
                        MOD_BIT(KC_LGUI) | MOD_BIT(KC_LSFT));
        } else {
          SMTD_REGISTER_16(true, KC_DOT);
        }
        return SMTD_RESOLUTION_DETERMINED;

      case SMTD_ACTION_RELEASE:
        if (tap_count < threshold) {
          unregister_mods(MOD_BIT(KC_LCTL) | MOD_BIT(KC_LALT) |
                          MOD_BIT(KC_LGUI) | MOD_BIT(KC_LSFT));
        } else {
          SMTD_UNREGISTER_16(true, KC_DOT);
        }
        smtd_finish_action(keycode, action);
        return SMTD_RESOLUTION_DETERMINED;
      }
      return SMTD_RESOLUTION_UNHANDLED;
    }
    break;

  case SYM:
    switch (keycode) {
      SMTD_MT(KC_EXLM, KC_LALT, threshold, true)
      SMTD_MT(KC_PLUS, KC_LCTL, threshold, true)
      SMTD_MTE(KC_EQL, KC_LSFT, threshold, true)
      SMTD_MTE(KC_COLN, KC_RSFT, threshold, true)
      SMTD_MT(KC_LPRN, KC_LCTL, threshold, true)
      SMTD_MT(KC_QUES, KC_LALT, threshold, true)
    }
    break;
  }

  smtd_finish_action(keycode, action);
  return SMTD_RESOLUTION_UNHANDLED;
}
