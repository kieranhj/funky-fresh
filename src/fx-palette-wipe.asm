\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	PALETTE WIPES
\ ******************************************************************

\\ Describe the track values used:
\\   rocket_track_zoom  => speed of wipe (frames per colour change).
\\   rocket_track_x_pos  => from colour (used as trigger).
\\   rocket_track_y_pos  => to colour (not cached).

\ ******************************************************************
\ Update FX
\
\ This function will be called after the display period, after the
\ music player has been polled, the Rocket tracks have been updated,
\ and the task system polled. This function is guaranteed to be
\ called before the corresponding draw function for the FX.
\
\ The function MUST COMPLETE BEFORE TIMER 1 REACHES 0, i.e. before
\ rasterline -2 begins, this is required so that the following FX
\ draw function has time to set up RVI for the beginning of the
\ display. If you are late then a BRK will be issued in DEBUG mode.
\ ******************************************************************

.fx_palette_wipe_update
{
	\\ This FX always uses whatever screen was last displayed.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.

	lda display_fx_init
	beq not_init

	\\ Reset trigger on init.
	lda #&ff:sta wipe_from

	\\ Change of source colour used as trigger.
	.not_init
	lda rocket_track_x_pos+1
	cmp wipe_from
	beq do_wipe
	sta wipe_from

	\\ New wipe triggered.
	jsr fx_palette_wipe_init_new_wipe

	.do_wipe
	\\ Has the wipe finished?
	ldx wipe_index
	cpx #16
	bcs done_wipe

	\\ Animation speed.
	dec wipe_counter
	bne fx_palette_wipe_rts
	jsr fx_palette_wipe_reset_counter

	\\ Update next palette entry.
	lda fx_palette_wipe_palette, X
	and #&f0
	ora rocket_track_y_pos+1
	eor #7
	sta fx_palette_wipe_palette, X
	inx
	stx wipe_index
	.done_wipe
}
\\ Fall through!
.fx_palette_wipe_init_set_all
{
	\\ Set the palette.
	ldx #15
	.pal_loop
	lda fx_palette_wipe_palette, X
	sta &fe21
	dex
	bpl pal_loop
}
.fx_palette_wipe_rts
	rts

\\ Assumes displaying a static image for simplicity.

.fx_palette_wipe_init_new_wipe
{
	\\ Set initial palette state.
	ldx #0
	stx wipe_index

	\\ Set the from colours.
	lda rocket_track_x_pos+1
	eor #7
	.loop
	sta fx_palette_wipe_palette, X
	clc
	adc #&10
	inx
	cpx #16
	bcc loop

	\\ Set the starting palette.
	jsr fx_palette_wipe_init_set_all
}
\\ Fall through!
.fx_palette_wipe_reset_counter
{
\\ TODO: Could use data byte from display_fx if neater.
	lda rocket_track_zoom+1
	bne ok
	lda #1
	.ok
	sta wipe_counter
	rts
}

.fx_palette_wipe_palette
SKIP 16

\\ TODO: Ability to set direction of the wipe animation.
\\ TODO: Ability to set different colour ramps for the wipe effect.
\\ TODO: Ability to specify 8 or 16 colour wipes.
\\ TODO: More interesting wipes (vertical blinds etc.)
