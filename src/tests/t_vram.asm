;==============================================================================
; t_vram.asm - VRAM test (destructive: the menu redraws the screen afterwards)
;
; Two passes (seed 00h and FFh), each one writes every 16KB block first and
; then reads them all back. Data = low addr XOR high addr XOR seed XOR
; (block*9): every bit sees 0 and 1, and a block that mirrors another one
; (missing VRAM chips, bad address line) fails because its data differ.
; The display is off (no access-timing limits on the TMS9918) and the border
; color changes per block to show progress.
; MSX2: block = VRAM address bits A14-A16 in R#14.
;==============================================================================

test_vram:
	call DISSCR
	di
	ld hl,v_verr
	ld b,8
.clr:	ld (hl),0
	inc hl
	djnz .clr

	ld a,00h
	call .pass
	ld a,0FFh
	call .pass

	ld a,(v_msxver)
	or a
	jr z,.m1
	ld bc,(0 << 8) + 14	; R#14 = 0 (BIOS expects it)
	call vdp_reg		; (the palette is reloaded by txt_init)
.m1:	ei

	;--- result ---------------------------------------------------------------
	ld hl,v_verr		; C = OR of the error bits of every block
	ld a,(v_vblk)
	ld b,a
	ld c,0
.or:	ld a,(hl)
	or c
	ld c,a
	inc hl
	djnz .or
	ld a,c
	or a
	jr nz,.fail

	ld hl,s_ok
	call out_str
	call vram_kb
	call out_dec
	ld hl,s_tested
	call out_str
	ld a,ST_OK
	ret

.fail:	; "FAIL bits 90h blk 2 5"
	push bc
	ld hl,s_fail
	call out_str
	ld hl,s_bits
	call out_str
	pop bc
	ld a,c
	call out_hex
	ld hl,s_blk
	call out_str
	ld hl,v_verr
	ld c,0
.blk:	ld a,(hl)
	or a
	jr z,.nb
	ld a,c
	add a,'0'
	call out_chr
	ld a,' '
	call out_chr
.nb:	inc hl
	inc c
	ld a,(v_vblk)
	cp c
	jr nz,.blk
	ld a,ST_FAIL
	ret

;--- one pass: A = seed ------------------------------------------------------------
.pass:
	ld (v_seed),a
	ld b,0			; write every block
.wb:	push bc
	call .border
	ld c,40h
	call .setaddr
	call .key
	ld hl,0
	ld c,VDP_DATA
.fill:	ld a,l
	xor h
	xor e
	out (c),a
	inc hl
	ld a,h
	cp 40h
	jr nz,.fill
	pop bc
	inc b
	ld a,(v_vblk)
	cp b
	jr nz,.wb

	ld b,0			; read every block back
.rb:	push bc
	call .border
	ld c,00h
	call .setaddr
	call .key
	ld hl,0
	ld d,0			; D = OR of (read XOR expected)
	ld c,VDP_DATA
.chk:	in a,(c)
	xor l
	xor h
	xor e
	or d
	ld d,a
	inc hl
	ld a,h
	cp 40h
	jr nz,.chk
	pop bc
	ld hl,v_verr
	ld a,b
	call add_hl_a
	ld a,(hl)
	or d
	ld (hl),a
	inc b
	ld a,(v_vblk)
	cp b
	jr nz,.rb
	ret

; E = seed XOR (block B * 9)
.key:	ld a,b
	add a,a
	add a,a
	add a,a
	add a,b
	ld e,a
	ld a,(v_seed)
	xor e
	ld e,a
	ret

; border color = progress (R#7). B = block
.border:
	push bc
	ld a,b
	add a,2
	and 0Fh
	ld b,a
	ld c,7
	call vdp_reg
	pop bc
	ret

; VRAM address = start of block B; C = 40h write / 00h read
.setaddr:
	ld a,(v_msxver)
	or a
	jr z,.s1		; MSX1: never touch R#14 (it would be R#6 on a TMS)
	ld a,b
	out (VDP_CTRL),a
	ld a,80h + 14
	out (VDP_CTRL),a
.s1:	xor a
	out (VDP_CTRL),a
	ld a,c
	out (VDP_CTRL),a
	ret
