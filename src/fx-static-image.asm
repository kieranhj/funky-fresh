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
	rts
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
