\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	DISPLAY FX
\ ******************************************************************

.display_fx_update
{
	lda track_display_fx
	cmp display_fx
	beq return

	sta display_fx
	asl a:asl a:tax

	lda display_fx_table+0, X
	sta call_fx_update_fn+1
	lda display_fx_table+1, X
	sta call_fx_update_fn+2

	lda display_fx_table+2, X
	sta call_fx_draw_fn+1
	lda display_fx_table+3, X
	sta call_fx_draw_fn+2

	.return
	rts
}

\ Arrive at VCC=0,HCC=0.
\ Assume horizontal registers are default but vertical registers
\ might be left in a ruptured state. Reset these to defaults.
.fx_default_crtc_draw
{
	lda #9:sta &fe00		; R9=7
	lda #7:sta &fe01

	lda #4:sta &fe00		; R4=38
	lda #38:sta &fe01

	lda #7:sta &fe00		; R7=35
	lda #35:sta &fe01

	lda #6:sta &fe00		; R6=32
	lda #32:sta &fe01
	rts
}

\\ TODO: Support Display FX code in SWRAM banks?
.display_fx_table
{
	equw do_nothing,			            fx_default_crtc_draw	    ; &00
	equw fx_vertical_stretch_update,	    fx_vertical_stretch_draw	; &01
	equw fx_static_image_display_main,		fx_default_crtc_draw	    ; &02
	equw fx_static_image_display_shadow,	fx_default_crtc_draw	    ; &03
}
