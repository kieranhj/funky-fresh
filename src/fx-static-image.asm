\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	STATIC IMAGE FX
\ ******************************************************************

.fx_static_image_main_update
{
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34
	; Set R12/R13 for full screen.
	lda #12:sta &fe00
	lda #HI(screen_addr/8):sta &fe01
	lda #13:sta &fe00
	lda #LO(screen_addr):sta &fe01
	rts
}

.fx_static_image_shadow_update
{
	; set bit 1 to display SHADOW.
	lda &fe34:ora #1:sta &fe34
	; Set R12/R13 for full screen.
	lda #12:sta &fe00
	lda #HI(screen_addr/8):sta &fe01
	lda #13:sta &fe00
	lda #LO(screen_addr):sta &fe01
	rts
}
