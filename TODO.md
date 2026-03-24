# TODO

## PC-Side Tooling

1. **Replace BASIC prerenderers with Python scripts** — Parameterised scripts run at build time. Priority targets are the 12 raw binaries in `data/raw/` copied verbatim with no generation script: `twister1/2`, `logo*`, `stripes`, `zoom-*`, `checks-bitmask-*`, `diagonals-16`, `path-zoom-256`, `cube-widths-128`.

2. **PC-side effect previewer** — Preview prerendered effects using BBC formatted data directly. Simulate per-scanline R12/R13 CRTC address selection and ULA palette register writes. Allow easy inspection of data, configuration of which data rows appear on each scanline, and per-line palette changes.

3. **Sprite-to-6502 code generator** — Generate 6502 code snippets from sprites and other sources for per-scanline runtime use. Existing template: `png2bbc_pal.py` outputs `frak-lines.asm` as a side-effect.

4. **Static cycle count analyser** — Analyse runtime effect loops, check cycle counts and exact timings. Reads beebasm source, sums cycles per code path, flags branches/loops. Validate against existing inline cycle count comments.

5. **Simple sequence authoring tool** — Replace/supplement Rocket sync tracker with a simpler PC-side tool for generating sequence events, triggers and data parameters. `rocket2bbc.py` is the existing abstraction layer — Rocket is just an editing frontend for the binary format it already produces.

6. **Mathematical table generator** — Output `.asm` data blocks (sin, bounce, easing curves) to replace Rocket's linear lerp. Support the runtime shift trick (`<< N` in the tool, `>> N` at runtime for extra interpolation precision).

7. **SWRAM bank auto-packer** — Read compiled binary sizes and generate bank layout `.asm` with overflow detection. Replaces hand-maintained `ram-banks.asm`.

8. **Scanline table authoring tool** — Specify which screen row appears on each display scanline per frame of an animation and output 512-byte/frame tables for a generic RVI draw loop. Allows full effect prototyping on the PC before writing any 6502.

9. **Compression ratio analyser** — Build-time report of pre/post compression sizes and remaining SWRAM headroom per bank.

10. **Switch from Exomizer to zx0** — zx0 typically compresses 8-bit binary data better than Exomizer, and the decompressor is smaller and faster to execute. Replace `lib/exo.asm` / `lib/exo.h.asm` with a zx0 decompressor and update the `$(EXO_AND_ARGS)` Makefile rule.
