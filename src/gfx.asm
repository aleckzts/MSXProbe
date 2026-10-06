;==============================================================================
; gfx.asm - SCREEN 2 video routines
;==============================================================================

;------------------------------------------------------------------------------
; vram_wr - set the VDP up to write from HL (0000h-3FFFh)
; Call with interrupts DISABLED: the interrupt handler reads the VDP status,
; which resets the port 99h latch and would corrupt the pair of writes.
; Changes: A
;------------------------------------------------------------------------------
vram_wr:
	ld a,l
	out (VDP_CTRL),a
	ld a,h
	and 3Fh
	or 40h			; bit 6 = write
	out (VDP_CTRL),a
	ret

;------------------------------------------------------------------------------
; vdp_reg - write VDP register C with value B (call with interrupts disabled)
;------------------------------------------------------------------------------
vdp_reg:
	ld a,b
	out (VDP_CTRL),a
	ld a,c
	or 80h
	out (VDP_CTRL),a
	ret

;------------------------------------------------------------------------------
; gprint - print text in SCREEN 2 using the BIOS font
; In: HL = zero-terminated string, D = row (0-23), E = column (0-31)
;     B  = color (foreground<<4 | background)
; Changes: AF, DE, HL
;------------------------------------------------------------------------------
gprint:
	ld a,(hl)
	or a
	ret z
	push hl
	push de
	push bc
	call gchar
	pop bc
	pop de
	pop hl
	inc hl
	inc e
	jr gprint

; gchar - A = character, D = row, E = column, B = color
gchar:
	di
	push bc
	; font: (CGTABL) + A*8
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,(CGTABL)
	add hl,bc
	ex de,hl		; DE = font, H = row, L = column
	ld a,l
	add a,a
	add a,a
	add a,a
	ld l,a			; HL = row*256 + column*8
	push hl
	call vram_wr
	ld b,8
.pat:	ld a,(de)		; 8+12+7+14 T > 29 T: safe on the TMS9918
	out (VDP_DATA),a
	inc de
	djnz .pat
	pop hl
	ld a,h
	add a,20h		; color table = patterns + 2000h
	ld h,a
	call vram_wr
	pop bc
	ld a,b
	ld b,8
.col:	out (VDP_DATA),a
	nop			; keep >= 29 T between accesses
	djnz .col
	ei
	ret

;------------------------------------------------------------------------------
; set_palette - (MSX2 and later) load the standard MSX palette into the VDP.
; The BIOS keeps a palette copy in VRAM, so after the VRAM test (or anything
; that trashes VRAM) the colors would be garbage. We write it directly
; (R#16 = 0, then 2 bytes per color to port 9Ah) and do not depend on the
; SUB-ROM. Does nothing on MSX1.
;------------------------------------------------------------------------------
VDP_PAL	equ 9Ah

set_palette:
	ld a,(v_msxver)
	or a
	ret z
	di
	ld bc,(0 << 8) + 16	; R#16 = 0: start at color 0
	call vdp_reg
	ld hl,msx_palette
	ld bc,(32 << 8) + VDP_PAL
	otir
	ei
	ret

; 0RRR0BBB, 00000GGG - standard MSX2 palette
msx_palette:
	db 00h,0, 00h,0, 11h,6, 33h,7, 17h,1, 27h,3, 51h,1, 27h,6
	db 71h,1, 73h,3, 61h,6, 64h,6, 11h,4, 65h,2, 55h,5, 77h,7
