\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	VERTICAL STRETCH FX
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

.standard_multiply_AX
{
	CPX #0:BEQ zero
	DEX:STX product+1
	LSR A:STA product
	LDA #0
	BCC s1:ADC product+1:.s1 ROR A:ROR product
	BCC s2:ADC product+1:.s2 ROR A:ROR product
	BCC s3:ADC product+1:.s3 ROR A:ROR product
	BCC s4:ADC product+1:.s4 ROR A:ROR product
	BCC s5:ADC product+1:.s5 ROR A:ROR product
	BCC s6:ADC product+1:.s6 ROR A:ROR product
	BCC s7:ADC product+1:.s7 ROR A:ROR product
	BCC s8:ADC product+1:.s8 ROR A:ROR product
	STA product+1
	RTS
	.zero
	STX product:STX product+1
	RTS
}

.fx_vertical_stretch_update
{
	ldx rocket_track_zoom+1
	lda dv_table_LO, X
	sta dv:sta fx_vertical_strech_dv_LO+1
	lda dv_table_HI, X
	sta dv+1:sta fx_vertical_strech_dv_HI+1

	\\ Set v to centre of the image.
	lda #0:sta v
	lda #63:sta v+1	; Image Height / 2

	\\ Subtract dv y_pos times to set starting v.
	\\ v = centre - y_pos * dv
	IF 0
	ldy rocket_track_y_pos+1
	.sub_loop
	sec				; 2c
	lda v			; 3c
	sbc dv			; 3c
	sta v			; 3c
	lda v+1			; 3c
	sbc dv+1		; 3c
	sta v+1			; 3c
	dey				; 2c
	bne sub_loop	; 3c
	\\ 19c * y_pos (60) = 960c!!
	ELSE
	\\ TODO: Fix this hack!

	\\ Assumes dv can be no larger than 1.0 / 256!
	lda dv+1:beq just_lower

	\\ If dv == 256 -> 1.0 then 
	\\ v = centre - y_pos so product = y_pos
	lda #0:sta product
	lda rocket_track_y_pos+1:sta product+1
	jmp done_lower

	.just_lower
	\\ product = y_pos * dv
	lda dv
	ldx rocket_track_y_pos+1
	jsr standard_multiply_AX
	.done_lower

	\\ v = centre - y_pos * dv
	sec
	lda v
	sbc product
	sta v
	lda v+1
	sbc product+1
	sta v+1
	ENDIF

	\\ Set CRTC start address of row 0.
	lsr a:tax
	lda #13:sta &fe00
	lda vram_table_LO, X
	sta &fe01
	lda #12:sta &fe00
	lda vram_table_HI, X
	sta &fe01

	\\ This FX always uses screen in MAIN RAM.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34

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

.fx_vertical_stretch_draw
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

	WAIT_CYCLES 33

		\\ <=== HCC=0 (scanline=-1)

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 78

		\\ At HCC=102 set R0=1.
		lda #1:sta &fe01					; 8c
		\\ <=== HCC=102

		\\ Burn R0=1 scanlines.
		WAIT_CYCLES 14
		clc									; 2c
		ldx #4								; 2c

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
		.*fx_vertical_strech_dv_LO
		adc #0:sta v				; 8c
		lda v+1
		.*fx_vertical_strech_dv_HI
		adc #0:sta v+1				; 8c
		\\ 16c

		\\ Row N+1 screen start
		tax							; 2c
		lda #13:sta &fe00					; 8c
		lda vram_table_LO, X				; 4c
		sta &fe01							; 6c
		lda #12:sta &fe00					; 8c
		lda vram_table_HI, X				; 4c
		sta &fe01							; 6c
		\\ 40c
	
		\\ NB. Must set R9 before final scanline of the row!
		\\ Row N+1 scanline
		lda #9:sta &fe00				; 8c
		lda v+1:asl a:and #6					; 7c
		\\ 2-bits * 2
		tax								; 2c
		eor #&ff						; 2c
		sec								; 2c
		adc #13							; 2c
		clc								; 2c
		adc prev_scanline				; 3c
		sta &fe01						; 6c
		stx prev_scanline				; 3c
		\\ 35c

		WAIT_CYCLES 15					; jump to black bar version here - oof!
		\\ <=== HCC=118 (scanline=odd)
			WAIT_CYCLES 80				; for palette changes.

			\\ Set R0=101 (102c)
			stz &fe00						; 6c
			lda #101:sta &fe01				; 8c

			WAIT_CYCLES 10

			\\ At HCC=102 set R0=1.
			lda #1:sta &fe01				; 8c
			\\ <=== HCC=102

			\\ Burn R0=1 scanlines.
			WAIT_CYCLES 18

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
}

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN_FOR_SIZE 256
.vram_table_LO
FOR n,0,127,1
EQUB LO((&3000 + (n DIV 4)*640)/8)
NEXT
FOR n,0,127,1
EQUB LO(&3000/8)
NEXT

PAGE_ALIGN_FOR_SIZE 256
.vram_table_HI
FOR n,0,127,1
EQUB HI((&3000 + (n DIV 4)*640)/8)
NEXT
FOR n,0,127,1
EQUB HI(&3000/8)
NEXT

PAGE_ALIGN_FOR_SIZE 64
.dv_table_LO
FOR n,0,63,1
height=128
max_height=height*10
h=128+n*(max_height-height)/63
dv = 256 * height / h
;PRINT h, height/h, dv
EQUB LO(dv)
NEXT

PAGE_ALIGN_FOR_SIZE 64
.dv_table_HI
FOR n,0,63,1
height=128
max_height=1280
h=128+n*(max_height-height)/63
dv = 256 * height / h
EQUB HI(dv)
NEXT
