\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	ZOOMING CHECKERBOARD
\ ******************************************************************

FX_CHECKER_ZOOM_MAX = 32

FX_CHECKER_ZOOM_COLOUR_3 = PAL_blue
FX_CHECKER_ZOOM_COLOUR_2 = PAL_cyan
FX_CHECKER_ZOOM_COLOUR_1 = PAL_yellow

\\ Describe the track values used:
\\   rocket_track_zoom  => depth of top layer  [0-31]

\ ******************************************************************
\ Update FX
\
\ Typically FX are driven by Rocket variables rather than updating
\ FX specific variables in this function, however these often have
\ to be processed or precalculated to prepare for the FX display.
\ This frequently includes self-modifying the FX draw function for
\ speed and cycle-counting purposes.
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

.fx_checker_zoom_update
{
    \\ Compute the starting Y value for each layer at depth
    \\ in rocket_track_zoom. Determine starting parity for each layer.
    lda rocket_track_x_pos:sta checker_y1
    lda rocket_track_x_pos+1:sta checker_y1+1

    lda rocket_track_y_pos:sta checker_y2
    lda rocket_track_y_pos+1:sta checker_y2+1

    lda rocket_track_time:sta checker_y3
    lda rocket_track_time+1:sta checker_y3+1

    \\ Parity is the top bit of the top byte of each check's Y value...

    \\ Cycle colours for more depth.
    lda rocket_track_zoom+1
    lsr a:lsr a:lsr a:lsr a:lsr a
    tax

    lda layer3_colour, X:sta &fe21
    lda layer2_colour, X:sta &fe21
    lda layer1_colour, X:sta &fe21

    \\ Compute the DY values for each layer at those depth.
    \\ This can be a table as only 32 depths, each with 3 layers.
    lda rocket_track_zoom+1
    and #FX_CHECKER_ZOOM_MAX-1
    tax

    \\ Preload the dy values and self-mod into the display fn for speed.
    lda fx_checker_zoom_dy3_LO, X
    sta fx_checker_zoom_dy3_LO_sm+1
    lda fx_checker_zoom_dy3_HI, X
    sta fx_checker_zoom_dy3_HI_sm+1

    lda fx_checker_zoom_dy2_LO, X
    sta fx_checker_zoom_dy2_LO_sm+1
    lda fx_checker_zoom_dy2_HI, X
    sta fx_checker_zoom_dy2_HI_sm+1

    lda fx_checker_zoom_dy1_LO, X
    sta fx_checker_zoom_dy1_LO_sm+1
    lda fx_checker_zoom_dy1_HI, X
    sta fx_checker_zoom_dy1_HI_sm+1

    \\ Can also use the depth value to set the CRTC screen address once.
	lda #13:sta &fe00					; +7 (10)
	lda fx_checker_zoom_vram_table_LO, X		; +4 (14)
	sta &fe01							; +6 (20)
	lda #12:sta &fe00					; +8 (28)
	lda fx_checker_zoom_vram_table_HI, X		; +4 (32)
	sta &fe01							; +6 (38)

	\\ R6=display 1 row.
	lda #6:sta &fe00					; 8c
	lda #1:sta &fe01					; 8c
	lda #119:sta row_count				; 5c
	rts
}

\\ TODO: Make this comment correct for this framework!
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

\\ Notes:
\\   Could compress all 8x bitmasks into one character row by using
\\   the extra bit of colour => the top layer would ORA bits 2 & 3
\\   in the pre-rendered screen, then would need to set 4x palette
\\   values per displayed row depending on the parity of the top
\\   layer. Make %10xx or %01xx opaque or transparent.
\\   Would require a minimum of 4x8=32c. Could be possible?
\\   What could we do with the second buffer? Sideway movement?
\\   Sequence demo effect to show different movements one at a time?

