\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	CYCLE COUNTING HELPER FUNCTIONS
\ ******************************************************************

IF 0
.cycles_wait_128		; JSR to get here takes 6c
{
	WAIT_CYCLES 128-6-6
	RTS					; 6c
}						; = 128c
ENDIF

.cycles_wait_scanlines				; 6c
	WAIT_CYCLES 2					; 2c
.cycles_wait_scanlines_minus_2c		; [6c]
	WAIT_CYCLES 18					; 18c
.cycles_wait_scanlines_minus_20c	; [6c]
{
	WAIT_CYCLES 128-6-2-3-6-20		; 91c
	.loop
	dex					; 2c
	beq done			; 2/3c
	WAIT_CYCLES 121
	jmp loop			; 3c
	.done
	RTS					; 6c
}
