;==============================================================================
; sysinfo.asm - What we can learn safely at boot (read-only detection)
;
; Fills v_msxver, v_vdp, v_vblk, v_cpu, v_slot_* and builds the three lines
; shown at the top of the main screen (sys_l1, sys_l2). The slot IDs are
; used by the SLOTS test.
;==============================================================================

SYS_LEN	equ 38			; max characters per info line

sysinfo_detect:
	;--- MSX version (main BIOS byte 002Dh) --------------------------------
	ld a,(MSXVER)
	cp 4
	jr c,.ver_ok
	ld a,4			; unknown
.ver_ok:
	ld (v_msxver),a

	;--- VDP and VRAM size ---------------------------------------------------
	or a
	jr nz,.msx2
	xor a			; MSX1: TMS99x8, 16KB
	ld (v_vdp),a
	inc a
	ld (v_vblk),a
	jr .cpu
.msx2:
	; Read status register S#1: bits 1-5 = VDP ID (0=V9938, 2=V9958).
	; Never on MSX1: the TMS ignores the high register bits and R#15
	; would become R#7 (border color).
	di
	ld a,1
	out (VDP_CTRL),a
	ld a,80h + 15
	out (VDP_CTRL),a
	in a,(VDP_CTRL)
	ld b,a
	xor a
	out (VDP_CTRL),a
	ld a,80h + 15
	out (VDP_CTRL),a	; back to S#0, as the BIOS expects
	ei
	ld a,b
	rrca
	and 1Fh
	ld c,1			; V9938
	jr z,.vdp
	ld c,2			; V9958
	cp 2
	jr z,.vdp
	ld c,3			; unknown
.vdp:	ld a,c
	ld (v_vdp),a
	ld a,(MODE)		; b1-2: 0=16K 1=64K 2=128K
	rrca
	and 3
	ld hl,.vblks
	add a,l
	ld l,a
	jr nc,.nc
	inc h
.nc:	ld a,(hl)
	ld (v_vblk),a

	;--- CPU (turbo R only) --------------------------------------------------
.cpu:
	xor a
	ld (v_cpu),a
	ld a,(v_msxver)
	cp 3
	jr nz,.slots
	call GETCPU		; 0=Z80 1=R800 ROM 2=R800 DRAM
	and 3
	cp 3
	jr c,.cpu_ok
	xor a
.cpu_ok:
	ld (v_cpu),a

	;--- Slots: BIOS, this ROM (page 1), RAM in page 3 -------------------------
.slots:
	ld a,(EXPTBL)
	ld (v_slot_bios),a
	ld b,1
	call get_slot
	ld (v_slot_me),a
	ld b,3
	call get_slot
	ld (v_slot_ram),a

	;--- Line 1: "MSX2+  VDP V9958  VRAM 128KB  60Hz" --------------------------
	ld hl,sys_l1
	ld b,SYS_LEN
	call out_begin
	ld a,(v_msxver)
	ld hl,s_msxver
	call out_table
	ld hl,s_vdp
	call out_str
	ld a,(v_vdp)
	ld hl,s_vdpname
	call out_table
	ld hl,s_vram
	call out_str
	call vram_kb
	call out_dec
	ld hl,s_kb
	call out_str
	ld hl,s_60hz
	ld a,(IDBYT0)
	rlca			; b7: 0=60Hz 1=50Hz
	jr nc,.hz
	ld hl,s_50hz
.hz:	call out_str

	;--- Line 2: "CPU Z80  Kbd JP  Chars JP" ---------------------------------
	ld hl,sys_l2
	ld b,SYS_LEN
	call out_begin
	ld hl,s_cpu
	call out_str
	ld a,(v_cpu)
	ld hl,s_cpuname
	call out_table
	ld hl,s_kbd
	call out_str
	ld a,(IDBYT1)
	and 0Fh
	cp 7
	jr c,.kb_ok
	ld a,7
.kb_ok:	ld hl,s_kbdname
	call out_table
	ld hl,s_chars
	call out_str
	ld a,(IDBYT0)
	and 0Fh
	cp 3
	jr c,.ch_ok
	ld a,3
.ch_ok:	ld hl,s_charname
	call out_table

	ret

.vblks:	db 1, 4, 8, 8		; VRAM size in 16KB blocks, by MODE b1-2

; vram_kb - VRAM size in KB -> HL
vram_kb:
	ld a,(v_vblk)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	ret
