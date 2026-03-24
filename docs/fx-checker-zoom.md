# fx-checker-zoom — Technical Notes

## What it does

Displays three layers of zooming checkerboard patterns at fixed depth intervals, creating a parallax zoom effect. Each layer scrolls at a different speed determined by perspective, and the three parity bits are combined into a 3-bit bitmask that selects which prerendered scanline to display from MAIN or SHADOW RAM.

## Three-layer perspective

Three Z depths are maintained: `z1`, `z2 = z1 + 32*DZ`, `z3 = z1 + 64*DZ` where `DZ=8`. For each zoom level, the dy (texture step) for each layer is computed inline using:

```
dy = SX / (VPW * (SX - CX) / (z - CZ))
```

with `VPW=160`, `SX=128`, `CX=0`, `CZ=-160`. The six dy tables (`fx_checker_zoom_dy1/2/3_LO/HI`) are all computed by beebasm `FOR` loops — no raw binary files.

## Bitmask → scanline selection

Each layer contributes one bit (bit 0, 1, or 2) to a 3-bit bitmask `X`:
- Bit 0: bottom layer parity (bit 7 of `checker_y1+1`, shifted >> 7)
- Bit 1: middle layer parity (bit 7 of `checker_y2+1`, shifted >> 6)
- Bit 2: top layer parity (bit 7 of `checker_y3+1`, shifted >> 5)

This bitmask indexes two tables:
- `fx_check_zoom_bitmask_to_R9` → R9 value (0,2,4,6 → 1,3,5,7): selects sub-scanline within the character row
- `fx_check_zoom_bitmask_to_shadow` → 0 or 1: bitmasks 4–7 use SHADOW RAM, 0–3 use MAIN

So the 8 bitmask combinations map to 4 scanlines × 2 screens = 8 prerendered checker patterns.

## RVI technique

Double-line RVI. The screen address (R12/R13) is set **once per frame** in update based on zoom depth (`fx_checker_zoom_vram_table_LO/HI`, 32 entries of `(&3000 + n*640)/8`). The SHADOW bit toggles per row at the end of each odd scanline to select between the two prerendered checker screens.

The jmptab/jmpinstruc self-modification pattern is used: `jmptab` (8 entries, bitmask 0–7) maps to one of four `scanline0/2/4/6` routines, each setting R0 and R9 to land on the correct sub-scanline.

## Colour cycling

`rocket_track_zoom >> 5` (top 3 bits) indexes into `layer1/2/3_colour` tables. Each table has 9 entries (cycling through 3 colours in different rotations per layer), so the colours shift as the depth increases.

## Data tables (all inline)

All tables computed at assembly time — no raw binaries in this FX:
- `fx_checker_zoom_vram_table_LO/HI` (32 entries)
- `fx_checker_zoom_dy1/2/3_LO/HI` (32 entries each, 6 tables)
- `fx_check_zoom_bitmask_to_R9`, `fx_check_zoom_bitmask_to_shadow` (8 entries each)
- `layer1/2/3_colour` (9 entries each)

## Rocket tracks used

| Track | Purpose |
|-------|---------|
| `rocket_track_zoom` | Depth of top layer [0–31]; also controls colour cycling (top 3 bits) |
| `rocket_track_x_pos` | Y starting position of bottom layer (checker_y1) |
| `rocket_track_y_pos` | Y starting position of middle layer (checker_y2) |
| `rocket_track_time` | Y starting position of top layer (checker_y3) |

## Known issues / TODOs

**`SKIP 40` padding** — a `; // TODO: Remove unnecessary padding!` comment above a 40-byte skip suggests alignment requirements created excess padding in the code section.

**Page boundary constraint** — `CHECK_SAME_PAGE_AS scanline0, TRUE` on `scanline6` enforces that all four scanline routines fit in one 256-byte page, required because `jmptab` stores only low bytes of addresses.
