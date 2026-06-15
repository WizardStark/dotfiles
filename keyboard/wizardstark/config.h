/*
  Set any config.h overrides for your specific keymap here.
  See config.h options at https://docs.qmk.fm/#/config_options?id=the-configh-file
*/

#define ORYX_CONFIGURATOR
#undef TAPPING_TERM
#define TAPPING_TERM 175
#define VOYAGER_USER_LEDS

#define USB_SUSPEND_WAKEUP_DELAY 0
#define FIRMWARE_VERSION u8"7RX4b/DXlK7"
#define RAW_USAGE_PAGE 0xFF60
#define RAW_USAGE_ID 0x61
#define LAYER_STATE_8BIT
#define COMBO_COUNT 14
#define COMBO_MUST_TAP_PER_COMBO
#define CAPS_WORD_INVERT_ON_SHIFT

#define RGB_MATRIX_STARTUP_SPD 60
