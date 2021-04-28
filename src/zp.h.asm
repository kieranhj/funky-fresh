;;  -*- beebasm -*-

; Stuff that has to stick around across intro, demo and outro.

; where this persistent data region begins
zp_top=$90

; TODO: Decide where slots are going to be stored from loader.
;swram_slots_base = $9c
SLOT_BANK0 = 4 ;0
SLOT_BANK1 = 5 ;1
SLOT_BANK2 = 6 ;2
SLOT_MUSIC = 7 ;3
