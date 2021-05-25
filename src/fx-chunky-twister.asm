\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	CHUNKY TWISTER FX
\ ******************************************************************

\\ TODO: Describe the FX and requirements.
\\ Describe the track values used:
\\   rocket_track_x_pos => x offset of top row (sin table)   [0-255]   <- makes it move side-to-side
\\   rocket_track_y_pos => x offset per row * 16 (sin table) [0-10*16] <- makes it curve

\\   rocket_track_time  => rotation of top row (cos table)   [0-255]   <- makes it spin
\\   rocket_track_zoom  => rotation per row * 16 (cos table) [0-10*16] <- makes it twist


\\ xm = cos((t/80)-y+20*sin(t/20000+a/(120+20*sin(t/100+y/500))))*16
\\ Want to get to:
\\ a = SIN(t * a + y * b)
\\ PICO-8 example: a = COS(t/300 + y/2000)

\\ Angle [0-255] in brads.
\\   [0-63] selects the row.
\\   Top two bits sets the quadrant & therefore the palette.

MACRO CHUNKY_TWISTER_SET_CRTC_FROM_ANGLE		; 65e/66o
{
	; 0-127
	lda angle:and #&3E				; 5c
	lsr a:tay						; 4c

	lda #13: sta &FE00				; 8c <= 7e
	ldx xy+1						; 3c
	lda x_wibble, X					; 4c
	lsr a							; 2c
	clc								; 2c
	adc twister_vram_table_LO, Y	; 4c
	sta &FE01						; 6c <= 5c

	lda #12: sta &FE00				; 8c
	lda twister_vram_table_HI, Y	; 4c
	adc #0							; 2c
	sta &FE01						; 6c

	lda x_wibble, X					; 4c
	and #1:sta shadow_bit 			; 5c
}
ENDMACRO

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

