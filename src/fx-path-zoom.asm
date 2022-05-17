\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	PATH ZOOMER FX
\ ******************************************************************

\\ TODO: Make sure this RAM is reserved properly.
FX_PATH_ZOOM_SCR_ADDR = &2D80

\\ NOTE THAT TILE SIZE IS HARD-CODED TO BE 64x64 TEXELS.

\\ Describe the track values used:
\\   rocket_track_anim  => frame no. [0-255]

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

.fx_path_zoom_update
{
	\\ TODO: Correctly determine the top line.
	\\ Set palette for first line.
	\\ Should really be in draw function?

	lda #0:sta temp

	lda rocket_track_y_pos+0
	sta v
	lda rocket_track_y_pos+1
	and #63
	sta v+1
	cmp #FRAK_SPRITE_HEIGHT
	bcc ok
	lda #FRAK_SPRITE_HEIGHT-1
	.ok

	\\ Hi byte of V * 16
	clc
	asl a:rol temp
	asl a:rol temp
	asl a:rol temp
	asl a:rol temp
	clc
	adc #LO(frak_data)
	sta pal_loop+1
	lda temp
	adc #HI(frak_data)
	sta pal_loop+2

	ldy #15						; 2c
	.pal_loop
	lda frak_data, y			; 4c
	sta &fe21					; 4c
	dey							; 2c
	bpl pal_loop				; 3c
	\\ 2+16*13-1=234c !!

	\\ TODO: Could be in draw function.

	\\ Set screen start address.
	lda #13:sta &fe00
	lda #LO(FX_PATH_ZOOM_SCR_ADDR/8):sta &fe01

	lda #12:sta &fe00
	lda #HI(FX_PATH_ZOOM_SCR_ADDR/8):sta &fe01

	\\ This FX always uses screen in MAIN RAM.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34		; 10c

	\\ Copy scanline data.
	ldx rocket_track_time+1		; every time!

	\\ DY comes from a static table.
	lda path_zoom_dy_table, X
	sta path_zoom_add_dv_LO+1

	lda path_zoom_scanline_addr_LO, X
	sta readptr+0
	lda path_zoom_scanline_addr_HI, X
	sta readptr+1
	jsr fx_path_zoom_copy

	lda #6:sta &fe00			; 8c
	lda #1:sta &fe01			; 8c
	lda #239:sta row_count		; 5c
	rts
}

\ ******************************************************************
\ Draw FX
\
\ The draw function is the main body of the FX.
\
\ This function will enter exactly at the start (i.e. HCC=0) of
\ rasterline -2, that is there are exactly two scanlines left before
\ the end of the 312 line PAL display. The 6845 registers will be such
\ that the Vertical Row Count is equal to the Vertical Total, i.e. the
\ CRTC cycle is ending. The current scanline is stored in prev_scanline
\ ZP variable and Scanlines per Row will be prev_scanline+1, i.e. two
\ scanlines remaining.
\
\ This setup allows for all the necessary preparation so that RVI can
\ be used to specify the exact scanline that appears on rasterline 0.
\
\ TODO: Some more explanation of entering this function.
\ 
\ On exit, this function must set up a valid 312 PAL display, with
\ vsync at the appropriate point for the framework, currently
\ rasterline 272 (character row 34). The value of the scanline
\ counter that will occur at rasterline 310 must be stored in the ZP
\ variable `prev_scanline` so that other FX functions can correctly
\ stablise the display for RVI. For the current framework this is
\ typically 6 for an 8 Scanlines per Row setup or 0 for 2 /row.
\
\ TODO: Update the above for new RTW RVI approach...
\
\ ******************************************************************

CODE_ALIGN 32

