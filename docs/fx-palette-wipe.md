# fx-palette-wipe — Technical Notes

## What it does

A palette transition effect that sweeps through all 16 ULA palette entries one-by-one, replacing a "from" colour with a "to" colour at a controlled speed. It operates on whatever screen was last displayed — it owns no screen RAM of its own.

## Trigger mechanism

The wipe is triggered by a **change** in `rocket_track_x_pos+1` (the "from colour"). On every frame, the current value is compared to the cached `wipe_from`; if different, a new wipe is initialised. This means the Rocket track only needs a step key to trigger — the wipe runs itself to completion at the speed set by `rocket_track_zoom`.

On init (`display_fx_init` set), `wipe_from` is set to `&ff` to ensure the first step-key always triggers.

## Wipe sequence

1. `fx_palette_wipe_init_new_wipe` sets all 16 `fx_palette_wipe_palette` entries to `(from_colour EOR 7)` — this is the ULA encoding of a physical colour (logical N maps to `N*&10 + physical EOR 7`)
2. Each frame, `wipe_counter` counts down from `rocket_track_zoom+1` (minimum 1)
3. When it reaches 0, the next palette entry (`wipe_index`) is updated: `(entry & &F0) OR (to_colour EOR 7)`
4. `wipe_index` increments; at 16 the wipe is complete and does nothing further

## No draw function

This FX has **no draw entry point**. After the update logic it falls through to `fx_palette_wipe_init_set_all`, which writes all 16 palette entries to `&FE21` on every frame. The display contract relies entirely on the static image being already visible from the previous frame's draw.

## Rocket tracks used

| Track | Purpose |
|-------|---------|
| `rocket_track_zoom+1` | Frames per step (speed) — 0 treated as 1 |
| `rocket_track_x_pos+1` | "From" colour (change triggers new wipe) |
| `rocket_track_y_pos+1` | "To" colour |

## Known issues / TODOs

**Shadow support** — always uses the last-displayed screen; no way to specify MAIN or SHADOW.

**Wipe direction** — always steps palette entries 0→15; no reverse or random order.

**Colour ramp** — only supports a flat colour swap; no support for intermediate gradient colours during the wipe.

**8 vs 16 colour wipes** — currently always sweeps all 16 entries; could be more impactful to sweep only the 8 logical colour entries.

**More interesting wipes** — the ref notes suggest vertical blinds effects; currently this is just a linear palette sweep.
