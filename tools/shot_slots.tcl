# Automatic test of the SLOTS map: opens it and takes a screenshot.
# Env: SHOT_OUT (output file prefix)
set out $::env(SHOT_OUT)
proc shot {name} { screenshot ${::out}_${name}.png }
proc press_up {} { keymatrixdown 8 0x20; after time 0.1 {keymatrixup 8 0x20} }
after time 9    "type { }"
after time 10   "shot slots_menu"
# cursor starts on VRAM: up, up = SLOTS
after time 10.5 "press_up"
after time 11   "press_up"
after time 11.5 "type \\r"
after time 13   "shot slots_map"
after time 13.5 "type { }"
after time 15   "shot slots_back"
after time 15.5 "exit"
