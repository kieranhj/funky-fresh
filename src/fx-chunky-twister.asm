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

	\\ Set up first row of the display.
	jsr fx_chunky_twister_calc_rot
	jsr fx_chunky_twister_set_rot
	sty &fe34

	\\ Prep for second row.
	lda #0:sta prev_scanline
	jsr fx_chunky_twister_calc_rot
	sta angle

	\\ R6=display 1 row.
	lda #6:sta &fe00
	lda #1:sta &fe01

	lda #118:sta row_count
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

\\ Limited RVI
\\ Display 0,2,4,6 scanline offset for 2 scanlines.
\\ <--- 102c total w/ 80c visible and hsync at 98c ---> <2c> ..13x <2c> = 128c
\\ Plus one extra for luck!
\\ R9 = 13 + current - next

\\ xm = cos((t/80)-y+20*sin(t/20000+a/(120+20*sin(t/100+y/500))))*16

.fx_chunky_twister_draw
{
	\\ <=== HCC=0

	\\ R4=0, R7=&ff, R6=1, R9=3
	lda #4:sta &fe00					; 8c
	lda #0:sta &fe01					; 8c

	\\ R9 must be set before final scanline of the row.
	lda #9:sta &fe00					; 8c

	\\ Row 0
	lda angle							; 3c
	\\ 2-bits * 2
	and #3:asl a						; 4c
	tax									; 2c
	eor #&ff							; 2c
	clc									; 2c
	adc #13								; 2c
	adc prev_scanline					; 3c
	sta &fe01							; 6c
	stx prev_scanline					; 3c
	\\ 24c

    WAIT_CYCLES 59

	\\ Sets R12,R13 + SHADOW
	lda angle							; 3c
	jsr fx_chunky_twister_set_rot		; 79c
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
		\\ <=== HCC=0
		stx &fe21							; 4c
		WAIT_CYCLES 8

	\\ Want to get to:
	\\ a = SIN(t * a + y * b)
	\\ PICO-8 example: a = COS(t/300 + y/2000)

	\\ Rows 1-30
	.char_row_loop
	{
		lda #9:sta &fe00					; 8c

		jsr fx_chunky_twister_calc_rot		; 72c
		sta angle							; 3c

		\\ 2-bits * 2
		and #3:asl a						; 4c
		tay									; 2c
		eor #&ff							; 2c
		clc									; 2c
		adc #13								; 2c
		adc prev_scanline					; 3c
		sta &fe01							; 6c
		sty prev_scanline					; 3c
		\\ 24c

		\\ Sets R12,R13 + SHADOW
		lda angle							; 3c
		jsr fx_chunky_twister_set_rot		; 79c
		; sets Y to shadow bit.

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c <= 7c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 6

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
		\\ <=== HCC=0
		stx &fe21							; 4c

		dec row_count						; 5c
		bne char_row_loop					; 3c
	}
    CHECK_SAME_PAGE_AS char_row_loop

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
	ldx #2:jsr cycles_wait_scanlines

	\\ R9=1
	lda #9:sta &fe00
	lda #1:sta &fe01
    rts
}

.fx_chunky_twister_calc_rot			; 6c
{
	clc								; 2c
	\\   rocket_track_y_pos => x offset per row (sin table)    [0-10]  <- makes it curve
	lda xy
	.^twister_calc_rot_lo
	adc #0:sta xy		; 8c

	lda xy+1
	.^twister_calc_rot_hi
	adc #0:sta xy+1		; 8c

	\ 4096/4000~=1
	clc								; 2c
	\\   rocket_track_zoom  => rotation per row (cos table)    [0-10]  <- makes it twist
	lda yb+2
	.^twister_calc_rot_zoom_lo
	adc #0:sta yb+2		; 8c actually LSB!
	lda yb
	.^twister_calc_rot_zoom_hi
	adc #0:sta yb		; 8c
	tay					; 2c
	lda yb+1
	.^twister_calc_rot_sign	adc #0
	and #15:sta yb+1				; 10c
	clc:adc #HI(cos):sta load+2		; 8c

	.load
	lda cos,Y						; 4c
	rts								; 6c
}
\\ 72c

.fx_chunky_twister_set_rot			; 6c
{
	; 0-127
	and #&7F						; 2c
	lsr a:lsr a:tay					; 6c

	lda #13: sta &FE00				; 8c
	ldx xy+1						; 3c
	lda x_wibble, X					; 4c
	sta angle						; 3c
	lsr a							; 2c
	clc								; 2c
	adc twister_vram_table_LO, Y	; 4c
	sta &FE01						; 6c <= 5c

	lda #12: sta &FE00				; 8c
	lda twister_vram_table_HI, Y	; 4c
	adc #0							; 2c
	sta &FE01						; 6c

	lda angle						; 3c
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
