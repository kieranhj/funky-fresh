\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	STATIC IMAGE FX
\ ******************************************************************

static_image_scrn_addr = screen_addr + 640

.fx_static_image_main_update
{
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34
	; Set R12/R13 for full screen.
	lda #12:sta &fe00
	lda #HI(static_image_scrn_addr/8):sta &fe01
	lda #13:sta &fe00
	lda #LO(static_image_scrn_addr/8):sta &fe01

	ldx #LO(fx_static_image_default_palette)
	ldy #HI(fx_static_image_default_palette)
	jmp fx_static_image_set_palette
}

.fx_static_image_shadow_update
{
	; set bit 1 to display SHADOW.
	lda &fe34:ora #1:sta &fe34
	; Set R12/R13 for full screen.
	lda #12:sta &fe00
	lda #HI(static_image_scrn_addr/8):sta &fe01
	lda #13:sta &fe00
	lda #LO(static_image_scrn_addr/8):sta &fe01

	ldx #LO(fx_static_image_default_palette)
	ldy #HI(fx_static_image_default_palette)
	jmp fx_static_image_set_palette
}

.fx_static_image_set_palette
{
    stx pal_loop+1
    sty pal_loop+2

	ldx #15
	.pal_loop
	lda fx_static_image_default_palette, X
	sta &fe21
	dex
	bpl pal_loop
	rts
}

\ Arrive at VCC=0,HCC=0.
\ Assume horizontal registers are default but vertical registers
\ might be left in a ruptured state. Reset these to defaults.
.fx_static_image_draw
{
	WAIT_SCANLINES_ZERO_X 2

	\\ <=== HCC=0

	lda #9:sta &fe00
	lda #7:sta &fe01		; R9=8 scanlines per row (default).

	lda #4:sta &fe00
	lda #38:sta &fe01		; R4=312 total lines.

	lda #7:sta &fe00
	lda #34:sta &fe01		; R7=vsync at line 272.

	lda #6:sta &fe00
	sta prev_scanline		; at scanline -2.
	lda #30:sta &fe01		; R6=240 visible lines.
	rts
}

.fx_static_image_default_palette
{
	EQUB &00 + PAL_black
	EQUB &10 + PAL_red
	EQUB &20 + PAL_green
	EQUB &30 + PAL_yellow
	EQUB &40 + PAL_blue
	EQUB &50 + PAL_magenta
	EQUB &60 + PAL_cyan
	EQUB &70 + PAL_white
	EQUB &80 + PAL_black
	EQUB &90 + PAL_red
	EQUB &A0 + PAL_green
	EQUB &B0 + PAL_yellow
	EQUB &C0 + PAL_blue
	EQUB &D0 + PAL_magenta
	EQUB &E0 + PAL_cyan
	EQUB &F0 + PAL_white
}
