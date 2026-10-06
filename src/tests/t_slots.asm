;==============================================================================
; t_slots.asm - SLOTS
;
; Menu line (also computed at boot): "0:BIOS 1:PROBE 2:RAM 3:EXP"
;   per primary slot: EXP = expanded, else the most relevant thing found in
;   the map below (PROBE > BIOS > DISK > MUSIC > ROM > RAM > SUB > DATA).
;
; ENTER on SLOTS shows the full map: every slot/subslot x page
; (0000h/4000h/8000h/C000h) with what is there:
;   BIOS BASIC SUB(-ROM) DISK MUSIC(MSX-MUSIC) ROM("AB") RAM PROBE DATA ----
;   MIRR = page 0 or 2 with the same 4-byte header as page 1 (16KB ROMs often
;   show up again in other pages because of partial address decoding)
; RAM is found with a NON-DESTRUCTIVE probe at page+0F00h (read, write the
; complement, compare, restore), only in slots with no "AB" ROM header, so we
; never switch MegaROM banks or poke a disk interface. Page 3 of a slot that
; is not the current one needs a stack-less routine (probe3).
; CART A / CART B: by MSX convention primary slots 1 and 2 are the cartridge
; connectors - there is no standard way to read this from the hardware.
;==============================================================================

; cell types (index into s_types)
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

MAP_ROW0 equ 3			; first row of the map on screen

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
	call slot_hasab
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
	ei			; RDSLT/WRSLT/probe3 leave interrupts off
	ret

; slot_hasab - v_hasab = 1 if slot (v_cid) has "AB" at 4000h or 8000h.
; Our own slot is never flagged: its "AB" is this program, and probing its
; other pages is safe.
slot_hasab:
	xor a
	ld (v_hasab),a
	ld a,(v_cid)
	ld hl,v_slot_me
	cp (hl)
	ret z
	ld hl,4000h
	ld de,s_ab
	call slot_cmp2
	jr z,.yes
	ld a,(v_cid)
	ld hl,8000h
	ld de,s_ab
	call slot_cmp2
	ret nz
.yes:	ld a,1
	ld (v_hasab),a
	ret

;------------------------------------------------------------------------------
; classify - what is in slot (v_cid), page (v_cpage)? -> A = T_*
;------------------------------------------------------------------------------
classify:
	ld a,(v_cpage)
	cp 3
	jp z,cl_page3
	rrca
	rrca
	ld h,a
	ld l,0
	ld (v_base),hl		; 0000h / 4000h / 8000h

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
.nme:	ld hl,(v_base)		; "AB" header?
	ld de,s_ab
	ld a,(v_cid)
	call slot_cmp2
	jr nz,.nab
	ld a,(v_cpage)
	cp 1
	jr z,.p1
	call cl_ismirror
	ld a,T_MIRR
	ret z
	ld a,T_ROM
	ret
.p1:
	call cl_isdisk
	ld a,T_DISK
	ret z
	ld hl,401Ch
	ld de,s_opll
	ld a,(v_cid)
	call slot_cmp4
	ld a,T_MUSIC
	ret z
	ld a,T_ROM
	ret
.nab:	ld a,(v_cpage)		; SUB-ROM: "CD" at 0000h
	or a
	jr nz,.ncd
	ld hl,0
	ld de,s_cd
	ld a,(v_cid)
	call slot_cmp2
	ld a,T_SUB
	ret z
.ncd:	ld a,(v_hasab)		; RAM probe only in slots without ROM
	or a
	jr nz,.ro
	call cl_ramprobe
	ld a,T_RAM
	ret c
.ro:	call cl_isempty
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

; cl_ismirror - Z if the first 4 bytes at (v_base) equal those at 4000h
; (same slot)
cl_ismirror:
	ld hl,4000h
	ld de,v_hdr
	ld b,4
.r:	push bc
	push de
	ld a,(v_cid)
	call RDSLT
	pop de
	pop bc
	ld (de),a
	inc hl
	inc de
	djnz .r
	ld hl,(v_base)
	ld de,v_hdr
	ld a,(v_cid)
	jp slot_cmp4

