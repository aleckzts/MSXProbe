;==============================================================================
; msx.inc - BIOS entry points, system variables and I/O ports
; References: MSX2 Technical Handbook, MSX Datapack, msx.org wiki
;==============================================================================

;--- Main BIOS (page 0) --------------------------------------------------------
CGTABL	equ 0004h	; (word) pointer to the character font in ROM
VDP_DR	equ 0006h	; VDP base READ port (normally 98h)
VDP_DW	equ 0007h	; VDP base WRITE port (normally 98h)
IDBYT0	equ 002Bh	; b0-3 charset, b4-6 date format, b7 0=60Hz 1=50Hz
IDBYT1	equ 002Ch	; b0-3 keyboard, b4-7 PRINT USING
MSXVER	equ 002Dh	; 0=MSX1 1=MSX2 2=MSX2+ 3=MSX turbo R
RDSLT	equ 000Ch	; read byte from slot   (A=slot, HL=addr) -> A
WRSLT	equ 0014h	; write byte to slot    (A=slot, HL=addr, E=value)
ENASLT	equ 0024h	; select slot in a page (A=slot, H=page<<6)
DISSCR	equ 0041h	; display off
ENASCR	equ 0044h	; display on
WRTVDP	equ 0047h	; write VDP register (C=reg, B=value)
CHGMOD	equ 005Fh	; change screen mode (A=mode; MSX2: 0-8)
SETWRT	equ 0053h	; set VRAM write address (HL)
CHGCLR	equ 0062h	; apply FORCLR/BAKCLR/BDRCLR
INITXT	equ 006Ch	; SCREEN 0
INIT32	equ 006Fh	; SCREEN 1
INIGRP	equ 0072h	; SCREEN 2
INIMLT	equ 0075h	; SCREEN 3
CHSNS	equ 009Ch	; key in buffer? (Z = no)
CHGET	equ 009Fh	; wait for a key
CHPUT	equ 00A2h	; print a character
POSIT	equ 00C6h	; move cursor (H=column, L=row, 1-based)
ERAFNK	equ 00CCh	; hide function key display
SNSMAT	equ 0141h	; read keyboard matrix row A -> A (bit 0 = pressed)
KILBUF	equ 0156h	; clear keyboard buffer
EXTROM	equ 015Fh	; (MSX2+) call SUB-ROM routine at IX
GETCPU	equ 0183h	; (turbo R) current CPU mode -> A

;--- SUB-ROM (MSX2 and later, via EXTROM) ----------------------------------------
INIPLT	equ 0141h	; reset the palette to defaults

;--- System variables (page 3) ---------------------------------------------------
LINL40	equ 0F3AEh	; SCREEN 0 width
TXTNAM	equ 0F3B3h	; SCREEN 0 name table address
T32NAM	equ 0F3BDh	; SCREEN 1 name table address
MLTCGP	equ 0F3D5h	; SCREEN 3 pattern table address
CLIKSW	equ 0F3DBh	; key click (0=off)
FORCLR	equ 0F3E9h	; foreground color
BAKCLR	equ 0F3EAh	; background color
BDRCLR	equ 0F3EBh	; border color
MODE	equ 0FAFCh	; (MSX2) b1-2 VRAM size: 0=16K 1=64K 2=128K
HIMEM	equ 0FC4Ah	; top of free RAM
JIFFY	equ 0FC9Eh	; interrupt counter (word)
CSRSW	equ 0FCA9h	; cursor display switch
EXPTBL	equ 0FCC1h	; [0]=BIOS slot ID, [1..3] b7=slot is expanded
SLTTBL	equ 0FCC5h	; BIOS copy of the subslot registers

;--- I/O ports -------------------------------------------------------------------
VDP_DATA equ 98h	; VRAM data
VDP_CTRL equ 99h	; registers / address / status
PSG_ADDR equ 0A0h	; PSG AY-3-8910: register select
PSG_WR	equ 0A1h	; PSG: write data
PSG_RD	equ 0A2h	; PSG: read data
PPI_A	equ 0A8h	; PPI port A: primary slot of each page

;--- Keys returned by CHGET ------------------------------------------------------
K_UP	equ 1Eh
K_DOWN	equ 1Fh
K_ENTER	equ 0Dh
K_ESC	equ 1Bh
K_SPACE	equ 20h
