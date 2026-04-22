# Phase 1 Audit Results

## Done before this session
- `TileMeta` autoload with Category, Socket, Direction enums — ✅
- `rng_streams.gd` — ✅
- `building_gen.gd` @tool scaffold (seed, buttons) — ✅
- `world_gen.gd` @tool scaffold (world_seed, buttons, child iteration) — ✅
- `test_rng_streams.gd` — ✅

## Missing (implemented in this session)

### Phase 1
- `wfc_room_generator.gd` — NEW. Pure WFC with pre-constrained borders, fixed-constraint API
  for door stitching (Phase 2). Bounded retries + trivial fallback.
- `furniture_pass.gd` — NEW. Anchor-based prop placement, flood-fill walkability validation.
  Phase 1 palette is empty (no prop tile assets exist yet); infrastructure is in place.
- `tile_meta.gd` — Added Anchor and RoomType enums.
- `building_gen.gd` — Updated: calls WFC then FurniturePass, multi-room support via
  room_columns/room_rows exports.
- `building_gen.tscn` — Added Props TileMapLayer child.
- `world_gen.gd` — Added seed persistence (user://worldgen.cfg).
- `test_level.gd` — Removed ROOM_LAYOUT constant, custom draw loop, room-collision
  runtime building; kept viewport-responsive UI layout.

### Phase 2
- `room_graph.gd` — NEW. BSP-style split into N rooms, assigns RoomType, places doors
  on shared walls, returns door constraints for WFC per room.
- `building_gen.gd` — Multi-room: generates room graph, runs WFC per room with door
  constraints, runs FurniturePass per room, validates flood-fill connectivity.
- `world_gen.gd` — Generates 2 buildings side-by-side; routes outdoor TileMapLayer
  between entrance tiles.
- `player.tscn` — Added Camera2D child for camera-follows-player.

## Known gaps / deferred
- TileSet custom data layers (category, socket_n/e/s/w, weight, anchor, room_types,
  clearance) — need to be authored in the Godot editor. WFC and FurniturePass use
  source_id as a proxy for now.
- Collision shapes per tile — need editor authoring.
- Actual prop tile assets — furniture pass is wired but palette is empty.
- Outdoor tile routing — basic placement done but routing algorithm is placeholder.
