# Phase 1 — Chunk 1: Foundation + smoke-test generation

Kicks off the procedural world-gen feature described in `planning/world_gen.md`. This chunk ships scaffolding only — no WFC, no props, no furniture. Proves the `@tool` pipeline and deterministic seeding end-to-end by rendering a trivial room (floor fill + wall border) when the Generate button is pressed.

## Scope

**In:**
- `TileMeta` autoload with `Category`, `Socket`, and `Direction` enums.
- `RngStreams` helper: single seed → named sub-streams via hashing, plus derived child seeds.
- `BuildingGen` (`@tool`, exported `building_seed`, `room_size`, `Generate`/`Randomize Seed` buttons). Trivial generator: floor fill inside, wall ring around the border.
- `WorldGen` (`@tool`, exported `world_seed`, `Generate`/`Randomize Seed` buttons). Iterates child `BuildingGen` nodes, derives per-building seeds, and calls their `generate()`.
- Attach scripts to the existing `building_gen.tscn` / `world_gen.tscn`.
- GUT unit test covering `RngStreams` determinism.

**Deliberately out (deferred to later chunks):**
- WFC algorithm and constraint solver.
- TileSet custom data layers (category, sockets, weights, prop metadata).
- Per-tile physics / collision authoring.
- Props `TileMapLayer` + furniture pass + walkability validation.
- Seed persistence in `user://`.
- Removal of `test_level.gd`. For this chunk, `main.tscn` stays as-is — `test_level.gd` continues to handle responsive layout / player placement while `WorldGen` renders tile output alongside it. Full removal lands once the generator + player positioning are wired properly.

## Design notes / decisions

- **Direction convention (locked mid-chunk):** For every atlas source, atlas x-coord encodes direction: `N=0, W=1, E=2, S=3` (NWES). `TileMeta.Direction` enum mirrors this so consumers say `Vector2i(Direction.NORTH, row)` and never pass raw ints. User commits to fixing sources that violate this. Saved to persistent memory.
- **Tile mappings for Chunk 1:**
  - Floors: source id 9, atlas coords `(0,0)..(3,0)` — four floor variants sampled with a dedicated `floor_variants` RNG stream.
  - Walls: source id 4, atlas coords indexed by the NWES direction convention.
- **Seed naming:** avoid `seed` as an identifier to sidestep the built-in `seed()` function; using `building_seed` and `world_seed`.
- **Editor preview ephemerality:** `@tool` scripts populate the `TileMapLayer` on button press. The scene will mark dirty if saved — convention for Chunk 1 is "don't save after previewing." Upgrade to a dedicated preview node is tracked in the plan doc.
- **Runtime entry:** `_ready()` checks `Engine.is_editor_hint()` and triggers generation only at runtime. Editor generation happens exclusively via the tool button. Same code path underneath.
- **Engine version:** `project.godot` now declares `4.6` (was 4.4 in the earlier plan doc). Notes updated; `@export_tool_button` is a 4.4+ feature so no compatibility concern.

## Verification plan

1. Open `scenes/building_gen.tscn` in the Godot editor.
2. Inspector shows: `Building Seed`, `Room Size`, `Generate` button, `Randomize Seed` button.
3. Click `Generate` → 8×8 room renders (floor fill, wall border).
4. Click `Generate` again with same seed → identical render.
5. Click `Randomize Seed` → new seed, different floor variant pattern (wall layout unchanged since border is deterministic).
6. Repeat from `scenes/world_gen.tscn` (`World Seed` → forwards derived seed to the child building).
7. Run GUT: `RngStreams` determinism tests pass.
