\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	FUNKY FRESH DEMO
\ ******************************************************************

_DEBUG = TRUE
_DEBUG_RASTERS = TRUE

INCLUDE "src/zp.h.asm"

\ ******************************************************************
\ *	OS defines
\ ******************************************************************

\\ TODO: Move OS defines to bbc.h.asm.

osfile = &FFDD
oswrch = &FFEE
osasci = &FFE3
osbyte = &FFF4
osword = &FFF1
osfind = &FFCE
osgbpb = &FFD1
oscli  = &FFF7
osargs = &FFDA

IRQ1V = &204

\\ Palette values for ULA
PAL_black	= (0 EOR 7)
PAL_blue	= (4 EOR 7)
PAL_red		= (1 EOR 7)
PAL_magenta = (5 EOR 7)
PAL_green	= (2 EOR 7)
PAL_cyan	= (6 EOR 7)
PAL_yellow	= (3 EOR 7)
PAL_white	= (7 EOR 7)

ULA_Mode4   = &88
ULA_Mode8   = &E0

\ ******************************************************************
\ *	MACROS
\ ******************************************************************

\\ TODO: Move standard macros to macros.h.asm.

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

MACRO RESTORE_SLOT
{
    pla:sta &f4:sta &fe30
}
ENDMACRO

MACRO RND
{
    LDA seed
    ASL A
    ASL A
    CLC
    ADC seed
    CLC
    ADC #&45
    STA seed
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

include "src/music_macros.asm"

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

; SCREEN constants
SCREEN_WIDTH_PIXELS = 320
SCREEN_HEIGHT_PIXELS = 256
SCREEN_ROW_BYTES = SCREEN_WIDTH_PIXELS * 8 / 8
SCREEN_SIZE_BYTES = (SCREEN_WIDTH_PIXELS * SCREEN_HEIGHT_PIXELS) / 8

screen_addr = &3000

; Exact time for a 50Hz frame less latch load time
FramePeriod = 312*64-2
TimerValue = (32+254)*64 - 2*64

KEY_PAUSE_INKEY = -56           ; 'P'
KEY_STEP_FRAME_INKEY = -68      ; 'F'
KEY_STEP_LINE_INKEY = -87       ; 'L'
KEY_NEXT_PATTERN_INKEY = -86    ; 'N'
KEY_RESTART_INKEY = -52         ; 'R'
KEY_DISPLAY_INKEY = -51         ; 'D'

\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &00
GUARD zp_top

.zp_start

INCLUDE "lib/exo.h.asm"

.readptr            skip 2
.writeptr           skip 2
.music_enabled      skip 1

.task_request       skip 1
.seed               skip 2

INCLUDE "lib/vgcplayer.h.asm"

.zp_end

\ ******************************************************************
\ *	BSS DATA IN LOWER RAM
\ ******************************************************************

RELOC_SPACE = &300
ORG &D00 - RELOC_SPACE
GUARD &D00
.reloc_to_start
.reloc_to_end

\ ******************************************************************
\ *	CODE START
\ ******************************************************************

ORG &E00
GUARD screen_addr + RELOC_SPACE

.start
.main_start

\ ******************************************************************
\ *	Code entry
\ ******************************************************************

.main
{
    SEI
    lda &fe4e
    sta previous_ifr+1
	LDA #&7F					; (disable all interrupts)
	STA &FE4E					; R14=Interrupt Enable

    LDA IRQ1V:STA old_irqv
    LDA IRQ1V+1:STA old_irqv+1
    CLI

    \\ TODO: Load banks and relocate data in a boot loader at &1900.

	\\ Relocate data to lower RAM
    IF 0
	lda #HI(reloc_from_start)
	ldx #HI(reloc_to_start)
	ldy #HI(reloc_to_end - reloc_to_start + &ff)
	jsr disksys_copy_block
    ENDIF

    \\ Load debug in ANDY
    IF _DEBUG AND 0
    {
        SELECT_DEBUG_SLOT
        ldx #LO(debug_filename)
        ldy #HI(debug_filename)
        lda #HI(&8000)
        jsr disksys_load_file
    }
    ENDIF

    \\ Load music into SWRAM (if available)
    {
        SWRAM_SELECT SLOT_MUSIC
        ldx #LO(music_filename)
        ldy #HI(music_filename)
        lda #HI(&8000)
        jsr disksys_load_file
    }

    \\ Load Banks
    IF 0
    {
        SWRAM_SELECT SLOT_BANK0
        ldx #LO(bank0_filename)
        ldy #HI(bank0_filename)
        lda #HI(&8000)
        jsr disksys_load_file

        SWRAM_SELECT SLOT_BANK1
        ldx #LO(bank1_filename)
        ldy #HI(bank1_filename)
        lda #HI(&8000)
        jsr disksys_load_file

        SWRAM_SELECT SLOT_BANK2
        ldx #LO(bank2_filename)
        ldy #HI(bank2_filename)
        lda #HI(&8000)
        jsr disksys_load_file
    }
    ENDIF

    \\ Init stack
    ldx #&ff:txs

    \\ Init ZP
    lda #0
    ldx #0
    .zp_loop
    sta &00, x
    inx
    cpx #zp_top
    bne zp_loop

    \\ Load HAZEL last as it trashes the FS workspace.
    IF 0
    {
        \\ Ensure HAZEL RAM is writeable.
        LDA &FE34:ORA #&8:STA &FE34

        ldx #LO(hazel_filename)
        ldy #HI(hazel_filename)
        lda #HI(hazel_start)
        jsr disksys_load_file
    }
    ENDIF

    \\ Set MODE w/out using OS.
    \\ TODO: Remember why? To avoid any flicker / garbage? Move to boot loader.

	\\ Set CRTC registers
	ldx #0
	.crtc_loop
	stx &fe00
	lda mode4_crtc_regs, X
	sta &fe01
	inx
	cpx #14
	bcc crtc_loop

    \\ Set palette
    ldx #LO(mode4_default_palette)
    ldy #HI(mode4_default_palette)
	jsr set_palette

	\\ Set ULA register
	lda #ULA_Mode4
	sta &248			; OS copy
	sta &fe20

    \\ Clear screens
    ldy #HI(screen_addr)
    ldx #HI(&8000 - screen_addr)
    jsr clear_pages
    
    \\ TODO: Set CRTC address wraparound bits!

    \\ Init system
    lda &fe44:sta seed
    lda &fe45:sta seed+1

    \\ Init music - has to be here for reload.
    SWRAM_SELECT SLOT_MUSIC
    lda #hi(vgm_stream_buffers)
    ldx #lo(vgc_data_tune)
    ldy #hi(vgc_data_tune)
    sec ; loop
    jsr vgm_init

	\\ Set interrupts and handler
	SEI							; disable CPU interupts
    ldx #2: jsr wait_frames

	\\ Not stable but close enough for our purposes
	; Write T1 low now (the timer will not be written until you write the high byte)
    LDA #LO(TimerValue):STA &FE44
    ; Get high byte ready so we can write it as quickly as possible at the right moment
    LDX #HI(TimerValue):STX &FE45            ; start T1 counting		; 4c +1/2c 

  	; Latch T1 to interupt exactly every 50Hz frame
	LDA #LO(FramePeriod):STA &FE46
	LDA #HI(FramePeriod):STA &FE47

	LDA #&7F					; (disable all interrupts)
	STA &FE4E					; R14=Interrupt Enable
	STA &FE43					; R3=Data Direction Register "A" (set keyboard data direction)
	LDA #&C0					; 
	STA &FE4E					; R14=Interrupt Enable
    lda #64
    sta &fe4b                   ; T1 free-run mode

    LDA #LO(irq_handler):STA IRQ1V
    LDA #HI(irq_handler):STA IRQ1V+1		; set interrupt handler
    CLI

    \\ Init debug system here.

    \\ Complete any initial preload.

    \\ Start music player
    {
        inc music_enabled
    }

    \\ Go!
    jsr wait_for_vsync
    jsr show_screen

    \\ Main loop!
    .loop
    {
        .wait_for_task
        lda task_request
        beq wait_for_task

        \\ Do our background task.

        dec task_request
    }
    jmp loop

    .finished
    SEI
    .previous_ifr
    lda #0:sta &fe4e            ; restore interrupts
    LDA old_irqv:STA IRQ1V
    LDA old_irqv+1:STA IRQ1V+1	; set interrupt handler
    CLI
    JMP MUSIC_JUMP_SN_RESET
}

.irq_handler
{
	lda &FC
	pha

	lda &FE4D
	and #&40
	bne is_timer1_sysvia

 	.return
	pla
	sta &FC
	rti 

    .is_timer1_sysvia
	\\ Acknowledge vsync interrupt
	sta &FE4D

    \\ Play music
    txa:pha:tya:pha

    \\ Then update music - could be on a mid-frame timer.
    MUSIC_JUMP_VGM_UPDATE

    pla:tay:pla:tax

    .return2
	pla
	sta &FC
	rti
}

.old_irqv   EQUW &FFFF

.do_task
{
.^do_task_load_A
    lda #0
.^do_task_load_X
    ldx #0
.^do_task_load_Y
    ldy #0
.^do_task_jmp
    jmp do_nothing
}

.MUSIC_JUMP_SN_RESET
{
    SELECT_MUSIC_SLOT
    jsr sn_reset
    RESTORE_SLOT
}
.do_nothing
    rts

.main_end

\ ******************************************************************
\ *	FX MODULES
\ ******************************************************************

.fx_start
.fx_end

\ ******************************************************************
\ *	LIBRARY MODULES
\ ******************************************************************

.library_start
include "lib/disksys.asm"
include "lib/screen.asm"
include "lib/exo.asm"
.library_end

\ ******************************************************************
\ *	Preinitialised data
\ ******************************************************************

.data_start

.music_filename     EQUS "MUSIC", 13
.bank0_filename     EQUS "BANK0", 13
.bank1_filename     EQUS "BANK1", 13
.bank2_filename     EQUS "BANK2", 13
.hazel_filename     EQUS "HAZEL", 13
IF _DEBUG
.debug_filename     EQUS "DEBUG", 13
ENDIF

.mode4_default_palette
{
	EQUB &00 + PAL_black
	EQUB &10 + PAL_black
	EQUB &20 + PAL_black
	EQUB &30 + PAL_black
	EQUB &40 + PAL_black
	EQUB &50 + PAL_black
	EQUB &60 + PAL_black
	EQUB &70 + PAL_black
	EQUB &80 + PAL_white
	EQUB &90 + PAL_white
	EQUB &A0 + PAL_white
	EQUB &B0 + PAL_white
	EQUB &C0 + PAL_white
	EQUB &D0 + PAL_white
	EQUB &E0 + PAL_white
	EQUB &F0 + PAL_white
}

.mode4_crtc_regs
{
	EQUB 63    			    ; R0  horizontal total
	EQUB 32					; R1  horizontal displayed
	EQUB 45					; R2  horizontal position
	EQUB &24				; R3  sync width
	EQUB 38					; R4  vertical total
	EQUB 0					; R5  vertical total adjust
	EQUB 32					; R6  vertical displayed
	EQUB 35					; R7  vertical position
	EQUB &F0				; R8  no interlace; cursor off; display off
	EQUB 7					; R9  scanlines per row
	EQUB 32					; R10 cursor start
	EQUB 8					; R11 cursor end
	EQUB HI(screen_addr/8)	; R12 screen start address, high
	EQUB LO(screen_addr/8)	; R13 screen start address, low
}

.data_end

\ ******************************************************************
\ *	Relocatable data
\ ******************************************************************

PAGE_ALIGN
.reloc_from_start
.reloc_from_end

\ ******************************************************************
\ *	End address to be saved
\ ******************************************************************

.end

\ ******************************************************************
\ *	Save the executable
\ ******************************************************************

SAVE "build/FRESH", start, end, main

\ ******************************************************************
\ *	Space reserved for runtime buffers not preinitialised
\ ******************************************************************

ORG reloc_from_start
GUARD screen_addr

.bss_start
.bss_end

\ ******************************************************************
\ *	Memory Info
\ ******************************************************************

PRINT "------"
PRINT "FUNKY-FRESH!"
PRINT "------"
PRINT "ZP size =", ~zp_end-zp_start, "(",~zp_top-zp_end,"free)"
PRINT "MAIN size =", ~main_end-main_start
PRINT "LIBRARY size =",~library_end-library_start
PRINT "DATA size =",~data_end-data_start
PRINT "RELOC size =",~reloc_from_end-reloc_from_start
PRINT "BSS size =",~bss_end-bss_start
PRINT "------"
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~screen_addr-P%
PRINT "------"

\ ******************************************************************
\ *	Build RAM banks
\ ******************************************************************

INCLUDE "src/ram-banks.asm"
