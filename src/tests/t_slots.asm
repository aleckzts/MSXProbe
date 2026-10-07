;==============================================================================
; t_slots.asm - SLOTS
;
; Reference: The MSX Red Book (Avalon Software, 1985)
;   https://github.com/gseidler/The-MSX-Red-Book
;   ch.1 "PPI Port A" fig.1 (Primary Slot Register) and "Expanders" fig.2
;   (Secondary Slot Register); ch.4 RDSLT, 027EH (slot masks), 02A3H
;   (secondary slot switching); ch.5 fig.44 (SLTATR: PS x SS x page grid).
;
; Menu line (also computed at boot): "0:BIOS 1:PROBE 2:RAM 3:EXP"
;   per primary slot: EXP = expanded, else the most relevant thing found in
;   the map below (PROBE > BIOS > DISK > MUSIC > ROM > RAM > SUB > DATA).
;
; ENTER on SLOTS shows the map laid out like the Red Book fig.44: one row
; per primary slot (PS0-PS3), one column group per secondary slot (SS0-SS3),
; four pages (0000h/4000h/8000h/C000h) in each group, a 2-letter code per
; cell (BI BA SU DK MU RO RA PR DA MI ..). Below it, the slot registers bit
; by bit like fig.1/fig.2: port A8h, FFFFh of each expanded primary slot,
; and the slot selected now in each page.
;   MIRR = page 0 or 2 with the same 4-byte header as page 1 (16KB ROMs often
;   show up again in other pages because of partial address decoding)
; RAM is found with a NON-DESTRUCTIVE probe at page+0F00h (read, write the
; complement, compare, restore), only in slots with no "AB" ROM header, so we
; never switch MegaROM banks or poke a disk interface.
;
; Speed: RDSLT works out the slot masks (027EH), switches the secondary slot
; register (02A3H) and the primary one (RDPRIM) for EVERY byte. Here each
; page is switched once and sampled in one go (snap): header, 3 samples and
; the RAM probe, by a small "block RDPRIM" copied to RAM (ramrd). Only page 1
; of another subslot of our own primary slot still needs RDSLT (snap_bios):
; switching it would remove this program. Page 3 uses probe3 (no stack).
;
; CART A / CART B: by MSX convention primary slots 1 and 2 are the cartridge
; connectors - there is no standard way to read this from the hardware.
;==============================================================================

; cell types (index into s_types / s_codes)
T_EMPTY	equ 0
T_RAM	equ 1
T_BIOS	equ 2
T_BASIC	equ 3
T_SUB	equ 4
T_DISK	equ 5
T_MUSIC	equ 6
T_ROM	equ 7
T_PROBE	equ 8
T_DATA	equ 9
T_MIRR	equ 10		; same header as page 1 of the slot: a mirror

; page snapshot (snap): 32 header bytes, 3 samples, RAM probe result
SN_0F00	equ 32
SN_2000	equ 33
SN_3FFF	equ 34
SN_RAM	equ 35		; 1 = page+0F00h is RAM
SN_SIZE	equ 36

; scan work area, in linebuf (only the SCREEN test uses it, never at the
; same time): one snapshot per page 0-2 and the RAM copy of ramrd
snap0	equ linebuf
snap1	equ linebuf + SN_SIZE
snap2	equ linebuf + 2 * SN_SIZE
ramrd	equ linebuf + 128

MAP_ROW0 equ 4			; row of PS0 on screen
REG_ROW0 equ 14			; registers header row

test_slots:
	call slotmap_scan	; fast and non-destructive: also at boot
	call slots_summary
	ld a,(v_quiet)		; at boot: no screen
	or a
	jr nz,.end
	call slotmap_show
	call get_key
.end:	ld a,ST_INFO
	ret

;==============================================================================
; Summary line, from the map: "0:BIOS 1:PROBE 2:RAM 3:EXP"
; Expanded slots show EXP; otherwise the most relevant thing in the slot.
;==============================================================================
slots_summary:
	xor a
	ld (v_idx),a
