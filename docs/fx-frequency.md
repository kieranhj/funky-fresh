# fx-frequency — Technical Notes

## What it does

Displays an 8×8 grid of coloured cells driven by the SN chip frequency values from the music. Each cell represents one frequency bin; cells light up white when a note is played at that frequency and fade through a colour sequence back to black over subsequent frames.

## Grid layout

- 8 rows × 8 columns = 64 cells total
- 240 visible scanlines ÷ 6 rows = 40 scanlines per row
- 80 chars ÷ 8 columns = 10 chars per column stripe
- Final 2 scanlines of each row are forced black (gap between rows)

## Colour sequence

Each cell steps through this fade on successive frames:

```
white(8) → cyan(9) → magenta(10) → blue(11) → yellow(12) → green(13) → red(14) → black(7)
```

The `fx_freq_next_pal_value` table (16 entries) encodes this chain. Values 0–7 are a parallel chain for the second set of 8 logical colours. Cells start at index 8 (white) and step toward 7 (black). `FX_FREQ_PAL_START=8`, `FX_FREQ_PAL_END=7`.

## Note detection

Three SN tone channels are checked each frame. A note is detected when either the tone register (hi or lo byte) or volume register changes compared to the previous frame (`vgc_reg_copy`). On detection:
- Top 6 bits of `TONE0_HI` → row index into `vgc_freq_array`
- Bottom 4 bits of `TONE0_LO` × 2 → column index into `vgc_freq_array`

The detected cell is reset to `FX_FREQ_PAL_START` (white) each time a note fires.

## Draw function

Uses normal CRTC with no RVI — the screen displays a static image underneath, and only the ULA palette registers are changed per row. The palette for each row's stripes is written at HCC=102 of the *previous* scanline, so the colour is active for the full row. The `WAIT_SCANLINES_ZERO_X` macro handles the inter-row gaps.

## Shared entry point

`fx_frequency_update_grid` (line 54) is the part of the update function that fades the grid and detects notes. It is called directly by `fx_stretch_grid_update` so the same grid data drives the stretch-grid composite FX.

## `_FX_FREQ_UNROLL` flag

When `TRUE` (the default), the fade loop and register-copy loop are fully unrolled by the assembler's `FOR` macro. This eliminates the loop overhead at the cost of code size.

## Known issues / TODOs

**Screen setup in update** — the `&FE34`, R12/R13, and R6 writes at the top of `fx_frequency_update` are noted "TODO: Move this to draw." They work correctly here since update runs during vblank, but they break the update/draw contract.
