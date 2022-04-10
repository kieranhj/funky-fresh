\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	UNIVERSAL HANDY MACROS
\ ******************************************************************

MACRO WAIT_NOPS n
PRINT "WAIT",n," CYCLES AS NOPS"

IF n < 0
	ERROR "Can't wait negative cycles!"
ELIF n=0
	; do nothing
ELIF n=1
	EQUB $33
	PRINT "1 cycle NOP is Master only and not emulated by b-em."
ELIF (n AND 1) = 0
	FOR i,1,n/2,1
	NOP
	NEXT
ELSE
	BIT 0
	IF n>3
		FOR i,1,(n-3)/2,1
		NOP
		NEXT
	ENDIF
ENDIF
ENDMACRO

MACRO WAIT_CYCLES n
PRINT "WAIT",n," CYCLES"
IF n >= 12
	FOR i,1,n/12,1
	JSR do_nothing
	NEXT
	WAIT_NOPS n MOD 12
ELSE
	WAIT_NOPS n
ENDIF
ENDMACRO

MACRO WAIT_SCANLINES_PRESERVE_REGS no_scanlines
{
	pha:txa:pha			; 8c
	ldx #no_scanlines	; 2c
	jsr cycles_wait_scanlines_minus_20c
	pla:tax:pla			; 10c
}
ENDMACRO

MACRO WAIT_SCANLINES_ZERO_X no_scanlines
{
	ldx #no_scanlines	; 2c
	jsr cycles_wait_scanlines_minus_2c
}
ENDMACRO

MACRO PAGE_ALIGN
H%=P%
ALIGN &100
PRINT "Lost ", P%-H%, "bytes"
ENDMACRO

MACRO PAGE_ALIGN_FOR_SIZE size
IF HI(P%+size) <> HI(P%)
	PAGE_ALIGN
ENDIF
ENDMACRO

MACRO CODE_ALIGN size
PRINT "Lost ", size, "bytes for code alignment."
skip size
ENDMACRO

MACRO CHECK_SAME_PAGE_AS base, fatal
IF HI(P%-1) <> HI(base)
PRINT "WARNING! Table or branch base address",~base, "may cross page boundary at",~P%
IF fatal
	ERROR "Crossing page boundary caused critical cycle timing error."
ENDIF
ENDIF
ENDMACRO

MACRO SWRAM_SELECT slot
{
    LDA #slot:STA &F4:STA &FE30      ; "swram_slots_base + slot" for dynamic SWRAM.
}
ENDMACRO

MACRO RND
{
    lda seed
    asl A
    asl A
    clc
    adc seed
    clc
    adc #&45
    sta seed
}
ENDMACRO

MACRO RND16
{
    lda seed+1
    lsr a
    rol seed
    bcc no_eor
    eor #&b4
    .no_eor
    sta seed+1
    eor seed
}
ENDMACRO

MACRO TELETEXT_ENABLE_6
	LDA #&F6:STA &FE20				; +6
ENDMACRO

MACRO TELETEXT_ENABLE_7
	LDA teletext_enable:STA &FE20	; +7
ENDMACRO

MACRO TELETEXT_DISABLE_6
	LDA #&F4:STA &FE20				; +6
ENDMACRO

MACRO TELETEXT_DISABLE_7
	LDA teletext_disable:STA &FE20	; +7
ENDMACRO
