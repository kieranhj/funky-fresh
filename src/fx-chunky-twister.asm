\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	CHUNKY TWISTER FX
\ ******************************************************************

\\ TODO: Describe the FX and requirements.

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

.fx_chunky_twister_update
{
	dec xi:dec xi
	lda xi:sta xy

	clc
	lda ta:adc #6:sta ta					\ a=4096/600~=6
	lda ta+1:adc #0:and #15:sta ta+1		\ 4096 byte table
	lda ta:sta yb:lda ta+1:sta yb+1

	jsr fx_chunky_twister_calc_rot
	jsr fx_chunky_twister_set_rot
	sty &fe34

	lda #0:sta prev_scanline
	jsr fx_chunky_twister_calc_rot
	sta temp
	RTS
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

\\ Limited RVI
\\ Display 0,2,4,6 scanline offset for 2 scanlines.
\\ <--- 102c total w/ 80c visible and hsync at 98c ---> <2c> ..13x <2c> = 128c
\\ Plus one extra for luck!
\\ R9 = 13 + current - next

\\ xm = cos((t/80)-y+20*sin(t/20000+a/(120+20*sin(t/100+y/500))))*16

.fx_chunky_twister_draw
{
    WAIT_CYCLES 14      ; Original raster-fx code started 14c into the frame.

	\\ R4=0, R7=&ff, R6=1, R9=3
	lda #4:sta &fe00
	lda #0:sta &fe01

	\\ vsync at row 35 = scanline 280.
	lda #7:sta &fe00
	lda #13:sta &fe01

	lda #6:sta &fe00
	lda #1:sta &fe01

	lda #9:sta &fe00
	lda #1:sta &fe01

	lda #126:sta row_count
	\\ 52c

	\\ Row 0
	lda temp							; 3c
	\\ 2-bits * 2
	and #3:asl a						; 4c
	tax									; 2c
	eor #&ff							; 2c
	clc									; 2c
	adc #13								; 2c
	adc prev_scanline						; 3c
	sta &fe01							; 6c
	stx prev_scanline						; 3c
	\\ 24c

	\\ Sets R12,R13 + SHADOW
	lda temp							; 3c
	jsr fx_chunky_twister_set_rot							; 79c
	; sets Y to shadow bit.

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c <= 7c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 16

		\\ At HCC=102 set R0=1.
		.blah
		lda #1:sta &fe01					; 8c

		\\ Burn 13 scanlines = 13x2c = 26c
		lda #127							; 2c
		sty &fe34							; 3c
		ldx #&40 + PAL_black				; 2c
		stx &fe21							; 4c
		ldx #&40 + PAL_blue					; 2c
		WAIT_CYCLES 6
		\\ At HCC=0 set R0=127
		sta &fe01							; 6c
		\\ <== start of new scanline here
		stx &fe21							; 4c
		WAIT_CYCLES 10

	\\ Want to get to:
	\\ a = SIN(t * a + y * b)
	\\ PICO-8 example: a = COS(t/300 + y/2000)

	\\ Rows 1-30
	.char_row_loop
	{
		lda #9:sta &fe00					; 8c

		jsr fx_chunky_twister_calc_rot						; 52c
		sta temp							; 3c

		\\ 2-bits * 2
		and #3:asl a						; 4c
		tay									; 2c
		eor #&ff							; 2c
		clc									; 2c
		adc #13								; 2c
		adc prev_scanline						; 3c
		sta &fe01							; 6c
		sty prev_scanline						; 3c
		\\ 24c

		\\ Sets R12,R13 + SHADOW
		lda temp							; 3c
		jsr fx_chunky_twister_set_rot							; 79c
		; sets Y to shadow bit.

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c <= 7c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 24

		\\ At HCC=102 set R0=1.
		.here
		lda #1:sta &fe01					; 8c

		\\ Burn 13 scanlines = 13x2c = 26c
		lda #127							; 2c
		sty &fe34							; 4c
		ldx #&40 + PAL_black				; 2c
		stx &fe21							; 4c
		ldx #&40 + PAL_blue					; 2c
		WAIT_CYCLES 6
		\\ At HCC=0 set R0=127
		sta &fe01							; 6c
		\\ <== start of new scanline here
		stx &fe21							; 4c

		DEC row_count						; 5c
		BEQ done							; 2c
		JMP char_row_loop					; 3c
		.done
	}
    CHECK_SAME_PAGE_AS char_row_loop

	\\ Total 312 line - 256 = 56 scanlines
	LDA #4: STA &FE00
	LDA #28: STA &FE01

	\\ If prev_scanline=6 then R9=7
	\\ If prev_scanline=4 then R9=5
	\\ If prev_scanline=2 then R9=3
	\\ If prev_scanline=0 then R9=1
	{
		lda #9:sta &fe00
		clc
		lda #1
		adc prev_scanline
		sta &fe01
	}

	\\ Row 31
	ldx #2:jsr cycles_wait_scanlines

	\\ R9=3
	lda #9:sta &fe00
	lda #1:sta &fe01

    RTS
}

.fx_chunky_twister_calc_rot							; 6c
{
	inc xy							; 5c

	\ 4096/4000~=1
	clc:lda yb:adc #1:sta yb		; 10c
	lda yb+1:adc #0:and #15:sta yb+1	; 10c
	clc:adc #HI(cos):sta load+2		; 8c
	ldy yb							; 3c
	.load
	lda cos,Y						; 4c
	rts								; 6c
}
\\ 52c

.fx_chunky_twister_set_rot							; 6c
{
	; 0-127
	AND #&7F						; 2c
	lsr a:lsr a:tay					; 6c

	LDA #13: STA &FE00				; 8c
	ldx xy							; 3c
	lda x_wibble, X					; 4c
	sta temp						; 3c
	lsr a							; 2c
	clc								; 2c
	adc twister_vram_table_LO, Y	; 4c
	STA &FE01						; 6c <= 5c

	LDA #12: STA &FE00				; 8c
	LDA twister_vram_table_HI, Y	; 4c
	adc #0							; 2c
	STA &FE01						; 6c

	lda temp						; 3c
	and #1							; 2c
	tay								; 2c
	rts								; 6c
}
\\ 79c

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN_FOR_SIZE 32
.twister_vram_table_LO
FOR n,0,31,1
EQUB LO((&3000 + n*640)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 32
.twister_vram_table_HI
FOR n,0,31,1
EQUB HI((&3000 + n*640)/8)
NEXT

PAGE_ALIGN
.x_wibble
FOR n,0,255,1
EQUB 54+40*SIN(2 * PI *n / 256) 
NEXT

\ Notes
\ Having a 12-bit COSINE table means that the smallest increment in
\ the input (1) results in <= 1 angle output.
PAGE_ALIGN
.cos
FOR n,0,4095,1
EQUB 255*COS(2*PI*n/4096)
NEXT
