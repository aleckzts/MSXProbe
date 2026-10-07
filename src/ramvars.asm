;==============================================================================
; ramvars.asm - RAM variables (page 3, from C000h)
;==============================================================================

; intro
v_y		ds 1		; logo vertical position (pixels)
v_r		ds 1		; character row being drawn
v_off		ds 1		; offset inside the logo column
v_grad		ds 2		; color gradient in use
v_fc		ds 1		; frame counter after the logo stops
v_blink		ds 1		; "press any key" state

; system (sysinfo.asm)
v_msxver	ds 1		; 0=MSX1 1=MSX2 2=MSX2+ 3=turbo R 4=?
v_vdp		ds 1		; 0=TMS99x8 1=V9938 2=V9958 3=?
v_vblk		ds 1		; VRAM size in 16KB blocks
v_cpu		ds 1		; 0=Z80 1=R800 ROM 2=R800 DRAM
v_slot_bios	ds 1		; slot IDs
v_slot_me	ds 1
v_slot_ram	ds 1
sys_l1		ds SYS_LEN + 1
sys_l2		ds SYS_LEN + 1

; string builder (text.asm)
v_rp		ds 2		; write pointer
v_rpend		ds 2		; limit

; menu
v_cur		ds 1		; test under the cursor
t_status	ds NTESTS	; ST_* per test
res_bufs	ds NTESTS * RES_SIZE

; tests
v_tstat		ds 1
v_tmp		ds 1
v_idx		ds 1
v_fmpac		ds 1
v_seed		ds 1
v_verr		ds 8		; VRAM error bits per 16KB block

; sound
v_sev		ds 2		; next jingle event
v_sfr		ds 1		; jingle frame
ch_state	ds 9		; 3 channels x (volume, counter, rate)

; SLOTS test
v_quiet		ds 1		; 1 = boot run (no screens)
v_cid		ds 1		; slot ID being classified
v_cpage		ds 1		; page being classified
v_hasab		ds 1		; slot has an "AB" ROM: no write probes
v_tmp2		ds 1
v_snp		ds 2		; snapshot of the page being classified
v_sid		ds 1		; snap: slot ID
v_spg		ds 1		; snap: page
v_stest		ds 1		; snap: 1 = RAM probe too
v_sbuf		ds 2		; snap: buffer
v_osec		ds 1		; snap: subslot register to restore
v_mapp		ds 2		; pointer into v_map
v_row		ds 1		; screen row
v_map		ds 16 * 4	; slot index x page -> T_* (FFh = no slot)

; SCREEN test
v_sn		ds 1		; modes available on this machine
v_scur		ds 1		; cursor in the mode list
scr_list	ds NSMODES	; mode index of each list item
scr_seen	ds NSMODES	; 1 = already shown
v_gen		ds 2		; bitmap line generator
v_bpl		ds 1		; bytes per line (0 = 256)
v_line		ds 1		; line being generated
v_yae		ds 1		; SCREEN 10 (1) or 12 (0)

	ALIGN 256
linebuf		ds 256		; one bitmap line (page aligned: index = L)
