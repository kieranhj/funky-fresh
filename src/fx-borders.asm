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
    \\ Check we have a top border at all!
    ldy rocket_track_top_border+1
    beq return
    cpy #FX_BORDER_MAX
    bcc ok
    ldy #FX_BORDER_MAX
    .ok
    sty border_row_count

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

\\ E.g. top_borders = 1
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
    WAIT_CYCLES 101

    \\ Put actual FX draw fn back!
    lda fx_borders_call_actual_draw_fn+1    ; 4c
    sta call_fx_draw_fn+1                   ; 4c
    lda fx_borders_call_actual_draw_fn+2    ; 4c
    sta call_fx_draw_fn+2                   ; 4c

    \\ We burnt a row.
    dec row_count                           ; 5c

    \\ Tell next draw fn what scanline we finished on.
    stx prev_scanline                       ; 3c

    \\ Need to count until border_row_count = 0.
    ldy border_row_count                    ; 3c
    \\ 27c

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

	    WAIT_SCANLINES_ZERO_X 1

        	\\ <=== HCC=32 (scanline=odd)

            WAIT_CYCLES 70

            cpy #2              ; 2c
            bcs still_colour
            ; 2c
            lda #PAL_black      ; 2c
            sta &fe21           ; 4c
            jmp continue        ; 3c
            .still_colour
            ; 3c
            WAIT_CYCLES 8
            .continue
            \\ 13c

            \\ We burnt a row.
            dec row_count       ; 5c

            \\ border_row_count--
            dey                 ; 2c
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
