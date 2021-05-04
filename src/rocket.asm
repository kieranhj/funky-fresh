\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	ROCKET SYNC MODULE
\ ******************************************************************

IF _DEBUG
.rocket_update_music
{
	lda rocket_audio_flag
	cmp music_enabled
	beq return

	cmp #0:beq pause

	lda task_request
	bne task_running

	\\ This takes a long time so can't be done in IRQ.
	\\ Options:
	\\ - run this as a background task?
	\\ - restart the demo and play from the beginning?!
	ldx rocket_vsync_count:stx do_task_load_X+1
	ldy rocket_vsync_count+1:sty do_task_load_Y+1
	lda #LO(rocket_set_pos):sta do_task_jmp+1
	lda #HI(rocket_set_pos):sta do_task_jmp+2
	inc task_request

	.task_running
	lda #&ff:sta rocket_fast_mode	; turbo mode on!

	.return
	rts

	.pause
	sta music_enabled
	\\ Kill sound.
	jmp MUSIC_JUMP_SN_RESET
}

.rocket_set_pos
{
	\\ Play from new position.
	MUSIC_JUMP_VGM_SEEK				; sloooow.
	lda #0:sta rocket_fast_mode		; turbo mode off!
	lda #1:sta music_enabled
	rts
}
ENDIF

IF _DEBUG = FALSE
MACRO ROCKET_DATA_PTR_INC a
{
	clc
	lda rocket_data_ptr
	adc #a
	sta rocket_data_ptr
	bcc no_carry
	inc rocket_data_ptr+1
	.no_carry
}
ENDMACRO

.rocket_init
{
	stx rocket_data_ptr
	sty rocket_data_ptr+1

	\\ Get time of first key.
	ldy #0:lda (rocket_data_ptr), Y
	sta rocket_next_key
	iny:lda (rocket_data_ptr), Y
	sta rocket_next_key+1
	ROCKET_DATA_PTR_INC 2

	\\ Zero all values.
	ldx #ROCKET_MAX_TRACKS*2-2
	lda #0
	.loop
	sta rocket_zp_start+0, X
	sta rocket_zp_start+1, X
	sta rocket_track_deltas+0, X
	sta rocket_track_deltas+1, X
	dex:dex
	bpl loop
	rts
}

.rocket_update_keys
{
	\\ Update key values.
	lda rocket_vsync_count+1
	cmp rocket_next_key+1
	bcc same_key
	lda rocket_vsync_count+0
	cmp rocket_next_key+0
	bcc same_key

	\\ vsync count >= next key frame.
	.read_next_track
	\\   Read track#.
	ldy #0
	lda (rocket_data_ptr), Y		; track#
	bpl key_type_linear
	\\   Until no more tracks.
	cmp #&ff
	beq done_key

	\\ Key type STEP
	and #&7f:asl a:tax
	\\   Read track value.
	iny:lda (rocket_data_ptr), Y
	sta rocket_zp_start+0, X		; track X value LO
	iny:lda (rocket_data_ptr), Y
	sta rocket_zp_start+1, X		; track X value HI
	\\   Read track delta (or 0).
	lda #0
	sta rocket_track_deltas+0, X	; track X delta LO
	sta rocket_track_deltas+1, X	; track X delta HI
	ROCKET_DATA_PTR_INC 3
	jmp read_next_track

	.key_type_linear
	asl a:tax
	\\   Read track value.
	iny:lda (rocket_data_ptr), Y
	sta rocket_zp_start+0, X		; track X value LO
	iny:lda (rocket_data_ptr), Y
	sta rocket_zp_start+1, X		; track X value HI
	\\   Read track delta (or 0).
	iny:lda (rocket_data_ptr), Y
	sta rocket_track_deltas+0, X	; track X delta LO
	iny:lda (rocket_data_ptr), Y
	sta rocket_track_deltas+1, X	; track X delta HI
	ROCKET_DATA_PTR_INC 5
	jmp read_next_track

	.done_key
	iny:lda (rocket_data_ptr), Y
	sta rocket_next_key
	iny:lda (rocket_data_ptr), Y
	sta rocket_next_key+1
	ROCKET_DATA_PTR_INC 3			; include &ff

	.same_key
	rts
}

.rocket_update_tracks
{
	\\ Interpolate track values.
	ldx #ROCKET_MAX_TRACKS*2-2
	.interp_loop
	clc								; 2c
	lda rocket_zp_start+0, X		; 4c
	adc rocket_track_deltas+0, X	; 4c
	sta rocket_zp_start+0, X		; 4c
	lda rocket_zp_start+1, X		; 4c
	adc rocket_track_deltas+1, X	; 4c
	sta rocket_zp_start+1, X		; 4c
	dex:dex							; 4c
	bpl interp_loop					; 3c
	\\ 33c per track
	\\ Assume 8x tracks = 264c ~= 2 scanlines.
	\\ Could be unrolled to 26c per track.
	rts
}

.rocket_next_key        skip 2

.rocket_track_deltas
skip ROCKET_MAX_TRACKS*2

ELSE
.rocket_update_tracks
{
	\\ Approximate the interpolation cost in _DEBUG.
	WAIT_CYCLES ROCKET_MAX_TRACKS * 33
	rts
}
ENDIF
