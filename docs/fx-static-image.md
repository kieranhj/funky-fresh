# fx-static-image — Technical Notes

## What it does

Displays a static image from either MAIN or SHADOW RAM with no RVI. This is the simplest FX and also acts as a **shared services provider** for other effects — its palette reset routine and default palette table are called by almost every other FX at teardown.

## Screen address

`static_image_scrn_addr = screen_addr + 640` — skips the first character row (8 scanlines) of the screen buffer. This is intentional: the first row is used for RVI setup timing by effects that need it.

## Shared services

Other FX call these directly:

| Label | Purpose |
|-------|---------|
| `fx_static_image_set_default_palette` | Resets lower 8 palette entries to default Mode 2 colours |
| `fx_static_image_set_palette` | Sets palette from an arbitrary address passed in X/Y |
| `fx_static_image_draw` | Full no-RVI draw: sets R12/R13, resets all CRTC timing registers |

The default palette maps logical colour N directly to physical colour N (identity mapping) for the lower 8 entries, with the upper 8 repeating the same mapping.

## Two update functions

- `fx_static_image_main_update` — clears bit 0 of `&FE34` to select MAIN RAM
- `fx_static_image_shadow_update` — sets bit 0 of `&FE34` to select SHADOW RAM

Both delegate immediately to `fx_static_image_set_default_palette`.

## Draw function

Sets R12/R13 for `static_image_scrn_addr`, waits 2 scanlines, then writes the standard CRTC values:
- R9=7 (8 scanlines per character row)
- R4=38 (312 total lines)
- R7=34 (vsync at line 272)
- R6=30 (240 visible lines)

This restores safe defaults after any FX that modified CRTC registers.

## Known issues / TODOs

**Screen/shadow selection in update** — both TODOs note "Move this to draw?" The `&FE34` write happens during vblank, which is safe, but consistency with the draw contract would put it in draw.

**Palette expectations unclear** — comment notes the convention for what state the palette should be in on entry/exit is not fully defined.
