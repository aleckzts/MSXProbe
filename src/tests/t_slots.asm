;==============================================================================
; t_slots.asm - SLOTS summary (read-only, one line):
;   "0:BIOS 1:PROBE 2:CART 3:EXP"
; Per primary slot: EXP = expanded, BIOS = main ROM, PROBE = where this ROM
; runs, CART = "AB" header in page 1 or 2, "-" = nothing found.
; The full slot/subslot x page map comes with the RAM test (docs/ROADMAP.md).
;==============================================================================

test_slots:
	xor a
	ld (v_idx),a
.slot:	ld a,(v_idx)
	add a,'0'
	call out_chr
	ld a,':'
	call out_chr
	call .label
	call out_str
	ld a,' '
	call out_chr
	ld a,(v_idx)
	inc a
	ld (v_idx),a
	cp 4
	jr c,.slot
	ei
	ld a,ST_INFO
	ret

; .label - HL = label of primary slot (v_idx)
.label:
	ld a,(v_idx)
	ld hl,EXPTBL
	call add_hl_a
	bit 7,(hl)
	ld hl,s_sl_exp
	ret nz
	ld a,(v_idx)
	ld hl,v_slot_bios
	cp (hl)
	ld hl,s_sl_bios
	ret z
	ld hl,v_slot_me
	cp (hl)
	ld hl,s_sl_probe
	ret z
	ld hl,4000h		; "AB" in page 1 or page 2?
	call .isab
	ld hl,s_sl_cart
	ret z
	ld hl,8000h
	call .isab
	ld hl,s_sl_cart
	ret z
	ld hl,s_sl_none
	ret

; Z if slot (v_idx) has "AB" at HL
.isab:	ld a,(v_idx)
	ld de,s_ab
	jp slot_cmp2

; slot_cmp2 - compare 2 bytes at HL in slot A with DE. Z = equal
slot_cmp2:
	ld b,2
	jp slot_cmp4.c

s_ab:	db "AB"
