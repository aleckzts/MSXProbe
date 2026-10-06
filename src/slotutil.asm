;==============================================================================
; slotutil.asm - Slot helpers
; Slot ID format (same as the BIOS): E000SSPP
;   E = primary slot is expanded, SS = subslot, PP = primary slot
;==============================================================================

;------------------------------------------------------------------------------
; get_slot - slot ID currently selected in page B (0-3) -> A
; Page 3 reads the real subslot register (FFFFh); pages 0-2 use the BIOS
; copy in SLTTBL. Changes: AF, BC, E, HL
;------------------------------------------------------------------------------
get_slot:
	ld c,b
	in a,(PPI_A)
	call .shr
	and 3
	ld e,a			; E = primary slot
	ld hl,EXPTBL
	add a,l
	ld l,a
	bit 7,(hl)
	ld a,e
	ret z			; not expanded
	ld a,c
	cp 3
	jr nz,.tbl
	ld a,(0FFFFh)		; page 3 is selected: read the real register
	cpl
	jr .got
.tbl:	ld hl,SLTTBL
	ld a,e
	add a,l
	ld l,a
	ld a,(hl)
.got:	call .shr
	and 3
	rlca
	rlca
	or e
	or 80h
	ret
; A >>= 2*C (C = page)
.shr:	ld b,c
	inc b
	jr .s2
.s1:	rrca
	rrca
.s2:	djnz .s1
	ret

;------------------------------------------------------------------------------
; idx2id - slot index A (primary*4 + subslot, 0-15) -> slot ID A
; Returns carry set when that slot does not exist (subslot 1-3 of a
; non-expanded primary slot). Changes: AF, B, E, HL
;------------------------------------------------------------------------------
idx2id:
	ld b,a
	rrca
	rrca
	and 3
	ld e,a			; E = primary
	ld a,b
	and 3
	ld b,a			; B = subslot
	ld hl,EXPTBL
	ld a,e
	add a,l
	ld l,a
	bit 7,(hl)
	jr nz,.exp
	ld a,b
	or a
	scf
	ret nz			; subslot != 0 on a plain slot: invalid
	ld a,e
	or a			; carry clear
	ret
.exp:	ld a,b
	rlca
	rlca
	or e
	or 80h			; carry clear
	ret

;------------------------------------------------------------------------------
; slot_cmp4 - compare 4 bytes at HL in slot A with DE. Z = equal.
; slot_cmp2 - same, 2 bytes.
; RDSLT works for pages 0-2 and leaves interrupts disabled.
slot_cmp2:
	ld b,2
	jr slot_cmp4.c
slot_cmp4:
	ld b,4
.c:	push bc
	push de
	push af
	call RDSLT
	ld c,a
	pop af
	pop de
	ex de,hl
	ld b,a
	ld a,c
	cp (hl)
	ld a,b
	ex de,hl
	pop bc
	ret nz
	inc hl
	inc de
	djnz .c
	ret			; Z

