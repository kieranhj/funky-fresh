\ ******************************************************************
\ *	BANK 0:
\ ******************************************************************

CLEAR &8000, &C000
ORG &8000
GUARD &C000
.bank0_start

.exo_asset_doom_mode2
INCBIN "build/doom-screen.exo"

.exo_asset_scr_mode2
INCBIN "build/scr-screen.exo"

.bank0_end

SAVE "build/BANK0", bank0_start, bank0_end, bank0_start

PRINT "------"
PRINT "BANK 0"
PRINT "------"
PRINT "SIZE =", ~bank0_end-bank0_start
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"

\ ******************************************************************
\ *	BANK 1:
\ ******************************************************************

CLEAR &8000, &c000
ORG &8000
GUARD &C000
.bank1_start

\\ TODO: Generate bank of assets and labels etc. automatically from one list.
.exo_asset_logo_mode2
INCBIN "build/logo-mode2.exo"

.exo_asset_twister_1
INCBIN "build/twister1-mode2.exo"

.exo_asset_twister_2
INCBIN "build/twister2-mode2.exo"

.exo_asset_stripes
INCBIN "build/logo-with-stripes-mode2.exo"

.exo_asset_zoom
INCBIN "build/zoom-screen.exo"

.exo_asset_checks_1
INCBIN "build/checks-bitmask-0-to-3.exo"

.exo_asset_checks_2
INCBIN "build/checks-bitmask-4-to-7.exo"

.exo_asset_diagonals
INCBIN "build/diagonals-16.exo"

.bank1_end

SAVE "build/BANK1", bank1_start, bank1_end, bank1_start

PRINT "------"
PRINT "BANK 1"
PRINT "------"
PRINT "SIZE =", ~bank1_end-bank1_start
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"

\ ******************************************************************
\ *	BANK 2: 
\ ******************************************************************

CLEAR &8000, &C000
ORG &8000
GUARD &C000
.bank2_start

\ ******************************************************************
\ *	DEMO MODULES
\ ******************************************************************

.fx_start
\\ v------ NB. Currently assuming all FX in same SWRAM bank!!
include "src/fx-vertical-stretch.asm"
include "src/fx-static-image.asm"
include "src/fx-chunky-twister.asm"
include "src/fx-frequency.asm"
include "src/fx-stretch-grid.asm"
include "src/fx-frak-zoomer.asm"
include "src/fx-checker-zoom.asm"
include "src/fx-spin-bar.asm"
include "src/fx-palette-wipe.asm"
include "src/fx-path-zoom.asm"
\\ ^------ NB. Currently assuming all FX in same SWRAM bank!!
.fx_end

.bank2_end

SAVE "build/BANK2", bank2_start, bank2_end, bank2_start

PRINT "------"
PRINT "BANK 2"
PRINT "------"
PRINT "FX size =", ~fx_end-fx_start
PRINT "SIZE =", ~bank2_end-bank2_start
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"

\ ******************************************************************
\ *	BANK 3: MUSIC
\ ******************************************************************

CLEAR &8000, &C000
ORG &8000
GUARD &C000
.bank3_start
.music_start
include "src/music.asm"
.music_end

.exo_asset_path_zoom
INCBIN "build/path-zoom-256.exo"

.exo_asset_cube_widths
INCBIN "build/cube-widths-128.exo"

.bank3_end

\ ******************************************************************
\ *	Space reserved for runtime buffers not preinitialised
\ ******************************************************************

.music_bss_start
PAGE_ALIGN
.vgm_buffer_start
; reserve space for the vgm decode buffers (8x256 = 2Kb)
.vgm_stream_buffers
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256
.vgm_buffer_end
.music_bss_end

SAVE "build/MUSIC", bank3_start, bank3_end, bank3_start

PRINT "------"
PRINT "BANK 3"
PRINT "------"
PRINT "MUSIC size =", ~music_end-music_start
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"

\ ******************************************************************
\ *	EVENTS DATA - NOW MASTER ONLY! PANIC USE OF HAZEL
\ ******************************************************************

HAZEL_START=&C300       ; looks like first two pages are DFS catalog + scratch
HAZEL_TOP=&DF00         ; looks like last page is FS control data

CLEAR &C000, &E000
ORG HAZEL_START
GUARD HAZEL_TOP
.hazel_start

.scroller_font
INCBIN "build/scroller-font.bin"

.hazel_end

SAVE "build/HAZEL", hazel_start, hazel_end

PRINT "------"
PRINT "HAZEL"
PRINT "------"
PRINT "SIZE =", ~hazel_end-hazel_start
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~HAZEL_TOP-hazel_end
PRINT "------"

\ ******************************************************************
\ *	ANDY: DEBUG ONLY
\ ******************************************************************

CLEAR &8000, &9000
ORG &8000
GUARD &9000
.andy_start

.debug_start
.debug_end

.andy_end

SAVE "build/DEBUG", andy_start, andy_end, andy_start

PRINT "----"
PRINT "ANDY"
PRINT "----"
PRINT "SIZE =", ~andy_end-andy_start
PRINT "DEBUG CODE size =",~debug_end-debug_start
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&9000-P%
PRINT "------"
