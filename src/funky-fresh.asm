\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	FUNKY FRESH DEMO FRAMEWORK
\ ******************************************************************

_DEBUG = TRUE

include "src/zp.h.asm"

\ ******************************************************************
\ *	OS defines
\ ******************************************************************

include "lib/bbc.h.asm"

\ ******************************************************************
\ *	MACROS
\ ******************************************************************

include "lib/macros.h.asm"
include "src/music_macros.asm"

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

; SCREEN constants
SCREEN_WIDTH_COLS = 80
SCREEN_HEIGHT_ROWS = 32 ; technically we're only displaying 30.
SCREEN_ROW_BYTES = SCREEN_WIDTH_COLS * 8
SCREEN_SIZE_BYTES = SCREEN_HEIGHT_ROWS * SCREEN_ROW_BYTES

screen_addr = &3000

; Exact time for a 50Hz frame less latch load time
FramePeriod = 312*64-2
; Exact time so that the FX draw function call starts at VCC=0,HCC=0.
; NB. Assumes vsync at scanline 272 (row 34) for 240 lines (30 rows) of visible display.
Timer1InitialValue = 38*64 - 2*64 - 60 -2
; Exact time of the visible portion of the display.
VisibleDisplayPeriod = 258*64 -4
; Exact time of the vblank portion of the display.
VBlankDisplayPeriod =  54*64	; -2
\ Need to fudge the two periods otherwise stabler raster NOP slide
\ requires more than the bottom 3 bits of the Timer 1 low counter.

\ UNUSED.
\KEY_PAUSE_INKEY = -56           ; 'P'
\KEY_STEP_FRAME_INKEY = -68      ; 'F'
\KEY_STEP_LINE_INKEY = -87       ; 'L'
\KEY_NEXT_PATTERN_INKEY = -86    ; 'N'
\KEY_RESTART_INKEY = -52         ; 'R'
\KEY_DISPLAY_INKEY = -51         ; 'D'

\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &00
GUARD rocket_zp_start

.zp_start

\\ Library ZP vars.
INCLUDE "lib/exo.h.asm"
INCLUDE "lib/vgcplayer.h.asm"

\\ System ZP vars.
;.readptr                skip 2
;.writeptr               skip 2
;.seed                   skip 2

.music_enabled          skip 1
.task_request           skip 1
.last_task_id			skip 1
.last_task_data			skip 1
.display_fx				skip 1
\\ TODO: Is delta_vsync actually needed?
.prev_vsync             skip 2
.delta_vsync            skip 1

\\ FX general ZP vars.
.row_count				skip 1
.prev_scanline			skip 1

\\ TODO: Move FX ZP vars?
\\ TODO: Give FX vars proper names!

\\ FX vertical stretch.
.v						skip 2
.dv						skip 2

\\ FX chunky twister.
.angle					skip 1
.ta						skip 2
.yb						skip 3
.xi						skip 2
.xy						skip 2
.shadow_bit             skip 1

\\ TODO: Local ZP vars?
.zp_end

include "src/rocket.h.asm"

\ ******************************************************************
\ *	BSS/DATA IN LOWER RAM
\ ******************************************************************

