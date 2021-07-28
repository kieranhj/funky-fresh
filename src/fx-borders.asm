\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	BORDER FX
\ ******************************************************************

FX_BORDER_MAX=117

\ This update function is special as it must work in cooperation with
\ other FX to produce the top border effect without duplicating code.
\ Expectionations:
\   TODO: Complete expectations for use.
.fx_borders_update_top
{
    \\ Check bottom border first.
    lda rocket_track_bottom_border+1
    sta bottom_row_count
    beq no_bottom

    \\ Shorten the number of rows in the effect.
    clc
    lda row_count
    sbc bottom_row_count    ; +1
    sta row_count
    .no_bottom

    \\ Check we have a top border at all!
    lda rocket_track_top_border+1
    beq return
    cmp #FX_BORDER_MAX
    bcc ok
    lda #FX_BORDER_MAX
    .ok
    sta border_row_count

    \\ Store per-row callback fn.
    stx fx_borders_per_row_callback+1
    sty fx_borders_per_row_callback+2

    tay

    \\ Redirect actual FX draw fn to our own.
    lda call_fx_draw_fn+1
    sta fx_borders_call_actual_draw_fn+1
    lda call_fx_draw_fn+2
    sta fx_borders_call_actual_draw_fn+2

    \\ Install our own handler!
    lda #LO(fx_borders_draw_top)
    sta call_fx_draw_fn+1
    lda #HI(fx_borders_draw_top)
    sta call_fx_draw_fn+2

    \\ Set R12/R13 to our blank row.
    lda #13:sta &fe00
    lda #LO(blank_addr/8):sta &fe01
    lda #12:sta &fe00
    lda #HI(blank_addr/8):sta &fe01

    \\ Set colour palette for border.
    \\ TODO: Can we use the lower byte of the border track instead?
    lda rocket_track_top_colour+1
    eor #7
    sta &fe21

	lda #6:sta &fe00
	lda #1:sta &fe01		; R6=1 visible row.

    .return
    rts
}

\\ E.g. top_border = 1
\\ scanline = -2 <== HCC=0 enter fx_borders_draw_top fn        (hidden)
\\ scanline = -1
\\ scanline =  0 <== Must set CRTC regs.                       (border colour)
\\ scanline =  1     row_count--
\\ scanline =  2 <== HCC=0 enter original fx draw fn at "-2"   (border black)
\\ scanline =  3     row_count--
\\ scanline =  4 <== original draw fx fn starts display.       (fx display)

.fx_borders_draw_top
{
	\\ <=== HCC=0 (scanline=-2)

    \\ To get here border_row_count must be > 0.
    WAIT_SCANLINES_ZERO_X 1
    WAIT_CYCLES 104

    \\ Put actual FX draw fn back!
    lda fx_borders_call_actual_draw_fn+1    ; 4c
    sta call_fx_draw_fn+1                   ; 4c
    lda fx_borders_call_actual_draw_fn+2    ; 4c
    sta call_fx_draw_fn+2                   ; 4c

    \\ We burnt a row.
    dec row_count                           ; 5c

    \\ Tell next draw fn what scanline we finished on.
    stz prev_scanline                       ; 3c
    \\ 24c

	\\ <=== HCC=0 (scanline=0)

    \\ Can only set CRTC registers at the start of new cycle.
    ; R9=2 scanlines per row.
    lda #9:sta &fe00        ; 8c
    lda #1:sta &fe01		; 8c
    ; R4=1 total row.
    lda #4:sta &fe00        ; 8c
    lda #0:sta &fe01        ; 8c
    \\ 32c

    .loop
    {
    	\\ <=== HCC=32 (scanline=even)

        \\ Give caller 128c including JSR/RTS overhead.
        .*fx_borders_per_row_callback
        jsr &ffff
        \\ NB. Does not preserve registers!!

        	\\ <=== HCC=32 (scanline=odd)

            WAIT_CYCLES 64

            lda border_row_count; 3c
            cmp #2              ; 2c
            bcs still_colour
            ; 2c
            lda #PAL_black      ; 2c
            sta &fe21           ; 4c
            jmp continue        ; 3c
            .still_colour
            ; 3c
            WAIT_CYCLES 8
            .continue
            \\ 16c

            \\ We burnt a row.
            dec row_count       ; 5c

            \\ Need to loop until border_row_count = 0.
            dec border_row_count; 5c
            beq prepare_final_row
            ; 2c

            \\ <=== HCC=124 (scanline=odd)

        WAIT_CYCLES 33

        jmp loop                ; 3c
    }
    .prepare_final_row
    ; 3c
    \\ <=== HCC=125 (scanline=odd)

    \\ Must arrange timing to fool actual draw fn into thinking it was
    \\ called at effectively scanline=-2 (but actually top_border*2)

    .^fx_borders_call_actual_draw_fn
    jmp &FFFF                               ; 3c
    \\ <=== HCC=0 (scanline=even)
}