.fx_path_zoom_draw
{
	\\ <=== HCC=0 (scanline=-2)

	WAIT_SCANLINES_ZERO_X 1				; +128 (0)

	\\ <=== HCC=0 (scanline=-1)

	\\ Set one scanline per row.
	lda #9:sta &fe00					; +8 (8)
	lda #0:sta &fe01					; +8 (16)

	\\ Set one row per cycle.
	lda #4:sta &fe00					; +8 (24)
	lda #0:sta &fe01					; +8 (32)

	\\ ^--- these are ignored as it is the final scanline of the cycle.

	WAIT_SCANLINES_ZERO_X 1				; +128 (32)

	\\ <=== HCC=32 (scanline=0)
	\\ ^--- register values now take effect.

	.scanline_loop
	{
		\\ <=== HCC=32

		\\ Update texture v.
		clc						; +2 (34)
		lda v					; +3 (37)
		.*path_zoom_add_dv_LO
		adc #128				; +2 (39)
		sta v					; +3 (42)
		lda v+1					; +3 (45)
		.*path_zoom_add_dv_HI
		adc #0					; +2 (47)
		and #63					; +2 (49)
		sta v+1					; +3 (52)

		\\ NEXT: Store v AND 63 but clamp lookup to FRAK_SPRITE_HEIGHT.

		cmp #FRAK_SPRITE_HEIGHT	; +2 (54)

		bcc ok					; ----------+
		;						; +2 (56)	|
		lda #FRAK_SPRITE_HEIGHT-1; +2 (58)	|
		jmp store				; +3 (61)	|
		.ok						; 			V
		;						;		 +3 (57)
		WAIT_CYCLES 4			;		 +4 (61)

		.store
		tax						; +2 (63)
		lda frak_lines_LO, X	; +4 (67)
		sta set_palette+1		; +4 (71)
		lda frak_lines_HI, X	; +4 (75)
		sta set_palette+2		; +4 (79)

		.set_palette
		jsr frak_line0			; +60 (11)
		WAIT_CYCLES 13			; +13 (24)

		dec row_count			; +5 (29)
		bne scanline_loop		; +3 (32)
	}
	CHECK_SAME_PAGE_AS scanline_loop, TRUE
	.scanline_last

	\\ <=== HCC=31 (scanline=239) [last visible row]

	\\ Set 8 scanlines per row.
	lda #9:sta &fe00					; +7 (38)
	lda #7:sta &fe01					; +8 (46)
	\\ We know setting R9 on the final scanline is ignored until scanline 240.

	lda #6:sta &fe00					; +8 (54)
	lda #0:sta &fe01					; +8 (62)

	WAIT_SCANLINES_ZERO_X 1				; +128 (62)

	\\ <=== HCC=46 (scanline=240)

	\\ Currently at scanline 240, need 312 lines total.
	\\ Remaining scanlines = 72 = 9 rows * 8 scanlines.
	lda #4: sta &FE00					; +8 (70)
	lda #8: sta &FE01					; +8 (78)

	\\ R7 vsync at scanline 272 = 240 + 4*8
	lda #7:sta &fe00					; +8 (78)
	lda #4:sta &fe01					; +8 (86)

	lda #6:sta prev_scanline

	\\ FX responsible for resetting lower palette.
	jmp fx_static_image_set_default_palette
}

.fx_path_zoom_copy
{
	FOR n,0,31,1
	ldy #n*8:lda (readptr), Y				; 8c
	sta FX_PATH_ZOOM_SCR_ADDR + n*8			; 4c
	NEXT
	inc readptr+1							; 5c
	FOR n,0,31,1
	ldy #n*8:lda (readptr), Y				; 8c
	sta FX_PATH_ZOOM_SCR_ADDR + 32*8 + n*8	; 4c
	NEXT
	inc readptr+1							; 5c
	FOR n,0,15,1
	ldy #n*8:lda (readptr), Y				; 8c
	sta FX_PATH_ZOOM_SCR_ADDR + 64*8 + n*8	; 4c
	NEXT
	\\ 80*12=960c
	rts										; 6c
}

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN
.path_zoom_scanline_addr_LO
FOR n,0,255,1
EQUB LO(&3000+(n DIV 8)*640 + (n MOD 8))
NEXT

PAGE_ALIGN
.path_zoom_scanline_addr_HI
FOR n,0,255,1
EQUB HI(&3000+(n DIV 8)*640 + (n MOD 8))
NEXT

PAGE_ALIGN
.path_zoom_dy_table
INCBIN "data/raw/path-zoom-dy-table.bin"
\\ TODO: Could just compute this table from the path equation.
IF 0
FOR n,0,255,1
cz=-90-80*COS(2*PI*n/256)
dx=-cz/160
dy=128*dx
EQUB dy
NEXT
ENDIF
