\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	TASKS MODULE
\ ******************************************************************

.tasks_fn_table
{
	equw do_nothing						    ; &00
	equw task_decrunch_asset_to_main	    ; &01
	equw task_decrunch_asset_to_shadow  	; &02
    equw task_wipe_screens                  ; &03
}
TASK_ID_MAX = 4

.tasks_update
{
    \\ If there's already a task running try again when it's done.
    lda main_task_req
    bne try_shadow_task

    \\ Check if this is a new task.
	lda rocket_track_task_id+1
	ldx rocket_track_task_id+0
    cmp main_task_id
    bne new_main_task
    cpx main_task_data
    beq try_shadow_task

    .new_main_task
    IF _DEBUG
    cmp #TASK_ID_MAX            ; protect against live editing errors!
    bcs try_shadow_task
    ENDIF

    \\ Setup the task in the main thread.
	sta main_task_id
	stx main_task_data

    \\ Convert task data to int.
    jsr task_data_to_int
    stx main_task_load_A+1

    lda main_task_id
	asl a:tax
	lda tasks_fn_table+0, X
	sta main_task_jmp+1
	lda tasks_fn_table+1, X
	sta main_task_jmp+2

    ldy #0:sty main_task_load_Y+1

    inc main_task_req

    .try_shadow_task
    \\ If there's already a task running try again when it's done.
    lda shadow_task_req
    bne return

    \\ Check if this is a new task.
	lda rocket_track_task_data+1
	ldx rocket_track_task_data+0
    cmp shadow_task_id
    bne new_shadow_task
    cpx shadow_task_data
    beq return

    .new_shadow_task
    IF _DEBUG
    cmp #TASK_ID_MAX            ; protect against live editing errors!
    bcs return
    ENDIF

    \\ Setup the task in the main thread.
	sta shadow_task_id
	stx shadow_task_data

    \\ Convert task data to int.
    jsr task_data_to_int
    stx shadow_task_load_A+1

    lda shadow_task_id
	asl a:tax
	lda tasks_fn_table+0, X
	sta shadow_task_jmp+1
	lda tasks_fn_table+1, X
	sta shadow_task_jmp+2

    ldy #1:sty shadow_task_load_Y+1

    inc shadow_task_req

	.return
	rts
}

.task_decrunch_asset_to_main
{
    asl a:asl a:tax

    \\ Ensure MAIN RAM writeable.
    lda &fe34:and #&fb:sta &fe34
    
    .^task_decrunch_asset_X

    \\ Select SWRAM slot.
    lda assets_table+2, X
    sta &f4:sta &fe30

    \\ Decrunch asset to screen.
    ldy assets_table+1, X
    lda assets_table+0, X
    tax
    lda #HI(screen_addr)
    jmp decrunch_to_page_A

    \\ TODO: Save/restore SWRAM slot?
}

.task_decrunch_asset_to_shadow
{
    asl a:asl a:tax

    \\ Ensure SHADOW RAM is writeable.
    lda &fe34:ora #&4:sta &fe34

    jmp task_decrunch_asset_X
}

.task_wipe_screens
{
    \\ Ensure MAIN RAM writeable.
    lda &fe34:and #&fb:sta &fe34
    ldy #HI(screen_addr):ldx #HI(SCREEN_SIZE_BYTES)
    jsr clear_pages

    \\ Ensure SHADOW RAM is writeable.
    lda &fe34:ora #&4:sta &fe34
    ldy #HI(screen_addr):ldx #HI(SCREEN_SIZE_BYTES)
}
\\ Fall through!
; Y=to page, X=number of pages
.clear_pages
{
	sty write_to+2

	ldy #0
	lda #0
	.page_loop
	.write_to
	sta &ff00, Y
	iny
	bne page_loop
	inc write_to+2
	dex
	bne page_loop
	rts
}

\\ TODO: Could bake this at conversion time rather than linear search a table.
.task_data_to_int
{
    txa
    ldx #0
    .loop
    cmp task_data_float_to_int, X
    beq return
    inx
    bne loop
    .return
    rts
}

.task_data_float_to_int
FOR n,0,99,1
EQUB 256*n/100
NEXT
