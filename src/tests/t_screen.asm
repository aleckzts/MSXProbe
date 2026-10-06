;==============================================================================
; t_screen.asm - SCREEN test: sub-menu with every screen mode this machine
; has; each one shows a demo at the mode's full resolution and colors.
;
;   text modes  : the whole character set, plus a column ruler on row 0
;   SCREEN 2/4  : 16 color bars + 1-pixel checkerboard strip (256x192)
;   SCREEN 3    : 16 color bars + block checkerboard (64x48)
;   SCREEN 5/7  : 16 color bars + 1-pixel checkerboard strip
;   SCREEN 6    : 4 color bars  + 1-pixel checkerboard strip (512 wide)
;   SCREEN 8    : all 256 colors (16x16 grid) + 1-pixel strip
;   SCREEN 12   : YJK color plane (K across, J down) + gray 1-pixel strip
;   SCREEN 10/11: YJK plane (top) + 16 palette colors (bottom, YAE mode)
;
; Bitmap modes are drawn with the display off, one line at a time: a
; generator fills linebuf, then OTIR sends it to VRAM. Addresses above 16KB
; use R#14 (A14-A16), set for every line.
;==============================================================================

SM_SIZE	 equ 6			; bytes per entry in scr_modes
NSMODES	 equ 12
SM_128K	 equ 1			; flag: needs 128KB VRAM
SCR_ROW0 equ 3			; first row of the list

; min MSX version, flags, label, routine
scr_modes:
	db 0, 0 : dw s_sm0_40, view_txt40
	db 1, 0 : dw s_sm0_80, view_txt80
	db 0, 0 : dw s_sm1,  view_scr1
	db 0, 0 : dw s_sm2,  view_scr2
	db 0, 0 : dw s_sm3,  view_scr3
	db 1, 0 : dw s_sm4,  view_scr4
	db 1, 0 : dw s_sm5,  view_scr5
	db 1, 0 : dw s_sm6,  view_scr6
	db 1, SM_128K : dw s_sm7,  view_scr7
	db 1, SM_128K : dw s_sm8,  view_scr8
	db 2, SM_128K : dw s_sm10, view_scr10
	db 2, SM_128K : dw s_sm12, view_scr12

;==============================================================================
; test_screen - the sub-menu
;==============================================================================
test_screen:
	; list of modes available here -> scr_list, count -> v_sn
	xor a
	ld (v_sn),a
	ld (v_scur),a
	ld hl,scr_seen
	ld b,NSMODES
.clr:	ld (hl),0
	inc hl
	djnz .clr
	ld c,0			; C = mode index
.build:	ld a,c
	call sm_entry		; HL = entry
	ld a,(v_msxver)
	cp 4
	jr c,.v
	xor a			; unknown version: MSX1 modes only
.v:	cp (hl)
	jr c,.skip		; machine older than the mode
	inc hl
	bit 0,(hl)
	jr z,.ok
	ld a,(v_vblk)
	cp 8
	jr c,.skip		; needs 128KB VRAM
.ok:	ld hl,scr_list
	ld a,(v_sn)
	call add_hl_a
	ld (hl),c
	ld hl,v_sn
	inc (hl)
.skip:	inc c
	ld a,c
	cp NSMODES
	jr c,.build

.redraw:
	call txt_init
	call scr_draw
.loop:	call scr_marks
.key:	call get_key
	cp K_UP
	jr z,.up
	cp K_DOWN
	jr z,.down
	cp K_ENTER
	jr z,.show
	cp K_SPACE
	jr z,.show
	cp K_ESC
	jr z,.done
	jr .key
.up:	ld a,(v_scur)
	or a
	jr nz,.u1
	ld a,(v_sn)
.u1:	dec a
	ld (v_scur),a
	jr .loop
.down:	ld a,(v_scur)
	inc a
	ld hl,v_sn
	cp (hl)
	jr c,.d1
	xor a
.d1:	ld (v_scur),a
	jr .loop

