\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	FRAK ZOOMER FX
\ ******************************************************************

FRAK_SPRITE_HEIGHT=44

\\ TODO: Describe the FX and requirements.
\\ Describe the track values used:

\ ******************************************************************
\ Update FX
\
\ The update function is used to update / tick any variables used
\ in the FX. It may also prepare part of the screen buffer before
\ drawing commenses but note the strict timing constraints!
\
\ This function will be called during vblank, after any system
\ modules have been polled.
\
\ The function MUST COMPLETE BEFORE TIMER 1 REACHES 0, i.e. before
\ raster line 0 begins. If you are late then the draw function will
\ be late and your raster timings will be wrong!
\ ******************************************************************

.fx_frak_zoomer_update
{
	\\ Want centre of screen to be centre of sprite.
	lda #0:sta v
	lda #FRAK_SPRITE_HEIGHT/2:sta v+1

	\\ Scanline 0,2,4,6 from zoom.
	lda rocket_track_zoom+1				; 3c
	sta zoom
	tax
	and #3:eor #3:asl a					; 6c
	sta next_scanline

	\\ Set dv.
	lda fx_zoom_dv_table, X
	sta fx_zoom_add_dv+1

	\\ Subtract dv 128 times to set starting v.
	\\ v = centre - y_pos * dv
	ldy rocket_track_y_pos+1
	beq done_sub_loop
	.sub_loop
	sec
	lda v
	sbc fx_zoom_dv_table, X
	sta v
	lda v+1
	sbc #0
	sta v+1

	\\ Wrap sprite height.
	bpl sub_ok
	clc
	adc #FRAK_SPRITE_HEIGHT
	sta v+1

	.sub_ok
	dey
	bne sub_loop
	.done_sub_loop

	\\ Hi byte of V * 16
	clc
	lda #0:sta temp
	lda v+1
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

	\\ Set palette for first line.
	ldy #15						; 2c
	.pal_loop
	lda frak_data, y			; 4c
	sta &fe21					; 4c
	dey							; 2c
	bpl pal_loop				; 3c
	\\ 2+16*13-1=234c !!
	\\ lda (frakptr), Y:sta &fe21:iny ; 11c
	\\ 16*11=176c hmmmm.

	lda #6:sta &fe00			; 8c
	lda #1:sta &fe01			; 8c

	lda #119:sta row_count		; 5c
	rts
}

\ ******************************************************************
\ Draw FX
\
\ The draw function is the main body of the FX.
\
\ This function will be exactly at the start* of raster line 0 with
\ a stablised raster. VC=0 HC=0|1 SC=0
\
\ This means that a new CRTC cycle has just started! If you didn't
\ specify the registers from the previous frame then they will be
\ the default MODE 0,1,2 values as per initialisation.
\
\ If messing with CRTC registers, THIS FUNCTION MUST ALWAYS PRODUCE
\ A FULL AND VALID 312 line PAL signal before exiting!
\ ******************************************************************

\\ Double-line RVI with no LHS blanking.
\\ Display 0,2,4,6 scanline as first row from any other.
\\ NB. Can't hide LHS garbage but don't need to as scanline -1!
\\  Set R9 before final scanline to 13 + current - next. eg. R9 = 13 + 0 - 0 = 13
\\
\\ cycles -->  94   96   98   100  102  104  106  108  110  112  114  116  118  120  122  124  126  0
\\             lda..sta............WAIT_CYCLES 18 ..............................lda..sta ...........|
\\             #1   &fe01                                                       #127 &fe01
\\ scanline 1            ^         2    3    4    5    6    7    8    9    10   11   12   13   xx   0
\\                       hpos                                                                  |
\\                                                         --> missed due to end of CRTC cycle +
\\ NB. There is no additional scanline if this is not the end of the CRTC cycle.

\\ Repeated double-line RVI with LHS blanking.
\\ Display 0,2,4,6 scanline as repeated row.
\\  Set R9 before final scanline to 9 + current - next = 9 constant.
\\
\\ cycles -->  96   98   100  102  104  106  108  110  112  114  116  118  120  122  124  126  0
\\             lda..sta............WAIT_CYCLES 10 ..........lda..stz ...........sta ...........|
\\             #1   &fe01                                   #127 &fe01          &fe01
\\ scanline 7       ^              8    9    x    0    1    2    3    4    5    ?    ?    ?    6
\\                  hpos                     |                                  |
\\       --> missed due to end of CRTC cycle +                                  + scanline counter prevented from updating whilst R0=0!

CODE_ALIGN 32

