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
	\\ Set screen address for zoom.
	lda rocket_track_zoom+1
	lsr a:lsr a		; 64 zooms, 2 scanlines each = 4 per row
	tax
	lda #13:sta &fe00
	lda fx_zoom_vram_table_LO, X
	clc
	adc rocket_track_x_pos
	sta &fe01
	lda #12:sta &fe00
	lda fx_zoom_vram_table_HI, X
	adc #0
	sta &fe01

	\\ Scanline 0,2,4,6
	lda rocket_track_zoom+1
	and #3
	eor #3
	asl a
	sta prev_scanline

	\\ Want centre of screen to be centre of sprite.
	lda #0:sta v
	lda #FRAK_SPRITE_HEIGHT/2:sta v+1

	\\ Set dv.
	ldx rocket_track_zoom+1
	lda fx_zoom_dv_table, X
	sta add_dv+1

	\\ Subtract dv 128 times to set starting v.
	ldy #64
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
	ldx #15
	.pal_loop
	lda frak_data, X
	sta &fe21
	dex
	bpl pal_loop

	\\ This FX always uses screen in MAIN RAM.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34
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

\\ To repeat just one scanline, need to burn 6 scanlines.
\\ 6x4c = 24c hsync at 98,
\\ <-- 104 cycles w/ 80 visible hsync at 98 --> <4c> <4c> ... <4c>
\\ Need R0=4 at HCC=104
\\ Need R0=100 at HCC=0

CODE_ALIGN 16

.fx_frak_zoomer_draw
{
	\\ <=== HCC=0 (scanline=-2)

	WAIT_SCANLINES_ZERO_X 2

	\\ <=== HCC=0 (scanline=0)

	WAIT_CYCLES 14

	\\ R4=0, R7=&ff, R6=1
	lda #4:sta &fe00			; 8c
	lda #0:sta &fe01			; 8c

	\\ vsync at row 35 = scanline 280.
	lda #7:sta &fe00			; 8c
	lda #3:sta &fe01			; 8c

	lda #6:sta &fe00			; 8c
	lda #1:sta &fe01			; 8c

	lda #126:sta row_count		; 5c

	WAIT_CYCLES 61

		\\ <=== HCC=0
		.scanline_1_hcc0
		lda #0:sta &fe00		; 8c
		lda #101:sta &fe01		; 8c

		\\ Need to set correct scanline here.
		\\ 0=>0 R9=13 burn 12
		\\ 0=>2 R9=11 burn 12
		\\ 0=>4 R9=9 burn 12
		\\ 0=>6 R9=7 burn 12

		lda #9:sta &fe00		; 8c
		sec						; 2c
		lda #13					; 2c
		sbc prev_scanline		; 3c
		sta &fe01				; 6c <== 5c
		lda #0:sta &fe00		; 8c

		WAIT_CYCLES 50
		
		\\ R0=1 <2c> x13
		lda #1:sta &fe01		; 8c
		\\ <=== HCC=102

		WAIT_CYCLES 18
		lda #127:sta &fe01		; 8c <== 7c
		\\ <=== HCC=0

		WAIT_CYCLES 16
		jmp scanline_even_hcc0	; 3c

	\\ Now 2x scanlines per loop.
	.scanline_loop
	{
		WAIT_CYCLES 11

		.^scanline_even_hcc0
		clc						; 2c
		lda v					; 3c
		.*add_dv
		adc #128				; 2c
		sta v					; 3c
		lda v+1					; 3c
		adc #0					; 2c

		cmp #FRAK_SPRITE_HEIGHT		; 2c
		bcc ok
		; 2c
		sbc #FRAK_SPRITE_HEIGHT		; 2c
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

		WAIT_CYCLES 4

		\\ Ideally call at HCC=68
		.set_palette
		jsr frak_line0			; 60c

		.*scanline_odd_hcc_0
		\\ <=== HCC=0
		lda #0:sta &fe00		; 8c
		lda #103:sta &fe01		; 8c

		lda #9:sta &fe00		; 8c
		lda #7:sta &fe01		; 8c
		lda #0:sta &fe00		; 8c	

		WAIT_CYCLES 56

		lda #3:sta &fe01		; 8c
		\\ <=== HCC=104

		WAIT_CYCLES 16
		lda #127:sta &fe01		; 8c
		\\ <=== HCC=0

		dec row_count			; 5c
		bne scanline_loop		; 3c
	}
	CHECK_SAME_PAGE_AS scanline_loop, FALSE
	.scanline_last

	\\ Need to recover back to correct scanline count.
	lda #9:sta &fe00
	clc
	lda prev_scanline
	adc #1
	sta &fe01

	lda #6:sta &fe00			; 8c
	lda #0:sta &fe01			; 8c

	WAIT_SCANLINES_ZERO_X 2

	\\ R9=7
	.scanline_end_of_screen
	lda #9:sta &fe00
	lda #7:sta &fe01

	\\ Total 312 line - 256 = 56 scanlines
	lda #4: sta &FE00
	lda #6: sta &FE01
    rts
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