.slot:	ld a,(v_idx)
	or a
	jr z,.nosp
	ld a,' '
	call out_chr
.nosp:	ld a,(v_idx)
	add a,'0'
	call out_chr
	ld a,':'
	call out_chr
	call .label
	call out_str
	ld a,(v_idx)
	inc a
	ld (v_idx),a
	cp 4
	jr c,.slot
	ret

; .label - HL = label for primary slot (v_idx)
.label:
	ld a,(v_idx)
	ld hl,EXPTBL
	call add_hl_a
	bit 7,(hl)
	ld hl,s_sl_exp
	ret nz
	ld hl,.prio		; first type of the priority list found wins
.p:	ld a,(hl)
	inc hl
	cp 0FFh
	jr z,.none
	push hl
	ld c,a
	ld a,(v_idx)		; plain slot: map row = primary*4
	add a,a
	add a,a
	add a,a
	add a,a
	ld hl,v_map
	call add_hl_a
	ld b,4
.c:	ld a,(hl)
	cp c
	jr z,.found
	inc hl
	djnz .c
	pop hl
	jr .p
.found:	pop hl
	ld a,c
	ld hl,s_types
	jp str_table
.none:	ld hl,s_sl_none
	ret
.prio:	db T_PROBE, T_BIOS, T_DISK, T_MUSIC, T_ROM, T_RAM, T_SUB, T_DATA, 0FFh

;==============================================================================
; Full map
;==============================================================================

; slotmap_scan - fill v_map (16 slots x 4 pages) with T_* (FFh = no slot)
slotmap_scan:
	ld hl,ramrd_rom		; block RDPRIM to RAM
	ld de,ramrd
	ld bc,ramrd_len
	ldir
	xor a
	ld (v_idx),a
.slot:	ld a,(v_idx)
	add a,a
	add a,a
	ld hl,v_map
	call add_hl_a
	ld (v_mapp),hl
	ld a,(v_idx)
	call idx2id
	jr c,.none
	ld (v_cid),a
	call snap_slot
	xor a
.page:	ld (v_cpage),a
	call classify
	ld hl,(v_mapp)
	ld (hl),a
	inc hl
	ld (v_mapp),hl
	ld a,(v_cpage)
	inc a
	cp 4
	jr c,.page
	jr .next
.none:	ld hl,(v_mapp)		; (idx2id changed HL)
	ld b,4
.ff:	ld (hl),0FFh
	inc hl
	djnz .ff
.next:	ld a,(v_idx)
	inc a
	ld (v_idx),a
	cp 16
	jr c,.slot
	ei			; snap/RDSLT/probe3 leave interrupts off
	ret

; snap_slot - read-only snapshots of pages 0-2 of slot (v_cid), and
; v_hasab = 1 if it has "AB" at 4000h or 8000h. Our own slot is never
; flagged: its "AB" is this program, and probing its other pages is safe.
snap_slot:
	ld b,3
.s:	push bc
	dec b
	ld a,b
	call snap_ptr
	ex de,hl
	ld c,0
	ld a,(v_cid)
	call snap
	pop bc
	djnz .s
	xor a
	ld (v_hasab),a
	ld a,(v_cid)
	ld hl,v_slot_me
	cp (hl)
	ret z
	ld hl,snap1
	call is_ab
	jr z,.yes
	ld hl,snap2
	call is_ab
	ret nz
.yes:	ld a,1
	ld (v_hasab),a
	ret

; snap_ptr - HL = snapshot of page A (0-2). Changes AF, DE
snap_ptr:
	ld hl,snap0
	ld de,SN_SIZE
	or a
	ret z
.a:	add hl,de
	dec a
	jr nz,.a
	ret

; is_ab - Z if HL points to "AB" (cartridge ROM header)
is_ab:	ld de,s_ab
	ld b,2
