# Funky Fresh — PC Tooling Progress

## Current Status

The Python 2 dependency has been eliminated from the build. `make.bat` now runs entirely under Python 3.

---

## Python 3 Migration — Completed Work

### Scripts updated in-place (Python 2 → 3 compatible)

| File | Changes |
|------|---------|
| `bin/bbc.py` | Added `pack_8bpp` for mode -1; already Python 3 compatible otherwise |
| `bin/png2bbc.py` | Fixed `save_file` (`chr()`→`bytes()`); all `print>>sys.stderr` → `print(..., file=sys.stderr)`; added mode -1 / 8bpp support |
| `bin/modules/huffman.py` | Python 3 compatibility fixes |
| `bin/modules/lz4enc.py` | Python 3 compatibility fixes |

### New Python 3 replacement scripts (originals remain unchanged/Python 2)

| New file | Replaces | Notes |
|----------|----------|-------|
| `bin/vgmconverter3.py` | `bin/vgmconverter.py` | Full port: `print()`, `//`, bytes/str handling, `struct.pack` → direct int appends, `b''` literals |
| `bin/png2bbc_font3.py` | `bin/png2bbc_font.py` | Full port: `bytes()` writes, `print()`, `//` for integer division |

### Already Python 3 (no changes needed)

- `bin/vgmpacker.py`
- `bin/png2bbc_pal.py`
- `bin/rocket2bbc.py`

### Makefile.mk changes

- Removed `PYTHON2` variable entirely
- All `$(PYTHON2)` calls replaced with `$(PYTHON3)`
- `VGM_CONVERTER` now points to `./bin/vgmconverter3.py`
- `png2bbc_font.py` references updated to `png2bbc_font3.py`

### Tested build targets

- `make.bat music` (vgmconverter3 → vgmpacker): **pass**
- `make.bat build/scroller-font.bin` (png2bbc_font3): **pass**
- `make.bat build/doom-screen.bin` (png2bbc.py): **pass**
- `make.bat build/scr-screen.bin` (png2bbc.py): **pass**
- `make.bat build/frak-sprite.bin` (png2bbc_pal.py): not re-tested (no changes to this script)
- Full `make.bat disc`: **not yet verified end-to-end**

---

## Redundant Files — Cleanup Needed

Three untracked `*3.py` files exist that are **not used by the Makefile** and should be deleted to avoid confusion:

| File | Status | Why |
|------|--------|-----|
| `bin/bbc3.py` | **Delete** | Has *different and incorrect* BBC pixel packing logic (`pack_4bpp` uses `(pixels[1]<<4)\|pixels[0]` — wrong for the BBC bit-interleaved format). The correct packing is in `bbc.py`. Dangerous to keep. |
| `bin/png2bbc3.py` | **Delete** | `png2bbc.py` is already Python 3 compatible; this duplicate serves no purpose |
| `bin/png2bbc_pal3.py` | **Delete** | `png2bbc_pal.py` is already Python 3 compatible; this duplicate serves no purpose |

---

## Immediate Next Steps

1. **Verify full build end-to-end**: run `make.bat disc` and confirm `disc/funky-fresh.ssd` is produced and runs in the emulator (note: `disc/` is cleaned between builds, its absence is normal).

2. **Delete the three redundant `*3.py` files** listed above. The `bbc3.py` in particular has wrong pixel packing and must not accidentally be used.

3. **Commit the Python 3 migration** as a clean, self-contained commit covering: `Makefile.mk`, `bin/bbc.py`, `bin/png2bbc.py`, `bin/modules/huffman.py`, `bin/modules/lz4enc.py`, `bin/vgmconverter3.py`, `bin/png2bbc_font3.py`.

---

## Tooling Wishlist — Not Yet Started

From the agreed list (see `memory/project_tooling_wishlist.md`):

1. **Replace BASIC prerenderers** — 12 raw binaries in `data/raw/` with no generation script (twister1/2, logo*, stripes, zoom-*, checks-bitmask-*, diagonals-16, path-zoom-256, cube-widths-128). Priority target.

2. **PC-side effect previewer** — simulate per-scanline CRTC R12/R13 address selection and ULA palette register writes using the BBC-formatted data directly.

3. **6502 code snippets from sprites** — template exists: `png2bbc_pal.py` outputs `frak-lines.asm`. Generalise this.

4. **Static cycle count analyser** — read beebasm source, sum cycles per code path, flag branches/loops, validate against existing inline comments.

5. **Simpler sequence authoring tool** — supplement/replace Rocket. `rocket2bbc.py` is the abstraction layer; Rocket is just an editing frontend.

6. **Mathematical table generator** — output `.asm` data blocks (sin, bounce, easing). Support the shift trick (`<<N` in tool, `>>N` at runtime).

7. **SWRAM bank auto-packer** — read compiled binary sizes, generate bank layout `.asm` with overflow detection. Replaces hand-maintained `ram-banks.asm`.

8. **Scanline table authoring tool** — specify which screen row appears on each display scanline per frame, output 512-byte/frame tables for generic RVI draw loop.

9. **Compression ratio analyser** — build-time report of pre/post exomizer sizes and remaining SWRAM headroom per bank.

10. **Switch from Exomizer to zx0** — evaluate compression ratio improvement and decoder size on 6502.

---

## Key Architectural Notes for Tools

- BBC Mode 2: 320×256, 8 colours, 2 pixels/byte, bit-interleaved format (see `bin/bbc.py:pack_4bpp` for the correct encoding — bits from two pixel values are interleaved across the byte, not packed as nibbles).
- SWRAM layout is in `src/ram-banks.asm`. Banks 0/1 hold compressed screen assets, bank 2 is display FX code, HAZEL holds scroller font.
- The `build/` directory is the staging area for all generated assets before disc assembly. All tool outputs land here.
- Rocket `.track` files are pre-processed binary keyframe streams, not raw `.rocket` project files. `bin/rocket2bbc.py` is the converter.
