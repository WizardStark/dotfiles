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
#define CAPS_WORD_INVERT_ON_SHIFT

#define RGB_MATRIX_STARTUP_SPD 60

#define MAX_DEFERRED_EXECUTORS 10

#define BETTER_VISUAL_MODE
#define VIM_I_TEXT_OBJECTS
#define VIM_PASTE_BEFORE
#define VIM_DOT_RET
#define VIM_W_BEGINNING_OF_WORD
#define VIM_FOR_ALL

#define SMTD_GLOBAL_RELEASE_TERM 35
