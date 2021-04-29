\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	TASKS MODULE
\ ******************************************************************

.tasks_fn_table
{
	equw do_nothing						    ; &00
	equw task_decrunch_asset_to_main	    ; &01
	equw task_decrunch_asset_to_shadow  	; &02
}
TASK_ID_MAX = 3

.tasks_update
{
    \\ If there is already a task running we cannot start this frame.
    lda task_request
    bne return

    \\ Check if this is a new task.
	lda track_task_id
	ldx track_task_data
	cmp last_task_id
	bne start_new_task
	cpx last_task_data
	beq return

	.start_new_task
    IF _DEBUG
    cmp #TASK_ID_MAX            ; protect against live editing errors!
    bcs return
    ENDIF

    \\ Setup the task in the main thread.
	sta last_task_id
	stx last_task_data
    stx do_task_load_A+1

	asl a:tax
	lda tasks_fn_table+0, X
	sta do_task_jmp+1
	lda tasks_fn_table+1, X
	sta do_task_jmp+2

    inc task_request

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
