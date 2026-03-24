# RVI — Raster Vertical Interrupt Technique

## The 6845 CRTC on the BBC Micro

The BBC Micro uses a Motorola/Hitachi 6845 CRTC to generate the video signal. It has two nested counters:

- **Horizontal character counter (HCC)**: counts 0 to R0, incrementing once per character time. Resets to 0 after reaching R0, starting a new scanline. One full scanline takes **(R0+1)** character times.
- **Vertical character counter (VCC)**: counts 0 to R4, incrementing each time HCC resets. One full frame takes **(R4+1)** character rows.
- **Scanline counter (VLC)**: counts 0 to R9 within each character row. Each character row takes **(R9+1)** scanlines. VCC increments when VLC resets.

In Mode 2 the CRTC runs at **2MHz**, giving 1 character time = 0.5µs. With the default R0=127, one scanline is 128 character times = 64µs = 15.625kHz. The BBC CPU also runs at 2MHz (nominally), so one CRTC character time ≈ one CPU cycle. This is why code comments use **"c" to mean both character times and CPU cycles interchangeably** for Mode 2 — 128c = one scanline.

The VIA T1 timer runs at 1MHz, so the frame period in timer ticks is 312 × 64 = 19968 ticks = 19.968ms ≈ 50Hz.

### Key registers

| Reg | Name | Function |
|-----|------|---------|
| R0 | Horizontal Total | (R0+1) character times per scanline. Short values burn scanlines rapidly. |
| R4 | Vertical Total | (R4+1) character rows per frame. R4=0 means 1 row per frame. |
| R6 | Vertical Displayed | Rows with DISPEN active. |
| R7 | Vertical Sync Position | Row at which VSync pulse fires. |
| R9 | Maximum Raster | (R9+1) scanlines per character row. Controls the sub-scanline selection. |
| R12 | Screen Start High | Bits 13–8 of the 14-bit memory address, latched at frame start. |
| R13 | Screen Start Low | Bits 7–0 of the 14-bit memory address, latched at frame start. |

The 14-bit R12/R13 address feeds directly into the BBC's memory addressing hardware. On the BBC the address is divided by 8 before being stored in R12/R13, as the CRTC address is in units of 8 bytes (one character row = 8 bytes wide in Mode 2's screen layout).

### When R12/R13 take effect

The 6845 latches R12/R13 into the active screen address when **both VCC=0 and VLC=0** — the start of a new frame. This means:

- In normal operation, changes to R12/R13 only take effect on the next frame (too late for per-scanline control).
- With **R4=0** (1 row per frame), VCC is always 0. Therefore the latch condition is satisfied at the start of *every* character row (when VLC resets to 0). This is the mechanism that allows R12/R13 to be changed per scanline in RVI — setting R4=0 makes every row a new "frame", and writing R12/R13 during one row takes effect at the start of the next.

---

## Framework entry point

The draw function is called by the IRQ handler at exactly **HCC=0, scanline=-2** — two scanlines before the visible display area begins. This is achieved by:

1. **Timer1 (VIA T1)** fires at the end of the visible display (after scanline 239). The timer is in free-run mode and alternates between two latch values: `VisibleDisplayPeriod` (258 × 64 ticks) and `VBlankDisplayPeriod` (54 × 64 ticks).

2. A **NOP slide** in the IRQ handler corrects for 1MHz timer jitter. The T1 counter runs at 1MHz but the CPU at 2MHz, so the timer fires with up to ±4 CPU cycles of jitter. The bottom 3 bits of the T1 low counter are read, inverted, and used to branch into a 7-NOP slide, adding 0–14 CPU cycles to reach a stable 2MHz-aligned position:
```asm
lda &fe44       ; read T1 low byte (also clears IFR T1 flag)
and #7
eor #7
sta branch+1
.branch
bpl branch      ; always-branch, operand patched to skip 0-7 NOPs
.slide
nop:nop:nop:nop
nop:nop:cmp &93
.stable
```

3. After the slide, the SWRAM bank is selected and the draw function is `jsr`'d from a known cycle position. The draw function begins with HCC≈0 on scanline -2.

`prev_scanline` (ZP) holds the sub-scanline value (0, 2, 4, or 6) from the last visible row of the previous frame, needed to compute R9 for the first display row.

---

