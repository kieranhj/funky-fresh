\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	ZOOMING CHECKERBOARD
\ ******************************************************************

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
    lda #0
    sta checker_y1:sta checker_y1+1
    sta checker_y2:sta checker_y2+1
    sta checker_y3:sta checker_y3+1

    \\ Parity is the top bit of the top byte of check Y value...

    \\ Compute the DY values for each layer at those depth.
    \\ This can be a table as only 32 depths, each with 3 layers.
    ldx rocket_track_zoom+1
    lda fx_checker_zoom_dy3_LO, X
    ;sta
    lda fx_checker_zoom_dy3_HI, X
    ;sta
    lda fx_checker_zoom_dy2_LO, X
    ;sta
    lda fx_checker_zoom_dy2_HI, X
    ;sta
    lda fx_checker_zoom_dy1_LO, X
    ;sta
    lda fx_checker_zoom_dy1_HI, X
    ;sta

    \\ As the layers are fixed, look up address of screen rows
    \\ that correspond to this depth, and write into draw fn.
    
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

.fx_checker_zoom_draw
{
	\\ <=== HCC=0 (scanline=-2)

    \\ Calculate bitmask from parity byte.
    \\ Parity is the top bit of each layer's Y value.
    \\ Top layer goes bit 7 -> bit 2 of the mask.
    lda checker_y3+1                        ; 3c
    lsr a:lsr a:lsr a: lsr a:lsr a          ; 10c <- EEK!
    sta temp                                ; 3c

    lda checker_y2+1                        ; 3c
    lsr a:lsr a:lsr a: lsr a:lsr a:lsr a    ; 12c <- EEK!
    ora temp                                ; 3c
    sta temp                                ; 3c

    lda checker_y1+1                            ; 3c
    lsr a:lsr a:lsr a: lsr a:lsr a:lsr a:lsr a  ; 14c <- EEK!
    ora temp                                ; 3c
    tax                                     ; 2c
    \\ 59c

    \\ ARGH! Forgot limitation that can only use first 6 scanlines with 
    \\ this approach. Need to move to RTW's better solution...

    \\ But something like.
    \\ Set R9 before final scanline of the row starts.
    \\ 27c

    \\ Set the CRTC screen start address for our depth value.
    ldy rocket_track_zoom
    lda #13: sta &FE00				; 8c
    lda fx_checker_zoom_vram_table_LO, Y
    sta &fe01

    lda #12: sta &FE00				; 8c
    lda fx_checker_zoom_vram_table_HIs, Y
    sta &fe01

    \\ Set SHADOW bit safely in hblank.
	lda &fe34:and #&fe:ora fx_check_zoom_bitmask_to_shadow,X:sta &fe34	; 13c

        \\ NB. NONE OF THIS HAS BEEN CYCLE COUNTED YET.

		\\ At HCC=104 set R0=1.
		.blah
		lda #1:sta &fe01					; 8c
		\\ <=== HCC=104

		WAIT_CYCLES 6
		ldx #4:ldy #9						; 4c

		\\ Burn R0=1 scanlines.
		lda #127							; 2c

		\\ Set R0=0 to blank 6x chars.
		stz &fe01							; 6c

		\\ At HCC=0 set R0=127.
		sta &fe01							; 6c

	\\ <=== HCC=0 (scanline=0)

    \\ For each slice.
    \\ Update Y values and parity of each layer.
    \\ Determine which screen address and scanline to use for next slice.
    \\ Do RVI shizzle.

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
.fx_check_zoom_bitmask_to_scanline
; ideally would have been 0,1,2,3,4,5,6,7
EQUB 0,2,4,6,0,2,4,6

PAGE_ALIGN_FOR_SIZE 8
.fx_check_zoom_bitmask_to_shadow
EQUB 0,0,0,0,4,4,4,4    ; this is not true!
; But might be easier this way as could set the screen start address
; just once per frame for the depth, then toggle between main & SHADOW
; to select from the 8 possible combinations of layers.

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
.fx_checker_zoom_dy1_HI    ; bottom layer
FOR n,0,31,1
z3=Z+n*DZ
z2=Z+n*DZ+32*DZ
z1=Z+n*DZ+64*DZ
dy1=SX/(VPW*(SX-CX)/(z1-CZ))
PRINT z1,dy1
EQUB HI(dy1 * 256 * 2)
NEXT
