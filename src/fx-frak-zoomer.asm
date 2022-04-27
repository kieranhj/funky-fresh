\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	FRAK ZOOMER FX
\ ******************************************************************

FRAK_SPRITE_WIDTH=32
FRAK_SPRITE_HEIGHT=43	; TODO: Need to make this a multiple of 2.
FRAK_MAX_ZOOM=55

\\ TODO: Describe the FX and requirements.
\\ Describe the track values used:

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

;When you start, one 16-bit number will be in product+0-product+1, low byte first as usual for 6502
;and the other 16-bit number will be in product+2-product+3, same way. When you're done,
;the 32-bit answer will take all four bytes, with the high cell first.
;IOW, $12345678 will be in the order 34 12 78 56.
;Addresses temp+0 and temp+1 will be used as a scratchpad.
.multiply_16_by_16
{
   	LDA  product+2    ; Get the multiplicand and
    STA  temp+0       ; put it in the scratchpad.
    LDA  product+3
    STA  temp+1
    STZ  product+2    ; Zero-out the original multiplicand area.
    STZ  product+3

    LDY  #16		  ; We'll loop 16 times.
.loop1
	ASL  product+2    ; Shift the entire 32 bits over one bit position.
    ROL  product+3
    ROL  product+0
    ROL  product+1
    BCC  loop2 ; Skip the adding-in to the result if
               ; the high bit shifted out was 0.
    CLC        ; Else, add multiplier to intermediate result.
    LDA  temp+0
    ADC  product+2
    STA  product+2
    LDA  temp+1
    ADC  product+3
    STA  product+3

    LDA  #0    ; If C=1, incr lo byte of hi cell.
    ADC  product+0
    STA  product+0

.loop2
	DEY        	  ; If we haven't done 16 iterations yet,
    BNE  loop1    ; then go around again.
    RTS
}

