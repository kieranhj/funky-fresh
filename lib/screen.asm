\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	SCREEN LIBRARY
\ ******************************************************************

.wait_for_vsync
{
	lda #2
	.vsync1
	bit &FE4D
	beq vsync1
    sta &FE4D       ; or could be ack'd in IRQ
	rts
}

.wait_frames
{
    .loop
    jsr wait_for_vsync
    dex
    bne loop
    rts
}

.set_palette
{
    stx pal_loop+1
    sty pal_loop+2

	ldx #15
	.pal_loop
	lda mode4_default_palette, X
	sta &fe21
	dex
	bpl pal_loop
	rts
}

.show_screen
	lda #&c0        ; video enable
	equb &2c		; BIT abs
.hide_screen
	lda #&f0        ; video disable
{
	ldx #8:stx &fe00:sta &fe01      ; CRTC R8
	rts
}

; Y=to page, X=number of pages
.clear_pages
{
	sty write_to+2

	ldy #0
	lda #0
	.page_loop
	.write_to
	sta &ff00, Y
	iny
	bne page_loop
	inc write_to+2
	dex
	bne page_loop

	rts
}

IF 0
.set_mode4_fg_colour
{
    ora #&80:SET_PALETTE_REG
}
\\ fall through
.set_mode4_colours
{
    eor #&10:SET_PALETTE_REG
    eor #&30:SET_PALETTE_REG
    eor #&10:SET_PALETTE_REG
    eor #&70:SET_PALETTE_REG
    eor #&10:SET_PALETTE_REG
    eor #&30:SET_PALETTE_REG
    eor #&10:SET_PALETTE_REG
    rts
}

.set_mode4_bg_colour
{
    SET_PALETTE_REG
    jmp set_mode4_colours
}

.set_mode_4
{
    lda #ULA_Mode4
    sta &248
    sta &fe20
    rts
}

.set_mode_8
{
    lda #ULA_Mode8
    sta &248
    sta &fe20
    rts
}

.set_mode8_default_palette
{
    ldx #LO(mode8_default_palette)
    ldy #HI(mode8_default_palette)
    jmp set_palette
}

.set_all_black_palette
    lda #PAL_black
.set_all__palette
{
    .loop
    SET_PALETTE_REG
    clc
    adc #&10
    bcc loop
    rts
}
ENDIF