## Core principle: R9 and the scanline counter

R9 defines the scanline counter maximum. The counter counts 0 → R9, then resets to 0 and increments VCC. Writing a new R9 value during the **final scanline of a character row** sets up how many scanlines the *next* row will have, because R9 is sampled as the counter reaches its end.

This is the timing requirement: **R9 must be written before the last scanline of the current row**, not during it, so it takes effect at the start of the next row rather than the current one.

To display sub-scanline `next` when the previously displayed scanline was `current`:

```
R9 = 13 + current - next
```

For example, current=6, next=0 → R9=13. Current=0, next=2 → R9=11.

The formula works because: with R4=0, after the current row's final scanline the VLC reaches R9 and the CRTC immediately starts a new "frame" (VCC and VLC both reset to 0). The number of short burn-scanlines between the end of the visible scanline and sub-scanline `next` must be exactly `R9 - current + next - something`... in practice the constant 13 is derived empirically from the specific timing of the implementation.

---

## Double-line RVI (the main technique)

All RVI effects except `fx-path-zoom` use double-line RVI:

- **R4=0** — one character row per frame (enables per-row R12/R13 updates)
- **R9=1** — 2 scanlines per row (each display row appears on 2 consecutive scanlines)
- 119 visible rows × 2 = 238 scanlines; 37 more rows fill to 312 total

Per row, the draw loop:
1. Updates texture coordinate `v`
2. Writes R12/R13 to select which screen row to display
3. On the odd scanline: writes R9 for the next row, dispatches to the scanline routine

### Scanline routines (RTW's technique)

The draw functions use a self-modifying indirect jump. A 4-entry `jmptab` stores the **low byte only** of each routine address. All four routines must therefore share the same 256-byte page, enforced by `CHECK_SAME_PAGE_AS`. A `JMP` instruction is patched at runtime to dispatch to the correct routine:

```asm
lda jmptab, X          ; X = next scanline quadrant (0-3)
sta jmpinstruc+1       ; patch low byte of JMP target
...
.jmpinstruc JMP scanline0   ; dispatched at HCC ≈ 101 (odd scanline)
.^jmpreturn                 ; all routines return here at HCC ≈ 122
sta &fe01                   ; HCC=128: write R0=127 (pre-loaded in A) to restore normal width
```

Each scanline routine runs from HCC≈101 to HCC=122 and sets R0 to a short value to burn the required number of sub-scanlines before the next visible scanline starts:

```
scanline0: R0=127           (no burn — sub-scanline 0 is first)
scanline2: R0=119, then R0=3  (burn 2 sub-scanlines of 2 chars each)
scanline4: R0=119, then R0=1  (burn 4 sub-scanlines)
scanline6: R0=115, then R0=1  (burn 6 sub-scanlines)
```

**How burning works**: R0 normally equals 127 (128 character times per scanline). Setting R0=1 makes each subsequent scanline only 2 character times long. The CRTC burns through these very quickly, exhausting the VLC counter (advancing sub-scanlines) at negligible cost. When R0 is restored to 127 (or 115/119 for partial-width cases), normal visible scanlines resume. The target sub-scanline then appears as the first line of the next character row.

The value written to restore R0 is pre-loaded into A before the JMP dispatch and written immediately on return at HCC=128:
```asm
lda #127           ; pre-load
...
.jmpinstruc JMP scanline0
.^jmpreturn        ; HCC=122
sta &fe01          ; HCC=128 — restores R0=127
```

### Scanline quadrant

The `txa:and #3:tax` pattern (seen in several effects) maps bits 0–1 of `v+1` (the high byte of the texture coordinate) to the jmptab quadrant index 0–3. Since `v+1` advances with `dv` each row, the scanline selection follows the texture scroll automatically — no separate counter is needed.

---

## Single-scanline RVI

`fx-path-zoom` uses a simpler variant: **R9=0, R4=0** — exactly 1 scanline per character row. No sub-scanline selection is needed; the CRTC naturally advances to a new row every scanline, and writing R12/R13 once per loop iteration is enough (the VCC=0 latch condition is met at the start of every row). Entry is at HCC=32, after a `WAIT_SCANLINES_ZERO_X 1` from scanline=-1.

---

## LHS garbage and blanking

