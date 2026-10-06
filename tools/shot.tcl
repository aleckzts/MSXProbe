# Automatic test in openMSX: walks through the intro and the menu pressing
# keys at fixed EMULATED times, takes screenshots, records audio and exits.
# Env: SHOT_OUT (output file prefix)
# Notes: keep normal throttle (with throttle off the renderer skips frames
# and screenshots come out black). Keys typed while a test runs are
# discarded by the menu, so leave enough time for each test.
set out $::env(SHOT_OUT)
record start -audioonly ${out}.wav
proc shot {name} { screenshot ${::out}_${name}.png }
after time 4    "shot 1_intro"
after time 9    "type { }"
after time 10   "shot 2_menu"
# cursor starts on VRAM (SLOTS ran at boot, RAM is not available)
after time 10.5 "type \\r"
after time 22   "shot 3_vram"
after time 22.5 "type \\r"
after time 26   "shot 4_sound"
after time 26.5 "type \\r"
after time 28   "shot 5_screen_menu"
after time 28.5 "type \\033"
after time 30   "shot 6_final"
after time 30.5 "record stop; exit"
