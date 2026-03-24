# fx-spin-bar — Technical Notes

## What it does

Renders a 3D spinning rectangular bar projected onto horizontal scanlines. The bar is modelled as a rectangle with 4 corners; at any rotation angle exactly 2 faces are visible. The effect is purely palette-based — the background and each face section are coloured by changing ULA logical colour 0 at the appropriate scanline threshold.

## Geometry

The bar is treated as a flat rectangle viewed edge-on. The 4 corner Y screen positions are:

```
y1' = y_pos - r_sin - r_cos    (top of top face)
y2' = y_pos + r_sin - r_cos    (bottom of top face)
y3' = y_pos - r_sin + r_cos    (top of bottom face)
y4' = y_pos + r_sin + r_cos    (bottom of bottom face)
```

where `r_sin = sin(angle) * zoom` and `r_cos = cos(angle) * zoom`, both computed via `fast_multiply_signedAX`.

## Quadrant-based face selection

The 4 quadrants (0–3, from `angle >> 6`) each present a different pair of visible faces. `quadrant_to_indices` (4×4 table) maps quadrant to which corner indices form the top and bottom edges. `quadrant_to_colour` (4×2 table) gives the emerging and hiding face colours per quadrant (cycling red → green → cyan → yellow).

## Raster list

`bar_y_rasters` (8 bytes) and `bar_y_colours` (8 bytes) are a paired scanline threshold/colour list:

| Index | Meaning |
|-------|---------|
| 0 | Screen top — background colour (`PAL_blue`) |
| 1 | Top edge start — edge colour (`PAL_black`) |
| 2 | Top face start — emerging face colour |
| 3 | Middle edge start — edge colour |
| 4 | Bottom face start — hiding face colour |
| 5 | Bottom edge start — edge colour |
| 6 | Background resume |
| 7 | End sentinel (255) |

When the top and bottom faces overlap (zero-width edge), entries 1 and 2 are removed by shifting the list down.

## Draw function

Uses standard CRTC with no RVI — 8 scanlines per character row. The loop runs 240 iterations (one per scanline), advancing the colour index X whenever `Y >= bar_y_rasters[X]`, then writing `bar_y_colours[X]` to `&FE21`. The loop entry point is HCC=102 to ensure the palette write occurs before the last visible character column of each scanline.

## Data tables (inline)

- `spin_x_sin_a`: 256 entries of `127*SIN(2*PI*n/256)`
- `spin_y_cos_a`: 256 entries of `127*COS(2*PI*n/256)`
- `angle_to_quadrant`: 256 entries of `n >> 6` (shared label with chunky twister)
- `quadrant_to_indices`, `quadrant_to_colour`: small inline tables

## Rocket tracks used

| Track | Purpose |
|-------|---------|
| `rocket_track_time+1` | Rotation angle (brads) |
| `rocket_track_zoom+1` | Bar size (scale factor for sin/cos) |
| `rocket_track_y_pos+1` | Y position of bar centre on screen |

## Dead code

An `IF 0` block contains an earlier version of the rotation calculation using the full 4096-entry cos table (same as chunky twister). The current code uses the simpler 256-entry `spin_x_sin_a`/`spin_y_cos_a` tables and direct brad lookup.

## Known issues / TODOs

**Shadow support** — always operates on whatever screen was last displayed; no MAIN/SHADOW control.

**No bounce mode** — TODO comment mentions "bounce mode" and "autospin" as desired features.

**No early termination** — the draw loop always runs all 240 scanlines even when the bar occupies only a small region. Terminating early once past the bar bottom would return cycles to the task loop.