.fx_checker_zoom_draw
{
	\\ <=== HCC=0 (scanline=-2)

    \\ Ignore top character row to begin with.

    WAIT_SCANLINES_ZERO_X 1             ; +128 (128)

   		\\ <=== HCC=0 (scanline=-1)
		lda #4:sta &fe00				; +8 (8)
		lda #0:sta &fe01				; +8 (16)

		lda #9:sta &fe00				; +8 (24)
		lda #1:sta &fe01				; +8 (32)

        WAIT_CYCLES 106                 ; +106 (128 + 10)

    .char_row_loop
    {
        \\ <=== HCC=10 (even)           ; (10) assumed

        \\ Update y value for top layer.
        clc                                 ; +2 (12)
        lda checker_y3                      ; +3 (15)
        .*fx_checker_zoom_dy3_LO_sm
        adc #0                              ; +2 (17)
        sta checker_y3                      ; +3 (20)
        lda checker_y3+1                    ; +3 (23)
        .*fx_checker_zoom_dy3_HI_sm
        adc #0                              ; +2 (25)
        sta checker_y3+1                    ; +3 (28)

        \\ Top layer goes bit 7 -> bit 2 of the mask.
        and #128                            ; +2 (30)
        lsr a:lsr a:lsr a: lsr a:lsr a      ; +10 (40)
        sta temp                            ; +3 (43)

        \\ Update y value for middle layer.
        clc                                 ; +2 (45)
        lda checker_y2                      ; +3 (48)
        .*fx_checker_zoom_dy2_LO_sm
        adc #0                              ; +2 (50)
        sta checker_y2                      ; +3 (53)
        lda checker_y2+1                    ; +3 (56)
        .*fx_checker_zoom_dy2_HI_sm
        adc #0                              ; +2 (58)
        sta checker_y2+1                    ; +3 (61)

        \\ Middle layer goes bit 7 -> bit 1 of the mask.
        and #128                            ; +2 (63)
        lsr a:lsr a:lsr a: lsr a:lsr a:lsr a; +12 (75)
        ora temp                            ; +3 (78)
        sta temp                            ; +3 (81)

        \\ Update y value for bottom layer.
        clc                                 ; +2 (83)
        lda checker_y1                      ; +3 (86)
        .*fx_checker_zoom_dy1_LO_sm
        adc #0                              ; +2 (88)
        sta checker_y1                      ; +3 (91)
        lda checker_y1+1                    ; +3 (94)
        .*fx_checker_zoom_dy1_HI_sm
        adc #0                              ; +2 (96)
        sta checker_y1+1                    ; +3 (99)

        \\ Bottom layer goes bit 7 -> bit 0 of the mask.
        lsr a:lsr a:lsr a: lsr a:lsr a:lsr a:lsr a ; +14 (113)
        ora temp                            ; +3 (116)
        tax                                 ; +2 (118)
        \\ X=layer bitmask.

        WAIT_CYCLES 10                      ; +10 (118)

			\\ <=== HCC=0 (odd)

    		; Set R9 for the next line.
	    	lda #9: sta &fe00				    ; +8 (8)
            lda fx_check_zoom_bitmask_to_R9, X  ; +4 (12)
		    sta &fe01						    ; +4 (16)
		    \\ R9 must be set in final scanline of the row for this scheme.

			lda jmptab, X:sta jmpinstruc+1	    ; +8 (24)

			ldy #1							    ; +2 (26)
			lda #0:sta &fe00				    ; +8 (34)

            WAIT_CYCLES 47                      ; +47 (81)

            \\ Set SHADOW bit safely in hblank.
	        lda &fe34:and #&fe                      ; +6 (87)
            ora fx_check_zoom_bitmask_to_shadow,X   ; +4 (93)
            sta &fe34	                            ; +4 (97)

			.jmpinstruc JMP scanline0		; +3 (101)
			.^jmpreturn						;    (122)

			sta &fe01						; +6 (128)

		\\ <=== HCC=0 (even)
		dec row_count						; +5 (14)
		beq scanline_last					; +2 (16)
		jmp char_row_loop					; +3 (19)
	}
	.scanline_last
	;CHECK_SAME_PAGE_AS char_row_loop, FALSE

    \\ <=== HCC=8 (even) [last visible char row.]
	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00						; +8 (16)
	lda #36: sta &FE01						; +8 (24)

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00						; +8 (32)
	lda #17:sta &fe01						; +8 (40)

    WAIT_SCANLINES_ZERO_X 2

   	\\ Set R9=1 so all remaining char rows are 2 scanlines each.
	lda #9:sta &fe00						; +7 (14)
	lda #1:sta &fe01						; +8 (22)

	lda #0:sta prev_scanline				; +5 (27)
	\\ FX responsible for resetting lower palette.
	jmp fx_static_image_set_default_palette

SKIP 40 ; // TODO: Remove unnecessary padding!

PAGE_ALIGN_FOR_SIZE 8
.jmptab
	EQUB LO(scanline0)
	EQUB LO(scanline2)
	EQUB LO(scanline4)
	EQUB LO(scanline6)
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
	; | next scanline 2: R0=119 R9=3 R0=3                           | 0   0   1   1   (2...)
	.scanline2							;    (101)
	LDA #119:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	INY:INY								; +4 (114)
	STY &FE01							; +6 (120)
	JMP jmpreturn						; +3 (123)
	
	;-------------------------------------------------------	
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 4: R0=119 R9=5                                | 0   1   2   3   (4...)
	.scanline4							;    (101)
	LDA #119:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	WAIT_CYCLES 4						; +4 (114)
	STY &FE01							; +6 (120)
	JMP jmpreturn						; +3 (123)

	;-------------------------------------------------------
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 6: R0=115 R9=7                        | 0   1   2   3   4   5   (6...)
	.scanline6							;    (101)
CHECK_SAME_PAGE_AS scanline0, TRUE
	LDA #115:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	STY &FE01							; +6 (116)
	WAIT_CYCLES 3						; +3 (119)
	JMP jmpreturn						; +3 (122)
}

PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_vram_table_LO
FOR n,0,31,1
EQUB LO((&3000 + n*640)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_vram_table_HI
FOR n,0,31,1
EQUB HI((&3000 + n*640)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 8
.fx_check_zoom_bitmask_to_R9
; ideally would have been 0,1,2,3,4,5,6,7
EQUB 1,3,5,7,1,3,5,7

PAGE_ALIGN_FOR_SIZE 8
.fx_check_zoom_bitmask_to_shadow
EQUB 0,0,0,0,1,1,1,1
; Set the screen start address just once per frame for the depth, then toggle
; between main & SHADOW to select from the 8 possible combinations of layers.

VPW=160:SX=128:CX=0:CZ=-160:Z=0:DZ=8
PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_dy3_LO    ; top layer
FOR n,0,31,1
z3=Z+n*DZ
dy3=SX/(VPW*(SX-CX)/(z3-CZ))
z2=Z+n*DZ+32*DZ
z1=Z+n*DZ+64*DZ
PRINT z3,dy3
EQUB LO(dy3 * 256 * 2)
NEXT

PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_dy3_HI    ; top layer
FOR n,0,31,1
z3=Z+n*DZ
dy3=SX/(VPW*(SX-CX)/(z3-CZ))
z2=Z+n*DZ+32*DZ
z1=Z+n*DZ+64*DZ
PRINT z3,dy3
EQUB HI(dy3 * 256 * 2)
NEXT

PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_dy2_LO    ; middle layer
FOR n,0,31,1
z3=Z+n*DZ
z2=Z+n*DZ+32*DZ
dy2=SX/(VPW*(SX-CX)/(z2-CZ))
z1=Z+n*DZ+64*DZ
PRINT z2,dy2
EQUB LO(dy2 * 256 * 2)
NEXT

PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_dy2_HI    ; middle layer
FOR n,0,31,1
z3=Z+n*DZ
z2=Z+n*DZ+32*DZ
dy2=SX/(VPW*(SX-CX)/(z2-CZ))
z1=Z+n*DZ+64*DZ
PRINT z2,dy2
EQUB HI(dy2 * 256 * 2)
NEXT

PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_dy1_LO    ; bottom layer
FOR n,0,31,1
z3=Z+n*DZ
z2=Z+n*DZ+32*DZ
z1=Z+n*DZ+64*DZ
dy1=SX/(VPW*(SX-CX)/(z1-CZ))
PRINT z1,dy1
EQUB LO(dy1 * 256 * 2)
NEXT

PAGE_ALIGN_FOR_SIZE 32
.fx_checker_zoom_dy1_HI    ; bottom layer
FOR n,0,31,1
z3=Z+n*DZ
z2=Z+n*DZ+32*DZ
z1=Z+n*DZ+64*DZ
dy1=SX/(VPW*(SX-CX)/(z1-CZ))
PRINT z1,dy1
EQUB HI(dy1 * 256 * 2)
NEXT

.layer3_colour
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &40 + FX_CHECKER_ZOOM_COLOUR_2

.layer2_colour
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &20 + FX_CHECKER_ZOOM_COLOUR_1

.layer1_colour
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_3
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_1
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_2
EQUB &10 + FX_CHECKER_ZOOM_COLOUR_3