; memcmp - compare B bytes at HL and DE. Z = equal
memcmp:	ld a,(de)
	cp (hl)
	ret nz
	inc hl
	inc de
	djnz memcmp
	ret

;------------------------------------------------------------------------------
; classify - what is in slot (v_cid), page (v_cpage)? -> A = T_*
; Pages 0-2 come from the snapshots taken by snap_slot.
;------------------------------------------------------------------------------
classify:
	ld a,(v_cpage)
	cp 3
	jp z,cl_page3
	call snap_ptr
	ld (v_snp),hl

	ld a,(v_cid)		; main ROM: BIOS + BASIC in pages 0-1
	ld hl,v_slot_bios
	cp (hl)
	jr nz,.nbios
	ld a,(v_cpage)
	cp 2
	jr nc,.nbios
	or a
	ld a,T_BIOS
	ret z
	ld a,T_BASIC
	ret
.nbios:	ld a,(v_cid)		; this program
	ld hl,v_slot_me
	cp (hl)
	jr nz,.nme
	ld a,(v_cpage)
	cp 1
	ld a,T_PROBE
	ret z
.nme:	ld hl,(v_snp)		; "AB" header?
	call is_ab
	jr nz,.nab
	ld a,(v_cpage)
	cp 1
	jr z,.p1
	ld hl,(v_snp)		; same 4 first bytes as page 1: mirror
	ld de,snap1
	ld b,4
	call memcmp
	ld a,T_MIRR
	ret z
	ld a,T_ROM
	ret
.p1:	call cl_isdisk
	ld a,T_DISK
	ret z
	ld hl,snap1 + 1Ch	; MSX-MUSIC: "OPLL" at 401Ch
	ld de,s_opll
	ld b,4
	call memcmp
	ld a,T_MUSIC
	ret z
	ld a,T_ROM
	ret
.nab:	ld a,(v_cpage)		; SUB-ROM: "CD" at 0000h
	or a
	jr nz,.ncd
	ld hl,snap0
	ld de,s_cd
	ld b,2
	call memcmp
	ld a,T_SUB
	ret z
.ncd:	ld a,(v_hasab)		; RAM probe only in slots without ROM:
	or a			; sample the page again, now probing
	jr nz,.ro
	ld a,(v_cpage)
	ld b,a
	ld c,1
	ld de,(v_snp)
	ld a,(v_cid)
	call snap
	ld hl,(v_snp)
	ld de,SN_RAM
	add hl,de
	ld a,(hl)
	or a
	ld a,T_RAM
	ret nz
.ro:	ld hl,(v_snp)		; empty: 0000h 0001h 0F00h 2000h 3FFFh = FFh
	ld a,(hl)
	inc hl
	and (hl)
	ld de,SN_0F00 - 1
	add hl,de
	and (hl)
	inc hl
	and (hl)
	inc hl
	and (hl)
	inc a
	ld a,T_EMPTY
	ret z
	ld a,T_DATA
	ret

; page 3: the current one is our RAM; others need the stack-less probe
cl_page3:
	ld a,(v_cid)
	ld hl,v_slot_ram
	cp (hl)
	ld a,T_RAM
	ret z
	ld a,(v_cid)
	jp probe3

; cl_isdisk - Z if slot (v_cid) is a disk interface: listed in DRVTBL, or
; the disk driver jump table at 4010h/4013h/4016h (JP = C3h)
cl_isdisk:
	ld hl,DRVTBL
	ld b,4
.t:	ld a,(hl)		; drives on this interface
	inc hl
	or a
	jr z,.tn
	ld a,(v_cid)
	cp (hl)
	ret z
.tn:	inc hl
	djnz .t
	ld hl,snap1 + 10h
	ld de,3
	ld b,3
	ld a,0C3h
.j:	cp (hl)
	ret nz
	add hl,de
	djnz .j
	ret			; Z