.fx_chunky_twister_update
{
	\\ Extend sign of track values.
	{
		ldx #0
		lda rocket_track_zoom+1
		bpl positive2
		dex
		.positive2
		stx twister_calc_rot_sign+1
	}

	\\ Copy values into self-mod for critical draw fn.
	lda rocket_track_y_pos+0:sta twister_calc_rot_lo+1
	lda rocket_track_y_pos+1:sta twister_calc_rot_hi+1

	\\ Shift down values to give more bits for interpolation.
	lsr twister_calc_rot_hi+1:ror twister_calc_rot_lo+1
	lsr twister_calc_rot_hi+1:ror twister_calc_rot_lo+1
	lsr twister_calc_rot_hi+1:ror twister_calc_rot_lo+1
	lsr twister_calc_rot_hi+1:ror twister_calc_rot_lo+1
	
	lda rocket_track_zoom+0:sta twister_calc_rot_zoom_lo+1
	lda rocket_track_zoom+1:sta twister_calc_rot_zoom_hi+1

	\\ Shift down values to give more bits for interpolation.
	lsr twister_calc_rot_zoom_hi+1:ror twister_calc_rot_zoom_lo+1
	lsr twister_calc_rot_zoom_hi+1:ror twister_calc_rot_zoom_lo+1
	lsr twister_calc_rot_zoom_hi+1:ror twister_calc_rot_zoom_lo+1
	lsr twister_calc_rot_zoom_hi+1:ror twister_calc_rot_zoom_lo+1

	\\   rocket_track_x_pos => x offset of top row (sin table) [0-255] <- makes it move side-to-side
	lda rocket_track_x_pos+0:sta xy
	lda rocket_track_x_pos+1:sta xy+1

	\\   rocket_track_time  => rotation of top row (cos table) [0-255] <- makes it spin
	lda #0:sta yb+2	; actually LSB
	lda rocket_track_time+0:sta yb
	lda rocket_track_time+1:sta yb+1

	; use top 12 bits for 4096 byte table
	lsr yb+1:ror yb+0:ror yb+2
	lsr yb+1:ror yb+0:ror yb+2
	lsr yb+1:ror yb+0:ror yb+2
	lsr yb+1:ror yb+0:ror yb+2

	\\ Holy hackballs! JSR to our inline fn by poking in an RTS.
	lda twister_calc_rot_rts:pha:lda #&60:sta twister_calc_rot_rts
	\\ Set up first row of the display.
	jsr fx_chunky_twister_calc_rot
	pla:sta twister_calc_rot_rts

	\\ R6=display 1 row.
	lda #6:sta &fe00
	lda #1:sta &fe01

	lda #119:sta row_count
	rts
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

\\ Limited jump RVI with LHS blanking.
\\ Display 0,2,4 scanline offset for 2 scanlines.
\\ (Or rather no jump > 4 scanlines distance between subsequent cycles.)
\\  Set R9 before final scanline to 9 + current - next. eg. R9 = 9 + 0 - 0 = 9
\\
\\ cycles -->       96   98   100  102  104  106  108  110  112  114  116  118  120  122  124  126  0
\\                  lda..sta............lda..WAIT_CYCLES 10 ..........stz............sta ...........|
\\                  #1   &fe01          #127                          &fe01          &fe01
\\ scanline 1            ^              2    3    4    5    6    7    8    9    xx   ?    ?    ?    0
\\                       hpos                                                   |    |
\\                                          --> missed due to end of CRTC cycle +    + scanline counter prevented from updating whilst R0=0!
\\
\\ NB. There is no additional scanline if this is not the end of the CRTC cycle.

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

PAGE_ALIGN_FOR_SIZE 4
.twister_quadrant_colour_1
EQUB &60 + PAL_cyan
EQUB &60 + PAL_green
EQUB &60 + PAL_yellow
EQUB &60 + PAL_red

PAGE_ALIGN_FOR_SIZE 4
.twister_quadrant_colour_2
EQUB &10 + PAL_red
EQUB &10 + PAL_cyan
EQUB &10 + PAL_green
EQUB &10 + PAL_yellow

PAGE_ALIGN_FOR_SIZE 4
.twister_quadrant_colour_3
EQUB &20 + PAL_green
EQUB &20 + PAL_yellow
EQUB &20 + PAL_red
EQUB &20 + PAL_cyan

.fx_chunky_twister_draw
{
	\\ <=== HCC=0 (scanline=-2)
	WAIT_CYCLES 16

	\\ R9 must be set before final scanline of the row.
	lda #9:sta &fe00					; 8c

	\\ Row 1 scanline.
	lda angle							; 3c
	\\ 2-bits * 2
	and #1:asl a						; 4c
	tax									; 2c
	eor #&ff							; 2c
	clc									; 2c
	adc #9								; 2c
	adc prev_scanline					; 3c
	sta &fe01							; 6c
	stx prev_scanline					; 3c
	\\ 27c

	\\ Set R12,R13 + SHADOW for row 0.
	CHUNKY_TWISTER_SET_CRTC_FROM_ANGLE 	; 66o

	    WAIT_CYCLES 16

		\\ Set R0=103 (104c)
		lda #0:sta &fe00					; 8c <= 7c
		lda #103:sta &fe01					; 8c

		WAIT_CYCLES 32

		ldx angle							; 3c
		ldy angle_to_quadrant, X			; 4c
		lda twister_quadrant_colour_1,Y:sta &fe21 			; 8c
		lda twister_quadrant_colour_2,Y:sta &fe21			; 8c
		lda twister_quadrant_colour_3,Y:sta &fe21			; 8c
		; 31c

		\\ Set SHADOW bit safely in hblank.
		lda &fe34:and #&fe:ora shadow_bit:sta &fe34	; 13c

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

		\\ At HCC=0 set R0=127
		sta &fe01							; 6c

	\\ <=== HCC=0 (scanline=0)

	\\ Set R4=0 (one row per cycle).
	stx &fe00								; 6c
	stz &fe01								; 6c	

	\\ Rows 1-30
	.char_row_loop
	{
		sty &fe00							; 6c

		.*fx_chunky_twister_calc_rot
		{
			clc								; 2c
			\\   rocket_track_y_pos => x offset per row (sin table)    [0-10]  <- makes it curve
			lda xy
			.*twister_calc_rot_lo
			adc #0:sta xy		; 8c

			lda xy+1
			.*twister_calc_rot_hi
			adc #0:sta xy+1		; 8c

			\ 4096/4000~=1
			clc								; 2c
			\\   rocket_track_zoom  => rotation per row (cos table)    [0-10]  <- makes it twist
			lda yb+2
			.*twister_calc_rot_zoom_lo
			adc #0:sta yb+2		; 8c actually LSB!
			lda yb
			.*twister_calc_rot_zoom_hi
			adc #0:sta yb		; 8c
			tay					; 2c
			lda yb+1
			.*twister_calc_rot_sign	adc #0
			and #15:sta yb+1				; 10c
			clc:adc #HI(cos):sta load+2		; 8c

			.load
			lda cos,Y						; 4c
			sta angle						; 3c
		}
		.*twister_calc_rot_rts
		\\ 63c

		\\ 2-bits * 2
		and #1:asl a						; 4c
		tay									; 2c
		eor #&ff							; 2c
		;clc								; 2c <= can be removed.
		adc #9								; 2c
		adc prev_scanline					; 3c
		sta &fe01							; 6c <= 5c
		sty prev_scanline					; 3c
		\\ 21c

		\\ <=== HCC=0 (scanline=odd)

			\\ Set R12,R13 + SHADOW for next row.
			;CHUNKY_TWISTER_SET_CRTC_FROM_ANGLE 	; 66o/67e
			{
				; 0-127
				lda angle						; 3c
				and #&3E						; 2c
				lsr a:tay						; 4c

				lda #13: sta &FE00				; 8c
				ldx xy+1						; 3c
				lda x_wibble, X					; 4c
				lsr a							; 2c
				clc								; 2c
				adc twister_vram_table_LO, Y	; 4c
				sta &FE01						; 6c <= 5c

				lda #12: sta &FE00				; 8c
				lda twister_vram_table_HI, Y	; 4c
				adc #0							; 2c
				sta &FE01						; 6c

				lda x_wibble, X					; 4c
				and #1:sta shadow_bit 			; 5c
			}

			\\ Set R0=103 (104c)
			stz &fe00							; 6c <= 5c
			lda #103:sta &fe01					; 8c

			WAIT_CYCLES 3

			ldx angle							; 3c
			ldy angle_to_quadrant, X			; 4c
			lda twister_quadrant_colour_1,Y:sta &fe21 			; 8c
			lda twister_quadrant_colour_2,Y:sta &fe21			; 8c
			ldx twister_quadrant_colour_3,Y						; 4c
			; 27c

			\\ Set SHADOW bit safely in hblank.
			lda &fe34:and #&fe:ora shadow_bit:sta &fe34	; 13c

			\\ At HCC=104 set R0=1.
			.here
			lda #1:sta &fe01					; 8c <= 7c
			\\ <=== HCC=104

			\\ Burn 2c scanlines through to 128c.
			lda #127							; 2c

			stx &fe21							; 4c
			WAIT_CYCLES 6

			\\ Set R0=0 to blank 6x chars.
			stz &fe01							; 6c

			\\ At HCC=0 set R0=127
			sta &fe01							; 6c

		\\ <=== HCC=0 (scanline=even)
		ldy #9								; 2c
		dec row_count						; 5c
		beq done_row_loop					; 2c
		jmp char_row_loop					; 3c
	}
	.done_row_loop
    CHECK_SAME_PAGE_AS char_row_loop, TRUE

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
}

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN
.x_wibble
FOR n,0,255,1
EQUB 54+40*SIN(2 * PI *n / 256) 
NEXT

PAGE_ALIGN
.angle_to_quadrant
FOR n,0,255,1
EQUB n >> 6
NEXT

\ Notes
\ Having a 12-bit COSINE table means that the smallest increment in
\ the input (1) results in <= 1 angle output.
PAGE_ALIGN
.cos
FOR n,0,4095,1
EQUB 255*COS(2*PI*n/4096)
NEXT
