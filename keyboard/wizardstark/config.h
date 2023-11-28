#define USB_POLLING_INTERVAL_MS 1
#define QMK_KEYS_PER_SCAN 12
#define TAPPING_TOGGLE 2
#define DEBOUNCE 10
#define DEBOUNCE_TYPE = sym_eager_pk

#ifdef RGB_MATRIX_ENABLE
    #define RGB_DISABLE_WHEN_USB_SUSPENDED
    #define RGB_MATRIX_KEYPRESSES            // Enables REACTIVE & SPLASH modes
    #define RGB_MATRIX_FRAMEBUFFER_EFFECTS   // Enables Heatmap, Rain

    // RGB step values
    #define RGBLIGHT_HUE_STEP 32             // The number of steps to cycle through the hue by (default 10)
    #define RGBLIGHT_SAT_STEP 17             // The number of steps to increment the saturation by (default 17)
    #define RGBLIGHT_VAL_STEP 17             // The number of steps to increment the brightness by (default 17)

    // Startup values, when none have been set
    // #define RGB_MATRIX_STARTUP_MODE RGB_MATRIX_SOLID_REACTIVE // Sets the default effect mode, if none has been set (was RGB_MATRIX_SOLID_COLOR)
    // #define RGB_MATRIX_STARTUP_HUE 24                         // Sets the default hue value, if none has been set
    // #define RGB_MATRIX_STARTUP_SAT 255                        // Sets the default saturation value, if none has been set
    // #define RGB_MATRIX_STARTUP_VAL 127                        // Sets the default brightness value, if none has been set
    // #define RGB_MATRIX_STARTUP_SPD 127                        // Sets the default animation speed, if none has been set

    // Uncomment any #undef line below to turn OFF any default enabled RGB background effect (enabled in keyboards/gmmk/pro/config.h).
    #undef ENABLE_RGB_MATRIX_ALPHAS_MODS                      // Solid color (seems redundant; seems same as RGB_MATRIX_SOLID_COLOR?)
    #undef ENABLE_RGB_MATRIX_GRADIENT_UP_DOWN               // Static, horizontal rainbow
    #undef ENABLE_RGB_MATRIX_GRADIENT_LEFT_RIGHT            // Static, vertical Rainbow
    #undef ENABLE_RGB_MATRIX_BREATHING                      // Breathing animation using selected HSV color
    #undef ENABLE_RGB_MATRIX_BAND_SAT                         // Single hue band fading saturation scrolling left to right (with white)
    #undef ENABLE_RGB_MATRIX_BAND_VAL                       // Single hue band fading brightness scrolling left to right (with black)
    #undef ENABLE_RGB_MATRIX_BAND_PINWHEEL_SAT                // Single hue 3 blade spinning pinwheel fades sat (with white)
    #undef ENABLE_RGB_MATRIX_BAND_PINWHEEL_VAL              // Single hue 3 blade spinning pinwheel fades brightness (with black)
    #undef ENABLE_RGB_MATRIX_BAND_SPIRAL_SAT                  // Single hue spinning spiral fades brightness (with white)
    #undef ENABLE_RGB_MATRIX_BAND_SPIRAL_VAL                // Single hue spinning spiral fades brightness (with black)
    #undef ENABLE_RGB_MATRIX_CYCLE_ALL                      // Full keyboard cycling through rainbow
    #undef ENABLE_RGB_MATRIX_CYCLE_LEFT_RIGHT               // Full gradient moving left to right
    #undef ENABLE_RGB_MATRIX_CYCLE_UP_DOWN                  // Full gradient scrolling top to bottom
    #undef ENABLE_RGB_MATRIX_RAINBOW_MOVING_CHEVRON           // Full gradient chevron scrolling left to right (too similar to cycle left right)
    #undef ENABLE_RGB_MATRIX_CYCLE_OUT_IN                   // Rainbow circles coming to center.
    #undef ENABLE_RGB_MATRIX_CYCLE_OUT_IN_DUAL                // Two Rainbow circles coming to 1/3 and 2/3 points. (seems mostly redundant with above)
    #undef ENABLE_RGB_MATRIX_CYCLE_PINWHEEL                   // Built-in cycling pinwheel (seems redundant with below)
    #undef ENABLE_RGB_MATRIX_CYCLE_SPIRAL                   // Full gradient spinning spiral around center of keyboard
    #undef ENABLE_RGB_MATRIX_RAINBOW_BEACON                   // Spinning rainbow (more distracting transitions)
    #undef ENABLE_RGB_MATRIX_RAINBOW_PINWHEELS              // Spinning rainbow (smoother)
    #undef ENABLE_RGB_MATRIX_DUAL_BEACON                      // Two rainbows spinning around keyboard (distracting, busy)
    #undef ENABLE_RGB_MATRIX_RAINDROPS                        // Sustained raindrops of blue, green, yellow (confusing to use with RGB layers)
    #undef ENABLE_RGB_MATRIX_JELLYBEAN_RAINDROPS            // Sustained raindrops of blue, purple, pink, green (confusing to use with RGB layers, but slightly better than above)
    #undef ENABLE_RGB_MATRIX_HUE_BREATHING                    // Hue shifts up a slight amount at the same time, then shifts back (very subtle)
    #undef ENABLE_RGB_MATRIX_HUE_PENDULUM                     // Hue shifts up a slight amount in a wave to the right, then back to the left (very subtle)
    #undef ENABLE_RGB_MATRIX_HUE_WAVE                         // Hue shifts up a slight amount and then back down in a wave to the right (very subtle)
    #undef ENABLE_RGB_MATRIX_PIXEL_RAIN                     // Non-sustained raindrops of pastel colors
    #undef ENABLE_RGB_MATRIX_PIXEL_FLOW                       // More active version of pixel rain with quick cycling (unusable, very distracting)
    #undef ENABLE_RGB_MATRIX_PIXEL_FRACTAL                    // Same as Pixel Flow but with current HSV only (somewhat distracting)
        //Only enabled if RGB_MATRIX_FRAMEBUFFER_EFFECTS is defined
    #undef ENABLE_RGB_MATRIX_TYPING_HEATMAP                 // Fading heatmap that follows keystrokes (has buggy side LEDs that glow red)
    #undef ENABLE_RGB_MATRIX_DIGITAL_RAIN                   // The Matrix (has buggy side LEDs that glow red)
        //Only enabled if RGB_MATRIX_KEYPRESSES or RGB_MATRIX_KEYRELEASES is defined
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE_SIMPLE          // Key hits shown in current hue - all other keys black
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE                 // Keyboard lights up in chosen hue, key hits shown in complementary hue (try this as default?)
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE_WIDE              // Hue & value pulse around a single key hit then fades value out (Single key)
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE_MULTIWIDE       // same as above but more intense (Multi-key)
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE_CROSS             // Column and Row single current color fade (Single key)
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE_MULTICROSS      // Column and Row single color fade. (Multi-key)
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE_NEXUS             // Hue & value pulse away on the same column and row of key hit then fades (Single key)
    #undef ENABLE_RGB_MATRIX_SOLID_REACTIVE_MULTINEXUS      // Hue & value pulse away on the same column and row of multi-key hit then fades
    #undef ENABLE_RGB_MATRIX_SPLASH                         // Full rainbow pulses from key hit. All else black.
    #undef ENABLE_RGB_MATRIX_MULTISPLASH                      // Full rainbow pulses from multi-keys. All else black. (distracting on multiple keystroke hits)
    #undef ENABLE_RGB_MATRIX_SOLID_SPLASH                     // Single color pulses from key hit. All else black. (distracting on multiple key hits)
    #undef ENABLE_RGB_MATRIX_SOLID_MULTISPLASH              // Single color pulses from muli-keys. All else black.
#endif //RGB_MATRIX_ENABLE
