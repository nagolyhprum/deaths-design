Do three things:

1. **Add a prominent NOTE in world_gen.md** under Phase 1 that says the following two items require editor work and must be done manually when back at the computer:
   - Add TileSet custom data layers (category, socket, weight, anchor) in the Godot editor
   - Add collision shapes per tile in the TileSet editor
   Mark these clearly as "⚠️ MANUAL EDITOR STEP REQUIRED" so they're impossible to miss.

2. **Update world_gen.md checkboxes** — go through Phase 1 and Phase 2 items and mark each one with [x] if it's implemented in code, [ ] if it still needs work, and the ⚠️ note for the two editor-only items above.

3. **Write tests for Phase 1 and Phase 2** — read the actual scripts (wfc_room_generator.gd, furniture_pass.gd, building_gen.gd, room_graph.gd, world_gen.gd, tile_meta.gd) and write GUT tests covering:
   - Phase 1: WFC produces a valid room grid, seed persistence saves/loads correctly, furniture pass doesn't place props on non-walkable tiles
   - Phase 2: room_graph assigns room types, building_gen connects all rooms (flood-fill passes), door stitching produces matching sockets on shared walls

   Put tests in a `tests/` folder. Run them headless to confirm they pass. Fix any failures found.

Commit and merge to main.
