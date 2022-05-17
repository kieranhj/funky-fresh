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

	lda #15:sta grid_row_count

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

;     disable            enable hsync=101
;        v                 v       v
;  +-----------------------+ R1=86 
;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
; |                                    
; | next scanline 0: R0=115 R9=1                        | 0   1   X   0   1   X   (0...)
; | next scanline 2: R0=113 R9=3                    | 0   1   2   3   X   0   1   (2...)
; | next scanline 4: R0=119 R9=5                                | 0   1   2   3   (4...)
; | next scanline 6: R0=115 R9=7                        | 0   1   2   3   4   5   (6...)
;
; Set R9 in final scanline as _don't_ want it to take effect until next cycle/char row.

.fx_stretch_grid_draw
{
	\\ <=== HCC=0 (scanline=-2)

	\\ Row 0 screen start
	ldx v+1								; +3 (3)
	lda #13:sta &fe00					; +7 (10)
	lda fx_stretch_vram_table_LO, X		; +4 (14)
	sta &fe01							; +6 (20)
	lda #12:sta &fe00					; +8 (28)
	lda fx_stretch_vram_table_HI, X		; +4 (32)
	sta &fe01							; +6 (38)

	ldy #0								; +2 (40)
	FOR stripe,0,7,1
	lda vgc_freq_array+stripe, Y        ; +4
	ora #&80+(stripe*&10)               ; +2 column <= could factor out?
	sta &fe21                           ; +4
	NEXT
	\\ 8x +10							; +80 (120)

	WAIT_CYCLES 8						; +8 (0)

		\\ <=== HCC=0 (scanline=-1)
		lda #4:sta &fe00				; +8 (8)
		lda #0:sta &fe01				; +8 (16)
		txa:and #3:tax					; +6 (22)
		inc row_count					; +5 (27)
		WAIT_CYCLES 8					; +8 (35)
		jmp right_in_there				; +3 (38)

	\\ Now 2x scanlines per loop.
	.char_row_loop
	{
		\\ <== HCC=19 (even)

		\\ Update v
		lda v								; +3 (22)
		.*fx_stretch_grid_dv_LO
		adc #0:sta v						; +5 (27)
		lda v+1								; +3 (30)
		.*fx_stretch_grid_dv_HI
		adc #0:sta v+1						; +5 (35)

		\\ Row N+1 screen start
		tax									; +2 (37)
		lda #13:sta &fe00					; +7 (44)
		lda fx_stretch_vram_table_LO, X		; +4 (48)
		sta &fe01							; +6 (54)
		lda #12:sta &fe00					; +8 (62)
		lda fx_stretch_vram_table_HI, X		; +4 (66)
		sta &fe01							; +6 (72)
	
		txa:and #3:tax						; +6 (78)

		\\ Set palette at end of line.

		lda grid_row_count					; +3 (81)
		cmp #1								; +2 (83)
		bne colour_path
		; 2c								; +2 (85)
		jmp set_black_palette				; +3 (88)
		.colour_path
		; 3c								; +3 (86)

		FOR stripe,0,7,1
		lda vgc_freq_array+stripe, Y    	; +4
		ora #&80+(stripe*&10)           	; +2 column <= could factor out?
		sta &fe21                       	; +4
		NEXT
		\\ 8x +10							; +80 (38)
		.^return_from_black_palette

			.^right_in_there				;    (38)

		    \\ <== HCC=38 (scanline=odd) so that colour is set before final stripe displayed.

			; Set R9 for the next line.
			lda #9: sta &fe00				; +8 (46)
			txa:asl a						; +4 (50)
			sta prev_scanline				; +3 (53)
			ora #1							; +2 (55)
			sta &fe01						; +5 (60)
			\\ R9 must be set in final scanline of the row for this scheme.

			lda jmptab, X:sta jmpinstruc+1	; +8 (68)

			\\ Increment freq_array index every 30 scanlines.
			{
				dec grid_row_count			; +5 (73)
				bne alt_path		; jump away and back.
											; +2 (75)
				tya:adc #8:tay				; +6 (81)
				lda #15						; +2 (83)
				sta grid_row_count  		; +3 (86)
			}
			.^return_from_alt_path

			ldx #1							; +2 (88)
			stz &fe00						; +6 (94)
			WAIT_CYCLES 4					; +4 (98)

			.jmpinstruc JMP scanline0		; +3 (101)
			.^jmpreturn						;    (122)

			sta &fe01						; +6 (128)

		\\ <=== HCC=0 (even)

		WAIT_CYCLES 7						; +7 (7)

		clc									; +2 (9)
		dec row_count						; +5 (14)
		beq scanline_last					; +2 (16)
		jmp char_row_loop					; +3 (19)
	}
	.scanline_last

	\\ <=== HCC=17 (even) [last visible char row.]

	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00						; +7 (24)
	lda #36: sta &FE01						; +8 (32)

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00						; +8 (40)
	lda #17:sta &fe01						; +8 (48)

	WAIT_CYCLES 80							; +80 (0)

		\\ We're in the final visible scanline of the screen.
		\\ <=== HCC=0 (odd)
		WAIT_SCANLINES_ZERO_X 1				; +128 (0)

	\\ <=== HCC=0 (off screen)
	WAIT_CYCLES 7							; +7 (7)

	\\ Set R9=1 so all remaining char rows are 2 scanlines each.
	lda #9:sta &fe00						; +7 (14)
	lda #1:sta &fe01						; +8 (22)

	lda #0:sta prev_scanline				; +5 (27)
    rts

	.alt_path								; +3 (76)
	WAIT_CYCLES 7							; +7 (83)
	jmp return_from_alt_path				; +3 (86)

	.set_black_palette						;    (88)
    FOR stripe,0,7,1
    lda #&80+(stripe*&10)+PAL_black     	; +2
    sta &fe21                           	; +4
    NEXT
    \\ 8x +6								; +48 (8)
	WAIT_CYCLES 27							; +27 (35)
	jmp return_from_black_palette			; +3 (38)

ALIGN 4
.jmptab
	EQUB LO(scanline0)
	EQUB LO(scanline2)
	EQUB LO(scanline4)
	EQUB LO(scanline6)

	;-------------------------------------------------------
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 0: R0=127 R9=1                        						| (0...)
	.scanline0							;    (101)
	LDA #127:STA &FE01					; +7 (108)
	WAIT_CYCLES 11						; +11 (119)
	JMP jmpreturn						; +3 (122)
	
	;-------------------------------------------------------
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 6: R0=115 R9=7                        | 0   1   2   3   4   5   (6...)
	.scanline6							;    (101)
	LDA #115:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	STX &FE01							; +6 (116)
	WAIT_CYCLES 3						; +3 (119)
	JMP jmpreturn						; +3 (122)
	
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 2: R0=119 R9=3 R0=3                           | 0   0   1   1   (2...)
	.scanline2							;    (101)
	LDA #119:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	INX:INX								; +4 (114)
	STX &FE01							; +6 (120)
	JMP jmpreturn						; +3 (123)
	
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 4: R0=119 R9=5                                | 0   1   2   3   (4...)
	.scanline4							;    (101)
CHECK_SAME_PAGE_AS scanline0, TRUE
	LDA #119:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	WAIT_CYCLES 4						; +4 (114)
	STX &FE01							; +6 (120)
	JMP jmpreturn						; +3 (123)

	;-------------------------------------------------------	
}