RELOC_SPACE = 0
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
    IF _DEBUG
    {
        \\ Print 'DEBUG' so we know which build it is!
        ldx #0
        .loop
        lda debug_filename, X
        jsr &ffee:inx:cpx #7:bcc loop
    }
    ENDIF

    \\ Init stack
    ldx #&ff:txs

    \\ Init ZP/
    inx
    lda #0
    .zp_loop
    sta &00, x
    inx
    cpx #zp_max	; TODO: Check if we need to keep SWRAM slots in ZP from Loader.
    bne zp_loop

    \\ TODO: Load banks and relocate data in a boot loader at &1900?
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

	\\ TODO: Put up loading screen here?
	\\ TODO: Progress bar?

    \\ Load music into SWRAM (if available)
    {
        SWRAM_SELECT SLOT_MUSIC
        ldx #LO(music_filename)
        ldy #HI(music_filename)
        lda #HI(&8000)
        jsr disksys_load_file
    }

    \\ Load SWRAM Banks
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

    IF 0
        SWRAM_SELECT SLOT_BANK2
        ldx #LO(bank2_filename)
        ldy #HI(bank2_filename)
        lda #HI(&8000)
        jsr disksys_load_file
    ENDIF
    }

    \\ Load HAZEL last as it trashes the FS workspace.
    IF 0
    {
        \\ Ensure HAZEL RAM is writeable.
        lda &fe34:ora #&8:sta &fe34

        ldx #LO(hazel_filename)
        ldy #HI(hazel_filename)
        lda #HI(hazel_start)
        jsr disksys_load_file
    }
    ENDIF

    \\ Set MODE w/out using MOS.
    \\ NB: This was done to avoid the flicker & garbage associated with MOS MODE change.
    \\ TODO: Move to boot loader?
    IF 1
    lda #22:jsr oswrch
    lda #2:jsr oswrch

	\\ Turn off cursor
	lda #10: sta &fe00
	lda #32: sta &fe01

	\\ Turn off interlace
	lda #8:sta &fe00
	lda #0:sta &fe01

    \\ Reduce screen to 240 lines.
    lda #6:sta &fe00
    lda #30:sta &fe01

    \\ Adjust vsync pos for 240 lines.
    lda #7:sta &fe00
    lda #34:sta &fe01

    {
        ldx #2
        lda #2
        .vsync1
        bit &FE4D
        beq vsync1
        sta &FE4D       ; or could be ack'd in IRQ
        dex
        bne vsync1
    }
    ELSE
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
    ENDIF

    \\ Init system
    ;lda &fe44:sta seed
    ;lda &fe45:sta seed+1
    jsr exo_init

    \\ Init music - has to be here for reload.
    SWRAM_SELECT SLOT_MUSIC
    lda #hi(vgm_stream_buffers)
    ldx #lo(vgc_data_tune)
    ldy #hi(vgc_data_tune)
    sec ; loop
    jsr vgm_init

    \\ Init sequence.
    IF _DEBUG=FALSE
    ldx #LO(rocket_data)
    ldy #HI(rocket_data)
    jsr rocket_init
    ENDIF

    \\ Complete any initial preload.
	\\ TODO: Initialise screens before sequence starts.

    \\ Init debug system here.

    \\ Late init.
	sei
    lda &fe4e:sta previous_ifr+1
    lda IRQ1V:sta old_irqv
    lda IRQ1V+1:sta old_irqv+1

	\\ Ensure the CRTC column counter is incrementing starting from a
	\\ known state with respect to the cycle stretching. Because the vsync
	\\ signal is reported via the VIA, which is a 1MHz device, the timing
	\\ could be out by 0.5 usec in 2MHz modes.
	\\
	\\ To fix: set R0=0, wait 256 cycles to ensure the horizontal counter
	\\ is stuck at 0, then set the horizontal counter to its correct
	\\ value. The 6845 is always accessed at 1MHz so the cycle counter
	\\ starts running on a 1MHz boundary.
	\\
	\\ Note: when R0=0, DRAM refresh is off. Don't delay too long.
	lda #0
	sta $fe00:sta $fe01
	WAIT_SCANLINES_ZERO_X 2
	sta $fe00:lda #127:sta $fe01

	\\ Wait for vsync
	{
		lda #2
        sta &fe4d
		.vsync1
		bit &fe4d
		beq vsync1
	}
	; Roughly synced to VSync

    ; Now fine tune by waiting just less than one frame
    ; and check if VSync has fired. Repeat until it hasn't.
    ; One frame = 312*128 = 39936 cycles
	{
		.syncloop
		sta &fe4d       ; 6
		ldx #209        ; 2
		.outerloop
		ldy #37         ; 2
		.innerloop
		dey             ; 2
		bne innerloop   ; 3/2 (innerloop = 5*37+2-1 = 186)
		dex             ; 2
		bne outerloop   ; 3/2 (outerloop = (186+2+3)*209+2-1 = 39920)
		bit &fe4D       ; 6
		bne syncloop    ; 3 (total = 39920+6+6+3 = 39935, one cycle less than a frame!)
		IF HI(syncloop) <> HI(P%)
		ERROR "This loop must execute within the same page"
		ENDIF
	}
    ; We are synced precisely with VSync!

	\\ Set up Timer1 to start at the first scanline
    lda #LO(Timer1InitialValue):sta &fe44		; 8c
    lda #HI(Timer1InitialValue):sta &fe45		; 8c

  	; Latch T1 to interupt at the end of the visible display.
	lda #LO(VisibleDisplayPeriod):sta &fe46
	lda #HI(VisibleDisplayPeriod):sta &fe47

	lda #&7F					; (disable all interrupts)
	sta &fe4e:sta &fe6e			; R14=Interrupt Enable
	sta &fe43					; R3=Data Direction Register "A" (set keyboard data direction)
	lda #&C0					; T1 Interrupt only.
	sta &fe4e					; R14=Interrupt Enable
    lda #64
    sta &fe4b			        ; T1 free-run mode

    lda #LO(irq_handler):sta IRQ1V
    lda #HI(irq_handler):sta IRQ1V+1		; set interrupt handler

	\\ TODO: Prime first frame of the VGC player to avoid spike?

    \\ Go!
    cli

    \\ Main loop!
    .loop
    {
        .wait_for_task
        lda task_request
        beq wait_for_task

        \\ Do our background task.
		jsr do_task

        dec task_request
    }
    jmp loop

    \\ TODO: Can we ever finish?
    .finished
    sei
    .previous_ifr
    lda #0:sta &fe4e            ; restore interrupts
    lda old_irqv:sta IRQ1V
    lda old_irqv+1:sta IRQ1V+1	; set interrupt handler
    cli
    jmp MUSIC_JUMP_SN_RESET
}

