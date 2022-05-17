\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	DISC BUILD
\ ******************************************************************

LOAD_ADDRESS = &FF0E00
EXEC_ADDRESS = &FF0E00
SWRAM_ADDRESS = &8000

\ PUTTEXT "src/boot.txt", "!BOOT", &FFFFFF, 0
\ PUTBASIC "src/loader.bas", "LOADER"
PUTFILE "build/FRESH", "FRESH", LOAD_ADDRESS, EXEC_ADDRESS
\PUTFILE "build/DEBUG", "DEBUG", SWRAM_ADDRESS, SWRAM_ADDRESS
PUTFILE "build/MUSIC", "MUSIC", SWRAM_ADDRESS, SWRAM_ADDRESS
PUTFILE "build/BANK0", "BANK0", SWRAM_ADDRESS, SWRAM_ADDRESS
PUTFILE "build/BANK1", "BANK1", SWRAM_ADDRESS, SWRAM_ADDRESS
PUTFILE "build/BANK2", "BANK2", SWRAM_ADDRESS, SWRAM_ADDRESS
\PUTFILE "build/EVENTS", "EVENTS", &C300, &C300
\PUTTEXT "data/readme.txt", "README", &FFFFFF, 0

\ TODO: Remove for final build!
PUTFILE "ref/MakeChecks.bas.bin", "MAKCHK3", &FF0E00, &FF802B
PUTFILE "ref/Zoomer160by2.bas.bin", "ZOOM1", &FF0E00, &FF802B
PUTFILE "ref/ZoomWithWrap.bas.bin", "ZOOM2", &FF0E00, &FF802B
PUTFILE "ref/PATHZ.bas.bin", "PATHZ", &FF0E00, &FF802B
