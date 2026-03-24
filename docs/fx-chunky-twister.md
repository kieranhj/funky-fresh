# fx-chunky-twister — Technical Notes

## What it does

Each display scanline shows a different prerendered row of a screen, with the row selection determined by a cosine function that advances differently per scanline. The result is a horizontal twisting/slanting effect. The twist is driven in real-time from Rocket tracks with no prerendered animation frames.

## Coordinate system

- `angle` (0–255 brads): the CRTC row selection value for the current scanline
  - Bits 0–5 (masked as `&3E >> 1`): selects prerendered screen row (0–31)
  - Bits 6–7: selects colour quadrant (0–3)
- `xy` (16-bit): the horizontal displacement, indexes into `x_wibble` for R13 offset
- `yb` (12-bit, stored across 3 bytes): current phase into the 4096-entry `cos` table

## Rocket tracks used

| Track | Purpose |
|-------|---------|
| `rocket_track_x_pos` | X position of top row — horizontal offset, drives `xy` |
| `rocket_track_y_pos` | X delta per row (after >> 4) — makes rows curve |
| `rocket_track_time` | Rotation angle of top row — drives `yb` through cos table |
| `rocket_track_zoom` | Rotation delta per row (after >> 4) — makes the column twist |

## The cos table

4096 entries (`cos[0..4095] = 255*COS(2*PI*n/4096)`). The 12-bit input gives sub-degree precision. On each row the 12-bit `yb` index advances by the per-row rotation delta. The 8-bit cosine output becomes `angle` for the next row.

## `x_wibble` table

256 entries: `54 + 40*SIN(2*PI*n/256)`. Maps `xy+1` (the high byte of the x position) to a char offset that is halved and added to the CRTC R13 address. The LSB of each entry is also used as the SHADOW bit — so alternate angle values display from MAIN or SHADOW RAM, allowing two different prerendered images to be interleaved.

## RVI technique

Double-line RVI with LHS blanking via `TELETEXT_ENABLE`/`TELETEXT_DISABLE`. The blanking hides the garbage pixels visible during the CRTC row transition. The same jmptab/scanline0/2/4/6 pattern as other double-line RVI effects, with R9 set during the odd scanline.

The `CHUNKY_TWISTER_SET_CRTC_FROM_ANGLE` macro writes R12/R13 and captures the shadow bit: 65c on even scanlines, used twice per frame (once for row 0 in draw entry, then once per row in the loop).

## Self-mod RTS hack in update

```asm
lda twister_calc_rot_rts:pha:lda #&60:sta twister_calc_rot_rts
jsr fx_chunky_twister_calc_rot
pla:sta twister_calc_rot_rts
```

The inline `fx_chunky_twister_calc_rot` function at HCC=17 in the draw loop doesn't normally end with an RTS — it falls through into the CRTC setup code. The update function needs to call this inline code to initialise the first row's angle, so it temporarily patches the location `twister_calc_rot_rts` to `&60` (RTS), calls it, then restores the original byte.

## Quadrant colours

Each of the 4 quadrants (bits 6–7 of `angle`) maps to a colour set via `twister_quadrant_colour_1/2/3`. Three palette entries are written per row (logical colours 6, 1, 2). The colours rotate: cyan/red/green → green/cyan/yellow → yellow/green/red → red/yellow/cyan.

## Data tables (inline, no raw binaries)

All data tables in this FX are computed by beebasm at assembly time:
- `twister_vram_table_LO/HI`: 32 entries, `(&3000 + n*640)/8` per row
- `x_wibble`: 256-entry sine table
- `angle_to_quadrant`: 256 entries of `n >> 6`
- `cos`: 4096-entry cosine table

## Known issues / TODOs

**`scanline6` is broken** — comment: `"<= broken should be 116"`. The `STY &FE01` at cycle 118 is 2 cycles late, meaning scanline 6 selection doesn't land at the right point.

**Sign extension** — `twister_calc_rot_sign` is set to 0x00 or 0xFF based on the sign of `rocket_track_zoom+1`, then added to the high byte of `yb` after masking. This is the sign-extension mechanism for the 16-bit rotation delta.

**Shift-down of track values** — all four track values are shifted right 4 bits in update before being stored as self-mod immediates. This sacrifices 4 bits of range to gain 4 bits of interpolation precision from the Rocket 8.8 fixed-point values.