;------------------------------------------------------------------------------
; snap - snapshot of page B (0-2) of slot A into the buffer at DE:
;   +0..31 header, +32 byte at 0F00h, +33 at 2000h, +34 at 3FFFh,
;   +35 = 1 if 0F00h is RAM (probe only done when C = 1)
; The slot is switched in ONCE (book 027EH/02A3H, done by hand) and ramrd
; reads everything. Leaves interrupts disabled.
;------------------------------------------------------------------------------
snap:
	ld (v_sbuf),de
	ld (v_sid),a
	ld a,c
	ld (v_stest),a
	ld a,b
	ld (v_spg),a
	call get_slot		; slot already selected in this page?
	ld hl,v_sid
	cp (hl)
	di
	in a,(PPI_A)
	ld b,a			; B = A8h now
	ld a,b
	jr z,.go		; yes: read in place, nothing to switch
	ld a,(v_spg)		; page 1 holds this program: another subslot
	dec a			; of our own primary slot is reachable only
	jr nz,.ok		; by the BIOS (it runs from page 0)
	ld a,b
	rrca
	rrca
	xor (hl)
	and 3
	jr z,snap_bios
.ok:	ld a,(hl)		; expanded: select the subslot first
	or a
	jp p,.prim
	ld a,(v_spg)
	ld b,a
	ld a,(hl)
	call sec_set
	ld (v_osec),a
.prim:	ld a,(v_spg)		; primary slot into the page
	ld b,a
	ld a,(v_sid)
	and 3
	ld d,a
	call pg_bits
	in a,(PPI_A)
	ld b,a			; B = A8h now
	and c
	or d			; A = A8h with the slot in the page
	call .go
	ld a,(v_sid)		; subslot register back
	or a
	ret p
	ld a,(v_osec)
	ld e,a
	ld a,(v_sid)
	jp sec_put
; A = new A8h, B = old A8h
.go:	push af
	ld a,(v_spg)
	rrca
	rrca
	ld h,a
	ld l,0			; HL = page base
	ld de,(v_sbuf)
	ld a,(v_stest)
	ld c,a
	pop af
	jp ramrd

; snap_bios - same as snap, through RDSLT/WRSLT (slow but always safe).
; Reads only the bytes classify uses; with C = 1 (second call) only probes.
snap_bios:
	ld a,(v_stest)
	or a
	jr nz,.probe
	ld hl,.tab
.next:	ld a,(hl)		; buffer index (FFh = end)
	cp 0FFh
	ret z
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = offset in the page
	inc hl
	push hl
	push af
	ld a,(v_spg)
	rrca
	rrca
	add a,d
	ld h,a
	ld l,e
	ld a,(v_sid)
	call RDSLT
	ld e,a
	pop af
	ld hl,(v_sbuf)
	call add_hl_a
	ld (hl),e
	pop hl
	jr .next
.tab:	db 0
	dw 0000h
	db 1
	dw 0001h
	db 2
	dw 0002h
	db 3
	dw 0003h
	db 10h
	dw 0010h
	db 13h
	dw 0013h
	db 16h
	dw 0016h
	db 1Ch
	dw 001Ch
	db 1Dh
	dw 001Dh
	db 1Eh
	dw 001Eh
	db 1Fh
	dw 001Fh
	db SN_0F00
	dw 0F00h
	db SN_2000
	dw 2000h
	db SN_3FFF
	dw 3FFFh
	db 0FFh
.probe:	ld a,(v_spg)		; RAM probe at page+0F00h
	rrca
	rrca
	add a,0Fh
	ld h,a
	ld l,0
	ld a,(v_sid)
	call RDSLT
	ld (v_tmp),a		; original value
	cpl
	ld e,a
	ld a,(v_sid)
	call WRSLT
	ld a,(v_sid)
	call RDSLT
	ld (v_tmp2),a		; what came back
	ld a,(v_tmp)
	ld e,a
	ld a,(v_sid)
	call WRSLT		; restore
	ld a,(v_tmp)
	cpl
	ld hl,v_tmp2
	sub (hl)		; 0 = RAM
	ld hl,(v_sbuf)
	ld de,SN_RAM
	add hl,de
	ld (hl),1
	ret z
	ld (hl),0
	ret

