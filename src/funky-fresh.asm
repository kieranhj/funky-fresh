\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	FUNKY FRESH DEMO FRAMEWORK
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

include "lib/macros.h.asm"

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
; Exact time so that the FX draw function call starts at VCC=0,HCC=0.
TimerValue1 = 32*64 - 2*64 - 54 -2
; Exact time so that everything else happens at scanline 256.
TimerValue2 = 32*64 + 256*64 - 2*64 - 52 -2

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

.readptr                skip 2
.writeptr               skip 2
.row_count				skip 1

.music_enabled          skip 1
.task_request           skip 1
.seed                   skip 2

INCLUDE "lib/vgcplayer.h.asm"

.v						skip 2
.dv						skip 2
.prev_scanline			skip 1

CLEAR &90, &9F
ORG &90
GUARD &9C
.zoom					skip 1

rocket_vsync_count = &9c
rocket_audio_flag = &9e
rocket_fast_mode = &9f

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
        lda &fe34:ORA #&8:sta &fe34

        ldx #LO(hazel_filename)
        ldy #HI(hazel_filename)
        lda #HI(hazel_start)
        jsr disksys_load_file
    }
    ENDIF

    \\ Set MODE w/out using MOS.
    \\ NB: This was done to avoid the flicker & garbage associated with MOS MODE change.
    \\ TODO: Move to boot loader.
    IF 1
    lda #22:jsr oswrch
    lda #2:jsr oswrch

	\\ Turn off cursor
	lda #10: sta &fe00
	lda #32: sta &fe01

	\\ Turn off interlace
	lda #8:sta &fe00
	lda #0:sta &fe01
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
    lda &fe44:sta seed
    lda &fe45:sta seed+1
    jsr exo_init

    \\ Init music - has to be here for reload.
    SWRAM_SELECT SLOT_MUSIC
    lda #hi(vgm_stream_buffers)
    ldx #lo(vgc_data_tune)
    ldy #hi(vgc_data_tune)
    sec ; loop
    jsr vgm_init

    \\ Complete any initial preload.
    ldx #LO(exo_data)
    ldy #HI(exo_data)
    lda #HI(screen_addr)
    jsr decrunch_to_page_A

    \\ Init debug system here.

    \\ Late init.
   	lda #0:sta zoom

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
	ldx #2:jsr cycles_wait_scanlines
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
    lda #LO(TimerValue1):sta &fe44		; 8c
    lda #HI(TimerValue1):sta &fe45		; 8c

    lda #LO(TimerValue2):sta &fe64		; 8c
    lda #HI(TimerValue2):sta &fe65		; 8c

  	; Latch T1 to interupt exactly every 50Hz frame
	lda #LO(FramePeriod):sta &fe46:sta &fe66		; 8c
	lda #HI(FramePeriod):sta &fe47:sta &fe67		; 8c

	lda #&7F					; (disable all interrupts)
	sta &fe4e:sta &fe6e			; R14=Interrupt Enable
	sta &fe43					; R3=Data Direction Register "A" (set keyboard data direction)
	lda #&C0					; 
	sta &fe4e:sta &fe6e			; R14=Interrupt Enable
    lda #64
    sta &fe4b:sta &fe6b         ; T1 free-run mode

    lda #LO(irq_handler):sta IRQ1V
    lda #HI(irq_handler):sta IRQ1V+1		; set interrupt handler

	\\ Prime first frame of the VGC player.