.show:	ld a,(v_scur)		; mark as seen, run the view
	ld hl,scr_seen
	call add_hl_a
	ld (hl),1
	call scr_cur_mode
	call sm_entry
	inc hl
	inc hl
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	call jp_hl
	call wait_any_key
	; cursor to the next mode not seen yet
	ld a,(v_scur)
	ld c,a
	ld a,(v_sn)
	ld b,a
.nx:	inc c
	ld a,c
	ld hl,v_sn
	cp (hl)
	jr c,.n1
	ld c,0
.n1:	ld a,c
	ld hl,scr_seen
	call add_hl_a
	ld a,(hl)
	or a
	jr z,.nf
	djnz .nx
	jp .redraw
.nf:	ld a,c
	ld (v_scur),a
	jp .redraw

.done:	; result: "12 modes, 3 viewed"
	ld a,(v_sn)
	ld l,a
	ld h,0
	call out_dec
	ld hl,s_modes
	call out_str
	ld hl,scr_seen
	ld b,NSMODES
	ld c,0
.cnt:	ld a,(hl)
	add a,c
	ld c,a
	inc hl
	djnz .cnt
	ld l,c
	ld h,0
	call out_dec
	ld hl,s_viewed
	call out_str
	ld a,ST_INFO
	ret

; scr_cur_mode - A = mode index of the item under the cursor
scr_cur_mode:
	ld a,(v_scur)
	ld hl,scr_list
	call add_hl_a
	ld a,(hl)
	ret

; sm_entry - A = mode index -> HL = its entry in scr_modes
sm_entry:
	ld l,a
	add a,a
	add a,l
	add a,a			; *6
	ld hl,scr_modes
	jp add_hl_a

; wait_any_key - wait for a new key press
wait_any_key	equ get_key

;------------------------------------------------------------------------------
; scr_draw - the mode list screen
;------------------------------------------------------------------------------
scr_draw:
	ld de,(0 << 8) + 1
	ld hl,s_scr_title
	call print_at
	ld de,(0 << 8) + 26
	call locate
	ld a,(v_msxver)
	ld hl,s_msxver
	call str_table
	call print
	ld d,1
	call sep_line
	ld c,0
.item:	ld a,c
	add a,SCR_ROW0
	ld d,a
	ld e,2
	call locate
	ld a,c
	push bc
	ld hl,scr_list
	call add_hl_a
	ld a,(hl)
	call sm_entry
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld b,35
	call print_pad
	pop bc
	inc c
	ld a,(v_sn)
	cp c
	jr nz,.item
	ld d,22
	call sep_line
	ld de,(23 << 8) + 1
	ld hl,s_scr_footer
	jp print_at

; scr_marks - '>' cursor in column 0 and '*' for seen modes in column 38
scr_marks:
	ld c,0
.l:	ld a,c
	add a,SCR_ROW0
	ld d,a
	ld e,0
	call locate
	ld a,(v_scur)
	cp c
	ld a,'>'
	jr z,.c
	ld a,' '
.c:	call CHPUT
	ld e,38
	call locate
	ld a,c
	ld hl,scr_seen
	call add_hl_a
	ld a,(hl)
	or a
	ld a,'*'
	jr nz,.s
	ld a,' '
.s:	call CHPUT
	inc c
	ld a,(v_sn)
	cp c
	jr nz,.l
	ret

; str_table - A = index, HL = "dw" table -> HL = string
str_table:
	add a,a
	call add_hl_a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ret

;==============================================================================
; Text modes: character set + column ruler
;==============================================================================
view_txt40:
	ld a,40
	ld (LINL40),a
	call INITXT
	ld hl,(TXTNAM)
	ld c,40
	jr txt_fill
view_txt80:
	ld a,80
	ld (LINL40),a
	call INITXT
	ld hl,(TXTNAM)
	ld c,80
	jr txt_fill
view_scr1:
	call INIT32
	ld hl,(T32NAM)
	ld c,32
	; fall through

; txt_fill - HL = name table, C = columns. Row 0 = "1234567890..." ruler,
; rows 1-23 = character codes 0,1,2... (the whole font, repeating)
txt_fill:
	push hl
	push bc
	call set_palette
	pop bc
	pop hl
	di
	call vram_wr
	ld b,c
	ld e,'1'