.irq_handler
{
	lda &fc:pha

    \\ Note that IFR will still be set with Vsync even if it didn't trigger an interrupt.
    bit &fe4d
    bvs visible_display_portion		; V=&40	**SELF MOD**
	.irq_handler_dest

	\\ Not SysVIA Timer 1 so return.
	pla:sta &fc
	rti

	.vblank_display_portion
	; T1 has already latched to its new value for the next interupt (visible potion)
	; Latch T1 for the next-plus_one interupt => at the end of the visible display.
	lda #LO(VisibleDisplayPeriod):sta &fe46
	lda #HI(VisibleDisplayPeriod):sta &fe47
	\\ Writing T1 high order latch also resets the T1 interrupt flag in IFR.
	
    txa:pha:tya:pha

    \\ NOTE: We have max 56 scanlines to do everything else in the system!
	IF _DEBUG
	jsr rocket_update_music

	lda music_enabled:pha
	beq music_paused
	ENDIF

    \\ Update music.
    MUSIC_JUMP_VGM_UPDATE
	.music_paused

    \\ Interpolate Rocket track values.
    jsr rocket_update_tracks

    \\ Process new Rocket track keys.
    IF _DEBUG=FALSE
    jsr rocket_update_keys
    ENDIF

	\\ Set up any new tasks.
	jsr tasks_update

	\\ Switch displayed FX before update fn.
	jsr display_fx_update

    \\ Update vsync count.
    IF _DEBUG
    pla:beq external_vsync
    ENDIF
    {
        inc rocket_vsync_count
        bne no_carry
        inc rocket_vsync_count+1
        .no_carry
    }
    IF _DEBUG
    .external_vsync
    {
        sec
        lda rocket_vsync_count+1:tay
        sbc prev_vsync+1
        lda rocket_vsync_count:tax
        sbc prev_vsync
        sta delta_vsync
        stx prev_vsync
        sty prev_vsync+1
    }
    ELSE
    lda #1:sta delta_vsync
    ENDIF
    \\ New frame effectively starts here!

    \\ Call FX update function.
	.^call_fx_update_fn
    jsr do_nothing

    pla:tay:pla:tax

	\\ Next IRQ will be the visible portion of the display.
	lda #(visible_display_portion-irq_handler_dest)
	sta irq_handler_dest-1

    IF _DEBUG
    {
        bit &fe4d
        bvc timer1_not_hit

        BRK ; we overran the frame!

        .timer1_not_hit
        lda &fe45
        .frame_time_remaining
    }
    ENDIF

    .return
	pla:sta &fc
	rti

	.visible_display_portion
    \\ Stabilise the raster.
    {
		\\ Reading the T1 low order counter also resets the T1 interrupt flag in IFR.
		lda &fe44

		\\ New stable raster NOP slide thanks to VectorEyes 8)
        ; Extract lowest 3 bits, use result to control a NOP slide. This corrects for timer jitter and provides stable raster.
        and #7
        eor #7
        sta branch+1
        .branch
        bpl branch \always
        .slide
        ; Note: this slide delays (CPU cycles) by TWICE the 'input' to the slide, which is
        ; what we want because the T1 counter is 1MHz, but the CPU runs at 2MHz.
        nop:nop:nop:nop
        nop:nop:cmp &93
		.stable
	}

	; T1 has already latched to its new value for the next interupt (vblank potion)
	; Latch T1 for the next-plus_one interupt => at the start of the visible display.
	lda #LO(VBlankDisplayPeriod):sta &fe46	; 8c
	lda #HI(VBlankDisplayPeriod):sta &fe47	; 8c

    txa:pha:tya:pha

    \\ Call FX draw function.
	.^call_fx_draw_fn
    jsr fx_default_crtc_draw		; restores CRTC regs to defaults.

    pla:tay:pla:tax

	\\ Next IRQ will be the vblank portion of the display.
	lda #(vblank_display_portion-irq_handler_dest)
	sta irq_handler_dest-1

	\ return
	pla:sta &fc
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

\ ******************************************************************
\ *	SYSTEM MODULES
\ ******************************************************************

include "src/display-fx.asm"
include "src/rocket.asm"
include "src/tasks.asm"

.main_end

\ ******************************************************************
\ *	DEMO MODULES
\ ******************************************************************

.fx_start

include "src/fx-vertical-stretch.asm"
include "src/fx-static-image.asm"
include "src/fx-chunky-twister.asm"

.fx_end

\ ******************************************************************
\ *	LIBRARY MODULES
\ ******************************************************************

.library_start
include "lib/disksys.asm"
;include "lib/screen.asm"
include "lib/exo.asm"
include "lib/cycles.asm"
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
.debug_filename     EQUS "DEBUG", 13,10
ENDIF

IF 0
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
ENDIF

include "src/assets-table.asm"

IF _DEBUG=FALSE
.rocket_data
incbin "build/funky-sequence.bin"
ENDIF

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
PRINT "ZP size =", ~zp_end-zp_start, "(",~rocket_zp_start-zp_end,"free)"
PRINT "ROCKET ZP size =", ~rocket_zp_end-rocket_zp_start, "(",~rocket_zp_reserved-rocket_zp_end,"free)"
PRINT "MAIN size =", ~main_end-main_start
PRINT "FX size =", ~fx_end-fx_start
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
