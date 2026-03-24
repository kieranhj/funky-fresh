# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Funky Fresh is a BBC Micro demo written in 6502 assembly, targeting the Acorn BBC Micro. It combines real-time visual effects synchronized to music via the Rocket keyframe tracker.

## Build & Run Commands

```bash
# Build everything (code + disc image)
make.bat

# Individual build stages
make.bat disc    # Full disc image
make.bat code    # Compile assembly only (requires music + assets first)
make.bat music   # Convert VGM audio to BBC format
make.bat assets  # Process all graphics/data assets
make.bat clean   # Remove build/ and disc/ directories

# Run in emulator with Rocket sync
run.bat

# Open ROM editor
editor.bat
```

The build uses `snmake.exe -f Makefile.mk`. Python 2 is used for graphics/audio conversion; Python 3 for Rocket track processing.

## Architecture

### Memory Layout

- **Zero page (`zp.h.asm`):** System variables, FX state, task state
- **Main RAM `&0E00`:** Entry point, framework, init code, vsync loop
- **Screen buffers:** `&3000` (main), shadow screen
- **SWRAM BANK0:** Compressed screen assets (doom-screen, scr-screen)
- **SWRAM BANK1:** Additional compressed images
- **SWRAM BANK2:** Display FX code (loaded and executed from here)
- **SWRAM MUSIC:** VGM playback data
- **SWRAM HAZEL:** Scroller font and additional data

### Effect System

Effects are defined in `src/display-fx.asm` as a dispatch table. Each effect (indices `&00`–`&0C`) provides two entry points:

- **Update** — runs after vsync, before IRQ (safe for computation)
- **Draw** — runs during active display period (timing-critical, tight cycle budget)

Effect source files follow the pattern `src/fx-*.asm`. To add a new effect: implement the update/draw pair, add it to the dispatch table in `display-fx.asm`, and assign it a Rocket track.

### Rocket Synchronization (`src/rocket.asm`)

Keyframe-based animation system. Rocket `.track` binary files (converted from `.rocket` project files via `bin/rocket2bbc.py`) are loaded from disc and drive all parameter animation. Supports step, linear, smooth, and ramp interpolation. Track list defined in `data/rocket/track_list.txt`.

### Task System (`src/tasks.asm`)

Background tasks execute during non-display periods (between frames). Used for decompressing assets to screen buffers:
- `task_decrunch_asset_to_main`
- `task_decrunch_asset_to_shadow`
- `task_wipe_screens`

### Asset Pipeline

| Source | Tool | Output |
|--------|------|--------|
| `.png` (Mode 2 graphics) | `bin/png2bbc.py` | `.bin` raw screen |
| `.bin` raw screen | `bin/exomizer.exe` | `.exo` compressed |
| `.png` (font) | `bin/png2bbc_font.py` | font binary |
| `.vgm` (music) | `bin/vgmconverter.py` + `vgmpacker.py` | `.vgc` compressed |
| `.rocket` (animation) | `bin/rocket2bbc.py` | `.track` binary |

All compressed binaries land in `build/`. The disc image is assembled via `src/disc-layout.asm`.

### Video Mode

Custom CRTC register configuration for Mode 2 (320×256, 8 colours, 2 pixels/byte). Frame timing is 312×128 cycles, synchronized via VIA 1MHz timer. Raster effects use precise cycle counting — see `lib/cycles.asm` and `ref/RVI.txt`.

## Key Files

| File | Purpose |
|------|---------|
| `src/funky-fresh.asm` | Main entry point, init, vsync loop |
| `src/display-fx.asm` | Effect dispatch table |
| `src/ram-banks.asm` | SWRAM bank layout and asset addresses |
| `src/tasks.asm` | Background decompression task system |
| `src/rocket.asm` | Rocket keyframe sync engine |
| `lib/bbc.h.asm` | BBC Micro hardware constants |
| `lib/vgcplayer.asm` | VGM music player |
| `Makefile.mk` | Full build rules |
| `ref/funky-fresh.txt` | Detailed implementation notes |
