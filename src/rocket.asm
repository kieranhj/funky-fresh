\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	ROCKET SYNC MODULE
\ ******************************************************************

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

	.return
	rts

	.pause
	sta music_enabled
	\\ Kill sound.
	jmp MUSIC_JUMP_SN_RESET
}

IF _DEBUG
.rocket_set_pos
{
	\\ Play from new position.
	lda #&ff:sta rocket_fast_mode	; turbo mode on!
	MUSIC_JUMP_VGM_SEEK				; sloooow.
	lda #0:sta rocket_fast_mode		; turbo mode off!
	lda #1:sta music_enabled
	rts
}
ENDIF
