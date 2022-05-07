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
	lda angle:and #&3E				; +5 (5)
	lsr a:tay						; +4 (9)

	lda #13: sta &FE00				; +7 (16)
	ldx xy+1						; +3 (19)
	lda x_wibble, X					; +4 (23)
	lsr a							; +2 (25)
	clc								; +2 (27)
	adc twister_vram_table_LO, Y	; +4 (31)
	sta &FE01						; +5 (36)

	lda #12: sta &FE00				; +8 (44)
	lda twister_vram_table_HI, Y	; +4 (48)
	adc #0							; +2 (50)
	sta &FE01						; +6 (56)

	lda x_wibble, X					; +4 (60)
	and #1:sta shadow_bit 			; +5 (65)
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
\\ (Or rather no jump forward > 4 scanlines distance between subsequent cycles.)
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

	\\ Set R12,R13 + SHADOW for row 0.
	CHUNKY_TWISTER_SET_CRTC_FROM_ANGLE 		; +65 (65)

	\\ Set colours.
	ldx angle									; +3 (68)
	ldy angle_to_quadrant, X					; +4 (72)
	lda twister_quadrant_colour_1,Y:sta &fe21 	; +8 (80)
	lda twister_quadrant_colour_2,Y:sta &fe21	; +8 (88)
	lda twister_quadrant_colour_3,Y:sta &fe21	; +8 (96)

	\\ Set SHADOW bit safely in non-visible portion.
	lda &fe34:and #&fe						; +6 (102)
	sta accon_sm+1							; +4 (106)
	ora shadow_bit:sta &fe34				; +7 (113)

	WAIT_CYCLES 15							; +15 (128)

		\\ <=== HCC=0 (scanline=-1)
		lda #4:sta &fe00					; +8 (8)
		lda #0:sta &fe01					; +8 (16)

		lda #9:sta &fe00					; +8 (24)
		lda #1:sta &fe01					; +8 (32)

		clc									; +2 (34)

		\\ Ignore scanline for top character row for now.
		\\ Otherwise jump into char_row_loop.
		WAIT_CYCLES	111						; +111 (128 + 17)

	\\ 2x scanlines per row.
	.char_row_loop
	{
		\\ <=== HCC=17 (even)

		.*fx_chunky_twister_calc_rot		; do the twist!
		{
			\\ Assumes C=0.
			\\   rocket_track_y_pos => x offset per row (sin table)    [0-10]  <- makes it curve
			lda xy							; +3 (20)
			.*twister_calc_rot_lo
			adc #0:sta xy					; +5 (25)

			lda xy+1						; +3 (28)
			.*twister_calc_rot_hi
			adc #0:sta xy+1					; +5 (33)

			\ 4096/4000~=1
			clc								; +2 (35)
			\\   rocket_track_zoom  => rotation per row (cos table)    [0-10]  <- makes it twist
			lda yb+2						; +3 (38)
			.*twister_calc_rot_zoom_lo
			;  actually LSB!
			adc #0:sta yb+2					; +5 (43)
			lda yb							; +3 (46)
			.*twister_calc_rot_zoom_hi
			adc #0:sta yb					; +5 (51)
			tay								; +2 (53)
			lda yb+1						; +3 (56)
			.*twister_calc_rot_sign
			adc #0							; +2 (58)
			and #15:sta yb+1				; +5 (63)
			clc:adc #HI(cos):sta load+2		; +8 (71)

			.load
			lda cos,Y						; +4 (75)
			sta angle						; +3 (78)
		}
		.*twister_calc_rot_rts

			\\ Set R12,R13 + SHADOW for next row.
			;CHUNKY_TWISTER_SET_CRTC_FROM_ANGLE
			{
				; 0-127
				;A=angle
				and #&3E						; +2 (80)
				lsr a:tay						; +4 (84)

				lda #13: sta &FE00				; +8 (92)
				ldx xy+1						; +3 (95)
				lda x_wibble, X					; +4 (99)
				lsr a							; +2 (101)
				clc								; +2 (103)
				adc twister_vram_table_LO, Y	; +4 (107)
				sta &FE01						; +5 (112)
				lda #12: sta &FE00				; +8 (120)

				lda twister_vram_table_HI, Y	; +4 (124)
				adc #0							; +2 (126)
				\\ <=== HCC=0 (odd)
				sta &FE01						; +6 (4)

				lda x_wibble, X					; +4 (8)
				and #1:sta shadow_bit 			; +5 (13)
			}

			; Set R9 for the next line.
			lda #9: sta &fe00					; +7 (20)
			lda angle:and #1					; +5 (25)
			tax:asl a							; +4 (29)
			ora #1								; +2 (31)
			sta &fe01							; +5 (36)
			\\ R9 must be set in final scanline of the row for this scheme.

			lda jmptab, X:sta jmpinstruc+1		; +8 (44)

			ldx angle							; +3 (47)
			ldy angle_to_quadrant, X			; +4 (52)
			lda twister_quadrant_colour_1,Y		; +4 (56)
			sta &fe21 							; +4 (60)

			lda twister_quadrant_colour_2,Y:sta &fe21	; +8 (68)
			lda twister_quadrant_colour_3,Y:sta &fe21	; +8 (76)
			stz &fe00							; +5 (81)

			TELETEXT_ENABLE_6					; +6 (87)

			\\ Set SHADOW bit safely in hblank.
			.^accon_sm
			lda #0:ora shadow_bit:sta &fe34		; +9 (96)
			WAIT_CYCLES 4						; +4 (100)

			.jmpinstruc JMP scanline0			; +3 (103)
			.^jmpreturn							;    (122)
			; duplicating end of loop saves 3 (remove jmpreturn)
			; double size of twister_vram_table_LO to save 2 (remove lsr)
			; change TELETEXT_DISABLE_7 to 6 maybe?
			; need 12 cycles total
			;  plus palette changes are visible. :S
			;  and scanline 6 fn is broken! :SS

			sta &fe01							; +6 (128)

		\\ <=== HCC=0 (even)

		; turn off teletext enable
		TELETEXT_DISABLE_7					; +7 (7)

		dec row_count						; +5 (12)
		beq done_row_loop					; +2 (14)
		jmp char_row_loop					; +3 (17)
	}
	.done_row_loop
    ;CHECK_SAME_PAGE_AS char_row_loop, TRUE

	\\ <=== HCC=15 (even)

	\\ Currently at scanline 2+118*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00						; +7 (22)
	lda #36: sta &FE01						; +8 (30)

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00						; +8 (38)
	lda #17:sta &fe01						; +8 (46)

	WAIT_CYCLES 34							; +34 (80)
	; turn on teletext enable
	TELETEXT_ENABLE_6						; +6 (86)
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

	\\ FX responsible for resetting lower palette.
	jmp fx_static_image_set_default_palette

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
	.scanline0							;    (103)
	LDA #127:STA &FE01					; +7 (110)
	WAIT_CYCLES 9						; +9 (119)
	JMP jmpreturn						; +3 (122)
	
	;-------------------------------------------------------
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 2: R0=119 R9=3 R0=3                           | 0   0   1   1   (2...)
	.scanline2							;    (103)
	LDA #119:STA &FE01					; +7 (110)
	LDA #127							; +2 (112)
	LDY #3								; +2 (114)
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
	LDY #1								; +2 (112)
	WAIT_CYCLES 2						; +2 (114)
	STY &FE01							; +6 (120)
	JMP jmpreturn						; +3 (123)

	;-------------------------------------------------------
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 6: R0=115 R9=7                        | 0   1   2   3   4   5   (6...)
	.scanline6							;    (103)
CHECK_SAME_PAGE_AS scanline0, TRUE
	LDA #115:STA &FE01					; +7 (110)
	LDY #1								; +2 (112)
	STY &FE01							; +6 (118) <= broken should be 116
	LDA #127							; +2 (120)
	JMP jmpreturn						; +3 (123)
	
	;-------------------------------------------------------	
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