.r0:	ld a,e			; ruler
	out (VDP_DATA),a
	inc e
	ld a,e
	cp '9'+1
	jr nz,.r1
	ld e,'0'
.r1:	djnz .r0
	ld d,23			; 23 rows of characters
	ld e,0			; E = character code
.row:	ld b,c
.ch:	ld a,e
	out (VDP_DATA),a
	inc e
	nop
	djnz .ch
	dec d
	jr nz,.row
	ei
	ret

;==============================================================================
; SCREEN 2 / 4: patterns, colors and a sequential name table
;==============================================================================
G2_BARS	equ 18			; character rows of bars, the rest is the strip

view_scr2:
	call INIGRP
	jr g2_draw
view_scr4:
	ld a,4
	call CHGMOD
g2_draw:
	call set_palette
	call DISSCR
	di
	; name table 1800h: 0..255 three times
	ld hl,1800h
	call vram_wr
	ld b,0
	ld c,3
.nam:	ld a,b
	out (VDP_DATA),a
	inc b
	jr nz,.nam
	dec c
	jr nz,.nam
	; patterns 0000h: bars = 0 (show the background color), strip = 1-px
	; checkerboard (AAh / 55h on alternate lines)
	ld hl,0
	call vram_wr
	ld bc,G2_BARS * 256
.pz:	xor a
	out (VDP_DATA),a
	dec bc
	ld a,b
	or c
	jr nz,.pz
	ld bc,(24 - G2_BARS) * 256
	ld e,0AAh
.pc:	ld a,e
	out (VDP_DATA),a
	cpl
	ld e,a
	dec bc
	ld a,b
	or c
	jr nz,.pc
	; colors 2000h: column c of the bars = color c/2 (fg = bg), strip F1h
	ld hl,2000h
	call vram_wr
	ld d,G2_BARS
.crow:	ld e,0			; E = column
.ccol:	ld a,e
	srl a
	ld c,a
	rlca
	rlca
	rlca
	rlca
	or c
	ld b,8
.cb:	out (VDP_DATA),a
	djnz .cb
	inc e
	bit 5,e
	jr z,.ccol
	dec d
	jr nz,.crow
	ld bc,(24 - G2_BARS) * 256
.cs:	ld a,0F1h
	out (VDP_DATA),a
	dec bc
	ld a,b
	or c
	jr nz,.cs
	ei
	jp ENASCR

;==============================================================================
; SCREEN 3 (multicolor, 64x48 blocks of 4x4 pixels)
; Pattern p (0-191), byte j (0-7): block row by = (p>>5)*8 + j,
; columns bx = 2*(p&31) (high nibble) and bx+1 (low nibble).
; Rows by < 40: color = bx/4 (16 bars). Rows 40-47: block checkerboard.
;==============================================================================
view_scr3:
	call INIMLT
	call set_palette
	call DISSCR
	di
	ld hl,(MLTCGP)
	call vram_wr
	ld c,0			; C = pattern p
.pat:	ld a,c
	rlca
	rlca
	rlca
	and 7			; p>>5
	add a,a
	add a,a
	add a,a
	ld d,a			; D = by of byte 0
	ld b,8
.byte:	ld a,d
	cp 40
	jr nc,.chk
	ld a,c			; bars: both nibbles = (p&31)/2
	and 31
	srl a
	ld e,a
	rlca
	rlca
	rlca
	rlca
	or e
	jr .put
.chk:	ld a,d			; checkerboard: white/black, swapped every row
	rrca
	ld a,0F1h
	jr nc,.put
	ld a,1Fh
.put:	out (VDP_DATA),a
	inc d
	djnz .byte
	inc c
	ld a,c
	cp 192
	jr nz,.pat
	ei
	jp ENASCR

;==============================================================================
; Bitmap modes (MSX2 and later)
;==============================================================================
view_scr5:
	ld a,5
	ld hl,gen5
	jr bm_view128
view_scr6:
	ld a,6
	ld hl,gen6
bm_view128:
	ld b,128
	jr bm_view
view_scr7:
	ld a,7
	ld hl,gen7
	jr bm_view256
view_scr8:
	ld a,8
	ld hl,gen8