.fx_frak_zoomer_draw
{
	\\ <=== HCC=0 (scanline=-2)

	\\ R9 must be set before final scanline of the row.
	lda #9:sta &fe00					; 8c

	\\ Set R9=13+current-next.
	lda #13								; 2c
	clc									; 2c
	adc prev_scanline					; 3c
	sec									; 2c
	sbc next_scanline					; 3c
	sta &fe01							; 6c

	ldx next_scanline					; 3c
	stx prev_scanline					; 3c
	\\ 24c

	\\ Set screen address for zoom.
	lda zoom							; 3c
	\\ 64 zooms, 2 scanlines each = 4 per char row.
	lsr a:lsr a:tax						; 6c
	lda #13:sta &fe00					; 8c <= 7c
	lda fx_zoom_vram_table_LO, X		; 4c
	clc									; 2c
	adc rocket_track_x_pos+1			; 3c
	sta &fe01							; 6c <= 5c
	lda #12:sta &fe00					; 8c
	lda fx_zoom_vram_table_HI, X		; 4c
	adc #0								; 2c
	sta &fe01							; 6c
	\\ 50c

	\\ This FX always uses screen in MAIN RAM.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34		; 10c

	WAIT_CYCLES 36

		\\ <=== HCC=0 (scanline=-1)

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 78

		\\ <=== HCC=94 (scanline=-1)

		lda #1:sta &fe01					; 8c
		\\ <=== HCC=102 (scanline=-1)

		\\ Burn R0=1 scanlines.
		WAIT_CYCLES 14
		ldx #4								; 2c
		ldy #9								; 2c

		\\ At HCC=0 set R0=127.
		lda #127:sta &fe01					; 8c

	\\ <=== HCC=0 (scanline=0)

	\\ Set R4=0 (one row per cycle).
	stx &fe00								; 6c
	stz &fe01								; 6c	

	\\ 2x scanlines per row.
	.scanline_loop
	{
		\\ <=== HCC=12 (scanline=even)

		\\ Update texture v.
		clc						; 2c
		lda v					; 3c
		.*fx_zoom_add_dv
		adc #128				; 2c
		sta v					; 3c
		lda v+1					; 3c
		adc #0					; 2c

		cmp #FRAK_SPRITE_HEIGHT	; 2c
		bcc ok
		; 2c
		sbc #FRAK_SPRITE_HEIGHT	; 2c
		jmp store				; 3c
		.ok
		; 3c
		WAIT_CYCLES 4
		.store
		sta v+1					; 3c
		\\ 27c

		tax						; 2c
		lda frak_lines_LO, X	; 4c
		sta set_palette+1		; 4c
		lda frak_lines_HI, X	; 4c
		sta set_palette+2		; 4c
		\\ 18c

		\\ Set R9=9 constant.
		sty &fe00				; 6c <= 5c
		sty &fe01				; 6c

		\\ <=== HCC=68 (scanline=even)
		.set_palette
		jsr frak_line0			; 60c

			\\ <=== HCC=0 (scanline=odd)

			lda #0:sta &fe00		; 8c
			lda #103:sta &fe01		; 8c

			WAIT_CYCLES 80

			lda #1:sta &fe01		; 8c
			\\ <=== HCC=104

			WAIT_CYCLES 10

			lda #127				; 2c
			stz &fe01				; 6c
			sta &fe01				; 6c

		\\ <=== HCC=0 (scanline=even)

		WAIT_CYCLES 4

		dec row_count			; 5c
		bne scanline_loop		; 3c
	}
	CHECK_SAME_PAGE_AS scanline_loop, TRUE
	.scanline_last

	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00
	lda #36: sta &FE01

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00
	lda #17:sta &fe01

	\\ Need to recover back to correct scanline count.
	lda #9:sta &fe00
	clc
	lda prev_scanline
	adc #1
	sta &fe01

	\\ Wait for scanline 240.
	WAIT_SCANLINES_ZERO_X 2

	\\ R9=1
	lda #9:sta &fe00
	lda #1:sta &fe01

	lda #0:sta prev_scanline

	\\ FX responsible for resetting lower palette.
	ldx #LO(fx_static_image_default_palette)
	ldy #HI(fx_static_image_default_palette)
	jmp fx_static_image_set_palette
}

include "build/frak-lines.asm"

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN_FOR_SIZE 16
.fx_zoom_vram_table_LO
FOR n,15,0,-1
EQUB LO((&3000 + (n)*1280)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 16
.fx_zoom_vram_table_HI
FOR n,15,0,-1
EQUB HI((&3000 + (n)*1280)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 64
.fx_zoom_dv_table
FOR n,63,0,-1
; u=128*d/80
; d=1+n*(79/31))
PRINT 2 / ((1 + n*79/63) / 80)
EQUB 255 * (1 + n*79/63) / 80		; 128
NEXT

.frak_data
INCBIN "build/frak-sprite.bin"
