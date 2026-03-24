# fx-path-zoom — Technical Notes

## What it does

A single-scanline RVI effect displaying the Frak sprite (via the palette trick from `fx-frak-zoomer`) at a zoom level that follows a precomputed camera path. Unlike the frak zoomer which computes scanline addresses from Rocket values each frame, this FX copies a prerendered scanline of screen data into a fixed buffer each frame and then repeats it across all 240 display scanlines, varying the palette per scanline to select the sprite row.

## Screen buffer

`FX_PATH_ZOOM_SCR_ADDR = &2D80` — a fixed address in main RAM. The update copies 80 bytes of prerendered scanline data here each frame. Because it is only one scanline (80 bytes), the CRTC R12/R13 is set to point here and never changes during drawing. R9=0 (1 scanline per character row) means each CRTC row maps to exactly one display scanline.

## Path animation

`rocket_track_time+1` (0–255) selects a frame from the path. Two tables map frame number to display parameters:

- `path_zoom_scanline_addr_LO/HI` (256 entries): address of the scanline to copy from the prerendered source data (`&3000 + (n DIV 8)*640 + (n MOD 8)`) — selects which scanline within a character row
- `path_zoom_dy_table` (raw binary from `data/raw/path-zoom-dy-table.bin`): the per-frame dv step for the Frak texture coordinate

The commented-out formula for the dy table:
```
cz = -90 - 80 * COS(2*PI*n/256)
dx = -cz / 160
dy = 128 * dx
```
This encodes a camera path oscillating between z=-10 and z=-170, giving varying zoom depths. A TODO notes this table should be computed from this formula directly rather than maintained as a raw binary.

## `fx_path_zoom_copy`

Fully unrolled copy: 80 `lda (readptr),Y : sta fixed_addr` pairs, accessing every 8th byte from the source (`ldy #n*8`). The source pointer increments twice mid-copy to cross page boundaries (every 32 bytes). Total: 80 × 12c = 960c, which is substantial but runs during vblank.

## Draw function

Single-scanline RVI (R9=0, R4=0 on scanline=-1): each character row is exactly 1 scanline. 240 iterations from scanline 0. Per scanline:
1. Advance `v += dv_LO` (8-bit add, wraps at 64 via `AND #63`)
2. Clamp: if `v+1 >= FRAK_SPRITE_HEIGHT` (43), use 42
3. Look up `frak_lines_LO/HI[v+1]`, self-mod `set_palette` JSR target
4. Call the palette subroutine (60c) then `WAIT_CYCLES 13`

Loop entry is at HCC=32 after a `WAIT_SCANLINES_ZERO_X 1` from scanline=-1. The `CHECK_SAME_PAGE_AS scanline_loop, TRUE` enforces the loop fits in one page.

## Palette trick

Shares `frak_lines_LO/HI` and all `frak_line*` subroutines with `fx-frak-zoomer`. See `fx-frak-zoomer.md` for the full description of the delta-encoded palette subroutines.

## Rocket tracks used

| Track | Purpose |
|-------|---------|
| `rocket_track_time+1` | Frame number [0–255], selects path position and zoom depth |
| `rocket_track_y_pos` | Frak sprite row for palette (Y texture coordinate) |

## Known issues / TODOs

**`path-zoom-dy-table.bin` is a raw binary** — the formula is present in the source as a commented-out `IF 0` block. This is a clear candidate for TODO item 1.

**`FX_PATH_ZOOM_SCR_ADDR = &2D80`** — a TODO notes this address must be reserved properly. It sits below `&3000` (the main screen) and may conflict with other allocations.

**Palette setup in update (234c)** — the same `pal_loop` issue as frak zoomer: 234c to write 16 palette entries during update. Noted "Should really be in draw function?"

**Shadow support** — always uses MAIN RAM; TODO to add MAIN/SHADOW selection.

**Top line determination** — `rocket_track_y_pos+1 AND #63` clamps to 0–63, then clamps again to `FRAK_SPRITE_HEIGHT-1` if too large. TODO: "Correctly determine the top line."
