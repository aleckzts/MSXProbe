;==============================================================================
; lang/en.asm - English UI strings
; To add a language: copy this file (same labels), translate, and select it
; with "make LANG=xx". Keep the length limits noted in each section.
; Use ASCII only: Japanese/Brazilian/European MSX fonts differ above 7Fh.
;==============================================================================

;--- Intro (SCREEN 2, 32 columns, uppercase looks best) ----------------------
s_subtitle:	db "MSX HARDWARE DIAGNOSTICS", 0
s_version:	db "VERSION ", VERSION_STR, " - 2026", 0
s_press:	db "PRESS ANY KEY", 0

;--- Main screen (SCREEN 0, 40 columns) ----------------------------------------
s_title:	db "MSX PROBE ", VERSION_STR, 0
s_title_r:	db "Hardware Diagnostics", 0
s_hdr_test:	db "TEST", 0
s_hdr_res:	db "RESULT", 0
s_footer:	db "Up/Down:select ENTER:run ESC:intro", 0	; max 39
s_not_tested:	db "-", 0
s_running:	db "Running...", 0
s_soon:		db "Not available yet", 0	; also blocks ENTER

; Test names (max 9 chars)
s_t_ram:	db "RAM", 0
s_t_vram:	db "VRAM", 0
s_t_sound:	db "SOUND", 0
s_t_screen:	db "SCREEN", 0
s_t_slots:	db "SLOTS", 0
s_t_keyb:	db "KEYBOARD", 0
s_t_joy:	db "JOYSTICK", 0
s_t_rtc:	db "RTC", 0		; real-time clock (MSX2 and later), not CPU speed
s_t_net:	db "NETWORK", 0

;--- System info lines (max 38 chars each once filled) -------------------------
s_vdp:		db "  VDP ", 0
s_vram:		db "  VRAM ", 0
s_kb:		db "KB", 0
s_60hz:		db "  60Hz", 0
s_50hz:		db "  50Hz", 0
s_cpu:		db "CPU ", 0
s_kbd:		db "  Kbd ", 0
s_chars:	db "  Chars ", 0

s_msxver:	dw .m1, .m2, .m2p, .mtr, .mxx
.m1:	db "MSX1", 0
.m2:	db "MSX2", 0
.m2p:	db "MSX2+", 0
.mtr:	db "MSX turbo R", 0
.mxx:	db "MSX?", 0

s_vdpname:	dw .tms, .v38, .v58, .vxx
.tms:	db "TMS99x8", 0
.v38:	db "V9938", 0
.v58:	db "V9958", 0
.vxx:	db "V99??", 0

s_cpuname:	dw .z80, .r8r, .r8d
.z80:	db "Z80", 0
.r8r:	db "R800 ROM", 0
.r8d:	db "R800 DRAM", 0

s_kbdname:	dw .jp, .int, .fr, .uk, .de, .ru, .es, .xx
.jp:	db "JP", 0
.int:	db "Intl", 0
.fr:	db "FR", 0
.uk:	db "UK", 0
.de:	db "DE", 0
.ru:	db "RU", 0
.es:	db "ES", 0
.xx:	db "?", 0

s_charname:	dw .jp, .int, .kr, .xx
.jp:	db "JP", 0
.int:	db "Intl", 0
.kr:	db "KR", 0
.xx:	db "?", 0

;--- Test results (max 28 chars once filled) -----------------------------------
s_ok:		db "OK ", 0
s_fail:		db "FAIL ", 0
s_tested:	db "KB tested", 0
s_bits:		db "bits ", 0
s_blk:		db " blk ", 0
s_psg_ok:	db "PSG OK", 0
s_psg_fail:	db "PSG FAIL R", 0
s_fmpac:	db ", FM-PAC ", 0
s_msxmusic:	db ", MSX-MUSIC ", 0
s_nofm:		db ", no FM", 0
s_modes:	db " modes, ", 0
s_viewed:	db " viewed", 0

; Slot labels for the SLOTS summary (max 5 chars)
s_sl_bios:	db "BIOS", 0
s_sl_exp:	db "EXP", 0
s_sl_probe:	db "PROBE", 0
s_sl_cart:	db "CART", 0
s_sl_none:	db "-", 0

;--- SCREEN test: mode list (SCREEN 0, 40 columns; max 34 chars each) ------
s_scr_title:	db "SCREEN MODES", 0
s_scr_footer:	db "Up/Down:select ENTER:show ESC:back", 0	; max 39
s_sm0_40:	db "SCREEN 0     40x24 text", 0
s_sm0_80:	db "SCREEN 0     80x24 text", 0
s_sm1:		db "SCREEN 1     32x24 text", 0
s_sm2:		db "SCREEN 2     256x192  16 colors", 0
s_sm3:		db "SCREEN 3     64x48    16 colors", 0
s_sm4:		db "SCREEN 4     256x192  16 of 512", 0
s_sm5:		db "SCREEN 5     256x212  16 of 512", 0
s_sm6:		db "SCREEN 6     512x212  4 of 512", 0
s_sm7:		db "SCREEN 7     512x212  16 of 512", 0
s_sm8:		db "SCREEN 8     256x212  256 colors", 0
s_sm10:		db "SCREEN 10/11 256x212  12499 YJK", 0
s_sm12:		db "SCREEN 12    256x212  19268 YJK", 0
