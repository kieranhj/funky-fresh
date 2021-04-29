\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	CYCLE COUNTING HELPER FUNCTIONS
\ ******************************************************************

.cycles_wait_128		; JSR to get here takes 6c
{
	WAIT_CYCLES 128-6-6
	RTS					; 6c
}						; = 128c

.cycles_wait_scanlines	; 6c
{
	WAIT_CYCLES 128-6-2-3-6
	.loop
	dex					; 2c
	beq done			; 2/3c
	WAIT_CYCLES 121
	jmp loop			; 3c
	.done
	RTS					; 6c
}
