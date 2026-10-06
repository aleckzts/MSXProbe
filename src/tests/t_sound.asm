;==============================================================================
; t_sound.asm - SOUND test
;
; 1. PSG registers: write 55h/AAh to the tone/noise/envelope period registers
;    and read them back through port A2h (masked to the bits that exist).
; 2. Audible check: one note on each channel A, B, C in turn.
; 3. MSX-MUSIC: look for "OPLL" at 401Ch in every slot (read-only).
;    "PAC2OPLL" = FM-PAC cartridge, "APRLOPLL" = built-in.
; SCC, MSX-AUDIO, Moonsound and friends: see docs/ROADMAP.md
;==============================================================================

test_sound:
	call psg_regtest
	jr nc,.psg_ok
	push af
	ld hl,s_psg_fail
	call out_str
	pop af
	call out_hex
	ld a,ST_FAIL
	ld (v_tstat),a
	jr .fm
.psg_ok:
	ld hl,s_psg_ok
	call out_str
	ld a,ST_OK
	ld (v_tstat),a
	ld hl,chan_check
	call snd_play

.fm:	call find_msxmusic	; A = slot ID, carry = not found
	jr c,.nofm
	ld (v_tmp),a
	ld hl,s_msxmusic
	ld a,(v_fmpac)
	or a
	jr z,.fmn
	ld hl,s_fmpac
.fmn:	call out_str
	ld a,(v_tmp)
	call out_slot
	jr .done
.nofm:	ld hl,s_nofm
	call out_str
.done:	ld a,(v_tstat)
	ret

;------------------------------------------------------------------------------
; psg_regtest - carry clear = OK, carry set + A = failing register
;------------------------------------------------------------------------------
psg_regtest:
	ld hl,.regs
.next:	ld a,(hl)
	cp 0FFh
	jr z,.ok
	ld b,a			; B = register
	inc hl
	ld c,(hl)		; C = mask of existing bits
	inc hl
	ld e,55h
	call .try
	jr nz,.bad
	ld e,0AAh
	call .try
	jr nz,.bad
	ld a,b			; leave the register at 0
	ld e,0
	call psg_w
	jr .next
.ok:	xor a			; carry clear
	ret
.bad:	push bc			; leave the register at 0
	ld a,b
	ld e,0
	call psg_w
	pop bc
	ld a,b
	scf
	ret
; write E to register B (masked) and read it back. Z = match
.try:	di
	ld a,b
	out (PSG_ADDR),a
	ld a,e
	and c
	ld d,a
	out (PSG_WR),a
	in a,(PSG_RD)
	and c
	cp d
	ei
	ret
; register, mask (R7, R8-R10 and R13 left alone: mixer/volume/envelope shape)
.regs:	db 0,0FFh, 1,0Fh, 2,0FFh, 3,0Fh, 4,0FFh, 5,0Fh, 6,1Fh, 11,0FFh, 12,0FFh
	db 0FFh

;------------------------------------------------------------------------------
; find_msxmusic - scan all slots for the MSX-MUSIC ROM.
; Out: carry clear + A = slot ID if found, v_fmpac = 1 for an FM-PAC
;------------------------------------------------------------------------------
find_msxmusic:
	xor a
	ld (v_fmpac),a
	ld (v_idx),a
.slot:	ld a,(v_idx)
	call idx2id
	jr c,.skip
	ld (v_tmp),a
	ld hl,401Ch
	ld de,s_opll
	call slot_cmp4
	jr nz,.skip
	ld a,(v_tmp)		; found: FM-PAC says "PAC2" at 4018h
	ld hl,4018h
	ld de,s_pac2
	call slot_cmp4
	jr nz,.int
	ld a,1
	ld (v_fmpac),a
.int:	ei
	ld a,(v_tmp)
	or a			; carry clear
	ret
.skip:	ld a,(v_idx)
	inc a
	ld (v_idx),a
	cp 16
	jr c,.slot
	ei
	scf
	ret

s_opll:	db "OPLL"
s_pac2:	db "PAC2"
