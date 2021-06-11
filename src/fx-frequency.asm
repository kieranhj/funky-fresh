\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	FREQUENCY FX
\ ******************************************************************

\\ TODO: Describe the FX and requirements.

FX_FREQ_PAL_START = 8
FX_FREQ_PAL_END = 7     ; PAL_black
FX_FREQ_ROWS = 8
FX_FREQ_COLS = 8
FX_FREQ_MAX = FX_FREQ_ROWS * FX_FREQ_COLS
VGC_FREQ_MAX = 64

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

.vgc_freq_array
FOR n,0,FX_FREQ_MAX-1,1
EQUB FX_FREQ_PAL_END
NEXT

.fx_frequency_update
{
	; clear bit 0 to display MAIN.
	lda &fe34:and #&fe:sta &fe34
	; Set R12/R13 for full screen.
	lda #12:sta &fe00
	lda #HI(static_image_scrn_addr/8):sta &fe01
	lda #13:sta &fe00
	lda #LO(static_image_scrn_addr/8):sta &fe01

    ; R6=240 visible lines.
	lda #6:sta &fe00        ; 8c
	lda #30:sta &fe01		; 8c
}
\\ Drop through!
.fx_frequency_update_grid
{
    \\ Fade all frequencies.
    IF 0
    ldx #VGC_FREQ_MAX-1
    .fade_loop
    ldy vgc_freq_array, X
    lda fx_freq_next_pal_value, Y ; next colour
    sta vgc_freq_array, X
    dex
    bpl fade_loop
    ELSE
    FOR x,0,VGC_FREQ_MAX-1,1
    ldy vgc_freq_array+x
    lda fx_freq_next_pal_value, Y ; next colour
    sta vgc_freq_array+x
    NEXT
    ENDIF

    \\ Check VGC registers values for new notes.
    ldx #2
    .loop
    lda vgm_fx+VGM_FX_TONE0_HI, X       ; current tone value for channel X
    cmp vgc_reg_copy+VGM_FX_TONE0_HI, X
    bne make_note

    lda vgm_fx+VGM_FX_TONE0_LO, X       ; current tone value for channel X
    cmp vgc_reg_copy+VGM_FX_TONE0_LO, X
    bne make_note

    lda vgm_fx+VGM_FX_VOL0, X           ; current volume value for channel X
    cmp vgc_reg_copy+VGM_FX_VOL0, X
    beq loop_cont

    .make_note
    lda #FX_FREQ_PAL_START          ; no. frames of fade
    ldy vgm_fx+VGM_FX_TONE0_HI, X   ; top 6-bits of tone value for channel X
    ; could invert the freq index here?
    sta vgc_freq_array, Y
    lda vgm_fx+VGM_FX_TONE0_LO, X   ; bottom 4-bits of tone value for channel X
    asl a
    tay
    ; could invert the freq index here?
    lda #FX_FREQ_PAL_START          ; no. frames of fade
    sta vgc_freq_array, Y

    .loop_cont
    dex
    bpl loop

    \\ Copy VGC registers.
    IF 0
    ldx #VGM_FX_MAX-1
    .copy_loop
    lda vgm_fx, X
    sta vgc_reg_copy, X
    dex
    bpl copy_loop
    ELSE
    FOR x,0,VGM_FX_MAX-1,1
    lda vgm_fx+x
    sta vgc_reg_copy+x
    NEXT
    ENDIF
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

.fx_frequency_draw
{
    \\ 240 lines split into 6 rows = 40 lines per row.
    \\ 80 columns split into 8 stripes = 10 columns per stripe.
    \\ Set colours JIT before the corresponding stripe.
    \\ Keep colours for 38 scanlines and set 2 lines of black.
    \\ To set colour:

    WAIT_SCANLINES_ZERO_X 1
    WAIT_CYCLES 100

    \\ Y=row offset
    ldy #0                              ; 2c

    .row_loop
    \\ <== HCC=102 (scanline=-1)

    WAIT_CYCLES 16

    FOR stripe,0,7,1
    lda vgc_freq_array+stripe, Y        ; 4c
    ora #&80+(stripe*&10)               ; 2c column <= could factor out?
    sta &fe21                           ; 4c
    NEXT
    \\ 10c * 8 = 80c

    \\ <== HCC=70 (scanline=0) so that colour is set before final stripe displayed.

    \\ Need to set CRTC vertical regs to static screen before scanline 1!
    ; R9=8 scanlines per row (default).
	lda #9:sta &fe00        ; 8c
	lda #7:sta &fe01		; 8c

    ; R4=312 total lines.
	lda #4:sta &fe00        ; 8c
	lda #38:sta &fe01		; 8c

    ; R7=vsync at line 272.
	lda #7:sta &fe00        ; 8c
	lda #34:sta &fe01		; 8c
    \\ 48c

    WAIT_CYCLES 80
    WAIT_SCANLINES_ZERO_X 26

    \\ <== HCC=70 (scanline=37)
    FOR stripe,0,7,1
    lda #&80+(stripe*&10)+PAL_black     ; 2c
    sta &fe21                           ; 4c
    NEXT
    \\ 6c * 8 = 48c

    \\ <== HCC=118 (scanline=37)
    WAIT_CYCLES 97
    WAIT_SCANLINES_ZERO_X 1

    \\ <== HCC=87 (scanline=39)
    tya                                 ; 2c
    clc                                 ; 2c
    adc #8                              ; 2c
    tay                                 ; 2c
    cpy #FX_FREQ_MAX                    ; 2c
    bcs done                            ; 2c
    jmp row_loop                        ; 3c
    CHECK_SAME_PAGE_AS row_loop, FALSE
    .done

    ; Set line displayed at scanline -2.
    lda #6                  ; 2c
	sta prev_scanline		; 3c
    rts
}

.vgc_reg_copy       skip VGM_FX_MAX

\\ white -> yellow -> cyan -> green -> magenta -> red -> blue -> black

.fx_freq_next_pal_value
equb &0C                  ; &00 PAL_white (7) (ii)
equb &0D                  ; &01 PAL_cyan (6) (vi)
equb &0E                  ; &02 PAL_magenta (5) (viii)
equb &0F                  ; &03 PAL_blue (4) (xiv)
equb &09                  ; &04 PAL_yellow (3) (iv)
equb &0A                  ; &05 PAL_green (2) (x)
equb &0B                  ; &06 PAL_red (1) (xii)
equb &07                  ; &07 PAL_black (0) (xvi) <-- ends here!
equb &00                  ; &08 PAL_white (15) (i)  <-- starts here!
equb &01                  ; &09 PAL_cyan (14) (v)
equb &02                  ; &0A PAL_magenta (13) (vii)
equb &03                  ; &0B PAL_blue (12) (xiii)
equb &04                  ; &0C PAL_yellow (11) (iii)
equb &05                  ; &0D PAL_green (10) (ix)
equb &06                  ; &0E PAL_red (9) (xi)
equb &07                  ; &0F PAL_black (8) (xv)
