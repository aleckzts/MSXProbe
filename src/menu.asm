;==============================================================================
; menu.asm - Main screen: boot info + test menu with results
;
;  row  0  MSX PROBE 0.2            Hardware Diagnostics
;  row  1  ----------------------------------------
;  rows 2-3  system info (sys_l1, sys_l2)
;  row  4  ----------------------------------------
;  row  5    TEST     RESULT
;  rows 6+ > SLOTS     0:BIOS 1:PROBE ...  (one line per test)
;  row 22  ----------------------------------------
;  row 23  Up/Down:select ENTER:run ESC:intro
;
; ENTER runs the test under the cursor, stores its one-line result, redraws
; everything and moves the cursor to the next test not run yet. Results stay
; on screen. Tests may destroy the screen (VRAM, SCREEN): we always redraw.
;
; Test contract: called with the string builder already pointing at the
; test's result buffer (out_str, out_dec...), returns A = status (ST_*).
; Routine 0 = not written yet: shows s_soon and ENTER is ignored on it.
;==============================================================================

ST_NONE	equ 0			; not run yet
ST_OK	equ 1
ST_FAIL	equ 2
ST_INFO	equ 3			; ran, shows information only
ST_NA	equ 4			; not available

ROW_MENU equ 6
COL_NAME equ 2
COL_RES	 equ 11
RES_LEN	 equ 28			; COL_RES + RES_LEN = 39: never touch column 40
RES_SIZE equ 32			; bytes per result buffer

; name, routine (0 = not available yet)
tests:
	dw s_t_slots,	test_slots	; fast and read-only: also runs at boot
	dw s_t_ram,	0
	dw s_t_vram,	test_vram
	dw s_t_sound,	test_sound
	dw s_t_screen,	test_screen
	dw s_t_rtc,	0
	dw s_t_net,	0
NTESTS	equ ($ - tests) / 4

;------------------------------------------------------------------------------
; menu_reset - every test back to "not tested", then run the quick boot
; tests (SLOTS, entry 0) so the main screen already shows their results and
; the cursor starts on the next test.
;------------------------------------------------------------------------------
menu_reset:
	xor a
.st:	push af
	call test_routine	; HL = routine, Z if 0
	ld e,ST_NONE
	jr nz,.set
	pop af			; not available: status NA + message
	push af
	call res_buf
	ex de,hl
	ld hl,s_soon
	ld bc,RES_LEN
	ldir
	ld e,ST_NA
.set:	pop af
	push af
	ld hl,t_status
	call add_hl_a
	ld (hl),e
	pop af
	inc a
	cp NTESTS
	jr c,.st
	xor a
	ld (v_cur),a
	inc a
	ld (v_quiet),a		; boot run: no screens, results only
	call test_exec
	xor a
	ld (v_quiet),a
	ret

;------------------------------------------------------------------------------
; menu - main screen loop. Returns on ESC (back to the intro).
;------------------------------------------------------------------------------
menu:
	call txt_init
	call menu_draw
.loop:
	call menu_marks
.key:	call get_key
	cp K_UP
	jr z,.up
	cp K_DOWN
	jr z,.down
	cp K_ENTER
	jr z,.run
	cp K_SPACE
	jr z,.run
	cp K_ESC
	ret z
	jr .key
.up:	ld a,(v_cur)
	or a
	jr nz,.u1
	ld a,NTESTS
.u1:	dec a
	ld (v_cur),a
	jr .loop
.down:	ld a,(v_cur)
	inc a
	cp NTESTS
	jr c,.d1
	xor a
.d1:	ld (v_cur),a
	jr .loop
.run:	ld a,(v_cur)
	call test_routine
	jr z,.key		; not available: ignore ENTER
	call menu_run
	jr menu

;------------------------------------------------------------------------------
; menu_run - run the test under the cursor, then pick the next untested one
;------------------------------------------------------------------------------
menu_run:
	; "Running..." in the result column
	ld a,(v_cur)
	add a,ROW_MENU
	ld d,a
	ld e,COL_RES
	call locate
	ld hl,s_running
	ld b,RES_LEN
	call print_pad
	; fall through to test_exec