;------------------------------------------------------------------------------
; ramrd_rom - "block RDPRIM", copied to ramrd (page 3) by slotmap_scan.
; Position independent. A = A8h with the slot switched in, B = A8h to
; restore, HL = page base, DE = buffer, C = 1: RAM probe at page+0F00h.
;------------------------------------------------------------------------------
ramrd_rom:
	out (PPI_A),a		; ---- slot switched in
	push bc
	ld bc,32
	ldir			; header
	pop bc
	ld l,0
	ld a,h
	add a,0Fh
	ld h,a
	ld a,(hl)		; +0F00h
	ld (de),a
	inc de
	ld a,h
	add a,11h
	ld h,a
	ld a,(hl)		; +2000h
	ld (de),a
	inc de
	ld a,h
	add a,1Fh
	ld h,a
	ld l,0FFh
	ld a,(hl)		; +3FFFh
	ld (de),a
	inc de
	ld a,h
	sub 30h
	ld h,a
	ld l,0			; +0F00h
	srl c			; probe asked for? C = 0 from here
	jr nc,.done
	ld a,(hl)
	cpl
	ld (hl),a		; write the complement
	cp (hl)
	cpl
	ld (hl),a		; restore (flags kept)
	jr nz,.done
	inc c			; read back what was written: RAM
.done:	ld a,c
	ld (de),a
	ld a,b
	out (PPI_A),a		; ---- slot back
	ret
ramrd_len equ $ - ramrd_rom
	ASSERT ramrd_len <= 128

;------------------------------------------------------------------------------
; Slot register helpers (book: 027EH masks, 02A3H secondary switching).
; The secondary slot register is FFFFh of its primary slot and reads back
; inverted; reaching it means switching page 3 (our stack and variables),
; so between the "page 3" marks only registers are used.
;------------------------------------------------------------------------------

; pg_bits - D = 2-bit slot number, B = page -> D = number at the page
; position, C = AND mask that clears that page. Changes F, B
pg_bits:
	ld c,0FCh
	inc b
	jr .n
.sh:	sla d
	sla d
	rlc c
	rlc c
.n:	djnz .sh
	ret

; sec_set - select the subslot of slot ID A in page B; A = previous
; register value. Interrupts must be off. Changes AF, BC, DE
sec_set:
	ld e,a
	rrca
	rrca
	and 3
	ld d,a			; D = subslot
	call pg_bits
	ld a,e
	rrca
	rrca
	and 0C0h
	ld e,a			; E = primary in bits 7-6
	in a,(PPI_A)
	ld b,a
	and 3Fh
	or e
	out (PPI_A),a		; ---- page 3 = primary: no stack, no variables
	ld a,(0FFFFh)
	cpl
	ld e,a			; E = previous value
	and c
	or d
	ld (0FFFFh),a
	ld a,b
	out (PPI_A),a		; ---- page 3 back
	ld a,e
	ret

; sec_put - write E to the secondary slot register of primary slot A.
; Interrupts must be off. Changes AF, B, D
sec_put:
	rrca
	rrca
	and 0C0h
	ld d,a
	in a,(PPI_A)
	ld b,a
	and 3Fh
	or d
	out (PPI_A),a		; ---- page 3 = primary
	ld a,e
	ld (0FFFFh),a
	ld a,b
	out (PPI_A),a		; ---- page 3 back
	ret

; sec_get - A = secondary slot register of primary slot A (real hardware
; value, not the SLTTBL copy). Changes AF, B, D
sec_get:
	rrca
	rrca
	and 0C0h
	ld d,a
	di
	in a,(PPI_A)
	ld b,a
	and 3Fh
	or d
	out (PPI_A),a		; ---- page 3 = primary
	ld a,(0FFFFh)
	cpl
	ld d,a
	ld a,b
	out (PPI_A),a		; ---- page 3 back
	ei
	ld a,d
	ret

