\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	VERTICAL STRETCH FX
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

.fx_vertical_stretch_update
{
	ldx track_zoom
	lda dv_table_LO, X
	sta dv
	lda dv_table_HI, X
	sta dv+1

	\\ Set v
	lda #0:sta v:sta v+1

IF 1
	\\ Want centre of screen to be centre of sprite.
	lda #0:sta v
	lda #128:sta v+1

	\\ Subtract dv 128 times to set starting v.
	ldy #64
	.sub_loop
	sec
	lda v
	sbc dv
	sta v
	lda v+1
	sbc dv+1
	sta v+1

	dey
	bne sub_loop
ENDIF

	\\ Set CRTC start address of row 0.
	lsr a:tax
	lda #13:sta &fe00
	lda vram_table_LO, X
	sta &fe01
	lda #12:sta &fe00
	lda vram_table_HI, X
	sta &fe01

	\\ Scanline of row 0 is always 0.
	lda #0
	sta prev_scanline

	\\ This FX always uses screen in MAIN RAM.
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34

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

CODE_ALIGN &100
.fx_vertical_stretch_draw
{
	\\ <=== HCC=0

	\\ R4=0
	lda #4:sta &fe00					; 8c
	lda #0:sta &fe01					; 8c

	\\ R7 vsync at row 35 = scanline 280.
	lda #7:sta &fe00					; 8c
	lda #3:sta &fe01					; 8c

	\\ R6=1
	lda #6:sta &fe00					; 8c
	lda #1:sta &fe01					; 8c
	\\ 48c

	\\ Update v
	clc:lda v:adc dv:sta v				; 11c
	lda v+1:adc dv+1:sta v+1			; 9c
	\\ 20c

	\\ Row 1 screen start
	lsr a:tax							; 4c
	lda #13:sta &fe00					; 8c
	lda vram_table_LO, X				; 4c
	sta &fe01							; 6c
	lda #12:sta &fe00					; 8c
	lda vram_table_HI, X				; 4c
	sta &fe01							; 6c
	\\ 40c
	
	\\ Row 1 scanline
	lda #9:sta &fe00					; 8c
	lda v+1:and #6						; 5c
	\\ 2-bits * 2
	tax									; 2c
	eor #&ff							; 2c
	sec									; 2c
	adc #13								; 2c
		clc									; 2c
		adc prev_scanline					; 3c
		sta &fe01							; 6c
		stx prev_scanline					; 3c
		\\ 35c

		lda #126:sta row_count				; 5c

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 58

		\\ At HCC=102 set R0=1.
		lda #1:sta &fe01					; 8c
		\\ Burn 13 scanlines = 13x2c = 26c
		WAIT_CYCLES 18

	\\ Now 2x scanlines per loop.
	.char_row_loop
	{
			\\ At HCC=0 set R0=127
			lda #127:sta &fe01		; 8c
		
		\\ <=== HCC=0
		\\ Update v
		clc:lda v:adc dv:sta v				; 11c
		lda v+1:adc dv+1:sta v+1			; 9c
		\\ 20c

		\\ Row N+1 screen start
		lsr a:tax							; 4c
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
		lda v+1:and #6					; 5c
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

		\\ 33c
			WAIT_CYCLES 68		\\ <=== HCC=0
			\\ 35c

			\\ Set R0=101 (102c)
			lda #0:sta &fe00				; 8c <= 7c
			lda #101:sta &fe01				; 8c

			WAIT_CYCLES 44

			\\ At HCC=102 set R0=1.
			lda #1:sta &fe01				; 8c
			\\ Burn 13 scanlines = 13x2c = 26c
			WAIT_CYCLES 10

			dec row_count				; 5c
			bne char_row_loop			; 3c
	}
	CHECK_SAME_PAGE_AS char_row_loop
	.scanline_last

		ldx #1						; 2c
		\\ At HCC=0 set R0=127
		lda #127:sta &fe01			; 8c <= 7c
	
	\\ <=== HCC=0
	jsr cycles_wait_scanlines	

		\\ <=== HCC=0
		\\ Set next scanline back to 0.
		lda #9:sta &fe00			; 8c
		clc							; 2c
		lda #13						; 2c
		adc prev_scanline			; 3c
		sta &fe01					; 6c

		lda #6:sta &fe00			; 8c <= 7c
		lda #0:sta &fe01			; 8c
		\\ 36c

		\\ Set R0=101 (102c)
		lda #0:sta &fe00			; 8c
		lda #101:sta &fe01			; 8c

		WAIT_CYCLES 42

		\\ At HCC=102 set R0=1.
		lda #1:sta &fe01			; 8c
		\\ Burn 13 scanlines = 13x2c = 26c
		WAIT_CYCLES 18

		lda #127:sta &fe01			; 8c
	\\ <=== HCC=0

	\\ R9=7
	.scanline_end_of_screen
	lda #9:sta &fe00
	lda #7:sta &fe01

	\\ Total 312 line - 256 = 56 scanlines
	lda #4: sta &fe00
	lda #6: sta &fe01
    RTS
}

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN_FOR_SIZE 128
.vram_table_LO
FOR n,0,127,1
EQUB LO((&3000 + (n DIV 4)*640)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 128
.vram_table_HI
FOR n,0,127,1
EQUB HI((&3000 + (n DIV 4)*640)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 128
.dv_table_LO
FOR n,0,63,1
height=128
max_height=height*10
h=128+n*(max_height-height)/63
dv = 512 * height / h
;PRINT h, height/h, dv
EQUB LO(dv)
NEXT

PAGE_ALIGN_FOR_SIZE 128
.dv_table_HI
FOR n,0,63,1
height=128
max_height=1280
h=128+n*(max_height-height)/63
dv = 512 * height / h
EQUB HI(dv)
NEXT
