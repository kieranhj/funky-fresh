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
	clc:lda v:adc dv:sta v				; +11 (11)
	lda v+1:adc dv+1:sta v+1			; +9 (20)

	\\ Row 1 screen start
	tax									; +2 (22)
	lda #13:sta &fe00					; +8 (30)
	lda fx_stretch_vram_table_LO, X		; +4 (34)
	sta &fe01							; +6 (40)
	lda #12:sta &fe00					; +8 (48)
	lda fx_stretch_vram_table_HI, X		; +4 (52)
	sta &fe01							; +6 (58)
	
	\\ Row 1 scanline
	lda #9:sta &fe00					; +8 (66)
	lda v+1:asl a:and #6				; +7 (73)
	\\ 2-bits * 2
	tax									; +2 (75)
	eor #&ff							; +2 (77)
	sec									; +2 (79)
	adc #13								; +2 (81)
	clc									; +2 (83)
	adc prev_scanline					; +3 (86)
	\\ R9 must be set before final scanline of the row.
	sta &fe01							; +6 (92)
	stx prev_scanline					; +3 (95)

	WAIT_CYCLES 21						; +21 (116)
	ldy #0								; +2 (118)

	\\ <=== HCC=118 (scanline=-2)

		FOR stripe,0,7,1
		lda vgc_freq_array+stripe, Y        ; +4
		ora #&80+(stripe*&10)               ; +2 column <= could factor out?
		sta &fe21                           ; +4
		NEXT
		\\ 8x +10							; +80 (70)

		\\ <== HCC=70 (scanline=odd) so that colour is set before final stripe displayed.

		\\ Set R0=101 (102c)
		stz &fe00							; +6 (76)
		lda #101:sta &fe01					; +8 (84)

		WAIT_CYCLES 10						; +10 (94)

		\\ At HCC=102 set R0=1.
		lda #1:sta &fe01					; +8 (102)
		\\ <=== HCC=102

		\\ Burn R0=1 scanlines.
		lda #15:sta grid_row_count			; +5 (107)
		clc									; +2 (109)
		ldx #4								; +2 (111)

		WAIT_CYCLES 9						; +9 (120)

		\\ At HCC=0 set R0=127
		lda #127:sta &fe01					; +8 (0)

	\\ <=== HCC=0 (scanline=0)

	stx &fe00								; +6 (6)
	stz &fe01								; +6 (12)

	\\ Now 2x scanlines per loop.
	.char_row_loop
	{
		\\ Update v
		lda v								; +3 (15)
		.*fx_stretch_grid_dv_LO
		adc #0:sta v						; +5 (20)
		lda v+1								; +3 (23)
		.*fx_stretch_grid_dv_HI
		adc #0:sta v+1						; +5 (28)

		\\ Row N+1 screen start
		tax									; +2 (30)
		lda #13:sta &fe00					; +8 (38)
		lda fx_stretch_vram_table_LO, X		; +4 (42)
		sta &fe01							; +6 (48)
		lda #12:sta &fe00					; +8 (56)
		lda fx_stretch_vram_table_HI, X		; +4 (60)
		sta &fe01							; +6 (66)
	
		\\ NB. Must set R9 before final scanline of the row!
		\\ Row N+1 scanline
		lda #9:sta &fe00					; +8 (74)
		lda v+1:asl a:and #6				; +7 (81)
		\\ 2-bits * 2
		tax									; +2 (83)
		eor #&ff							; +2 (85)
		sec									; +2 (87)
		adc #13								; +2 (89)
		clc									; +2 (91)
		adc prev_scanline					; +3 (94)
		sta &fe01							; +6 (100)
		stx prev_scanline					; +3 (103)

		lda grid_row_count					; +3 (106)
		cmp #1								; +2 (108)
		bne colour_path
		; 2c								; +2 (110)
		jmp set_black_palette				; +3 (113)
		.colour_path
		; 3c								; +3 (111)
		WAIT_CYCLES 7						; +7 (118)

		\\ <=== HCC=118 (scanline=even)

			FOR stripe,0,7,1
			lda vgc_freq_array+stripe, Y    ; +4
			ora #&80+(stripe*&10)           ; +2 column <= could factor out?
			sta &fe21                       ; +4
			NEXT
			\\ 8x +10						; +80 (70)
			.^return_from_black_palette

		    \\ <== HCC=70 (scanline=odd) so that colour is set before final stripe displayed.

			\\ Set R0=101 (102c)
			stz &fe00						; +6 (76)
			lda #101:sta &fe01				; +8 (84)

			WAIT_CYCLES 8					; +8 (92)
			clc								; +2 (94)

			\\ At HCC=102 set R0=1.
			lda #1:sta &fe01				; +8 (102)
			\\ <=== HCC=102

			\\ Burn R0=1 scanlines.

			\\ Increment freq_array index every 30 scanlines.
			{
				dec grid_row_count			; +5 (107)
				bne alt_path		; jump away and back.
											; +2 (109)
				tya:adc #8:tay				; +6 (115)
				lda #15						; +2 (117)
				sta grid_row_count  		; +3 (120)
			}
			.^return_from_alt_path

			\\ At HCC=0 set R0=127
			lda #127:sta &fe01				; +8 (0)

		\\ <=== HCC=0 (scanline=even)

		clc									; +2 (2)
		dec row_count						; +5 (7)
		beq scanline_last					; +2 (9)
		jmp char_row_loop					; +3 (12)
	}
	.scanline_last

	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00						; +8 (18)
	lda #36: sta &FE01						; +8 (26)

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00						; +8 (34)
	lda #17:sta &fe01						; +8 (42)

	\\ If prev_scanline=6 then R9=7
	\\ If prev_scanline=4 then R9=5
	\\ If prev_scanline=2 then R9=3
	\\ If prev_scanline=0 then R9=1
	{
		lda #9:sta &fe00					; +8 (50)
		clc									; +2 (52)
		lda #1								; +2 (54)
		adc prev_scanline					; +3 (57)
		sta &fe01							; +5 (62)
	}

	\\ Row 31
	WAIT_SCANLINES_ZERO_X 2					; +256 (62)

	\\ R9=1
	lda #9:sta &fe00						; +8 (70)
	lda #1:sta &fe01						; +8 (78)

	lda #0:sta prev_scanline				; +5 (83)
    rts										; +6 (89)

	.alt_path								; +3 (110)
	WAIT_CYCLES 7							; +7 (117)
	jmp return_from_alt_path				; +3 (120)

	.set_black_palette						;    (113)
    FOR stripe,0,7,1
    lda #&80+(stripe*&10)+PAL_black     	; +2
    sta &fe21                           	; +4
    NEXT
    \\ 8x +6								; +48 (33)
	WAIT_CYCLES 34							; +34 (67)
	jmp return_from_black_palette			; +3 (70)
}
