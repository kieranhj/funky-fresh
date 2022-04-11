\ -*- mode:beebasm -*-
\ ******************************************************************
\ *	ASSETS TABLE
\ ******************************************************************

.assets_table
{
    equw exo_asset_logo_mode2,      SLOT_BANK1       ; &00
    equw exo_asset_doom_mode2,      SLOT_BANK0       ; &01
    equw exo_asset_scr_mode2,       SLOT_BANK0       ; &02
    equw exo_asset_twister_1,       SLOT_BANK1       ; &03
    equw exo_asset_twister_2,       SLOT_BANK1       ; &04
    equw exo_asset_stripes,         SLOT_BANK1       ; &05
    equw exo_asset_zoom,            SLOT_BANK1       ; &06
    equw exo_asset_checks_1,        SLOT_BANK1       ; &07
    equw exo_asset_checks_2,        SLOT_BANK1       ; &08
    ; v--------------------------------------------- ; update ASSET_ID_MAX!
}
ASSET_ID_MAX = 9