;------------------------------------------------------------------------------
; test_exec - run test (v_cur) into its result buffer, store the status and
; move the cursor to the next test not run yet. No screen output.
;------------------------------------------------------------------------------
test_exec:
	; result buffer -> string builder
	ld a,(v_cur)
	call res_buf
	ld b,RES_LEN
	call out_begin

	; call the test routine
	ld a,(v_cur)
	call test_routine
	call jp_hl

	; store the status (never leave it as ST_NONE)
	or a
	jr nz,.st
	ld a,ST_INFO
.st:	ld e,a
	ld a,(v_cur)
	ld hl,t_status
	call add_hl_a
	ld (hl),e

	; leave things in a known state
	call psg_silence
	ei

	; next test not run yet (wrapping); stay put if all were run
	ld a,(v_cur)
	ld c,NTESTS
.next:	inc a
	cp NTESTS
	jr c,.n1
	xor a
.n1:	ld e,a
	ld hl,t_status
	call add_hl_a
	ld a,(hl)
	or a
	ld a,e
	jr z,.found
	dec c
	jr nz,.next
	ret
.found:	ld (v_cur),a
	ret

jp_hl:	jp (hl)

;------------------------------------------------------------------------------
; menu_draw - full redraw of the main screen
;------------------------------------------------------------------------------
menu_draw:
	ld de,(0 << 8) + 1
	ld hl,s_title
	call print_at
	ld de,(0 << 8) + 19
	ld hl,s_title_r
	call print_at

	ld d,1
	call sep_line
	ld de,(2 << 8) + 1
	ld hl,sys_l1
	call print_at
	ld de,(3 << 8) + 1
	ld hl,sys_l2
	call print_at
	ld d,4
	call sep_line

	ld de,(5 << 8) + COL_NAME
	ld hl,s_hdr_test
	call print_at
	ld de,(5 << 8) + COL_RES
	ld hl,s_hdr_res
	call print_at

	xor a
.items:	push af
	call menu_item
	pop af
	inc a
	cp NTESTS
	jr c,.items

	ld d,22
	call sep_line
	ld de,(23 << 8) + 1
	ld hl,s_footer
	jp print_at

sep_line:
	ld a,'-'
	ld b,40
	jp print_line

;------------------------------------------------------------------------------
; menu_item - draw test A: name + result
;------------------------------------------------------------------------------
menu_item:
	ld c,a
	add a,ROW_MENU
	ld d,a
	ld e,COL_NAME
	call locate
	ld a,c
	call test_entry
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld b,COL_RES - COL_NAME
	call print_pad
	; result, or "-" when not run
	ld a,c
	ld hl,t_status
	call add_hl_a
	ld a,(hl)
	or a
	ld hl,s_not_tested
	jr z,.res
	ld a,c
	call res_buf
.res:	ld b,RES_LEN
	jp print_pad

;------------------------------------------------------------------------------
; menu_marks - cursor marker '>' in column 0
;------------------------------------------------------------------------------
menu_marks:
	ld c,0
.l:	ld a,c
	add a,ROW_MENU
	ld d,a
	ld e,0
	call locate
	ld a,(v_cur)
	cp c
	ld a,'>'
	jr z,.put
	ld a,' '
.put:	call CHPUT
	inc c
	ld a,c
	cp NTESTS
	jr c,.l
	ret

;------------------------------------------------------------------------------
; Small helpers
;------------------------------------------------------------------------------
; test_entry - A = test number -> HL = its entry in "tests"
test_entry:
	add a,a
	add a,a
	ld hl,tests
	jr add_hl_a

; test_routine - A = test number -> HL = its routine, Z if there is none
test_routine:
	call test_entry
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	or h
	ret

; res_buf - A = test number -> HL = its result buffer
res_buf:
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl		; *32
	ld de,res_bufs
	add hl,de
	ret

; add_hl_a - HL += A
add_hl_a:
	add a,l
	ld l,a
	ret nc
	inc h
	ret
