# World Generation Plan

Living plan for procedural building generation in Deaths Design. Updated as phases land or decisions change.

## Overview

Multi-pass procedural generation of multi-floor buildings:

1. **Graph/layout tier** — pick footprint, divide into rooms, assign types, place doors and stairs.
2. **Tile WFC tier** — Wave Function Collapse within each room laying down floors, walls, and doors, with tier-1 decisions as fixed constraints.
3. **Furniture pass** — populate rooms with props based on room type, anchor rules, and a dedicated RNG stream. Validated with a walkability flood-fill.
4. **Hazard pass** *(Phase 4)* — hazards are a specialized prop subtype; same pipeline, own RNG stream, telegraph-visibility validation.

## Architecture

- `world_gen.tscn` — top-level world scene. Holds all `building_gen` instances and an outdoor `TileMapLayer` for terrain between buildings. Owns world-level generation (placement, streets, connectivity).
- `building_gen.tscn` — one instance per building. Generates its own interior via WFC. Contains **one `TileMapLayer` per floor** (ground, upper floors, basement). Only the active floor is enabled at a time.
- `TileMeta` autoload (`scripts/tile_meta.gd`) — shared enums for tile categories, sockets, anchor rules, and room types.
- Runtime and editor both drive generation through the same pure `generate(seed, tile_map_layer)` function so previews match gameplay.

## Locked decisions

- **Floor model:** one active floor rendered at a time. Stairs are transition tiles. Internally a building is a `[x, y, floor]` grid expressed as one `TileMapLayer` per floor under `building_gen`.
- **Rendering:** Godot `TileMapLayer` (isometric mode) replaces the custom sprite-draw approach. The existing `_rebuild_room_layout` / `_build_collision_body` / `_build_atlas_texture` path is removed.
- **Collision:** lives on the TileSet resource (`physics_layers` + per-tile collision shapes), not runtime-tagged per placement.
- **Tile metadata:** TileSet **custom data layers** (`category: int`, `socket_n/e/s/w: int`, `weight: float`) backed by enums in the `TileMeta` autoload. Plain int in the editor for Phase 1; upgrade to a `TileMetadata` resource with dropdowns if authoring gets painful.
- **Determinism:** one user-facing **world seed**. `world_gen` derives per-building seeds (`hash(world_seed, "building", grid_pos)`). Each `building_gen` splits its seed into named sub-streams (`layout`, `wfc`, `hazards`, …). No global `randi()`.
- **Seed exposure:** `building_gen.seed` is an exported property. `world_gen` sets it when placing a building. A building can also be instanced standalone with a hand-set seed for isolated iteration.
- **Entrance coupling:** `world_gen` decides which edge of each building faces the street and passes that as a constraint (e.g. `entrance_side`) into `building_gen`. WFC treats that tile as a fixed door.
- **Editor preview:** both `world_gen.gd` and `building_gen.gd` are `@tool` scripts exposing a `world_seed` / `seed` int and `@export_tool_button("Generate")` in the inspector. Also `@export_tool_button("Randomize Seed")`.
- **Preview is ephemeral:** generating in the editor must not persist into the saved scene. Runtime regenerates fresh on load; editor generates into the same `TileMapLayer` but the user is expected to not save after preview. Upgrade to a dedicated wipe-on-enter preview node if this bites.
- **Editor/runtime parity:** a single pure `generate(seed, tile_map_layer)` function is called by both the tool button and runtime startup. No divergent code paths.
- **Adjacency authoring:** hand-authored socket table from the existing interior tilesheet. Exemplar-room learning deferred.
- **Camera framing:** Camera2D child on the Player node follows the player with position smoothing.
- **Starting point:** authored `ROOM_LAYOUT` in `test_level.gd` is removed; the generator is the only source of truth for tiles.
- **Props & furniture:** placed in a dedicated pass *after* WFC. Two tracks, one pass:
  - **Simple single-cell props** (plant, chair, small table, counter) live on a dedicated **`props` TileMapLayer** above the floor/wall layer per floor. TileSet custom data layers drive placement: `anchor: int` (`WALL_N/E/S/W`, `CORNER`, `CENTER`, `DOOR_ADJACENT`), `room_types: Array[int]`, `weight: float`, `clearance: int`.
  - **Multi-cell / animated props** (dining table, stove, fridge, bed) are prefab scenes (`scenes/props/*.tscn`) instanced as children of `building_gen` at tile coordinates.
- **Walkability validation:** after the furniture pass, flood-fill from doors and stairs. If any becomes unreachable, unplace the most recent prop or reseed the furniture pass. Bounded retries.
- **Hazards are a prop subtype:** Phase 4 adds hazard behavior onto the same prop infrastructure rather than a parallel system.
- **Y-sort:** isometric props taller than their base tile must have correct Y-sort origin. Tiles use per-tile Y-sort origin in the TileSet; prefab props enable `y_sort_enabled` on the root.

