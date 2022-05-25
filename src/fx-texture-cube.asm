\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	TEXTURED CUBE FX
\ ******************************************************************

\\ Describe the track values used:
\\   rocket_track_anim  => rotation in brads [0-255]

FX_TEXTURE_CUBE_BLANK_ADDR=&3000
FX_TEXTURE_CUBE_BLANK_SL=0

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

.fx_texture_cube_update
{
	\\ This FX always uses screen in MAIN RAM.
	\\ TODO: Add a data byte to specify MAIN or SHADOW.
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34		; 10c

	\\ Get data for rotation.
	lda rocket_track_time+1		; every time!
	and #63
	tax
	lda texture_cube_table_LO, X
	sta readptr
	lda texture_cube_table_HI, X
	sta readptr+1

	ldy #0:lda (readptr), Y			; [0] dy0
	sta texture_cube_loop0_rows+1

	iny:lda (readptr), Y			; [1] w1
	sta w+1
	stz w

	iny:lda (readptr), Y			; [2] dy1
	sta texture_cube_loop1_rows+1

	iny:lda (readptr), Y			; [3] dw1_LO
	sta texture_cube_loop1_rows_dw_LO+1
	iny:lda (readptr), Y			; [4] dw1_HI
	sta texture_cube_loop1_rows_dw_HI+1

	iny:lda (readptr), Y			; [5] w2
	sta texture_cube_loop2_w+1

	iny:lda (readptr), Y			; [6] dy2
	sta texture_cube_loop2_rows+1

	iny:lda (readptr), Y			; [7] dw2_LO
	sta texture_cube_loop2_rows_dw_LO+1
	iny:lda (readptr), Y			; [8] dw2_HI
	sta texture_cube_loop2_rows_dw_HI+1

	\\ Calculate size of final loop.
	sec
	lda #119
	sbc texture_cube_loop0_rows+1
	sbc texture_cube_loop1_rows+1
	sbc texture_cube_loop2_rows+1
	sta texture_cube_loop3_rows+1

	\\ One row visible.
	lda #6:sta &fe00			; 8c
	lda #1:sta &fe01			; 8c

	lda #119:sta row_count		; 5c

	\\ Set display to a blank row (w=0).
	lda #13:sta &fe00
	lda fx_texture_cube_vram_table_LO:sta &fe01
	lda #12:sta &fe00
	lda fx_texture_cube_vram_table_HI:sta &fe01
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

.fx_texture_cube_draw
{
	\\ <=== HCC=0 (scanline=-2)

	WAIT_SCANLINES_ZERO_X 1				; +128 (0)

	\\ <=== HCC=0 (scanline=-1)

	\\ Set two scanlines per row.
	lda #9:sta &fe00					; +8 (8)
	lda #1:sta &fe01					; +8 (16)

	\\ Set one row per cycle.
	lda #4:sta &fe00					; +8 (24)
	lda #0:sta &fe01					; +8 (32)
	\\ ^--- these are ignored as it is the final scanline of the cycle.

	WAIT_CYCLES 104						; +104 (8)
	\\ ^--- register values now take effect.

	.^texture_cube_loop0_rows
	ldy #0								; +2 (10)
	.loop0
	{
		\\ <=== HCC=10 (scanline=even)

		\\ Always blank (width 0).
		lda #13:sta &fe00				; +8 (18)
		lda fx_stretch_vram_table_LO	; +4 (22)
		sta &fe01						; +6 (28)
		lda #12:sta &fe00				; +8 (36)
		lda fx_stretch_vram_table_HI	; +4 (40)
		sta &fe01						; +6 (46)
		WAIT_CYCLES 82					; +82 (0)

			\\ <=== HCC=0 (odd)

			; Set R9 for the next line.
			lda #9: sta &fe00			; +8 (8)
			lda #1: sta &fe01			; +8 (16)
			WAIT_CYCLES 115				; +115 (3)
			dey							; +2 (5)
			beq done_loop0				; +2 (7) 
			jmp loop0					; +3 (10)
	}
	.done_loop0

	\\ <=== HCC=8 (scanline=even)

	.^texture_cube_loop1_rows
	ldy #0								; +2 (10)

	.loop1
	{
		\\ <=== HCC=10 (scanline=even)

		\\ Set screen start for next row.
		ldx w+1							; +3 (13)
		lda #13:sta &fe00				; +7 (20)
		lda fx_stretch_vram_table_LO, X	; +4 (24)
		sta &fe01						; +6 (30)
		lda #12:sta &fe00				; +8 (38)
		lda fx_stretch_vram_table_HI, X	; +4 (42)
		sta &fe01						; +6 (48)

		\\ NEED 60 CYCLES SOMEWHERE FOR PALETTE CHANGES EVENTUALLY!!
		WAIT_CYCLES 80					; +80 (0)

			\\ <=== HCC=0 (odd)

			; Set R9 for the next line.
			lda #9: sta &fe00				; +8 (8)
			txa:and #3:tax					; +6 (14)
			asl a:ora #1					; +4 (18)
			sta &fe01						; +6 (24)
			\\ R9 must be set in final scanline of the row for this scheme.

			\\ Update w += dw for next row.
			clc								; +2 (26)
			lda w							; +3 (29)
			.*texture_cube_loop1_rows_dw_LO
			adc #0							; +2 (31)
			sta w+0							; +3 (34)
			lda w+1							; +3 (37)
			.*texture_cube_loop1_rows_dw_HI
			adc #0							; +2 (39)
			sta w+1							; +3 (42)

			WAIT_CYCLES 38					; +38 (80)

			lda jmptab1, X:sta jmpinstruc1+1	; +8 (88)

			ldx #1							; +2 (90)
			lda #0:sta &fe00				; +8 (98)
			.jmpinstruc1 JMP jmptab1		; +3 (101)
			.^jmpreturn1					;    (122)
			sta &fe01						; +6 (128)

		\\ <=== HCC=0 (even)
		WAIT_CYCLES 3					; +3 (3)

		dey								; +2 (5)
		beq done_loop1					; +2 (7)
		jmp loop1						; +3 (10)
	}
	.done_loop1

	\\ <=== HCC=8 (even)

	.^texture_cube_loop2_w
	lda #0								; +2 (10)
	sta w+1								; +3 (13)
	stz w+0								; +3 (16)

	.^texture_cube_loop2_rows
	ldy #0								; +2 (18)
	beq skip_loop2						;					----+
										; +2 (20)				|
	.loop2
	{
		\\ <=== HCC=20 (scanline=even)

		\\ Set screen start for next row.
		ldx w+1							; +3 (23)
		lda #13:sta &fe00				; +7 (30)
		lda fx_stretch_vram_table_LO, X	; +4 (34)
		sta &fe01						; +6 (40)
		lda #12:sta &fe00				; +8 (48)
		lda fx_stretch_vram_table_HI, X	; +4 (52)
		sta &fe01						; +6 (58)

		\\ NEED 60 CYCLES SOMEWHERE FOR PALETTE CHANGES EVENTUALLY!!
		WAIT_CYCLES 70					; +70 (0)

			\\ <=== HCC=0 (odd)

			; Set R9 for the next line.
			lda #9: sta &fe00				; +8 (8)
			txa:and #3:tax					; +6 (14)
			asl a:ora #1					; +4 (18)
			sta &fe01						; +6 (24)
			\\ R9 must be set in final scanline of the row for this scheme.

			\\ Update w += dw for next row.
			clc								; +2 (26)
			lda w							; +3 (29)
			.*texture_cube_loop2_rows_dw_LO
			adc #0							; +2 (31)
			sta w							; +3 (34)
			lda w+1							; +3 (37)
			.*texture_cube_loop2_rows_dw_HI
			adc #0							; +2 (39)
			sta w+1							; +3 (42)

			WAIT_CYCLES 38					; +38 (80)

			lda jmptab2, X:sta jmpinstruc2+1	; +8 (88)

			ldx #1							; +2 (90)
			lda #0:sta &fe00				; +8 (98)
			.jmpinstruc2 JMP jmptab2		; +3 (101)
			.^jmpreturn2					;    (122)
			sta &fe01						; +6 (128)

		\\ <=== HCC=0 (even)
		WAIT_CYCLES 13					; +13 (13)

		dey								; +2 (15)
		beq done_loop2					; +2 (17)
		jmp loop2						; +3 (20)
	}
	.done_loop2
	;									; +3 (18)
	\\ <=== HCC=18 (even)										|
	WAIT_CYCLES 3						; +3 (21)				v
	.skip_loop2											  ; +3 (21)
	CHECK_SAME_PAGE_AS loop2, TRUE

	\\ <=== HCC=21 (even)

	.^texture_cube_loop3_rows
	ldy #0								; +2 (23)
	.loop3
	{
		\\ <=== HCC=23 (scanline=even)

		\\ Always blank (width 0).
		lda #13:sta &fe00				; +7 (30)
		lda fx_stretch_vram_table_LO	; +4 (34)
		sta &fe01						; +6 (40)
		lda #12:sta &fe00				; +8 (48)
		lda fx_stretch_vram_table_HI	; +4 (52)
		sta &fe01						; +6 (58)
		WAIT_CYCLES 70					; +70 (0)

			\\ <=== HCC=0 (odd)

			; Set R9 for the next line.
			lda #9: sta &fe00			; +8 (8)
			lda #1: sta &fe01			; +8 (16)
			WAIT_CYCLES 128				; +128 (16)
			dey							; +2 (18)
			beq done_loop3				; +2 (20)
			jmp loop3					; +3 (23)
	}
	.done_loop3
	
	\\ <=== HCC=21 (even) [last visible char row.]

	\\ Currently at scanline 119*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00						; +7 (28)
	lda #36: sta &FE01						; +8 (36)

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00						; +8 (44)
	lda #17:sta &fe01						; +8 (52)

	lda #0:sta prev_scanline

	\\ FX responsible for resetting lower palette.
	jmp fx_static_image_set_default_palette

ALIGN 4
.jmptab1
{
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
	JMP jmpreturn1						; +3 (122)
	
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
	STX &FE01							; +6 (116)
	WAIT_CYCLES 3						; +3 (119)
	JMP jmpreturn1						; +3 (122)
	
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 2: R0=119 R9=3 R0=3                           | 0   0   1   1   (2...)
	.scanline2							;    (101)
	LDA #119:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	INX:INX								; +4 (114)
	STX &FE01							; +6 (120)
	JMP jmpreturn1						; +3 (123)
	
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
	STX &FE01							; +6 (120)
	JMP jmpreturn1						; +3 (123)
	;-------------------------------------------------------	
}

ALIGN 4
.jmptab2
{
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
	JMP jmpreturn2						; +3 (122)
	
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
	STX &FE01							; +6 (116)
	WAIT_CYCLES 3						; +3 (119)
	JMP jmpreturn2						; +3 (122)
	
	;     disable            enable hsync=101
	;        v                 v       v
	;  +-----------------------+ R1=86 
	;   0    6            80   86        106 108 110 112 114 116 118 120 122 124 126 128 
	; |                                    
	; | next scanline 2: R0=119 R9=3 R0=3                           | 0   0   1   1   (2...)
	.scanline2							;    (101)
	LDA #119:STA &FE01					; +7 (108)
	LDA #127							; +2 (110)
	INX:INX								; +4 (114)
	STX &FE01							; +6 (120)
	JMP jmpreturn2						; +3 (123)
	
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
	STX &FE01							; +6 (120)
	JMP jmpreturn2						; +3 (123)
	;-------------------------------------------------------	
}
}

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

MIN_W=32
MAX_W=159
ERR=1e-7

cz=-160
oz=0
vp_scale=80
centre_x=0
centre_y=0

MACRO PROJECT_FACE x1,y1,z1,x2,y2,z2,colour
{
	s1x = centre_x + vp_scale * x1 / (z1 + oz - cz)
	s1y = centre_y + vp_scale * y1 / (z1 + oz - cz)
	s2x = centre_x + vp_scale * x2 / (z2 + oz - cz)
	s2y = centre_y + vp_scale * y2 / (z2 + oz - cz)

	PRINT "SCREEN (",s1x,s1y,") -> (",s2x,s2y,")"
	PRINT "EDGE FROM y=",s1y,"to",s2y

	w1 = (s1x - centre_x) * 2
	w2 = (s2x - centre_x) * 2

	IF w1<MIN_W
		ERROR "w1 < MIN_W"
	ELIF w1>MAX_W
		ERROR "w1 > MAX_W"
	ENDIF

	IF w2<MIN_W
		ERROR "w2 < MIN_W"
	ELIF w2>MAX_W
		ERROR "w2 > MAX_W"
	ENDIF

	PRINT "WIDTH FROM ",w1,"to",w2

	dy = s2y-s1y

	\\ Face can be still be considered not visible after
	\\ projection as it will be hidden by a nearer face.
	IF dy<0
		PRINT "CULL FACE"
		EQUB 255,0,255,0,0		; repeat w=0 for 255 rows.
	ELSE
		\\ Scanline Y coordinate, width.
		EQUB 60-s2y, w2-MIN_W+1, dy

		dx = (w1-w2)/dy
		\\ PRINT ty,w2,dx,256*dx
		EQUB LO(256*dx),HI(256*dx)
	ENDIF
}
ENDMACRO

\\ For a given rotation what info do we need?
\\  There will be at most two visible faces.
\\  Y0 coordinate of top edge
\\  Width (X0) of top edge
\\  dx0 from top edge to middle edge
\\  Y1 coordinate of middle edge
\\  Don't need width of middle edge at this is computed as we go
\\   X1 = X0 + dx0 * (Y1-Y0)
\\  dx1 from middle edge to bottom edge (if there is one)
\\  Y2 coordinate of bottom edge (if there is one)
\\  Later on will also need dz or 1/dz to compute texture lookup

\\ Verts on side of a cube (square)

\\                F4
\\ 	Y        v4 +-->-+ v1                    +--+
\\ 	^    		^    |    F1		Rotation |  v
\\ 	|     	F3	|    v     
\\  +---> Z  v3 +-<--+ v2
\\                F2
v1x=64:v1y=64:v1z=64
v2x=64:v2y=-64:v2z=64
v3x=64:v3y=-64:v3z=-64
v4x=64:v4y=64:v4z=-64

PRINT "v1=(",v1y,v1z,") v2=(",v2y,v2z,") v3=",v3y,v3z,") v4=",v4y,v4z,")"

ALIGN 8
.texture_cube_rotations
IF 1
INCBIN "./data/raw/texture-cube-rotations.bin"
ELSE
FOR a,0,63,1			; brad
s = SIN(2 * PI * a / 256)
c = COS(2 * PI * a / 256)
\\ Rotate around X axis
\\ Project onto screen
\\ Pick the 2x visible faces

\\ Rotate around X axis
r1y = c*v1y - s*v1z
r1z = s*v1y + c*v1z
r2y = c*v2y - s*v2z
r2z = s*v2y + c*v2z
r3y = c*v3y - s*v3z
r3z = s*v3y + c*v3z
r4y = c*v4y - s*v4z
r4z = s*v4y + c*v4z

PRINT "a=",a," deg=",(360*a/256)
;PRINT "r1=(",r1y,r1z,") r2=(",r2y,r2z,") r3=",r3y,r3z,") r4=",r4y,r4z,")"

\\ Sides of the square (edge of the cube looking down X axis)
l1y = r2y-r1y : l1z = r2z-r1z
l2y = r3y-r2y : l2z = r3z-r2z
l3y = r4y-r3y : l3z = r4z-r3z
l4y = r1y-r4y : l4z = r1z-r4z

\\ Normals to the edges
n1z = l4z : n2z = l1z : n3z = l2z : n4z = l3z

\\ Only edges with positive Z component of normal are visible (facing camera at +ve Z)

;PRINT "l1y=",l1y,"l2y=",l2y,"l3y=",l3y,"l4y=",l4y
;PRINT "l1z=",l1z,"l2z=",l2z,"l3z=",l3z,"l4z=",l4z

IF n4z<-ERR
	PRINT "Face 4 visible: (",r4y,r4z,") -> (",r1y,r1z,")"
	PROJECT_FACE v4x,r4y,r4z,v1x,r1y,r1z, 128
ENDIF
IF n3z<-ERR
	PRINT "Face 3 visible: (",r3y,r3z,") -> (",r4y,r4z,")"
	PROJECT_FACE v3x,r3y,r3z,v4x,r4y,r4z, 0
ENDIF
IF n2z<-ERR
	PRINT "Face 2 visible: (",r2y,r2z,") -> (",r3y,r3z,")"
	PROJECT_FACE v2x,r2y,r2z,v3x,r3y,r3z, 128
ENDIF
IF n1z<-ERR
	PRINT "Face 1 visible: (",r1y,r1z,") -> (",r2y,r2z,")"
	PROJECT_FACE v1x,r1y,r1z,v2x,r2y,r2z, 0
ENDIF

faces=-((n4z<-ERR)+(n3z<-ERR)+(n2z<-ERR)+(n1z<-ERR))

IF faces=1
	PRINT "DUMMY FACE"
	EQUB 255,0,255,0,0		; repeat w=0 for 255 rows.
ELIF faces<>2
	ERROR "Somehow have",faces,"faces visible!!!"
ENDIF
NEXT
ENDIF

.texture_cube_table_LO
FOR n,0,63,1
EQUB LO(texture_cube_rotations+9*n)
NEXT

.texture_cube_table_HI
FOR n,0,63,1
EQUB HI(texture_cube_rotations+9*n)
NEXT

PAGE_ALIGN
.fx_texture_cube_vram_table_LO
FOR n,0,127,1
EQUB LO((&3000 + (n DIV 4)*640)/8)
NEXT

.fx_texture_cube_vram_table_HI
FOR n,0,127,1
EQUB HI((&3000 + (n DIV 4)*640)/8)
NEXT

\\ TODO:
\\  Load ptr to table in update.
\\  Display appropriate scanline double on appropriate raster lines.
\\  
