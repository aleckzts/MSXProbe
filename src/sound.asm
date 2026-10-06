;==============================================================================
; sound.asm - Tiny PSG (AY-3-8910 / YM2149) effects driver
;
; Per-frame events: each event starts a note on a channel with an initial
; volume and a decay "rate" (frames per volume step).
; The driver is called once per frame (after HALT).
;==============================================================================

; PSG period: P = 1789773 / (16 * freq) = 111861 / freq
N_C5	equ 214
N_E5	equ 170
N_G5	equ 143
N_C6	equ 107
N_E6	equ 85
N_G6	equ 71
N_C7	equ 53

;------------------------------------------------------------------------------
; psg_w - write E to PSG register A (with interrupts disabled around it: the
; BIOS interrupt handler selects R14/R15 to read the joysticks)
;------------------------------------------------------------------------------
psg_w:
	di
	out (PSG_ADDR),a
	ld a,e
	out (PSG_WR),a
	ei
	ret

;------------------------------------------------------------------------------
; psg_init - mixer: tones A/B/C on, noise off.
; R7 bit7=1 (port B output) and bit6=0 (port A input) are MANDATORY on MSX
; (port A reads the joysticks, port B drives pins / Kana LED).
;------------------------------------------------------------------------------
PSG_MIXER equ 10111000b

psg_init:
	ld a,7
	ld e,PSG_MIXER
	call psg_w
	; fall through to psg_silence

; psg_silence - volume 0 on the 3 channels and reset the driver state
psg_silence:
	ld a,8
	ld e,0
	call psg_w
	ld a,9
	call psg_w
	ld a,10
	call psg_w
	ld hl,ch_state
	ld b,9
.clr:	ld (hl),0
	inc hl
	djnz .clr
	ld hl,snd_end
	ld (v_sev),hl
	ret

;------------------------------------------------------------------------------
; snd_start - start the intro jingle
;------------------------------------------------------------------------------
snd_start:
	call psg_silence
	ld hl,jingle
	ld (v_sev),hl
	xor a
	ld (v_sfr),a
	ret

;------------------------------------------------------------------------------
; snd_frame - process one frame. Returns Z when the sound is over.
;------------------------------------------------------------------------------
snd_frame:
	di
	ld hl,(v_sev)
.event:
	ld a,(hl)
	cp 0FFh
	jr z,.decay		; end of list
	ld b,a
	ld a,(v_sfr)
	cp b
	jr nz,.decay		; next event not due yet
	inc hl
	ld c,(hl)		; C = channel 0-2
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)		; DE = period
	ld a,c
	add a,a			; R0/R2/R4 = fine period
	out (PSG_ADDR),a
	ld b,a
	ld a,e
	out (PSG_WR),a
	ld a,b
	inc a			; R1/R3/R5 = coarse period
	out (PSG_ADDR),a
	ld a,d
	out (PSG_WR),a
	inc hl
	ld b,(hl)		; B = volume
	inc hl
	ld e,(hl)		; E = rate
	inc hl
	push hl
	ld a,c
	add a,a
	add a,c			; A = channel*3
	ld hl,ch_state		; channel state = ch_state + channel*3
	add a,l
	ld l,a
	jr nc,.nc
	inc h
.nc:	ld (hl),b		; current volume
	inc hl
	ld (hl),e		; decay counter
	inc hl
	ld (hl),e		; rate (counter reload)
	pop hl
	jr .event

.decay:
	ld (v_sev),hl
	ld ix,ch_state
	ld c,8			; channel A volume register
	ld d,0			; OR of all volumes (0 = silence)
.ch:	ld a,(ix+0)
	or a
	jr z,.wr
	dec (ix+1)
	jr nz,.wr
	ld a,(ix+2)
	ld (ix+1),a
	dec (ix+0)
.wr:	ld a,c
	out (PSG_ADDR),a
	ld a,(ix+0)
	out (PSG_WR),a
	or d
	ld d,a
	inc ix
	inc ix
	inc ix
	inc c
	ld a,c
	cp 11
	jr nz,.ch
	ld hl,v_sfr
	inc (hl)
	ei
	ld hl,(v_sev)
	ld a,(hl)
	inc a			; FFh -> 0: list is over
	jr z,.tail
	or 1			; events still pending: NZ
	ret
.tail:	ld a,d
	or a			; Z when every channel is silent
	ret

;------------------------------------------------------------------------------
; Intro jingle: rising G5-C6-E6-G6 arpeggio ending on a C7/C6/E6 chord with
; a long decay. Format: frame, channel, period, volume, rate
;------------------------------------------------------------------------------
jingle:
	db 0, 1 : dw N_C5 : db 12, 3
	db 0, 0 : dw N_G5 : db 15, 2
	db 3, 0 : dw N_C6 : db 15, 2
	db 6, 0 : dw N_E6 : db 15, 2
	db 9, 0 : dw N_G6 : db 15, 2
	db 12, 0 : dw N_C7 : db 15, 6
	db 12, 1 : dw N_C6 : db 13, 6
	db 12, 2 : dw N_E6 : db 12, 6
snd_end:
	db 0FFh

;------------------------------------------------------------------------------
; Channel check used by the SOUND test: C5 on A, E5 on B, G5 on C, one after
; the other, so you can hear each channel separately.
;------------------------------------------------------------------------------
chan_check:
	db 0, 0 : dw N_C5 : db 13, 2
	db 30, 1 : dw N_E5 : db 13, 2
	db 60, 2 : dw N_G5 : db 13, 2
	db 0FFh

; snd_play - play an event list at HL until it ends (blocking)
snd_play:
	push hl
	call psg_silence
	pop hl
	ld (v_sev),hl
	xor a
	ld (v_sfr),a
.wait:	halt
	call snd_frame
	jr nz,.wait
	ret
