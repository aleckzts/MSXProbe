;==============================================================================
; intro.asm - Konami-style intro
;
; The logo (160x24 bitmap) rises from the bottom of the screen
; to the middle in SCREEN 2, slowing down at the end. When it stops: white
; flash + PSG jingle, then the texts appear.
;
; Technique: in SCREEN 2 the BIOS leaves the name table sequential, so the
; pattern of cell (row r, column c) lives at VRAM r*256 + c*8 - the screen
; behaves like a bitmap. Each frame we redraw only the 4 character rows the
; logo covers (patterns + colors), ~1.2KB of VRAM.
;==============================================================================

LOGO_C0		equ (32 - LOGO_COLS) / 2	; first column (centered)
LOGO_Y_START	equ 192				; start just below the screen
LOGO_Y_STOP	equ 64				; stop in the middle (lines 64..87)

intro:
	call psg_silence

	; SCREEN 2, black background and border
	ld a,15
	ld (FORCLR),a
	ld a,1
	ld (BAKCLR),a
	ld (BDRCLR),a
	call CHGCLR
	call INIGRP
	call set_palette

	ld hl,grad_normal
	ld (v_grad),hl
	ld a,LOGO_Y_START
	ld (v_y),a

	;--- logo rising ------------------------------------------------------
.rise:
	halt				; sync with VBLANK
	call logo_draw
	ld a,(v_y)
	sub LOGO_Y_STOP		; A = distance left
	jr z,.stopped
	ld b,2			; far: 2 px per frame
	cp 40
	jr nc,.step
	ld b,1			; near: 1 px per frame
	cp 12
	jr nc,.step
	ld a,(JIFFY)		; very near: 1 px every 2 frames
	rrca
	jr c,.rise
.step:
	ld a,(v_y)
	sub b
	ld (v_y),a
	jr .rise

	;--- stopped: flash + jingle + texts ------------------------------------
.stopped:
	ld hl,grad_flash
	ld (v_grad),hl
	call logo_draw
	call snd_start
	xor a
	ld (v_fc),a

.jingle:
	halt
	call snd_frame
	push af			; Z = jingle finished
	ld a,(v_fc)
	inc a
	ld (v_fc),a

	cp 5			; frame 5: back to normal colors
	jr nz,.t1
	ld hl,grad_normal
	ld (v_grad),hl
	call logo_draw
	jr .next
.t1:	cp 12			; frame 12: subtitle
	jr nz,.t2
	ld hl,s_subtitle
	ld de,(13 << 8) + 4
	ld b,70h		; cyan
	call gprint
	jr .next
.t2:	cp 20			; frame 20: version
	jr nz,.next
	ld hl,s_version
	ld de,(15 << 8) + 7
	ld b,0E0h		; gray
	call gprint
.next:
	pop af
	jr nz,.jingle
	ld a,(v_fc)
	cp 22			; make sure all texts are out
	jr c,.jingle
	ld a,0FFh
	ld (v_blink),a		; force the "press any key" redraw
	ret

;------------------------------------------------------------------------------
; wait_key_blink - blink "PRESS ANY KEY" until a key is pressed
;------------------------------------------------------------------------------
wait_key_blink:
	call wait_release
.loop:
	halt
	ld a,(JIFFY)
	and 20h			; toggles every 32 frames
	ld hl,v_blink
	cp (hl)
	jr z,.key
	ld (hl),a
	ld b,0F0h		; white
	or a
	jr z,.show
	ld b,00h		; transparent = hidden
.show:	ld hl,s_press
	ld de,(20 << 8) + 9
	call gprint
.key:
	call CHSNS
	jr z,.loop
	jp CHGET

;------------------------------------------------------------------------------
; logo_draw - draw the logo at vertical position (v_y), in pixels.
; Rewrites the 4 character rows starting at r0 = v_y/8 (clipped at row 24).
; Reads data at offset off = r*8 - y + PAD, always inside the column thanks
; to the 8 zero bytes above and below it.
; OUTI + JP NZ = 29 T-states per byte: safe for the TMS9918 with display on.
;------------------------------------------------------------------------------
logo_draw:
	di
	ld a,(v_y)
	ld c,a			; C = y
	rrca
	rrca
	rrca
	and 1Fh
	ld (v_r),a		; r0
	ld b,4
.row:
	push bc
	ld a,(v_r)
	cp 24
	jr nc,.skip		; below the screen
	add a,a
	add a,a
	add a,a			; r*8
	sub c
	add a,LOGO_PAD
	ld (v_off),a

	; --- patterns: VRAM 0000h + r*256 + c0*8
	ld a,(v_r)
	ld h,a
	ld l,LOGO_C0 * 8
	call vram_wr
	ld hl,logo_data
	ld a,(v_off)
	ld e,a
	ld d,0
	add hl,de
	ld de,LOGO_STRIDE
	ld c,VDP_DATA
	ld a,LOGO_COLS
.pcol:	push hl
	ld b,8
.pout:	outi
	jp nz,.pout
	pop hl
	add hl,de
	dec a
	jr nz,.pcol

	; --- colors: VRAM 2000h + r*256 + c0*8 (same gradient in every column)
	ld a,(v_r)
	add a,20h
	ld h,a
	ld l,LOGO_C0 * 8
	call vram_wr
	ld hl,(v_grad)
	ld a,(v_off)
	ld e,a
	ld d,0
	add hl,de
	ld a,LOGO_COLS
.ccol:	push hl
	ld b,8
.cout:	outi
	jp nz,.cout
	pop hl
	dec a
	jr nz,.ccol
.skip:
	ld hl,v_r
	inc (hl)
	pop bc
	djnz .row
	ei
	ret

;------------------------------------------------------------------------------
; Color gradients (1 byte per pixel line: foreground<<4 | transparent bg)
; TMS palette: 6=dark red 8=red 9=light red 10=dark yellow
;              11=light yellow 15=white
;------------------------------------------------------------------------------
grad_normal:
	ds LOGO_PAD, 0
	db 0F0h,0F0h,0F0h,0B0h,0B0h,0B0h,0B0h,0B0h
	db 0B0h,0A0h,0A0h,0A0h,0A0h,0A0h,090h,090h
	db 090h,090h,080h,080h,080h,060h,060h,060h
	ds LOGO_PAD, 0
grad_flash:
	ds LOGO_PAD, 0
	ds LOGO_H, 0F0h
	ds LOGO_PAD, 0
