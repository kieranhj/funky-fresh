\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	SPINNING HORIZONTAL BAR
\ ******************************************************************

\\ Describe the track values used:
\\   rocket_track_zoom  => size on screen.
\\   rocket_track_x_pos  => bar size?
\\   rocket_track_y_pos  => y position on screen.
\\   rocket_track_anim  => rotation (cos table)

\\ Want to get to:
\\ a = SIN(t * a + y * b)

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

.fx_spin_bar_update
{
	\\ This FX always uses whatever screen was last displayed.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
IF 0
	\\   rocket_track_time  => rotation of top row (cos table) [0-255] <- makes it spin
	lda #0:sta yb+0	; actually LSB
	lda rocket_track_time+0:sta yb+1
	lda rocket_track_time+1:sta yb+2

	; use top 12 bits for 4096 byte table
	lsr yb+2:ror yb+1:ror yb+0
	lsr yb+2:ror yb+1:ror yb+0
	lsr yb+2:ror yb+1:ror yb+0
	lsr yb+2:ror yb+1:ror yb+0

	; compute rotation angle.
	lda yb+2
	and #15
	clc
	adc #HI(cos)
	sta load+2

	ldy yb+1
	.load
	lda cos, Y
ELSE
	lda rocket_track_time+1
	sta angle	; in brads
ENDIF

	\\ Bar centred at y_pos.
	\\        R
	\\   x1 +--+ x2  =>  x3 +--+ x1  =>  x4 +--+ x3  =>  x2 +--+ x4
	\\    C |  | Y          |  |            |  |            |  | 
	\\   x3 +--+ x4      x4 +--+ x2      x2 +--+ x1      x1 +--+ x3
	\\       G
	\\
	\\ y1'=x1*sin(a)+y1*cos(a) = x1*sin(a)+y1*cos(a)
	\\ y2'=x1*sin(a)+y2*cos(a) = -x1*sin(a)+y1*cos(a)
	\\ y3'=x3*sin(a)+y3*cos(a) = x1*sin(a)-y1*cos(a)
	\\ y4'=x4*sin(a)+y4*cos(a) = -x1*sin(a)+-y1*cos(a)

	tay
	lda rocket_track_y_pos+1
	sec
	sbc spin_x_sin_a, Y
	sec
	sbc spin_y_cos_a, Y
	sta bar_y_corners+0

	lda rocket_track_y_pos+1
	clc
	adc spin_x_sin_a, Y
	sec
	sbc spin_y_cos_a, Y
	sta bar_y_corners+1

	lda rocket_track_y_pos+1
	sec 
	sbc spin_x_sin_a, Y
	clc
	adc spin_y_cos_a, Y
	sta bar_y_corners+2

	lda rocket_track_y_pos+1
	clc
	adc spin_x_sin_a, Y
	clc
	adc spin_y_cos_a, Y
	sta bar_y_corners+3

	\\ Quadrant tells us which faces we can see.
	\\ [0-63] = x1->x2, x2->x4
	\\ [64-127] = x3->x1, x1->x2
	\\ [128-191] = x4->x3, x3->x1
	\\ [192-256] = x2->x4, x4->x3
	lda angle_to_quadrant, Y
	asl a:asl a:tax

	ldy quadrant_to_indices, X
	lda bar_y_corners, Y:sta bar_y_rasters+0
	inx
	ldy quadrant_to_indices, X
	lda bar_y_corners, Y:sta bar_y_rasters+1
	inx
	ldy quadrant_to_indices, X
	lda bar_y_corners, Y:sta bar_y_rasters+2

	lda #255:sta bar_y_rasters+3

	\\ xy should now contain raster lines for colour changes.
	ldy angle
	lda angle_to_quadrant, Y
	asl a:tax

	lda #&00 + PAL_blue
	sta bar_y_colours+0:sta &fe21

	lda quadrant_to_colour, X
	sta bar_y_colours+1
	inx
	lda quadrant_to_colour, X
	sta bar_y_colours+2

	lda #&00 + PAL_blue
	sta bar_y_colours+3
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

.fx_spin_bar_draw
{
	\\ At rasterline xy+0 set palette to ta+0.
	\\ At rasterline xy+1 set palette to ta+1.
	\\ At rasterline xy+2 set palette to PAL_blue.

	; Set R12/R13 for full screen.
	lda #12:sta &fe00								; +8 (8)
	lda #HI(static_image_scrn_addr/8):sta &fe01		; +8 (16)
	lda #13:sta &fe00								; +8 (24)
	lda #LO(static_image_scrn_addr/8):sta &fe01		; +8 (32)

	WAIT_SCANLINES_ZERO_X 2

	\\ <=== HCC=32 (scanline=0)

	; R9=8 scanlines per row (default).
	lda #9:sta &fe00			; +8 (40)
	lda #7:sta &fe01			; +8 (48)

	; R4=312 total lines.
	lda #4:sta &fe00			; +8 (56)
	lda #38:sta &fe01			; +8 (64)

	; R7=vsync at line 272.
	lda #7:sta &fe00			; +8 (72)
	lda #34:sta &fe01			; +8 (80)

	; R6=240 visible lines.
	lda #6:sta &fe00			; +8 (88)
	; at scanline -2.
	sta prev_scanline			; +3 (91)
	lda #30:sta &fe01			; +7 (98)

	\\ Cycle count to end of scanline.

	ldx #0						; +2 (100)
	ldy #0						; +2 (102)
	.scanline_loop
	{
		\\ <=== HCC=102
		tya						; +2 (104)
		cmp bar_y_rasters, X	; +4 (108)
		\\ Increment X if Y > xy[X]
		txa						; +2 (110)
		adc #0					; +2 (112)
		tax						; +2 (114)
		lda bar_y_colours, X	; +4 (118)
		sta &fe21				; +4 (122)

		\\ Cycle count to one scanline.
		WAIT_CYCLES 101			; +101 (95)

		iny						; +2 (97)
		cpy #240				; +2 (99)
		bne scanline_loop		; +3 (102)
	}
	.done_scanlines
	CHECK_SAME_PAGE_AS scanline_loop, TRUE
	rts
}


.quadrant_to_indices
EQUB 0,1,3,&FF
EQUB 2,0,1,&FF
EQUB 3,2,0,&FF
EQUB 1,3,2,&FF

.quadrant_to_colour
\\         Emerging           Hiding.
EQUB &00 + PAL_red, 	&00 + PAL_yellow
EQUB &00 + PAL_green,	&00 + PAL_red
EQUB &00 + PAL_cyan,	&00 + PAL_green
EQUB &00 + PAL_yellow,	&00 + PAL_cyan

PAGE_ALIGN
.spin_x_sin_a
FOR n,0,255,1
EQUB 40*SIN(2*PI*n/256)
NEXT

PAGE_ALIGN
.spin_y_cos_a
FOR n,0,255,1
EQUB 40*COS(2*PI*n/256)
NEXT
