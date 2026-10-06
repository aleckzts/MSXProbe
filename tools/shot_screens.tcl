# Automatic test of the SCREEN sub-menu: opens it and shows every mode,
# one screenshot per mode. Env: SHOT_OUT (output file prefix)
set out $::env(SHOT_OUT)
proc shot {name} { screenshot ${::out}_${name}.png }
proc press_down {} { keymatrixdown 8 0x40; after time 0.1 {keymatrixup 8 0x40} }
after time 9    "type { }"
# main menu: cursor on VRAM -> down, down = SCREEN
after time 10   "press_down"
after time 10.5 "press_down"
after time 11   "type \\r"
after time 12.5 "shot scr_menu"
set t 13
for {set i 0} {$i < 12} {incr i} {
    after time $t "type \\r"
    after time [expr {$t + 2.5}] "shot scr_mode[format %02d $i]"
    after time [expr {$t + 3}] "type { }"
    set t [expr {$t + 4.5}]
}
after time $t "type \\033"
after time [expr {$t + 1.5}] "shot scr_result"
after time [expr {$t + 2}] "exit"
