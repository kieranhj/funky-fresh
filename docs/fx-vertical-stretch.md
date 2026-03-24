# fx-vertical-stretch — Technical Notes

## What it does

Vertically zooms and pans a static screen image by using RVI to select which screen row appears on each display scanline. At zoom=0 the image is 1:1; at zoom=63 it is stretched 10× vertically, showing a small region of the source image filling the whole screen.

## Data tables (all inline)

All tables are computed at assembly time via beebasm `FOR` loops — no raw binaries:

**`fx_stretch_vram_table_LO/HI`** (256 entries each):
- Entries 0–127: `(&3000 + (n DIV 4)*640) / 8` — maps texture coordinate v (0–127) to CRTC screen address, stepping one screen row for every 4 texture rows (i.e. `v` is in units of 1/4 of a character row)
- Entries 128–255: all point to `&3000/8` (clamped to top of screen)

**`fx_stretch_dv_table_LO/HI`** (64 entries each):
- Formula: `dv = 256 * height / h` where `h = 128 + n * (1280 - 128) / 63`
- zoom=0: h=128, dv=256 (dv=1.0, one texel per scanline = 1:1)
- zoom=63: h=1280, dv≈25.6 (10× stretch, each texel covers ~10 scanlines)

## Update function

1. Looks up `dv` from `fx_stretch_dv_table` for current zoom, stores in ZP `dv` and self-mods draw loop immediates
2. Computes starting v: `v = 63 - y_pos * dv` (centres the viewport at `y_pos`)
   - Optimisation: if `dv+1 != 0` (i.e. dv ≥ 256, meaning 1.0), `y_pos` is used directly as the product to avoid overflow in the multiply
   - Otherwise: `fast_multiply_AX(dv_LO, y_pos_HI)` gives `product = y_pos * dv`

## Draw function

Double-line RVI: 119 iterations covering scanlines 0–237, plus 37 rows of blank to reach 312 total.

Per even scanline:
1. Advance `v += dv` (16-bit add, self-modified immediate)
2. Look up R12/R13 from `fx_stretch_vram_table[v+1]`
3. Write to CRTC
4. Map `v+1 & 3` to scanline quadrant for R9/jmptab

The entry is at HCC=19 because the first iteration is entered via `right_in_there` at HCC=35 from the scanline=-1 setup, and subsequent iterations loop back at HCC=19.

## `_FX_VERT_STRETCH_REMOVE_RVI` flag

When `TRUE` (currently `FALSE`), an alternative implementation using `TELETEXT_ENABLE`/`TELETEXT_DISABLE` for LHS blanking is compiled instead of the standard RVI wait cycles. The conditional blocks throughout the draw function show both code paths — the current default path just uses `WAIT_CYCLES 7` in place of each teletext macro.

## RVI technique

Standard double-line RVI with jmptab/scanline0/2/4/6 pattern. The R9 value for the next row is computed as `(v+1 & 3) * 2 | 1`. The four scanline routines (all within one 256-byte page) set R0 to different widths to land on the correct sub-scanline.

## Rocket tracks used

| Track | Range | Purpose |
|-------|-------|---------|
| `rocket_track_zoom` | 0–63 | Zoom factor (0=1:1, 63=10×) |
| `rocket_track_y_pos` | 0–127 | Y position of middle line (63=centre) |

## Known issues / TODOs

**Shadow support** — always uses MAIN RAM; TODO to add data byte for MAIN/SHADOW selection.

**CRTC setup in update** — R6=1 and `row_count=119` are set at the end of update rather than in draw. Safe since update runs during vblank, but breaks the strict update/draw separation.

**Palette reset** — update calls `fx_static_image_set_default_palette` at the end, noted as needed because a palette wipe may have changed the palette. This is a defensive reset rather than this FX owning specific colours.
