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

MACRO CHECK_SAME_PAGE_AS base
IF HI(P%-1) <> HI(base)
PRINT "WARNING! Table or branch base address",~base, "may cross page boundary at",~P%
ENDIF
ENDMACRO

MACRO SWRAM_SELECT slot
{
    LDA #slot:STA &F4:STA &FE30      ; "swram_slots_base + slot" for dynamic SWRAM.
}
ENDMACRO