## Phase checklist

### Phase 1 — MVP: seeded single room ✅ *complete as of 2026-04-22*

> ⚠️ **MANUAL EDITOR STEP REQUIRED — do these in the Godot editor before running generation:**
>
> 1. **⚠️ MANUAL EDITOR STEP REQUIRED — Add TileSet custom data layers** (`category`, `socket`, `weight`, `anchor`) in the Godot editor. Open `assets/tiles/building_tiles.tres` in the TileSet editor and add four custom data layers of type `int`/`float` before running generation. These values are what WFC reads at runtime to determine adjacency rules.
>
> 2. **⚠️ MANUAL EDITOR STEP REQUIRED — Add collision shapes per tile** in the TileSet editor. Each wall tile and door tile needs a polygon collision shape assigned in the Physics > Collision Shapes panel. Without this, the player will walk through walls at runtime.
>
> Both items are editor-only and cannot be scripted. All code infrastructure is in place; the generator will run correctly once the TileSet data is authored.

- [x] Delete `ROOM_LAYOUT` constant and its iteration in `test_level.gd`
- [x] Replace `test_level.gd` / `test_level.tscn` with `building_gen.gd` / `building_gen.tscn` (and `world_gen` as its parent)
- [x] Add `TileMeta` autoload (`scripts/tile_meta.gd`) with `Category`, `Socket`, `Direction`, `Anchor`, and `RoomType` enums
- [ ] ⚠️ MANUAL EDITOR STEP REQUIRED — Configure the interior TileSet: isometric mode, collision shapes per tile, custom data layers (`category`, `socket_n/e/s/w`, `weight`) — **must be done in the Godot editor; see note above**
- [ ] ⚠️ MANUAL EDITOR STEP REQUIRED — Hand-author category + socket + weight values for every tile in the existing sheet — **must be done in the Godot editor; see note above**
- [x] `scripts/rng_streams.gd`: helper for splitting a seed into named sub-streams
- [x] `scripts/wfc_room_generator.gd`: pure `generate(seed, tile_map_layer, origin, size, fixed_constraints)` → populates the layer; bounded retry + fallback tile on contradiction; fixed-constraint API for door stitching (Phase 2)
- [x] `building_gen.gd`: `@tool`, exported `building_seed: int`, `room_cols`, `room_rows`, `@export_tool_button("Generate")`, `@export_tool_button("Randomize Seed")`; calls WFC then FurniturePass
- [x] `world_gen.gd`: `@tool`, exported `world_seed: int`, generate/randomize buttons; forwards derived seed to BuildingGen children
- [x] Add a second `TileMapLayer` (`PropsLayer`) for props on `building_gen`
- [ ] ⚠️ MANUAL EDITOR STEP REQUIRED — Add prop-related custom data layers to the interior TileSet (`anchor`, `room_types`, `weight`, `clearance`) and author values for existing prop tiles — **needs editor authoring + prop tile assets**
- [x] `scripts/furniture_pass.gd`: pure function reads WFC result + prop palette, places props on the props layer using a dedicated `furniture` RNG sub-stream, runs flood-fill walkability validation with bounded retry
- [ ] Minimal Phase 1 prop palette: 1–2 props from the existing sheet — **deferred: no prop tile assets in TileSet yet**
- [x] Runtime entry point calls the same `generate()` used by the tool button (WFC → furniture)
- [x] Seed persistence across runtime launches (`user://worldgen.cfg`)
- [ ] Verify: same seed reproduces same room *and* furniture in editor and runtime — **needs editor/runtime verification once collision shapes and prop assets are added**

### Phase 2 — Multi-room layout (single floor) *(in progress as of 2026-04-22)*

- [x] Building footprint + room graph (tier 1) — `scripts/room_graph.gd`
- [x] Room type assignment (kitchen, hall, bedroom, bathroom, living room) — `TileMeta.RoomType`, `RoomGraph._shuffled_room_types`
- [x] Door placement between rooms, treated as WFC fixed constraints — `RoomGraph.door_constraints_for()`
- [x] Per-room WFC stitched at shared walls — `building_gen.gd` `_generate_multi_room()`
- [ ] Per-room-type prop palettes (kitchen → counter/stove/fridge, bedroom → bed/dresser, etc.) — **deferred: no prop tile assets yet**
- [ ] Furniture pass consumes room type to pick the right palette — infrastructure in place; awaits prop assets
- [x] Connectivity validation via flood-fill from spawn (across rooms + through doors) — `building_gen._validate_connectivity()`
- [ ] `world_gen` places multiple buildings, routes outdoor tiles between entrances — placeholder routing implemented; full authoring deferred
- [ ] "Active building" ownership: `world_gen` toggles which building's floor is live — deferred to Phase 3
- [x] Camera follows player — Camera2D child added to `player.tscn`