;	MUSIC_JUMP_VGM_UPDATE

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
    lda &fe4d
    and #&40
    bne is_timer1_sysvia

	lda &fe6d
	and #&40
	beq return

	.is_timer1_uservia
	sta &fe6d
    txa:pha:tya:pha

    \\ NOTE: Assuming this returns after 256 scanlines then we have
    \\ just 56 scanlines left to do everything else in the system!
	IF _DEBUG
	jsr rocket_update_music

	lda music_enabled
	beq music_paused
	ENDIF

    \\ Update music.
    MUSIC_JUMP_VGM_UPDATE

    \\ Update vsync count.
    {
        inc rocket_vsync_count
        bne no_carry
        inc rocket_vsync_count+1
        .no_carry
    }
	.music_paused

	\\ Need to update 'script' here.
	\\ Switch displayed FX before update fn.

    \\ Call FX update function.
    jsr fx_update_function

    pla:tay:pla:tax

    .return
	pla:sta &fc
	rti

    .is_timer1_sysvia
    sta &fe4d

    \\ Stabilise the raster.
    {
		\\ Reading the T1 low order counter also resets the T1 interrupt flag in IFR
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

    txa:pha:tya:pha

    \\ Call FX draw function.
    jsr fx_draw_function

    pla:tay:pla:tax
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
\ *	HELPER FUNCTIONS
\ ******************************************************************

.cycles_wait_128		; JSR to get here takes 6c
{
	WAIT_CYCLES 128-6-6
	RTS					; 6c
}						; = 128c

.cycles_wait_scanlines	; 6c
{
	WAIT_CYCLES 128-6-2-3-6

	.loop
	dex					; 2c
	beq done			; 2/3c

	WAIT_CYCLES 121

	jmp loop			; 3c

	.done
	RTS					; 6c
}

.main_end

\ ******************************************************************
\ *	FX MODULES
\ ******************************************************************

.fx_start

\ Arrive at VCC=0,HCC=0.
\ Assume horizontal registers are default but vertical registers
\ might be left in a ruptured state. Reset these to defaults.
.fx_draw_default_crtc
{
	lda #9:sta &fe00		; R9=7
	lda #7:sta &fe01

	lda #4:sta &fe00		; R4=38
	lda #38:sta &fe01

	lda #7:sta &fe00		; R7=35
	lda #35:sta &fe01

	lda #6:sta &fe00		; R6=32
	lda #32:sta &fe01

	rts
}

\ ******************************************************************
\ Update FX
\
\ The update function is used to update / tick any variables used
\ in the FX. It may also prepare part of the screen buffer before
\ drawing commenses but note the strict timing constraints!
\
\ This function will be called during vblank, after any system
\ modules have been polled.
\
\ The function MUST COMPLETE BEFORE TIMER 1 REACHES 0, i.e. before
\ raster line 0 begins. If you are late then the draw function will
\ be late and your raster timings will be wrong!
\ ******************************************************************

.fx_update_function
{
	ldx zoom
	lda dv_table_LO, X
	sta dv
	lda dv_table_HI, X
	sta dv+1

	\\ Set v
	lda #0:sta v:sta v+1

IF 0
	\\ Want centre of screen to be centre of sprite.
	lda #0:sta v
	lda #128:sta v+1

	\\ Subtract dv 128 times to set starting v.
	ldy #64
	.sub_loop
	sec
	lda v
	sbc dv
	sta v
	lda v+1
	sbc dv+1
	sta v+1

	dey
	bne sub_loop
ENDIF

	\\ Set CRTC start address of row 0.
	lsr a:tax
	lda #13:sta &fe00
	lda vram_table_LO, X
	sta &fe01
	lda #12:sta &fe00
	lda vram_table_HI, X
	sta &fe01

	\\ Scanline of row 0 is always 0.
	lda #0
	sta prev_scanline
	rts
}

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

\\ Limited RVI
\\ Display 0,2,4,6 scanline offset for 2 scanlines.
\\ <--- 102c total w/ 80c visible and hsync at 98c ---> <2c> ..13x <2c> = 128c
\\ Plus one extra for luck!
\\ R9 = 13 + current - next

PAGE_ALIGN
.fx_draw_function
{
	\\ <=== HCC=0

	\\ R4=0
	lda #4:sta &fe00					; 8c
	lda #0:sta &fe01					; 8c

	\\ R7 vsync at row 35 = scanline 280.
	lda #7:sta &fe00					; 8c
	lda #3:sta &fe01					; 8c

	\\ R6=1
	lda #6:sta &fe00					; 8c
	lda #1:sta &fe01					; 8c
	\\ 48c

	\\ Update v
	clc:lda v:adc dv:sta v				; 11c
	lda v+1:adc dv+1:sta v+1			; 9c
	\\ 20c

	\\ Row 1 screen start
	lsr a:tax							; 4c
	lda #13:sta &fe00					; 8c
	lda vram_table_LO, X				; 4c
	sta &fe01							; 6c
	lda #12:sta &fe00					; 8c
	lda vram_table_HI, X				; 4c
	sta &fe01							; 6c
	\\ 40c
	
	\\ Row 1 scanline
	lda #9:sta &fe00					; 8c
	lda v+1:and #6						; 5c
	\\ 2-bits * 2
	tax									; 2c
	eor #&ff							; 2c
	sec									; 2c
	adc #13								; 2c
		clc									; 2c
		adc prev_scanline					; 3c
		sta &fe01							; 6c
		stx prev_scanline					; 3c
		\\ 35c

		lda #126:sta row_count				; 5c

		\\ Set R0=101 (102c)
		lda #0:sta &fe00					; 8c
		lda #101:sta &fe01					; 8c

		WAIT_CYCLES 58

		\\ At HCC=102 set R0=1.
		lda #1:sta &fe01					; 8c
		\\ Burn 13 scanlines = 13x2c = 26c
		WAIT_CYCLES 18

	\\ Now 2x scanlines per loop.
	.char_row_loop
	{
			\\ At HCC=0 set R0=127
			lda #127:sta &fe01		; 8c
		
		\\ <=== HCC=0
		\\ Update v
		clc:lda v:adc dv:sta v				; 11c
		lda v+1:adc dv+1:sta v+1			; 9c
		\\ 20c

		\\ Row N+1 screen start
		lsr a:tax							; 4c
		lda #13:sta &fe00					; 8c
		lda vram_table_LO, X				; 4c
		sta &fe01							; 6c
		lda #12:sta &fe00					; 8c
		lda vram_table_HI, X				; 4c
		sta &fe01							; 6c
		\\ 40c
	
		\\ NB. Must set R9 before final scanline of the row!
		\\ Row N+1 scanline
		lda #9:sta &fe00				; 8c
		lda v+1:and #6					; 5c
		\\ 2-bits * 2
		tax								; 2c
		eor #&ff						; 2c
		sec								; 2c
		adc #13							; 2c
		clc								; 2c
		adc prev_scanline				; 3c
		sta &fe01						; 6c
		stx prev_scanline				; 3c
		\\ 35c

		\\ 33c
			WAIT_CYCLES 68		\\ <=== HCC=0
			\\ 35c

			\\ Set R0=101 (102c)
			lda #0:sta &fe00				; 8c <= 7c
			lda #101:sta &fe01				; 8c

			WAIT_CYCLES 44

			\\ At HCC=102 set R0=1.
			lda #1:sta &fe01				; 8c
			\\ Burn 13 scanlines = 13x2c = 26c
			WAIT_CYCLES 10

			dec row_count				; 5c
			bne char_row_loop			; 3c
	}
	CHECK_SAME_PAGE_AS char_row_loop
	.scanline_last

		ldx #1						; 2c
		\\ At HCC=0 set R0=127
		lda #127:sta &fe01			; 8c <= 7c
	
	\\ <=== HCC=0
	jsr cycles_wait_scanlines	

		\\ <=== HCC=0
		\\ Set next scanline back to 0.
		lda #9:sta &fe00			; 8c
		clc							; 2c
		lda #13						; 2c
		adc prev_scanline			; 3c
		sta &fe01					; 6c

		lda #6:sta &fe00			; 8c <= 7c
		lda #0:sta &fe01			; 8c
		\\ 36c

		\\ Set R0=101 (102c)
		lda #0:sta &fe00			; 8c
		lda #101:sta &fe01			; 8c

		WAIT_CYCLES 42

		\\ At HCC=102 set R0=1.
		lda #1:sta &fe01			; 8c
		\\ Burn 13 scanlines = 13x2c = 26c
		WAIT_CYCLES 18

		lda #127:sta &fe01			; 8c
	\\ <=== HCC=0

	\\ R9=7
	.scanline_end_of_screen
	lda #9:sta &fe00
	lda #7:sta &fe01

	\\ Total 312 line - 256 = 56 scanlines
	lda #4: sta &fe00
	lda #6: sta &fe01
    RTS
}

.fx_end

\ ******************************************************************
\ *	ROCKET MODULES
\ ******************************************************************

.rocket_update_music
{
	lda rocket_audio_flag
	cmp music_enabled
	beq return

	sta music_enabled
	cmp #0
	beq pause

	lda task_request
	bne task_running

	\\ Play from new position.
	;lda #&ff:sta rocket_fast_mode	; turbo mode on!
	ldx rocket_vsync_count:stx do_task_load_X+1
	ldy rocket_vsync_count+1:sty do_task_load_Y+1
	lda #LO(rocket_set_pos):sta do_task_jmp+1
	lda #HI(rocket_set_pos):sta do_task_jmp+2
	inc task_request

	.task_running
	lda #0:sta music_enabled
	\\ This takes a long time so can't be done in IRQ.
	\\ Options:
	\\ - run this as a background task?
	\\ - restart the demo and play from the beginning?!
	;jsr vgm_seek					; sloooow.
	;lda #0:sta rocket_fast_mode		; turbo mode off!
	.return
	rts

	.pause
	\\ Kill sound.
	jmp MUSIC_JUMP_SN_RESET
}

.rocket_set_pos
{
	lda #&ff:sta rocket_fast_mode	; turbo mode on!
	jsr vgm_seek					; sloooow.
	lda #0:sta rocket_fast_mode		; turbo mode off!
	lda #1:sta music_enabled
	rts
}

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

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN_FOR_SIZE 128
.vram_table_LO
FOR n,0,127,1
EQUB LO((&3000 + (n DIV 4)*640)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 128
.vram_table_HI
FOR n,0,127,1
EQUB HI((&3000 + (n DIV 4)*640)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 128
.dv_table_LO
FOR n,0,63,1
height=128
max_height=height*10
h=128+n*(max_height-height)/63
dv = 512 * height / h
;PRINT h, height/h, dv
EQUB LO(dv)
NEXT

PAGE_ALIGN_FOR_SIZE 128
.dv_table_HI
FOR n,0,63,1
height=128
max_height=1280
h=128+n*(max_height-height)/63
dv = 512 * height / h
EQUB HI(dv)
NEXT

.exo_data
INCBIN "build/logo-mode2.exo"

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