;------------------------------------------------------------------------------
; probe3 - what is in page 3 (C000h-FFFFh) of slot A? -> A = T_RAM/EMPTY/DATA
; Switching page 3 removes our stack and variables, so between the two
; "page 3 switched" marks only registers are used. FFFFh (subslot register
; of an expanded slot) is never probed. Leaves interrupts disabled.
;------------------------------------------------------------------------------
probe3:
	ld e,a			; E = slot ID
	di
	in a,(PPI_A)
	ld d,a			; D = original A8h
	ld a,e
	and 3
	rrca
	rrca			; primary -> bits 7-6
	ld c,a
	ld a,d
	and 3Fh
	or c
	out (PPI_A),a		; ---- page 3 switched: no stack, no variables
	bit 7,e
	jr z,.probe
	ld a,(0FFFFh)
	cpl
	ld b,a			; B = original subslot register
	ld a,e
	and 0Ch
	rlca
	rlca
	rlca
	rlca			; subslot -> bits 7-6
	ld h,a
	ld a,b
	and 3Fh
	or h
	ld (0FFFFh),a
.probe:	ld a,(0CF00h)
	ld l,a
	cpl
	ld (0CF00h),a
	ld a,(0CF00h)
	cpl
	cp l			; Z = RAM
	ld a,l
	ld (0CF00h),a		; restore
	ld h,T_RAM
	jr z,.done
	ld a,(0C000h)
	ld h,a
	ld a,(0C001h)
	and h
	ld h,a
	ld a,(0CF00h)
	and h
	ld h,a
	ld a,(0E000h)
	and h
	ld h,a
	ld a,(0FFFEh)
	and h
	inc a			; FFh -> 0: empty
	ld h,T_EMPTY
	jr z,.done
	ld h,T_DATA
.done:	bit 7,e
	jr z,.r1
	ld a,b
	ld (0FFFFh),a		; subslot register back
.r1:	ld a,d
	out (PPI_A),a		; ---- page 3 back
	ld a,h
	ret

;------------------------------------------------------------------------------
; slotmap_show - draw the map screen (Red Book fig.44 + fig.1/fig.2)
;   SLOT MAP                         MSX2+
;   ----------------------------------------
;         SS0      SS1      SS2      SS3
;       0 4 8 C  0 4 8 C  0 4 8 C  0 4 8 C
;   PS0 BIBA....
;   PS1 MIPRMI..
;   PS2 ........
;   PS3 RARARARA ........ ........ SUSU....
;   ----------------------------------------
;    BI BIOS   BA BASIC  SU SUB     DK DISK     (legend, 4 lines)
;   ----------------------------------------
;    REGISTER 76543210 PAGE 3   2   1   0
;    PORT A8H 11110000      3   3   0   1
;    FFFFH(3) 00000000      0   0   0   0
;    SLOT NOW               3-0 3-0 1   0
;------------------------------------------------------------------------------
slotmap_show:
	call txt_init
	ld de,(0 << 8) + 1
	ld hl,s_map_title
	call print_at
	ld de,(0 << 8) + 26
	call locate
	ld a,(v_msxver)
	ld hl,s_msxver
	call str_table
	call print
	ld d,1
	call sep_line
	ld de,(2 << 8) + 0
	ld hl,s_map_ss
	call print_at
	ld de,(3 << 8) + 0
	ld hl,s_map_pg
	call print_at

	; grid: row = primary slot, column group = subslot
	xor a
	ld (v_idx),a
.slot:	ld a,(v_idx)
	ld b,a
	rrca
	rrca
	and 3
	add a,MAP_ROW0
	ld d,a			; D = row
	ld a,b
	and 3
	jr nz,.cells
	ld e,0			; first subslot: row label "PSn"
	call locate
	ld hl,s_map_ps
	call print
	ld a,b
	rrca
	rrca
	and 3
	add a,'0'
	call CHPUT
	ld a,(v_idx)
	and 3
