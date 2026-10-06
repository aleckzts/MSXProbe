;==============================================================================
; text.asm - SCREEN 0 output and the "out_*" string builder
;
; The string builder writes into a RAM buffer with a length limit, so tests
; and the system info can compose results without overflowing the line:
;     ld hl,buffer : ld b,28 : call out_begin
;     ld hl,s_ok : call out_str
;     ld hl,128 : call out_dec ...
;==============================================================================

;------------------------------------------------------------------------------
; txt_init - SCREEN 0, 40 columns, white on dark blue, no function keys
;------------------------------------------------------------------------------
txt_init:
	ld a,15
	ld (FORCLR),a
	ld a,4
	ld (BAKCLR),a
	ld (BDRCLR),a
	call CHGCLR
	ld a,40
	ld (LINL40),a
	call INITXT
	call set_palette
	ld a,(v_msxver)		; MSX2+: leave YJK mode (SCREEN 10-12 test)
	cp 2
	jr c,.no25
	di
	ld bc,(0 << 8) + 25
	call vdp_reg
	ei
.no25:	call ERAFNK
	xor a
	ld (CSRSW),a
	ret

;------------------------------------------------------------------------------
; locate - move the cursor to D = row, E = column (0-based)
;------------------------------------------------------------------------------
locate:
	push hl
	ld h,e
	inc h
	ld l,d
	inc l
	call POSIT
	pop hl
	ret

;------------------------------------------------------------------------------
; print - print zero-terminated string at HL. Returns HL after the 0.
;------------------------------------------------------------------------------
print:
	ld a,(hl)
	inc hl
	or a
	ret z
	call CHPUT
	jr print

; print_at - D = row, E = column, HL = string
print_at:
	call locate
	jr print

;------------------------------------------------------------------------------
; print_pad - print string HL in a field of B characters (cut or padded
; with spaces)
;------------------------------------------------------------------------------
print_pad:
	ld a,(hl)
	or a
	jr z,.pad
	call CHPUT
	inc hl
	djnz print_pad
	ret
.pad:	ld a,' '
.sp:	call CHPUT
	djnz .sp
	ret

; print_line - D = row: print B times character A from column 0
print_line:
	ld e,0
	call locate
.l:	call CHPUT
	djnz .l
	ret

;------------------------------------------------------------------------------
; get_key - wait for a NEW key press and return it in A.
; First waits until every key is released (keyboard matrix rows 0-8 all 1),
; then clears the buffer: a key still held from the previous screen (some
; BIOSes re-read the matrix when the screen mode changes) is not taken twice.
;------------------------------------------------------------------------------
get_key:
	call wait_release
.w:	halt
	call CHSNS
	jr z,.w
	jp CHGET

; wait_release - wait until no key is pressed, then clear the key buffer
wait_release:
	ei
.r:	ld c,0
	ld b,0FFh		; B = AND of all rows
.row:	ld a,c
	call SNSMAT
	and b
	ld b,a
	inc c
	ld a,c
	cp 9
	jr c,.row
	ld a,b
	inc a			; FFh -> 0: nothing pressed
	jr z,.done
	halt
	jr .r
.done:	jp KILBUF

;==============================================================================
; String builder
;==============================================================================

; out_begin - HL = buffer, B = maximum characters (buffer needs B+1 bytes)
out_begin:
	ld (v_rp),hl
	ld (hl),0
	ld a,l
	add a,b
	ld l,a
	jr nc,.nc
	inc h
.nc:	ld (v_rpend),hl
	ret

; out_chr - append character A (ignored when the buffer is full).
; Preserves all registers except F.
out_chr:
	push hl
	push de
	push af
	ld hl,(v_rp)
	ld de,(v_rpend)
	or a
	sbc hl,de
	jr nc,.full
	add hl,de
	pop af
	push af
	ld (hl),a
	inc hl
	ld (hl),0
	ld (v_rp),hl
.full:	pop af
	pop de
	pop hl
	ret

; out_str - append zero-terminated string HL
out_str:
	ld a,(hl)
	or a
	ret z
	call out_chr
	inc hl
	jr out_str

; out_table - append string number A of a "dw" table at HL
out_table:
	add a,a
	ld e,a
	ld d,0
	add hl,de
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jr out_str

; out_hex - append A as 2 hex digits + 'h'
out_hex:
	push af
	rrca
	rrca
	rrca
	rrca
	call .nib
	pop af
	call .nib
	ld a,'h'
	jr out_chr
.nib:	and 0Fh
	add a,'0'
	cp '9'+1
	jr c,out_chr
	add a,'A'-'9'-1
	jr out_chr

; out_dec - append HL as decimal (no leading zeros)
out_dec:
	ld e,0			; E = "a digit was already printed"
	ld bc,-10000
	call .dig
	ld bc,-1000
	call .dig
	ld bc,-100
	call .dig
	ld bc,-10
	call .dig
	ld a,l
	add a,'0'
	jr out_chr
.dig:	ld a,'0'-1
.sub:	inc a
	add hl,bc
	jr c,.sub
	sbc hl,bc		; carry is clear here: undo the last add
	cp '0'
	jr nz,.put
	inc e
	dec e
	ret z			; skip leading zero
.put:	ld e,1
	jr out_chr

; out_slot - append slot ID A as "1" or "3-2"
out_slot:
	push af
	and 3
	add a,'0'
	call out_chr
	pop af
	bit 7,a
	ret z
	push af
	ld a,'-'
	call out_chr
	pop af
	rrca
	rrca
	and 3
	add a,'0'
	jp out_chr