\\ E.g. bottom_border = 1
\\ scanline = 234 <== Original fx draw fn exits loop.           (display fx)
\\ scanline = 235 <== Set R12/R13 to blank chars.    
\\ scanline = 236 <== Start of next CRTC cycle w/ scanline=0    (border black)
\\ scanline = 237     
\\ scanline = 238 <== Must set CRTC regs for vsync.             (border colour)
\\ scanline = 239
\\ scanline = 240 <== return

.fx_borders_draw_bottom
{
    \\ <=== HCC=~0 (scanline=-6)
    \\ Scanline = top_border*2 + row_count

	\\ If prev_scanline=6 then R9=7
	\\ If prev_scanline=4 then R9=5
	\\ If prev_scanline=2 then R9=3
	\\ If prev_scanline=0 then R9=1
	{
		lda #9:sta &fe00            ; 8c
		clc                         ; 2c
		lda #1                      ; 2c
		adc prev_scanline           ; 3c
		sta &fe01                   ; 6c <= 5c
	}
    \\ 20c

    lda bottom_row_count            ; 3c
    beq fx_borders_no_bottom        ; 2c

    \\ We don't know exact timing but doesn't matter in this case.
    \\ Assume R4=0.

    \\ Set R12/R13 to our blank row.
    lda #13:sta &fe00               ; 8c
    lda #LO(blank_addr/8):sta &fe01 ; 8c
    lda #12:sta &fe00               ; 8c
    lda #HI(blank_addr/8):sta &fe01 ; 8c

    \\ <=== HCC=~57 (scanline=-6)
    \\ Must wait until next cycle and scanline=0.
    \\ CRTC is displaying last row of effect.
    WAIT_SCANLINES_ZERO_X 1
    WAIT_CYCLES 23
    lda #PAL_black                  ; 2c
    sta &fe21                       ; 4c
    WAIT_CYCLES 42

    \\ CRTC now displaying blank black chars.
    \\ <=== HCC=~0 (scanline=-4)

	lda #9:sta &fe00                ; 8c
	lda #1:sta &fe01                ; 8c

    .loop
    {
        \\ <=== HCC=~16 (scanline=even)

        WAIT_SCANLINES_ZERO_X 1
        WAIT_CYCLES 64

            \\ <=== HCC=~80 (scanline=odd)

            \\ Always set bg colour.
            lda rocket_track_bottom_colour+1; 3c
            eor #7                          ; 2c
            sta &fe21                       ; 4c

            WAIT_CYCLES 31

            dec bottom_row_count            ; 5c
            beq fx_borders_no_bottom        ; 2/3c

        WAIT_CYCLES 14
        jmp loop
    }
    \\ <=== HCC=~0 (scanline=-2)
}
\\ Fall through!
.fx_borders_no_bottom
{
	\\ Currently at scanline 119*2=238, need 312 lines total.
	\\ Remaining scanlines = 74 = 37 rows * 2 scanlines.
	lda #4: sta &FE00
	lda #36: sta &FE01

	\\ R7 vsync at scanline 272 = 238 + 17*2
	lda #7:sta &fe00
	lda #17:sta &fe01

	\\ Wait until scanline 240.
	WAIT_SCANLINES_ZERO_X 2

	\\ R9=1
	lda #9:sta &fe00
	lda #1:sta &fe01
	lda #0:sta prev_scanline

    lda #PAL_black                  ; 2c
    sta &fe21                       ; 4c
    rts
}
