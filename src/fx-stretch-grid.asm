\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	VERTICAL STRETCH ON TOP OF FREQUENCY GRID FX
\ ******************************************************************

\\ TODO: Describe the FX and requirements.
\\ Describe the track values used:
\\   rocket_track_zoom  => zoom factor               [0-63]  <- 1x to 10x height
\\   rocket_track_y_pos => y position of middle line [0-127] <- middle of screen is 63

\ ******************************************************************
\ Update FX
\
\ The update function is used to update / tick any variables used
\ in the FX. It may also prepare part of the screen buffer before
\ drawing commences but note the strict timing constraints!
\
\ This function will be called during vblank, after any system
\ modules have been polled.
\
\ The function MUST COMPLETE BEFORE TIMER 1 REACHES 0, i.e. before
\ raster line 0 begins. If you are late then the draw function will
\ be late and your raster timings will be wrong!
\ ******************************************************************

.fx_stretch_grid_update
{
	\\ Hope there's enough time for all this!!

	jsr fx_vertical_stretch_update

	lda dv:sta fx_stretch_grid_dv_LO+1
	lda dv+1:sta fx_stretch_grid_dv_HI+1

	jmp fx_frequency_update_grid
}

\\ TODO: Make this comment correct for this framework!
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
\\ Plus one extra for luck! (i.e. we wait for 13 but C9 counts 14 in total.)
\\ R9 = 13 + current - next
\\
\\  Assumes R4=0, i.e. one row per CRTC cycle.
\\  Scanline 0 has normal R0 width 128c.
\\  Must set R9 before final scanline to 13 + current - next. eg. R9 = 13 + 0 - 2 = 11
\\  Set scanline 1 to have width 102c.
\\  At 102c set R0 width to 2c and skip remaining 26c.
\\  At 0c reset R0 width to 128c.
\\
\\ Select CRTC register 0, i.e. lda #0:sta &fe00
\\
\\ cycles -->  94  96  98  100  102  104  106  108  110  112  114  116  118  120  122  124  126  0
\\             lda.sta..........WAIT_CYCLES 18 ..............................lda..sta ...........|
\\             #1  &fe01                                                     #127 &fe01
\\ scanline 1                   2    3    4    5    6    7    8    9    10   11   xx   0    1    2
\\                                                                                |
\\                                            --> missed due to end of CRTC frame +
\\
\\ NB. There is no additional scanline if this is not the end of the CRTC frame.

