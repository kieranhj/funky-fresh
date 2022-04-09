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
	lda fx_stretch_dv_table_LO, X
	sta dv:sta fx_vertical_strech_dv_LO+1
	lda fx_stretch_dv_table_HI, X
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

	; TODO: Move all of the below to display portion before scanline 0?

	\\ This FX always uses screen in MAIN RAM.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
	; clear bit 0 to display MAIN.
	; Should be OK to do this in update given guaranteed position relative to displayed portion?
	lda &fe34:and #&fe:sta &fe34		; 10c

	; initial 'normal' CRTC values
	LDA #1:STA &FE00:LDA #86:STA &FE01
	LDA #2:STA &FE00:LDA #104:STA &FE01

	\\ R6=display 1 row.
	lda #6:sta &fe00					; 8c
	lda #1:sta &fe01					; 8c
	lda #119:sta row_count				; 5c

	; Enable teletext to do blanking on the ULA
	; (it will be disabled explicitly at the start of each RVI line)
	TELETEXT_ENABLE_6
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

.fx_vertical_stretch_draw
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

	WAIT_CYCLES 90						; +90 (128)

		\\ <=== HCC=0 (scanline=-1)
		lda #4:sta &fe00				; +8 (8)
		lda #0:sta &fe01				; +8 (16)
		txa:and #3:tax					; +6 (22)
		inc row_count					; +5 (27)
		WAIT_CYCLES 5					; +5 (32)
		jmp right_in_there				; +3 (35)

	\\ Now 2x scanlines per loop.
	.char_row_loop
	{
		\\ <== HCC=19 (even)

		\\ Update v
		lda v
		.*fx_vertical_strech_dv_LO
		adc #0:sta v						; +8 (27)
		lda v+1
		.*fx_vertical_strech_dv_HI
		adc #0:sta v+1						; +8 (35)

		\\ Row N+1 screen start
		tax									; +2 (37)
		lda #13:sta &fe00					; +7 (44)
		lda fx_stretch_vram_table_LO, X		; +4 (48)
		sta &fe01							; +6 (54)
		lda #12:sta &fe00					; +8 (62)
		lda fx_stretch_vram_table_HI, X		; +4 (66)
		sta &fe01							; +6 (72)
	
		txa:and #3:tax						; +6 (78)
		WAIT_CYCLES 2						; +2 (80)
		; turn on teletext enable
		TELETEXT_ENABLE_7					; +7 (87)
		WAIT_CYCLES 41						; +41 (128)

			\\ <=== HCC=0 (odd)
			TELETEXT_DISABLE_7				; +7 (7)
			WAIT_CYCLES 28					; +28 (35)

			.^right_in_there				;    (35)

			; Set R9 for the next line.
			lda #9: sta &fe00				; +7 (42)
			txa:asl a						; +4 (46)
			sta prev_scanline				; +3 (47)
			ora #1							; +2 (49)
			sta &fe01						; +5 (54)
			\\ R9 must be set in final scanline of the row for this scheme.

			lda jmptab, X:sta jmpinstruc+1	; +8 (64)

			WAIT_CYCLES 16					; +16 (80)
			TELETEXT_ENABLE_7				; +7 (87)

			ldy #1							; +2 (89)
			lda #0:sta &fe00				; +7 (96)
			WAIT_CYCLES 2					; +9 (98)

			.jmpinstruc JMP scanline0		; +3 (101)
			.^jmpreturn						;    (122)

			sta &fe01						; +6 (128)

		\\ <=== HCC=0 (even)

		; turn off teletext enable
		TELETEXT_DISABLE_7					; +7 (7)

		clc									; +2 (9)
		dec row_count						; +5 (14)
		beq scanline_last					; +2 (16)
		jmp char_row_loop					; +3 (19)
	}
	.scanline_last
	;CHECK_SAME_PAGE_AS char_row_loop, FALSE

	\\ <=== HCC=17 (even) [last visible char row.]

	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00						; +7 (24)
	lda #36: sta &FE01						; +8 (32)

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00						; +8 (40)
	lda #17:sta &fe01						; +8 (48)

	WAIT_CYCLES 32							; +32 (80)
	; turn on teletext enable
	TELETEXT_ENABLE_6							; +6 (86)
	WAIT_CYCLES 42							; +42 (128)

		\\ We're in the final visible scanline of the screen.
		\\ <=== HCC=0 (odd)
		TELETEXT_DISABLE_7					; +7 (7)

		WAIT_CYCLES 73						; +73 (80)
		; turn on teletext enable
		TELETEXT_ENABLE_7					; +7 (87)
		WAIT_CYCLES 41						; +41 (128)

	\\ <=== HCC=0 (off screen)
	TELETEXT_DISABLE_7						; +7 (7)

	\\ Set R9=1 so all remaining char rows are 2 scanlines each.
	lda #9:sta &fe00						; +7 (14)
	lda #1:sta &fe01						; +8 (22)

	lda #0:sta prev_scanline				; +5 (27)

	; initial 'normal' CRTC values
	LDA #1:STA &FE00:LDA #80:STA &FE01
	LDA #2:STA &FE00:LDA #98:STA &FE01
    rts

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
	STY &FE01							; +6 (116)
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
	INY:INY								; +4 (114)
	STY &FE01							; +6 (120)
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
	STY &FE01							; +6 (120)
	JMP jmpreturn						; +3 (123)

	;-------------------------------------------------------	
}

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN_FOR_SIZE 256
.fx_stretch_vram_table_LO
FOR n,0,127,1
EQUB LO((&2FD0 + (n DIV 4)*640)/8)
NEXT
FOR n,0,127,1
EQUB LO(&2FD0/8)
NEXT

PAGE_ALIGN_FOR_SIZE 256
.fx_stretch_vram_table_HI
FOR n,0,127,1
EQUB HI((&2FD0 + (n DIV 4)*640)/8)
NEXT
FOR n,0,127,1
EQUB HI(&2FD0/8)
NEXT

PAGE_ALIGN_FOR_SIZE 64
.fx_stretch_dv_table_LO
FOR n,0,63,1
height=128
max_height=height*10
h=128+n*(max_height-height)/63
dv = 256 * height / h
;PRINT h, height/h, dv
EQUB LO(dv)
NEXT

PAGE_ALIGN_FOR_SIZE 64
.fx_stretch_dv_table_HI
FOR n,0,63,1
height=128
max_height=1280
h=128+n*(max_height-height)/63
dv = 256 * height / h
EQUB HI(dv)
NEXT