When R12/R13 are written early in a scanline, the new address takes effect at the start of the *next* row (VLC=0). But for the first few character columns of the transitioning scanline, the CRTC may output pixels from the old address before fully settling. This produces visible garbage columns on the left edge of the screen.

The TELETEXT trick uses the ULA control register at `&FE20` to blank the output:

```asm
MACRO TELETEXT_ENABLE_6    ; LDA #&F6:STA &FE20   (6c) — blanks output
MACRO TELETEXT_DISABLE_7   ; LDA teletext_disable:STA &FE20   (7c) — restores output
```

Writing `&F6` to the ULA enables teletext mode, which forces the display output to blank (black). Writing `&F4` restores Mode 2. By enabling blanking for the transition cycles at the start of each odd scanline and disabling it once the CRTC has settled, the artifact columns are hidden.

This is used in `fx-chunky-twister` and optionally in `fx-vertical-stretch` (`_FX_VERT_STRETCH_REMOVE_RVI = TRUE`). The cost is 13c per scanline for the enable+disable pair, reducing the available budget for effect logic. It can also cause visible column artifacts on real hardware depending on monitor and CRTC variant.

---

## Cycle budget and helper macros

One scanline = 128c (128 CRTC character times at 2MHz = 64µs). The draw function must produce a complete, valid 312-scanline PAL signal.

| Macro | Effect | Cost |
|-------|--------|------|
| `WAIT_CYCLES n` | Burn exactly n cycles: `JSR do_nothing` (12c each) + NOPs | n cycles |
| `WAIT_SCANLINES_ZERO_X n` | Wait n full scanlines from JSR entry; **destroys X** | n × 128c − 2c |
| `WAIT_SCANLINES_PRESERVE_REGS n` | As above, preserves A/X via stack | n × 128c − 20c |
| `PAGE_ALIGN_FOR_SIZE n` | Align to 256-byte page if next n bytes would cross one | — |
| `CHECK_SAME_PAGE_AS base, fatal` | Assert/warn that P% shares a page with `base` | — |

A typical per-scanline budget breakdown in a double-line RVI loop (even scanline):

| Operation | Cycles |
|-----------|--------|
| Update v (16-bit add, self-mod immediate) | ~8c |
| Write R12/R13 (4 × CRTC reg writes) | ~28c |
| Map v to scanline quadrant | ~6c |
| Write R9 + jmptab dispatch (odd scanline) | ~18c |
| Scanline routine body (scanline0–6) | ~21c |
| Restore R0 + loop overhead | ~12c |
| **Available for effect work** | **~35c** |

---

## `prev_scanline` — inter-frame handoff

`prev_scanline` stores the VLC sub-scanline value (0, 2, 4, or 6) that was active at the last visible row of the previous frame (scanline 310). The draw function reads it on entry to compute R9 for the very first character row:

```asm
lda #13
clc
adc prev_scanline     ; current sub-scanline from previous frame
sec
sbc next_scanline     ; target sub-scanline for row 0 (from update)
sta &fe01             ; write R9
```

At the end of the draw function, each effect must set `prev_scanline` correctly:
- Double-line RVI effects (R9=1 at frame end): set `prev_scanline = 0`
- Effects using standard R9=7 (8 scanlines/row): set `prev_scanline = 6`

---

## Full frame structure

```
scanline −2  ← draw function entry (HCC=0)
             ← R12/R13 set for row 0; R9 computed from prev_scanline
scanline −1  ← R4=0 and R9=1 written (take effect after this scanline)
scanline   0 ← first visible row (row 0, sub-scanline per next_scanline)
 ...
scanline 237 ← last visible row (row 119 of 119)
             ← R4=36, R7=17 written
scanline 238 ← post-visible; CRTC now using standard R4/R9
 ...
scanline 271 ← VSync fires (CRTC row 34 from scanline 238)
 ...
scanline 311 ← last scanline of frame
             ← Timer1 fires → IRQ vblank handler:
                  music update → Rocket tracks → tasks → FX update
             ← Timer1 re-latched → fires again at end of visible display
scanline −2  ← draw function called again (next frame)
```

The draw function is solely responsible for producing a valid 312-scanline PAL signal. If R4, R6, R7, R9 are not set correctly before the CRTC re-reads them, the signal will be invalid and the monitor may lose sync.