.fx_stretch_grid_draw
{
	\\ <=== HCC=0 (scanline=-2)

	\\ Update v 		<-- could be done in update.
	clc:lda v:adc dv:sta v				; 11c
	lda v+1:adc dv+1:sta v+1			; 9c
	\\ 20c

	\\ Row 1 screen start
	tax							; 2c
	lda #13:sta &fe00					; 8c
	lda vram_table_LO, X				; 4c
	sta &fe01							; 6c
	lda #12:sta &fe00					; 8c
	lda vram_table_HI, X				; 4c
	sta &fe01							; 6c
	\\ 40c
	
	\\ Row 1 scanline
	lda #9:sta &fe00					; 8c
	lda v+1:asl a:and #6						; 7c
	\\ 2-bits * 2
	tax									; 2c
	eor #&ff							; 2c
	sec									; 2c
	adc #13								; 2c
	clc									; 2c
	adc prev_scanline					; 3c
	\\ R9 must be set before final scanline of the row.
	sta &fe01							; 6c
	stx prev_scanline					; 3c
	\\ 35c

	WAIT_CYCLES 21
	ldy #0								; 2c

	\\ <=== HCC=118 (scanline=-2)

		FOR stripe,0,7,1
		lda vgc_freq_array+stripe, Y        ; 4c
		ora #&80+(stripe*&10)               ; 2c column <= could factor out?
		sta &fe21                           ; 4c
		NEXT
		\\ 10c * 8 = 80c

		\\ <== HCC=70 (scanline=odd) so that colour is set before final stripe displayed.

		\\ Set R0=101 (102c)
		stz &fe00							; 6c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 10

		\\ At HCC=102 set R0=1.
		lda #1:sta &fe01					; 8c
		\\ <=== HCC=102

		\\ Burn R0=1 scanlines.
		lda #15:sta grid_row_count			; 5c
		clc									; 2c
		ldx #4								; 2c

		WAIT_CYCLES 9

		\\ At HCC=0 set R0=127
		lda #127:sta &fe01					; 8c

	\\ <=== HCC=0 (scanline=0)

	stx &fe00								; 6c
	stz &fe01								; 6c

	\\ Now 2x scanlines per loop.
	.char_row_loop
	{
		\\ Update v
		lda v
		.*fx_stretch_grid_dv_LO
		adc #0:sta v				; 8c
		lda v+1
		.*fx_stretch_grid_dv_HI
		adc #0:sta v+1				; 8c
		\\ 16c

		\\ Row N+1 screen start
		tax								; 2c
		lda #13:sta &fe00				; 8c
		lda vram_table_LO, X			; 4c
		sta &fe01						; 6c
		lda #12:sta &fe00				; 8c
		lda vram_table_HI, X			; 4c
		sta &fe01						; 6c
		\\ 38c
	
		\\ NB. Must set R9 before final scanline of the row!
		\\ Row N+1 scanline
		lda #9:sta &fe00				; 8c
		lda v+1:asl a:and #6			; 7c
		\\ 2-bits * 2
		tax								; 2c
		eor #&ff						; 2c
		sec								; 2c
		adc #13							; 2c
		clc								; 2c
		adc prev_scanline				; 3c
		sta &fe01						; 6c
		stx prev_scanline				; 3c
		\\ 37c

		;WAIT_CYCLES 15					; jump to black bar version here - oof!
		lda grid_row_count				; 3c
		cmp #1							; 2c
		bne colour_path
		; 2c
		jmp set_black_palette			; 3c
		.colour_path
		; 3c
		WAIT_CYCLES 7
		\\ 15c

		\\ <=== HCC=118 (scanline=even)

			FOR stripe,0,7,1
			lda vgc_freq_array+stripe, Y        ; 4c
			ora #&80+(stripe*&10)               ; 2c column <= could factor out?
			sta &fe21                           ; 4c
			NEXT
			\\ 10c * 8 = 80c
			.^return_from_black_palette

		    \\ <== HCC=70 (scanline=odd) so that colour is set before final stripe displayed.

			\\ Set R0=101 (102c)
			stz &fe00						; 6c
			lda #101:sta &fe01				; 8c

			WAIT_CYCLES 8
			clc								; 2c

			\\ At HCC=102 set R0=1.
			lda #1:sta &fe01				; 8c
			\\ <=== HCC=102

			\\ Burn R0=1 scanlines.

			\\ Increment freq_array index every 30 scanlines.
			{
				dec grid_row_count	; 5c
				bne alt_path		; jump away and back.
									; 2c
				tya:adc #8:tay		; 6c
				lda #15				; 2c
				sta grid_row_count  ; 3c
				\\ 18c
			}
			.^return_from_alt_path

			\\ At HCC=0 set R0=127
			lda #127:sta &fe01				; 8c

		\\ <=== HCC=0 (scanline=even)

		clc							; 2c
		dec row_count				; 5c
		beq scanline_last			; 2c
		jmp char_row_loop			; 3c
	}
	CHECK_SAME_PAGE_AS char_row_loop, FALSE
	.scanline_last

	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00
	lda #36: sta &FE01

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00
	lda #17:sta &fe01

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
	WAIT_SCANLINES_ZERO_X 2

	\\ R9=1
	lda #9:sta &fe00
	lda #1:sta &fe01

	lda #0:sta prev_scanline
    rts

	.alt_path					; 8c
	WAIT_CYCLES 7
	jmp return_from_alt_path	; 3c
	\\ 18c

	.set_black_palette					; 10c
    FOR stripe,0,7,1
    lda #&80+(stripe*&10)+PAL_black     ; 2c
    sta &fe21                           ; 4c
    NEXT
    \\ 6c * 8 = 48c

	WAIT_CYCLES 34
	jmp return_from_black_palette		; 3c
	\\ 95c
}
