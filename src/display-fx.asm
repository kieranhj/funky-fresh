\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	DISPLAY FX
\ ******************************************************************

\\ TODO: Support Display FX code in SWRAM banks.
.display_fx_table
{
	equw do_nothing,			            fx_default_crtc_draw,		SLOT_BANK2	; &00
	equw fx_vertical_stretch_update,	    fx_vertical_stretch_draw,	SLOT_BANK2	; &01
	equw fx_static_image_main_update,		fx_default_crtc_draw,		SLOT_BANK2  ; &02
	equw fx_static_image_shadow_update,		fx_default_crtc_draw,		SLOT_BANK2  ; &03
	equw fx_chunky_twister_update,			fx_chunky_twister_draw,		SLOT_BANK2	; &04
}
DISPLAY_FX_MAX = 5

.display_fx_update
{
	lda rocket_track_display_fx+1
	cmp display_fx
	beq return

	IF _DEBUG
	cmp #DISPLAY_FX_MAX		; protect against live editing errors!
	bcs return
	ENDIF

	\\ Set Display FX callbacks in IRQ.
	sta display_fx
	asl a:asl a
	clc
	adc display_fx:adc display_fx
	tax

	lda display_fx_table+0, X
	sta call_fx_update_fn+1
	lda display_fx_table+1, X
	sta call_fx_update_fn+2

	lda display_fx_table+2, X
	sta call_fx_draw_fn+1
	lda display_fx_table+3, X
	sta call_fx_draw_fn+2

	lda display_fx_table+4, X
	sta call_fx_update_slot+1
	sta call_fx_draw_slot+1

	.return
	rts
}

\ Arrive at VCC=0,HCC=0.
\ Assume horizontal registers are default but vertical registers
\ might be left in a ruptured state. Reset these to defaults.
.fx_default_crtc_draw
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
