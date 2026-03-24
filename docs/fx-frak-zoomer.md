# fx-frak-zoomer — Technical Notes

## What it does

The Frak zoomer displays the Frak sprite at a variable zoom level with X/Y panning. Rather than writing pixel data into screen RAM per frame, it uses the **ULA palette as the pixel data** — each column of the sprite is represented by a palette entry, and by rewriting the 16 palette registers each scanline via RVI, different rows of the sprite are displayed. The screen RAM itself is essentially a fixed lookup structure; all the visual content comes from palette writes.

## The palette trick (`png2bbc_pal.py` + `frak-lines.asm`)

`png2bbc_pal.py` reads the sprite PNG and for each pair of rows generates a small subroutine in `frak-lines.asm`. Each subroutine writes only the palette bytes that **changed** vs the previous row — delta encoding at code level — then `WAIT_CYCLES` to pad to a fixed 60 cycles total:

- 8 palette writes × ~7.5c = 60c per row in the worst case
- Rows with fewer changes get `WAIT_CYCLES` padding to stay at exactly 60c
- `prev_line` in the generator is initialised to `[0xf5, 0xe5, ...]` (reversed) to seed the delta from an assumed starting palette state

The lookup tables `frak_lines_LO` / `frak_lines_HI` give the address of each row's subroutine so it can be `jsr`'d directly from the draw loop.

## Zoom data tables

Six raw binaries in `data/raw/` drive the zoom maths — all prime candidates for Python generation (TODO item 1):

| File | Content |
|------|---------|
| `zoom-dv-table.bin` | Fixed-point dv (texture step) per zoom level |
| `zoom-to-crtc-addr.bin` | R12/R13 screen base address per zoom level |
| `zoom-sprite-width-in-chars.bin` | Sprite width in chars per zoom level |
| `zoom-to-scanline.bin` | Starting sub-scanline (0/2/4/6) per zoom level |
| `zoom-viewport-width.bin` | Half-viewport width in texture coords per zoom level |
| `zoom-viewport-height.bin` | Half-viewport height in texture coords per zoom level |

These all have a mathematical relationship to each other and to `FRAK_MAX_ZOOM=55` / `FRAK_SPRITE_WIDTH=32` / `FRAK_SPRITE_HEIGHT=43` — they should be generatable from a single Python script with those parameters.

## RVI technique

Double-line RVI: each display row is shown twice (even + odd scanline). `next_scanline` holds which sub-scanline within the character row (0, 2, 4, or 6) to display. R9 is written as `13 + current - next` before the final scanline of each row, controlling the CRTC's scanline counter reset point. The 119-iteration main loop covers 238 scanlines; the remaining 74 are handled by setting R4=36 after the loop.

## Update function

Runs during vblank:

1. Clamp zoom to `FRAK_MAX_ZOOM-1`, look up dv and starting scanline
2. Calculate texture V start: `v = (y_pos - 60*dv) MOD sprite_height` — centres the viewport. The `frak_mod_sprite_height` table (256 entries of `n MOD 43`) handles the modulo cheaply
3. Calculate char X offset via a 16×16 multiply and 4-bit shift
4. Write the first row's palette — **234 cycles**, noted with a comment "Should really be in draw function"

## Rocket tracks used

| Track | Range | Purpose |
|-------|-------|---------|
| `rocket_track_zoom` | 0–54 | Zoom level (clamped to `FRAK_MAX_ZOOM-1`) |
| `rocket_track_x_pos` | — | Horizontal pan in viewport coordinate space |
| `rocket_track_y_pos` | — | Vertical pan in viewport coordinate space |

## Known issues / TODOs

**`FRAK_SPRITE_HEIGHT=43` is not a multiple of 2** — commented as a TODO. Since dv steps through texture coordinates in fixed-point and the modulo wraps at 43, an odd height means the wrap point can land at a fractional row, causing a single-scanline glitch at the boundary.

**Palette loop in update** — the 234c `pal_loop` is acknowledged as misplaced. It should be in draw but was put in update for timing safety. The comment notes an alternative using indirect addressing at 176c. The real fix would be to set the palette at the very start of the draw function using the pointer already computed in update.

**Shadow screen support missing** — `lda &fe34:and #&fe:sta &fe34` unconditionally selects main RAM. TODO to add a data byte (from a Rocket track or sequence) to choose main vs shadow.

**X modulo implicit** — line 97 does `AND #15` to wrap `left_pos` into `[0,16)`, treating the sprite as 16 units wide in the viewport coordinate system. The viewport coordinate space is deliberately decoupled from physical pixels but this is not commented.

**`png2bbc_pal.py` is Python 2** — uses `print>>sys.stderr` and Python 2 string writes. A Python 3 port exists as `bin/png2bbc_pal3.py` (untracked) but the migration is incomplete. Currently called via `PYTHON3` in the Makefile.
