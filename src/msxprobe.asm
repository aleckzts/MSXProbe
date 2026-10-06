;==============================================================================
;  MSX PROBE - MSX Hardware Diagnostics
;  16KB ROM at 4000h-7FFFh for MSX1 / MSX2 / MSX2+ / turbo R
;
;  Flow: intro (logo + jingle) -> main screen (boot info + test menu)
;
;  Assembler: sjasmplus (see Makefile)
;==============================================================================

	DEVICE NOSLOT64K

	DEFINE VERSION_STR "0.2"

	INCLUDE "inc/msx.inc"

;------------------------------------------------------------------------------
; Cartridge header
;------------------------------------------------------------------------------
	ORG 4000h
	BLOCK 4000h, 0FFh	; unused ROM = FFh, like an erased EPROM
	ORG 4000h
rom_start:
	db "AB"			; cartridge ID
	dw start		; INIT
	dw 0			; STATEMENT
	dw 0			; DEVICE
	dw 0			; TEXT
	ds 6, 0			; reserved
	db "MSXPROBE ", VERSION_STR, 0	; signature (find the ROM in dumps)

;------------------------------------------------------------------------------
; Entry point. Called by the BIOS cartridge scan (or by a loader such as
; SofaRun). Never returns: the user leaves with reset.
;------------------------------------------------------------------------------
start:
	di
	; Stack: use HIMEM if plausible (>= C400h), else F380h, so we do not
	; trample system areas when started from DOS.
	ld hl,(HIMEM)
	ld a,h
	cp 0C4h
	jr nc,.sp_ok
	ld hl,0F380h
.sp_ok:	ld sp,hl

	xor a
	ld (CLIKSW),a		; no key click
	call psg_init
	call sysinfo_detect	; what we know at boot (shown on the main screen)
	call menu_reset		; all tests "not tested"
	ei

main_loop:
	call intro
	call wait_key_blink
	call menu		; returns on ESC
	jr main_loop

;------------------------------------------------------------------------------
	INCLUDE "intro.asm"
	INCLUDE "menu.asm"
	INCLUDE "text.asm"
	INCLUDE "gfx.asm"
	INCLUDE "sound.asm"
	INCLUDE "sysinfo.asm"
	INCLUDE "slotutil.asm"
	INCLUDE "tests/t_vram.asm"
	INCLUDE "tests/t_sound.asm"
	INCLUDE "tests/t_screen.asm"
	INCLUDE "tests/t_slots.asm"
	INCLUDE "lang/en.asm"
	INCLUDE "logo.inc"

rom_code_end:
	ASSERT rom_code_end <= 8000h, "ROM is over 16KB!"
	DISPLAY "ROM bytes used: ", /D, rom_code_end - rom_start, " of 16384"

;------------------------------------------------------------------------------
; RAM variables (page 3). They emit no bytes into the ROM.
;------------------------------------------------------------------------------
	ORG 0C000h
	INCLUDE "ramvars.asm"
	ASSERT $ < 0C400h, "RAM variables are past C400h"

	SAVEBIN "build/msxprobe.rom", 4000h, 4000h
