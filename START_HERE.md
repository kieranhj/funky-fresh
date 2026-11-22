# funky-fresh: start here

"Funky Fresh Framework": a BBC Micro (Master) demo in 6502 assembly (beebasm), with raster/RVI effects sequenced to music via the Rocket sync tracker. A demo plus its PC-side asset pipeline.

| | |
|---|---|
| GitHub | https://github.com/kieranhj/funky-fresh (public) |
| Local path | D:\beeb\mine\funky-fresh (moved from OneDrive\BEEB\Repos\funky-fresh on 2026-11-22) |
| Branch | wip/claude-counts-cycles (checked out, 38 commits ahead of main; main last moved 2021-06-21). Many other branches: wip/* effect branches (2021-2022), experimental-*, chunky-twister-v2, shelf-checkers, wip/lets-do-this (2026-04), wip/2026-11-tidy |
| Last commit | 2026-07-03: Ran Claude RVI skill across all the FX. |

## What's in here
- `src/` - the demo: `funky-fresh.asm`, `disc-layout.asm`, `fx-*.asm` effects; `lib/` - shared code (exo decompressor, etc.).
- `data/` - music (`beeb-demo.vgm`), gfx PNGs, `rocket/` tracks, `raw/` (12 prerendered binaries with no generator yet).
- `bin/` - bundled tools: beebasm, exomizer, beebjit, snmake (GNU make), editor (Rocket), Python converters (png2bbc*, vgmconverter3, vgmpacker, rocket2bbc).
- `Makefile.mk` - the real build; `make.bat` runs it with `bin\snmake.exe`.
- `docs/` - technical docs; `ref/` - reference sources; `roms/`; `disc/funky-fresh.ssd` (tracked build output).
- `TODO.md` (tooling ideas), `progress.md` (Python 3 migration log), `CLAUDE.md`.

## Build and run
- `make`: runs `bin\snmake.exe -f Makefile.mk disc` -> music, assets, code, then `disc\funky-fresh.ssd`. Other targets: `make code`, `make clean`, `make help`.
- Tested 2026-11-22 on a scratch copy (works). Not run in place, because the `disc` target deletes and recreates `disc\`, and `disc/funky-fresh.ssd` has uncommitted changes.
- Tools: all in `bin\` (Python 3 `python.exe` on PATH for the converters; no Python 2 needed any more, see progress.md).
- Run: `run.bat` launches `bin\beebjit` (Master, autoboot, Rocket sync on); `editor.bat` starts the Rocket editor.

## Local changes
- Uncommitted now: `TODO.md` (+89 lines), `disc/funky-fresh.ssd` (rebuilt), `run.bat` (Rocket options), untracked `ref/frak-sprites.asm`.
- `wip/2026-11-tidy` (local + origin) is a snapshot of exactly that uncommitted work as of 2026-11-21 (same 4 files).
- 11 wip/* branches are pushed to origin; most are 2021-2022 effect experiments.

## Status and next steps
- 2026 work: scripts converted to Python 3, technical docs + TODO added, a static-screen width fix, and an RVI cycle-count pass over every effect.
- Next ideas are in TODO.md (PC-side tooling: replace BASIC prerenderers, previewer, cycle analyser, zx0 instead of Exomizer, ...).
- Branch hygiene: decide which of the many wip/experimental branches still matter, and whether this branch should become main.

## See also
- CLAUDE.md (build stages, architecture), TODO.md, progress.md, docs/.
- D:\beeb\third-party\fdload_dfs has rvi-cycle-check configs that point at this repo's FX files.