; cl_ramprobe - carry set if (v_base)+0F00h in slot (v_cid) is RAM
cl_ramprobe:
	ld hl,(v_base)
	ld a,h
	or 0Fh
	ld h,a
	ld a,(v_cid)
	call RDSLT
	ld (v_tmp),a		; original value
	cpl
	ld e,a
	ld a,(v_cid)
	call WRSLT
	ld a,(v_cid)
	call RDSLT
	ld (v_tmp2),a		; what came back
	ld a,(v_tmp)
	ld e,a
	ld a,(v_cid)
	call WRSLT		; restore
	ld a,(v_tmp)
	cpl
	ld b,a
	ld a,(v_tmp2)
	cp b
	scf
	ret z
	or a
	ret

; cl_isempty - Z if sample bytes of the page all read FFh (nothing there)
cl_isempty:
	ld a,0FFh
	ld (v_and),a
	ld hl,.offs
	ld b,5
.s:	push bc
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	push hl
	ld hl,(v_base)
	add hl,de
	ld a,(v_cid)
	call RDSLT
	ld hl,v_and
	and (hl)
	ld (hl),a
	pop hl
	pop bc
	djnz .s
	ld a,(v_and)
	inc a
	ret
.offs:	dw 0000h, 0001h, 0F00h, 2000h, 3FFFh

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
	ld hl,4010h
	ld b,3
.j:	push bc
	ld a,(v_cid)
	call RDSLT
	pop bc
	cp 0C3h
	ret nz
	inc hl
	inc hl
	inc hl
	djnz .j
	ret			; Z

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
; slotmap_show - draw the map screen
;   SLOT MAP                         MSX2+
;   ----------------------------------------
;    SLOT  0000  4000  8000  C000  NOTE
;    0     BIOS  BASIC ----  ----
;    1     ----  PROBE ----  ----  CART A
;    3-0   ----  ----  RAM   RAM
;   ...
;   Pages now  0:0  1:1  2:3-0  3:3-0
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
	ld de,(2 << 8) + 1
	ld hl,s_map_hdr
	call print_at

	ld a,MAP_ROW0
	ld (v_row),a
	xor a
	ld (v_idx),a
.slot:	ld a,(v_idx)		; skip slots that do not exist
	add a,a
	add a,a
	ld hl,v_map
	call add_hl_a
	ld a,(hl)
	inc a
	jr z,.next
	ld (v_mapp),hl
	; slot number
	ld a,(v_row)
	ld d,a
	ld e,1
	call locate
	ld a,(v_idx)
	call idx2id
	call print_slot
	; 4 cells
	ld c,0
.cell:	ld a,(v_row)
	ld d,a
	ld a,c
	add a,a
	ld b,a
	add a,a
	add a,b			; *6
	add a,7
	ld e,a
	call locate
	ld hl,(v_mapp)
	ld a,c
	call add_hl_a
	ld a,(hl)
	ld hl,s_types
	call str_table
	call print
	inc c
	ld a,c
	cp 4
	jr c,.cell
	; note: CART A / CART B on the first row of primary slots 1 and 2
	ld a,(v_idx)
	ld hl,s_carta
	cp 1 * 4
	jr z,.note
	ld hl,s_cartb
	cp 2 * 4
	jr nz,.nonote
.note:	push hl
	ld a,(v_row)
	ld d,a
	ld e,31
	call locate
	pop hl
	call print
.nonote:
	ld hl,v_row
	inc (hl)
.next:	ld a,(v_idx)
	inc a
	ld (v_idx),a
	cp 16
	jr c,.slot

	; slots selected right now in each page
	ld d,20
	call sep_line
	ld de,(21 << 8) + 1
	ld hl,s_pages
	call print_at
	xor a
.pg:	push af
	add a,'0'
	call CHPUT
	ld a,':'
	call CHPUT
	pop af
	push af
	ld b,a
	call get_slot
	call print_slot
	ld a,' '
	call CHPUT
	call CHPUT
	pop af
	inc a
	cp 4
	jr c,.pg
	ld de,(22 << 8) + 1
	ld hl,s_map_legend
	call print_at
	ld de,(23 << 8) + 1
	ld hl,s_anykey
	jp print_at

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