bm_view256:
	ld b,0
	; fall through

; bm_view - A = mode, HL = line generator, B = bytes per line (0 = 256)
bm_view:
	ld (v_gen),hl
	ld c,a
	ld a,b
	ld (v_bpl),a
	ld a,c
	call CHGMOD
	call set_palette
	jr bm_draw

view_scr12:
	xor a			; YJK only
	jr yjk_view
view_scr10:
	ld a,1			; YJK + YAE (palette pixels)
yjk_view:
	ld (v_yae),a
	ld hl,genyjk
	ld (v_gen),hl
	xor a
	ld (v_bpl),a
	ld a,8			; G7 layout; YJK is switched on in R#25
	call CHGMOD
	call set_palette
	di
	ld a,(v_yae)
	or a
	ld b,08h		; YJK
	jr z,.r25
	ld b,18h		; YJK + YAE
.r25:	ld c,25
	call vdp_reg
	ei
	; fall through

; bm_draw - 212 lines through the generator (v_gen), v_bpl bytes each
bm_draw:
	call DISSCR
	xor a
	ld (v_line),a
.line:	di
	ld a,(v_bpl)
	or a
	ld a,(v_line)
	jr z,.a256
	; 128 bytes/line: address = y<<7
	ld b,a
	rlca
	and 1			; R#14 = y>>7
	ld c,a
	ld a,b
	rrca
	and 80h
	ld e,a			; low byte = (y&1)<<7
	ld a,b
	srl a
	and 3Fh
	ld d,a			; high bits = (y>>1)&3Fh
	jr .addr
.a256:	; 256 bytes/line: address = y<<8
	ld b,a
	rlca
	rlca
	and 3
	ld c,a			; R#14 = y>>6
	ld e,0
	ld a,b
	and 3Fh
	ld d,a
.addr:	ld a,c
	out (VDP_CTRL),a
	ld a,80h + 14
	out (VDP_CTRL),a
	ld a,e
	out (VDP_CTRL),a
	ld a,d
	or 40h
	out (VDP_CTRL),a
	ld hl,(v_gen)
	call jp_hl		; fill linebuf
	ld hl,linebuf
	ld a,(v_bpl)
	ld b,a
	ld c,VDP_DATA
	otir			; display is off: full speed is fine
	ei
	ld hl,v_line
	inc (hl)
	ld a,(hl)
	cp 212
	jr nz,.line
	di
	ld bc,(0 << 8) + 14
	call vdp_reg		; R#14 back to 0
	ei
	jp ENASCR

;--- line generators: in v_line, fill linebuf -----------------------------------
STRIP_Y	equ 180			; first line of the 1-pixel strip

; SCREEN 5: 2 pixels/byte, 16 bars of 16 pixels
gen5:	ld a,(v_line)
	cp STRIP_Y
	jr nc,strip128
	ld hl,linebuf
.l:	ld a,l
	rrca
	rrca
	rrca
	and 0Fh			; color = x/16 = byte/8
	call nib2
	ld (hl),a
	inc l
	bit 7,l
	jr z,.l
	ret

; SCREEN 6: 4 pixels/byte, 4 bars of 128 pixels
gen6:	ld a,(v_line)
	cp STRIP_Y
	jr nc,.strip
	ld hl,linebuf
.l:	ld a,l
	rlca
	rlca
	rlca
	and 3			; color = byte/32
	ld e,a
	add a,a
	add a,a
	add a,e
	ld e,a			; *5
	add a,a
	add a,a
	add a,a
	add a,a
	or e			; *55h: color in all 4 pixels
	ld (hl),a
	inc l
	bit 7,l
	jr z,.l
	ret
.strip:	ld b,128
	ld a,(v_line)
	rrca
	ld a,0CCh		; pixels 3,0,3,0
	jr nc,fill_line
	ld a,33h
	jr fill_line

; SCREEN 7: 2 pixels/byte, 16 bars of 32 pixels
gen7:	ld a,(v_line)
	cp STRIP_Y
	jr nc,strip256
	ld hl,linebuf
