;;  -*- beebasm -*-

; Stuff that has to stick around across intro, demo and outro.

rocket_zp_start=&90
rocket_zp_reserved=&9C

zp_max=$A0      ; stay "cooperative" with the OS for now.

; TODO: Decide where slots are going to be stored from loader.
;swram_slots_base = $9c <= this is now in Rocket workspace.
SLOT_BANK0 = 4 ;0
SLOT_BANK1 = 5 ;1
SLOT_BANK2 = 6 ;2
SLOT_MUSIC = 7 ;3