.cells:	ld b,a			; column = 4 + 9 * subslot
	add a,a
	add a,a
	add a,a
	add a,b
	add a,4
	ld e,a
	ld a,(v_idx)		; slot exists?
	add a,a
	add a,a
	ld hl,v_map
	call add_hl_a
	ld a,(hl)
	inc a
	jr z,.next
	call locate
	ld b,4
.cell:	push hl
	ld a,(hl)
	add a,a
	ld hl,s_codes
	call add_hl_a
	ld a,(hl)
	call CHPUT
	inc hl
	ld a,(hl)
	call CHPUT
	pop hl
	inc hl
	djnz .cell
.next:	ld a,(v_idx)
	inc a
	ld (v_idx),a
	cp 16
	jr c,.slot

	; legend
	ld d,MAP_ROW0 + 4
	call sep_line
	ld hl,s_map_legend
	ld d,MAP_ROW0 + 5
.leg:	ld e,0
	call print_at		; HL = next line
	inc d
	ld a,d
	cp REG_ROW0 - 1
	jr c,.leg
	call sep_line

	; slot registers, bits 7-0 = pages 3-0
	ld de,(REG_ROW0 << 8) + 0
	ld hl,s_reg_hdr
	call print_at
	ld a,REG_ROW0 + 1
	ld (v_row),a
	ld d,a
	ld e,0
	ld hl,s_reg_a8
	call print_at
	in a,(PPI_A)
	call reg_row
	xor a			; FFFFh of each expanded primary slot
.ex:	ld (v_idx),a
	ld hl,EXPTBL
	call add_hl_a
	bit 7,(hl)
	jr z,.nex
	ld hl,v_row
	inc (hl)
	ld d,(hl)
	ld e,0
	ld hl,s_reg_ss
	call print_at
	ld a,(v_idx)
	add a,'0'
	call CHPUT
	ld a,')'
	call CHPUT
	ld a,(v_idx)
	call sec_get
	call reg_row
.nex:	ld a,(v_idx)
	inc a
	cp 4
	jr c,.ex
	ld hl,v_row		; slot ID selected now in each page
	inc (hl)
	ld d,(hl)
	ld e,0
	ld hl,s_reg_now
	call print_at
	ld a,3
.now:	ld (v_tmp),a
	ld b,a
	call get_slot
	push af
	ld a,(v_tmp)		; column = 36 - 4 * page
	add a,a
	add a,a
	cpl
	add a,36 + 1
	ld e,a
	ld a,(v_row)
	ld d,a
	call locate
	pop af
	call print_slot
	ld a,(v_tmp)
	dec a
	jp p,.now

	ld de,(22 << 8) + 0
	ld hl,s_reg_note
	call print_at
	ld de,(23 << 8) + 1
	ld hl,s_anykey
	jp print_at

; reg_row - on row (v_row): register A in binary at column 10 and the
; 2-bit slot number of pages 3, 2, 1, 0 at columns 24, 28, 32, 36
reg_row:
	ld c,a
	ld a,(v_row)
	ld d,a
	ld e,10
	call locate
	ld b,8
.bit:	rlc c
	ld a,'0'
	adc a,0
	call CHPUT
	djnz .bit
	ld e,24
.pg:	call locate
	rlc c
	rlc c
	ld a,c
	and 3
	add a,'0'
	call CHPUT
	ld a,e
	add a,4
	ld e,a
	cp 40
	jr c,.pg
	ret

; print_slot - print slot ID A on screen as "1" or "3-2"
print_slot:
	push af
	and 3
	add a,'0'
	call CHPUT
	pop af
	bit 7,a
	ret z
	push af
	ld a,'-'
	call CHPUT
	pop af
	rrca
	rrca
	and 3
	add a,'0'
	jp CHPUT

s_ab:	db "AB"
s_cd:	db "CD"
