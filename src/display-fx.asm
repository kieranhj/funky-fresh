\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	DISPLAY FX
\ ******************************************************************

\\ TODO: Support Display FX code in SWRAM banks.
.display_fx_table
{
	equw do_nothing,			            fx_static_image_draw,		SLOT_BANK2	; &00
	equw fx_static_image_main_update,		fx_static_image_draw,		SLOT_BANK2  ; &01
	equw fx_static_image_shadow_update,		fx_static_image_draw,		SLOT_BANK2  ; &02
	equw fx_vertical_stretch_update,	    fx_vertical_stretch_draw,	SLOT_BANK2	; &03
	equw fx_chunky_twister_update,			fx_chunky_twister_draw,		SLOT_BANK2	; &04
	equw fx_frequency_update,				fx_frequency_draw,			SLOT_BANK2	; &05
	equw fx_stretch_grid_update,	   		fx_stretch_grid_draw,		SLOT_BANK2	; &06
	equw fx_frak_zoomer_update,	   			fx_frak_zoomer_draw,		SLOT_BANK2	; &07
	equw fx_checker_zoom_update,	   		fx_checker_zoom_draw,		SLOT_BANK2	; &08
	equw fx_palette_wipe_update,   			fx_static_image_draw,		SLOT_BANK2	; &09
    ; v---------------------------------------------------------------------------- ; update DISPLAY_FX_MAX!
}
DISPLAY_FX_MAX = 10

.display_fx_update
{
	stz display_fx_init

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

	lda #&ff:sta display_fx_init

	.return
	rts
}