.fx_frak_zoomer_update
{
	\\ Scanline 0,2,4,6 from zoom.
	lda rocket_track_zoom+1				; 3c
	cmp #FRAK_MAX_ZOOM
	bcc zoom_ok
	lda #FRAK_MAX_ZOOM-1
	.zoom_ok
	sta zoom
	tax
	lda fx_zoom_scanlines, X
	sta next_scanline

	\\ Set dv.
	txa:asl a:tax
	lda fx_zoom_dv_table+0, X
	sta fx_zoom_add_dv_LO+1
	lda fx_zoom_dv_table+1, X
	sta fx_zoom_add_dv_HI+1

	\\ top_pos = (y_pos - 60*dv) MOD sprite_height
	sec
	lda rocket_track_y_pos+0
	sbc fx_zoom_viewport_height+0,X
	sta v+0
	lda rocket_track_y_pos+1
	sbc fx_zoom_viewport_height+1,X
	tay
	lda frak_mod_sprite_height, Y
	sta v+1

	\\ Hi byte of V * 16
	clc
	lda #0:sta temp
	lda v+1
	asl a:rol temp
	asl a:rol temp
	asl a:rol temp
	asl a:rol temp
	clc
	adc #LO(frak_data)
	sta pal_loop+1
	lda temp
	adc #HI(frak_data)
	sta pal_loop+2

	\\ Set palette for first line.
	\\ Should really be in draw function.
	ldy #15						; 2c
	.pal_loop
	lda frak_data, y			; 4c
	sta &fe21					; 4c
	dey							; 2c
	bpl pal_loop				; 3c
	\\ 2+16*13-1=234c !!
	\\ ALT: lda (frakptr), Y:sta &fe21:iny ; 11c
	\\ 16*11=176c hmmmm.

	\\ Need char offset for left edge of viewport that is 80 units wide, centre is 40.
	\\ So subtract distance to left edge of viewport before calculating.
	\\ left_pos = (x_pos - 40*dv) MOD sprite_width
	\\ char_off = (sprite_width_in_chars_for_zoom * left_pos) / sprite_width.
	\\ sprite_width_in_chars_for_zoom and x_pos both 12-bits.
	sec
	lda rocket_track_x_pos+0
	sbc fx_zoom_viewport_width+0,X
	sta product+0
	lda rocket_track_x_pos+1
	sbc fx_zoom_viewport_width+1,X
	and #15	;MOD FRAK_SPRITE_WIDTH_IN_CHARS
	sta product+1
	lda fx_zoom_max_char_width+0,X:sta product+2
	lda fx_zoom_max_char_width+1,X:sta product+3
	jsr multiply_16_by_16

	;IOW, $12345678 will be in the order 34 12 78 56.
	;We want 345 as a 12-bit number so shift by 4:
	lsr product+0:ror product+3
	lsr product+0:ror product+3
	lsr product+0:ror product+3
	lsr product+0:ror product+3
	lda product+0:sta char_off+1
	lda product+3:sta char_off+0

	lda #6:sta &fe00			; 8c
	lda #1:sta &fe01			; 8c
	lda #119:sta row_count		; 5c
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

\\ Double-line RVI with no LHS blanking.
\\ Display 0,2,4,6 scanline as first row from any other.
\\ NB. Can't hide LHS garbage but will only be visible on scanline 0. :\
\\  Set R9 before final scanline to 13 + current - next. eg. R9 = 13 + 6 - 0 = 13
\\
\\ cycles -->  94   96   98   100  102  104  106  108  110  112  114  116  118  120  122  124  126  0
\\             lda..sta............WAIT_CYCLES 18 ..............................lda..sta ...........|
\\             #1   &fe01                                                       #127 &fe01
\\ scanline 1            ^         2    3    4    5    6    7    8    9    10   11   12   13   xx   0
\\                       hpos                                                                  |
\\                                                         --> missed due to end of CRTC cycle +
\\ NB. There is no additional scanline if this is not the end of the CRTC cycle.

\\ Repeated double-line RVI with LHS blanking.
\\ Display 0,2,4,6 scanline as repeated row.
\\  Set R9 before final scanline to 9 + current - next = 9 constant.
\\
\\ cycles -->  96   98   100  102  104  106  108  110  112  114  116  118  120  122  124  126  0
\\             lda..sta............WAIT_CYCLES 10 ..........lda..stz ...........sta ...........|
\\             #1   &fe01                                   #127 &fe01          &fe01
\\ scanline 7       ^              8    9    x    0    1    2    3    4    5    ?    ?    ?    6
\\                  hpos                     |                                  |
\\       --> missed due to end of CRTC cycle +                                  + scanline counter prevented from updating whilst R0=0!

CODE_ALIGN 32

.fx_frak_zoomer_draw
{
	\\ <=== HCC=0 (scanline=-2)

	\\ R9 must be set before final scanline of the row.
	lda #9:sta &fe00					; 8c

	\\ Set R9=13+current-next.
	lda #13								; 2c
	clc									; 2c
	adc prev_scanline					; 3c
	sec									; 2c
	sbc next_scanline					; 3c
	sta &fe01							; 6c

	ldx next_scanline					; 3c
	stx prev_scanline					; 3c
	\\ 24c

	\\ Set screen address for zoom.
	lda zoom							; 3c
	asl a:tax							; 4c
	lda #13:sta &fe00					; 8c <= 7c
	lda fx_zoom_crtc_addresses+0, X		; 4c
	clc									; 2c
	adc char_off							; 3c
	sta &fe01							; 6c <= 5c
	lda #12:sta &fe00					; 8c
	lda fx_zoom_crtc_addresses+1, X		; 4c
	adc char_off+1							; 3c
	sta &fe01							; 6c <= 5c
	\\ 48c

	\\ This FX always uses screen in MAIN RAM.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34		; 10c

	WAIT_CYCLES 38

		\\ <=== HCC=0 (scanline=-1)

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 78

		\\ <=== HCC=94 (scanline=-1)

		lda #1:sta &fe01					; 8c
		\\ <=== HCC=102 (scanline=-1)

		\\ Burn R0=1 scanlines.
		WAIT_CYCLES 14
		ldx #4								; 2c
		ldy #9								; 2c

		\\ At HCC=0 set R0=127.
		lda #127:sta &fe01					; 8c

	\\ <=== HCC=0 (scanline=0)

	\\ Set R4=0 (one row per cycle).
	stx &fe00								; 6c
	stz &fe01								; 6c	

	\\ 2x scanlines per row.
	.scanline_loop
	{
		\\ <=== HCC=12 (scanline=even)

		\\ Update texture v.
		clc						; 2c
		lda v					; 3c
		.*fx_zoom_add_dv_LO
		adc #128				; 2c
		sta v					; 3c
		lda v+1					; 3c
		.*fx_zoom_add_dv_HI
		adc #0					; 2c

		cmp #FRAK_SPRITE_HEIGHT	; 2c
		bcc ok
		; 2c
		sbc #FRAK_SPRITE_HEIGHT	; 2c
		jmp store				; 3c
		.ok
		; 3c
		WAIT_CYCLES 4
		.store
		sta v+1					; 3c
		\\ 27c

		tax						; 2c
		lda frak_lines_LO, X	; 4c
		sta set_palette+1		; 4c
		lda frak_lines_HI, X	; 4c
		sta set_palette+2		; 4c
		\\ 18c

		\\ Set R9=9 constant.
		sty &fe00				; 6c <= 5c
		sty &fe01				; 6c

		\\ <=== HCC=68 (scanline=even)
		.set_palette
		jsr frak_line0			; 60c

			\\ <=== HCC=0 (scanline=odd)

			lda #0:sta &fe00		; 8c
			lda #103:sta &fe01		; 8c

			WAIT_CYCLES 80

			lda #1:sta &fe01		; 8c
			\\ <=== HCC=104

			WAIT_CYCLES 10

			lda #127				; 2c
			stz &fe01				; 6c
			sta &fe01				; 6c

		\\ <=== HCC=0 (scanline=even)

		WAIT_CYCLES 4

		dec row_count			; 5c
		bne scanline_loop		; 3c
	}
	CHECK_SAME_PAGE_AS scanline_loop, TRUE
	.scanline_last

	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00
	lda #36: sta &FE01

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00
	lda #17:sta &fe01

	\\ Need to recover back to correct scanline count.
	lda #9:sta &fe00
	clc
	lda prev_scanline
	adc #1
	sta &fe01

	\\ Wait for scanline 240.
	WAIT_SCANLINES_ZERO_X 2

	\\ R9=1
	lda #9:sta &fe00
	lda #1:sta &fe01

	lda #0:sta prev_scanline

	\\ FX responsible for resetting lower palette.
	jmp fx_static_image_set_default_palette
}

\\ Generated code for palette swaps each line.
include "build/frak-lines.asm"

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

; TODO: Should really be 2x bytes LO & HI for dv=1.0 at zoom=0.
PAGE_ALIGN_FOR_SIZE 2*FRAK_MAX_ZOOM
.fx_zoom_dv_table
incbin "data/raw/zoom-dv-table.bin"

PAGE_ALIGN_FOR_SIZE 2*FRAK_MAX_ZOOM
.fx_zoom_crtc_addresses
incbin "data/raw/zoom-to-crtc-addr.bin"

PAGE_ALIGN_FOR_SIZE 2*FRAK_MAX_ZOOM
.fx_zoom_max_char_width
incbin "data/raw/zoom-sprite-width-in-chars.bin"

PAGE_ALIGN_FOR_SIZE FRAK_MAX_ZOOM
.fx_zoom_scanlines
incbin "data/raw/zoom-to-scanline.bin"

PAGE_ALIGN_FOR_SIZE 2*FRAK_MAX_ZOOM
.fx_zoom_viewport_width
incbin "data/raw/zoom-viewport-width.bin"

PAGE_ALIGN_FOR_SIZE 2*FRAK_MAX_ZOOM
.fx_zoom_viewport_height
incbin "data/raw/zoom-viewport-height.bin"

.frak_data
INCBIN "build/frak-sprite.bin"

.frak_mod_sprite_height
FOR n,0,255,1
EQUB n MOD FRAK_SPRITE_HEIGHT
NEXT