### Phase 3 — Multi-floor + basements

- [ ] Additional per-floor `TileMapLayer` children inside `building_gen`
- [ ] Stair tiles placed as fixed constraints in tier 1 before WFC runs
- [ ] Floor switching: enable active layer, disable others (visibility + collision) on stair use
- [ ] Basements as negative-indexed floor layers, same generator with different room-type weights
- [ ] Reachability guarantee: every floor accessible from spawn
- [ ] Per-seed building cache so deaths don't trigger regeneration

### Phase 4 — Hazards

- [ ] Hazard definitions per room type (kitchen → stove fire, stairwell → fall, …) as a prop subtype
- [ ] Dedicated `hazards` RNG stream (independent of furniture stream so adding hazards doesn't shift existing furniture layouts)
- [ ] Hazards placed by the same furniture pass pipeline, gated by room type
- [ ] Telegraph-tile visibility validation from likely approach paths
- [ ] Trigger → warning → consequence → reset flow per hazard
- [ ] Death/restart integration

### Phase 5 — Building variety + content

- [ ] Multiple building archetypes (house, shop, apartment, …)
- [ ] Tile set expansion per archetype
- [ ] Goal-structured buildings: spawn → store
- [ ] Exterior / connector generation (streets, paths)

## Open questions / decide later

- WFC failure handling: reseed-per-room vs global restart — decide on first failure observed in Phase 2.
- Tile metadata storage: stay on plain-int custom data layers, or upgrade to a `TileMetadata` Resource for enum dropdowns in the TileSet editor — revisit if Phase 2 authoring gets painful.
- Adjacency learning from exemplar rooms — revisit if hand-authored tables become unwieldy past Phase 3.
- Performance budget: on-demand per-room generation vs upfront whole-building — decide at Phase 2.
- Seed UX: plain integer, string-hashed slug, or daily seed — revisit when debug UI is in use.
- Editor preview persistence model: rely on "don't save after generate" vs dedicated wipe-on-enter preview node — revisit if scenes get accidentally baked.
- "Fill empty space logically" scope: streets-between-entrances only, or decoration as well — decide at Phase 2.
- Multi-cell prop authoring: prefab scenes vs Godot's multi-cell TileSet tiles — decide when the first multi-cell prop (likely dining table) shows up in Phase 2.
- Walkability retry strategy: unplace the most recent prop vs reseed the whole furniture pass — decide on first observed failure.
- Active-building ownership model: which node owns "current building" state and drives floor-layer toggling — decide at Phase 3.

## Change log

- *2026-04-22* — Document created. Phase 1 MVP scoped: single seeded room, one active floor, hand-authored adjacency table, clean slate (no `ROOM_LAYOUT`).
- *2026-04-22* — Architecture locked in: `world_gen` + `building_gen` scenes, one `TileMapLayer` per floor, TileMapLayer-based rendering (replaces sprite-draw), collision on TileSet resource. Single world seed with derived per-building seeds. `world_gen` passes `entrance_side` constraint into `building_gen`.
- *2026-04-22* — Editor preview added: `@tool` scripts, `@export_tool_button` Generate + Randomize Seed on both scenes. Runtime and editor share one pure `generate()` function. Preview is ephemeral.
- *2026-04-22* — `TileMeta` autoload added to plan: enums for `Category` and `Socket`; TileSet custom data layers store the int values. Resource-backed metadata deferred unless authoring is painful.
- *2026-04-22* — Furniture pass added as a dedicated third generation step (post-WFC). Two tracks — single-cell prop tiles on a `props` TileMapLayer, and prefab scenes for multi-cell/animated props. Walkability flood-fill validates each pass. Hazards become a prop subtype in Phase 4, riding the same pipeline. Phase 1 includes a minimal furniture pass (1–2 props) to exercise the whole pipeline end-to-end.
- *2026-04-22* — Phase 1 completed (code). Missing items deferred to editor authoring session: TileSet custom data layers, collision shapes per tile, prop tile assets. `wfc_room_generator.gd`, `furniture_pass.gd` written; `building_gen.gd` updated to use both; `PropsLayer` added to `building_gen.tscn`; seed persistence added to `world_gen.gd`; `ROOM_LAYOUT` removed from `test_level.gd`.
- *2026-04-22* — Phase 2 implemented (code). `room_graph.gd` generates grid-based floor plans with RoomType assignment and door constraints. `building_gen.gd` runs per-room WFC with door stitching and flood-fill connectivity validation. Camera2D child added to `player.tscn`. Prop palettes and outdoor routing remain stubs pending tile assets.