.l:	ld a,l
	rrca
	rrca
	rrca
	rrca
	and 0Fh			; color = byte/16
	call nib2
	ld (hl),a
	inc l
	jr nz,.l
	ret

; strips of white/black single pixels (4bpp), swapped on odd lines
strip128:
	ld b,128
	jr strip
strip256:
	ld b,0
strip:	ld a,(v_line)
	rrca
	ld a,0F1h
	jr nc,fill_line
	ld a,1Fh
	; fall through
; fill_line - B bytes (0 = 256) of A into linebuf
fill_line:
	ld hl,linebuf
.f:	ld (hl),a
	inc l
	djnz .f
	ret

; nib2 - A = color 0-15 -> A = color in both nibbles
nib2:	ld e,a
	rlca
	rlca
	rlca
	rlca
	or e
	ret

; SCREEN 8: 1 byte/pixel (GGGRRRBB), 16x16 grid with all 256 colors
gen8:	ld a,(v_line)
	cp 208			; 16 cells x 13 lines
	jr nc,.strip
	ld c,0			; C = y / 13
.div:	sub 13
	jr c,.dv
	inc c
	jr .div
.dv:	ld a,c
	rlca
	rlca
	rlca
	rlca
	ld c,a			; C = row of cells * 16
	ld hl,linebuf
.l:	ld a,l
	rrca
	rrca
	rrca
	rrca
	and 0Fh
	add a,c
	ld (hl),a
	inc l
	jr nz,.l
	ret
.strip:	ld hl,linebuf		; FFh/00h single pixels, swapped per line
	ld a,(v_line)
	rrca
	sbc a,a
.s:	ld (hl),a
	cpl
	inc l
	jr nz,.s
	ret

; SCREEN 12 / 10: YJK. Every 4 pixels share J and K (6-bit signed), split
; over the low 3 bits of the 4 bytes: K low, K high, J low, J high.
; Here K grows across (64 groups), J grows down; Y fixed (A0h works as
; Y=20 in SCREEN 12 and as Y=10 with A=0 in SCREEN 10).
genyjk:	ld a,(v_yae)
	or a
	ld a,(v_line)
	jr z,.y12
	cp 150
	jr nc,.pal		; SCREEN 10: palette colors at the bottom
	jr .plane
.y12:	cp 200
	jr nc,.gray		; SCREEN 12: gray 1-pixel strip at the bottom
.plane:	rrca
	rrca
	and 3Fh
	sub 26
	and 3Fh
	ld d,a			; D = J (same for the whole line)
	ld a,(v_line)
	or a
	call z,.kinit		; first line: K bytes (never change)
	ld a,d
	and 7
	or 0A0h
	ld b,a			; B = byte 2 (J low)
	ld a,d
	rrca
	rrca
	rrca
	and 7
	or 0A0h
	ld c,a			; C = byte 3 (J high)
	ld hl,linebuf + 2
	ld e,64			; 64 groups of 4 pixels
.j:	ld (hl),b
	inc l
	ld (hl),c
	inc l
	inc l
	inc l
	dec e
	jr nz,.j
	ret
; .kinit - bytes 0/1 of every group: K low / K high, K = group - 32
.kinit:	ld hl,linebuf
	ld e,64
.k:	ld a,l
	rrca
	rrca
	and 3Fh
	xor 20h
	ld c,a			; C = K
	and 7
	or 0A0h
	ld (hl),a		; byte 0: K low
	inc l
	ld a,c
	rrca
	rrca
	rrca
	and 7
	or 0A0h
	ld (hl),a		; byte 1: K high
	inc l
	inc l			; bytes 2/3 (J) are written per line
	inc l
	dec e
	jr nz,.k
	ret
.gray:	ld hl,linebuf		; Y = 31 / 0 alternating, J = K = 0
	rrca
	sbc a,a
	and 0F8h
.g:	ld (hl),a
	xor 0F8h
	inc l
	jr nz,.g
	ret
.pal:	ld hl,linebuf		; A=1: high nibble = palette color
.c:	ld a,l
	and 0F0h		; color = x/16 in the high nibble
	or 08h
	ld (hl),a
	inc l
	jr nz,.c
	ret
