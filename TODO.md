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

## Demo Release

### Effects

**Thematic notes:**

- The demo embraces the chunky aesthetic — effectively 160×128 in 8 colours. Lean into this style rather than fighting it.
- Don't worry about dithering, use solid background colours and contrasting palette combinations, perhaps with black outlines.
- The Frak! sprite is iconic and could work as a recurring visual theme tying the demo together — zoomer, static screens, logo treatments, etc.
- Could rip the Frak! sprites if appropriate.
- Use the Frak! bubble as a means to do greets?
- Funky Frak! rather than Funky Fresh?!?

**Keepers:**

1. **Path zoom** ★★★ — The standout effect. Polish and feature prominently in the sequence.

2. **Stretch grid** ★★★ — Very strong. Needs a proper logo designed for it. LHS garbage blanking needs resolving per-effect.

3. **Bendy twister** ★★☆ — Good effect, people like it. Two issues to fix:
   - Visible palette changes during the effect need hiding.
   - LHS feathering needs sorting out.

4. **Spin bar** ★★☆ — Decent, if a bit basic. Could work well as a transition or combined with other elements (scroller, text). Plenty of spare cycles per rasterline.

5. **Static screen** ★☆☆ — If needed to hide loading.

**Work in progress:**

6. **Textured cube** ★★☆ — High potential but not working yet. 4-section approach (top bg, top face, bottom face, bottom bg). Needs debugging and completing.

**Candidates for new effects:**

- Pseudo 3D X-rotator. Rather than the full textured cube, just pre-render each line at N resolutions.
- Candiru X-rotators, no texture but nice colours, maybe with a black edge to give an outline effect? 
- Logo X,Y wibbler. As per stretch but include X wibble at one pixel resolution.
- Textured (rigid) twister. Set the palette in the border again mapped onto the twister rows.
- Large chunky logos (maybe quarter of the screen) that scroll left & right independently. Offset up and down at row resolution.

**Not for this demo:**

- **Checkerboard zoom** ★☆☆ — Janky at current double-line resolution. Would benefit significantly from moving to single scanline per row. Needs rework to be worth keeping.

### Feature Improvements

1. **Replace Rocket linear lerp with pre-baked tables** — Rocket interpolation makes everything feel linear and stiff. Use pre-calculated tables (sin, bounce, easing curves) driven from code for flowing, non-linear motion. Related: PC-side tooling item #6.

2. **Add energy and non-linear motion throughout** — Movement is too linear and stiff. Use tables for bounce, acceleration, beat-synced pulses. "Edge of Disgrace energy level."

3. **Combine spin bar with other FX** — Plenty of spare cycle time per rasterline. Could combine with a scroller or text.

4. **Optimise Rocket runtime interpolation** — Remove interpolation overhead for fixed/step key tracks. Step keys could be single byte. Reduces per-frame cost (currently 33c per track).

5. **Consider replacing Rocket with a simpler sequencing system** — The Rocket editor cannot currently connect to the emulator in the new dev environment. Given the existing pain points (linear lerp, too many tracks, runtime cost), it may be better to drop Rocket entirely in favour of a simpler PC-side sequencing tool that outputs the same `.track` binary format via `rocket2bbc.py`. Related: PC-side tooling item #5.

### Missing Features

1. **Transitions** — No transitions between effects yet. Ideas from the doc:
   - Top & bottom bars as simple transitions.
   - Vertical blind wipes (Twisted Brain style).
   - Frequency grid for blocky wipes with colour ripple.
   - Spinning bar fill screen then swap.
   - Animated convex raster shapes that fill screen. - NOT FOR THIS DEMO
   - Horizontal/vertical strip wipes using repeated scanlines.

2. **Text display for greets/credits** — Need large moving text, ideally two independent text elements. Slide-on and stick, wobble effects.

3. **Scrolltext** — Could combine with horizontal twisty bar FX which has spare cycles.

4. **Demo reset task** — Need a "demo reset" at sequence start to zero all FX vars for clean playback from the beginning. Ensures scrubbing/restart works correctly.

5. **FX display from SWRAM** — Noted as TODO in the doc. Load and run FX display code from SWRAM.

6. **Palette control track** — No general solution for palette changes between effects. Options discussed: separate track, event-style LOGICAL.physical bytes. Needs a decision.

7. **Sequencing and pacing** — Full sequence needs authoring. Loading 20K screens takes ~8.3s during RVI — pacing must account for this. Use static screen transitions to gain loading cycles.

### Bugs

1. **LHS RVI garbage** — Partially solved with R0=0 blanking but no one-size-fits-all fix. Works on real hw but moving screen right exposes visible column on far left. Still one column visible on real CUB monitor. Per-effect decision needed — currently affects stretch grid and bendy twister.

2. **Static screen display incorrect** — Likely a bug in the Python 3 conversion of `bin/png2bbc.py`. Output doesn't match expected display. Compare against Python 2 version output to isolate the issue.

3. **Scrubbing + task loading inconsistency** — Starting in the middle of the sequence misses asset initialisation tasks. Main & shadow RAM can't be uninitialised once set. Separate task tracks for main/shadow helps (done) but scrubbing still unreliable.

4. **BASIC prerenderer code in binary format** — Source for pre-rendered screen generation is opaque binary BASIC. Needs converting to Python scripts. Related: PC-side tooling item #1.

5. **Rocket editor won't connect to emulator** — Unable to establish connection between the Rocket sync tracker and beebjit in the current dev environment. Root cause unknown. This may push the decision to replace Rocket with a simpler sequencing approach.
