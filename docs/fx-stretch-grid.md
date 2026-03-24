# fx-stretch-grid — Technical Notes

## What it does

A composite FX combining `fx-vertical-stretch` and `fx-frequency`. The screen is vertically stretched/zoomed (selecting which screen row appears on each scanline), while the frequency grid colours are overlaid by changing the ULA palette for each horizontal band of 15 rows. The result is a zooming image with an active frequency visualiser colour scheme.

## Composition

`fx_stretch_grid_update`:
1. Calls `fx_vertical_stretch_update` — computes `dv`, starting `v`, and self-mods `fx_stretch_grid_dv_LO/HI`
2. Copies `dv` into the draw function's self-mod immediates (`fx_stretch_grid_dv_LO/HI+1`)
3. Resets `grid_row_count` to 15
4. Calls `fx_frequency_update_grid` — fades grid colours and detects new notes

`fx_stretch_grid_draw` is a modified version of `fx_vertical_stretch_draw` that sets frequency stripe palette values at the start of each character row instead of waiting.

## Frequency stripe layout

240 scanlines ÷ 16 scanlines per band = 15 bands. Each band corresponds to one row of 8 frequency columns. `grid_row_count` counts down from 15 within each band; when it reaches 1 the final row of the band sets all stripes to black (creating a visual gap between bands). When it reaches 0, `Y` advances by 8 to move to the next frequency row, and `grid_row_count` resets to 15.

The stripe palette writes occur at HCC=81–128 on the even scanline, setting 8 ULA entries at logical colours `&80`–`&F0`.

## RVI technique

Identical to `fx-vertical-stretch`: double-line RVI with the jmptab/scanline0/2/4/6 pattern. R9 is set during the odd scanline; R12/R13 are set at the start of each even scanline from `fx_stretch_vram_table_LO/HI`. `txa:and #3:tax` maps the low 2 bits of `v+1` to the scanline quadrant.

## Branching structure

Two code paths break out of the main loop for timing:
- `alt_path` — when `grid_row_count != 0`, skips the Y increment (7c + jmp back = 10c total to match main path)
- `set_black_palette` — when `grid_row_count == 1`, writes 8 × black palette entries (48c), then `WAIT_CYCLES 27` to pad to 80c to match the colour path

Both paths converge at `right_in_there` / `return_from_black_palette` for the R9 and jmptab setup.

## Shared data

Uses `fx_stretch_vram_table_LO/HI` and `fx_stretch_dv_table_LO/HI` from `fx-vertical-stretch.asm`, and `vgc_freq_array` from `fx-frequency.asm`. All three source files must be linked together.

## Rocket tracks used

Same as `fx-vertical-stretch`:

| Track | Purpose |
|-------|---------|
| `rocket_track_zoom` | Zoom factor [0–63] |
| `rocket_track_y_pos` | Y position of middle line [0–127] |
