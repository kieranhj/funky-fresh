# fx-texture-cube — Technical Notes

## What it does

Renders a perspective-projected rotating cube face textured with the Frak sprite (via the palette trick). The cube rotates around its X axis. At any rotation, exactly 2 faces are visible, each rendered as a trapezoid whose width changes per scanline. Screen row selection (for the width illusion) and palette writes (for the texture) are both driven per scanline via RVI.

## Four-loop structure

The 119 visible double-line rows are divided into four sequential loops, with row counts self-modified from the rotation data table each frame:

| Loop | Content |
|------|---------|
| `loop0` | Top blank region (background above the cube) |
| `loop1` | Top face — width grows/shrinks, texture advances |
| `loop2` | Bottom face — skipped (`beq skip_loop2`) when only one face is visible |
| `loop3` | Bottom blank region (background below the cube) |

`texture_cube_loop3_rows` is computed as `119 - loop0 - loop1 - loop2` to fill the remainder.

## Rotation data table

`texture_cube_rotations` stores 13 bytes per rotation frame (64 frames = 832 bytes total). Currently loaded from `data/raw/texture-cube-rotations.bin`. The inline generation code is present in the source as an `IF 0` block — a clear TODO item 1 candidate.

Each 13-byte record:

| Offset | Field | Purpose |
|--------|-------|---------|
| 0 | `dy0` | Row count for top blank loop |
| 1 | `w1` | Width at top edge of face 1 (offset from `MIN_W=32`) |
| 2 | `dy1` | Row count for face 1 |
| 3–4 | `dw1` | Width delta per row for face 1 (16-bit signed) |
| 5–6 | `dv1` | Texture V delta per row for face 1 (16-bit) |
| 7 | `w2` | Width at top edge of face 2 |
| 8 | `dy2` | Row count for face 2 (0 = single visible face) |
| 9–10 | `dw2` | Width delta per row for face 2 |
| 11–12 | `dv2` | Texture V delta per row for face 2 |

## Width → screen address

`w+1` (the current face width, 0–127) indexes `fx_stretch_vram_table_LO/HI` from `fx-vertical-stretch.asm`. Width=0 maps to the top of the screen buffer; increasing width maps to lower rows, creating the trapezoid perspective illusion by displaying progressively wider screen rows.

`v_to_frak_line` maps the 6-bit V coordinate (0–63) to a Frak sprite row (0–42):
- 0–9 → 42 (clamped to last row)
- 10–52 → 0–42
- 53–63 → 42 (clamped)

## Palette trick

Shares `frak_lines_LO/HI` and `frak_line*` subroutines from `fx-frak-zoomer` / `fx-path-zoom`. See `fx-frak-zoomer.md` for details. The 60c palette subroutine is called from both face loops.

## Two jmptab copies

`loop1` and `loop2` each have their own copy of the `jmptab1`/`jmptab2` tables and `scanline0/2/4/6` routines with different `jmpreturn1`/`jmpreturn2` targets. These are structurally identical but cannot be shared because the return addresses differ. Each must fit within one 256-byte page (`CHECK_SAME_PAGE_AS scanline0, TRUE`).

## `PROJECT_FACE` macro

Used in the `IF 0` generation block. Takes two 3D vertex coordinates, projects them onto the screen using:
```
sx = centre_x + vp_scale * x / (z + oz - cz)
```
with `vp_scale=80`, `cz=-160`, `oz=0`. Outputs the encoded 5-byte record. The macro validates that projected widths fall within `[MIN_W=32, MAX_W=159]` and emits a cull record (`255,0,255,0,0`) for back-facing edges.

## Rocket tracks used

| Track | Purpose |
|-------|---------|
| `rocket_track_time+1` | Rotation angle [0–63 brads, masked with `AND #63`] |

## Known issues / TODOs

**`texture-cube-rotations.bin` is a raw binary** — the generation formula is present in the source (`IF 0` block) but disabled. Re-enabling it would eliminate this raw binary dependency and make the rotation data parameterised.

**Shadow support** — always uses MAIN RAM.

**Cycle entry point mismatch between loops** — `loop0` enters at HCC=10, `loop1` at HCC=10, `loop2` at HCC=26. The entry point shifts because `done_loop1` exits at HCC=8 and the `loop2` setup takes 18c before the loop body. This means the cycle budgets and wait counts differ between the two face loops despite their structural similarity.

**`fx_texture_cube_vram_table_LO/HI`** — a separate 128-entry vram table using the same `(n DIV 4)*640` formula as `fx_stretch_vram_table`. These could be unified but are kept separate to avoid any dependency ordering issues.
