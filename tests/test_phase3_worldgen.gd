extends GutTest

# Phase 3 tests: multi-floor generation, stair placement, floor switching,
# basement support, cross-floor reachability, and building cache.


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_building(seed: int, cols: int, rows: int, floors: int, basement: bool) -> BuildingGen:
	var b := BuildingGen.new()
	b.building_seed = seed
	b.room_size     = Vector2i(8, 8)
	b.room_cols     = cols
	b.room_rows     = rows
	b.num_floors    = floors
	b.has_basement  = basement
	return b


# ── StairPlacer ───────────────────────────────────────────────────────────────

func test_stair_placer_produces_one_pair_for_two_floors() -> void:
	var indices: Array[int] = [0, 1]
	var pairs := StairPlacer.place(42, Vector2i(8, 8), 1, 1, indices)
	assert_eq(pairs.size(), 1, "two floors → one stair pair")


func test_stair_placer_produces_two_pairs_for_three_floors() -> void:
	var indices: Array[int] = [0, 1, 2]
	var pairs := StairPlacer.place(42, Vector2i(8, 8), 1, 1, indices)
	assert_eq(pairs.size(), 2, "three floors → two stair pairs")


func test_stair_placer_produces_two_pairs_with_basement() -> void:
	var indices: Array[int] = [-1, 0, 1]
	var pairs := StairPlacer.place(42, Vector2i(8, 8), 1, 1, indices)
	assert_eq(pairs.size(), 2, "basement + two above-ground floors → two stair pairs")


func test_stair_placer_positions_are_interior_cells() -> void:
	var indices: Array[int] = [0, 1]
	var room_size := Vector2i(8, 8)
	var pairs := StairPlacer.place(7, room_size, 2, 2, indices)
	for pair in pairs:
		var sd: StairPlacer.StairData = pair
		# Interior = not on the border (x in 1..6, y in 1..6 for an 8x8 room grid)
		var local_x := sd.tile_pos.x % room_size.x
		var local_y := sd.tile_pos.y % room_size.y
		assert_true(local_x > 0 and local_x < room_size.x - 1,
			"stair x=%d should be interior (not on x-border)" % sd.tile_pos.x)
		assert_true(local_y > 0 and local_y < room_size.y - 1,
			"stair y=%d should be interior (not on y-border)" % sd.tile_pos.y)


func test_stair_placer_is_deterministic() -> void:
	var indices: Array[int] = [0, 1]
	var p1 := StairPlacer.place(999, Vector2i(8, 8), 2, 2, indices)
	var p2 := StairPlacer.place(999, Vector2i(8, 8), 2, 2, indices)
	assert_eq(p1.size(), p2.size())
	for i in p1.size():
		var a: StairPlacer.StairData = p1[i]
		var b: StairPlacer.StairData = p2[i]
		assert_eq(a.tile_pos, b.tile_pos, "pair %d should be identical for same seed" % i)


func test_stair_placer_different_seeds_differ() -> void:
	var indices: Array[int] = [0, 1]
	var p1 := StairPlacer.place(1, Vector2i(8, 8), 2, 2, indices)
	var p2 := StairPlacer.place(2, Vector2i(8, 8), 2, 2, indices)
	var sd1: StairPlacer.StairData = p1[0]
	var sd2: StairPlacer.StairData = p2[0]
	# Different seeds should (almost certainly) produce different positions.
	# If this flickers, expand the seed range.
	assert_ne(sd1.tile_pos, sd2.tile_pos,
		"different seeds should produce different stair positions")


func test_stair_placer_floor_from_to_match_indices() -> void:
	var indices: Array[int] = [-1, 0, 1]
	var pairs := StairPlacer.place(42, Vector2i(8, 8), 1, 1, indices)
	var sd0: StairPlacer.StairData = pairs[0]
	var sd1: StairPlacer.StairData = pairs[1]
	assert_eq(sd0.floor_from, -1, "first pair: floor_from should be -1 (basement)")
	assert_eq(sd0.floor_to,    0, "first pair: floor_to should be 0 (ground)")
	assert_eq(sd1.floor_from,  0, "second pair: floor_from should be 0 (ground)")
	assert_eq(sd1.floor_to,    1, "second pair: floor_to should be 1 (upper)")


# ── WFC catalog: stair tile defs ─────────────────────────────────────────────

func test_wfc_catalog_has_stair_up_def() -> void:
	var def := WfcRoomGenerator.get_tile_def(
		WfcRoomGenerator.STAIR_UP_SOURCE_ID, Vector2i(0, 0))
	assert_not_null(def, "STAIR_UP tile should be in the WFC catalog")


func test_wfc_catalog_has_stair_down_def() -> void:
	var def := WfcRoomGenerator.get_tile_def(
		WfcRoomGenerator.STAIR_DOWN_SOURCE_ID, Vector2i(0, 0))
	assert_not_null(def, "STAIR_DOWN tile should be in the WFC catalog")


func test_stair_tiles_have_floor_sockets_on_all_sides() -> void:
	for src_id in [WfcRoomGenerator.STAIR_UP_SOURCE_ID, WfcRoomGenerator.STAIR_DOWN_SOURCE_ID]:
		var def := WfcRoomGenerator.get_tile_def(src_id, Vector2i(0, 0))
		assert_not_null(def)
		assert_eq(def.sock_n, TileMeta.Socket.FLOOR,
			"stair source %d: north socket should be FLOOR" % src_id)
		assert_eq(def.sock_s, TileMeta.Socket.FLOOR,
			"stair source %d: south socket should be FLOOR" % src_id)
		assert_eq(def.sock_w, TileMeta.Socket.FLOOR,
			"stair source %d: west socket should be FLOOR" % src_id)
		assert_eq(def.sock_e, TileMeta.Socket.FLOOR,
			"stair source %d: east socket should be FLOOR" % src_id)


# ── Multi-floor generation ────────────────────────────────────────────────────

func test_multifloor_creates_dyn_layers_for_each_floor() -> void:
	var b := _make_building(42, 1, 1, 2, false)
	b.generate()

	var has_floor_0 := false
	var has_floor_1 := false
	for child in b.get_children():
		if child.name == "DynFloor_0":
			has_floor_0 = true
		if child.name == "DynFloor_1":
			has_floor_1 = true
	assert_true(has_floor_0, "DynFloor_0 should exist after 2-floor generate")
	assert_true(has_floor_1, "DynFloor_1 should exist after 2-floor generate")
	b.free()


func test_multifloor_creates_props_layers_for_each_floor() -> void:
	var b := _make_building(42, 1, 1, 2, false)
	b.generate()

	var has_props_0 := false
	var has_props_1 := false
	for child in b.get_children():
		if child.name == "DynProps_0":
			has_props_0 = true
		if child.name == "DynProps_1":
			has_props_1 = true
	assert_true(has_props_0, "DynProps_0 should exist after 2-floor generate")
	assert_true(has_props_1, "DynProps_1 should exist after 2-floor generate")
	b.free()


func test_multifloor_stair_up_tile_on_floor_0() -> void:
	var b := _make_building(42, 1, 1, 2, false)
	b.generate()

	var stair_positions := b.get_stair_up_positions(0)
	assert_false(stair_positions.is_empty(), "floor 0 should have at least one stair-up position")

	var fl: TileMapLayer = null
	for child in b.get_children():
		if child.name == "DynFloor_0" and child is TileMapLayer:
			fl = child
			break
	assert_not_null(fl, "DynFloor_0 TileMapLayer should exist")

	var pos := stair_positions[0]
	assert_eq(fl.get_cell_source_id(pos), WfcRoomGenerator.STAIR_UP_SOURCE_ID,
		"floor 0 at stair position %s should have STAIR_UP tile" % str(pos))
	b.free()


func test_multifloor_stair_down_tile_on_floor_1() -> void:
	var b := _make_building(42, 1, 1, 2, false)
	b.generate()

	var stair_down_positions := b.get_stair_down_positions(1)
	assert_false(stair_down_positions.is_empty(), "floor 1 should have at least one stair-down position")

	var fl: TileMapLayer = null
	for child in b.get_children():
		if child.name == "DynFloor_1" and child is TileMapLayer:
			fl = child
			break
	assert_not_null(fl, "DynFloor_1 TileMapLayer should exist")

	var pos := stair_down_positions[0]
	assert_eq(fl.get_cell_source_id(pos), WfcRoomGenerator.STAIR_DOWN_SOURCE_ID,
		"floor 1 at stair position %s should have STAIR_DOWN tile" % str(pos))
	b.free()


func test_stair_up_and_down_share_same_tile_pos() -> void:
	var b := _make_building(7, 1, 1, 2, false)
	b.generate()

	var up_pos   := b.get_stair_up_positions(0)
	var down_pos := b.get_stair_down_positions(1)
	assert_false(up_pos.is_empty())
	assert_false(down_pos.is_empty())
	assert_eq(up_pos[0], down_pos[0],
		"stair_up on floor 0 and stair_down on floor 1 should share the same XY")
	b.free()


# ── Basement ──────────────────────────────────────────────────────────────────

func test_basement_creates_negative_floor_layer() -> void:
	var b := _make_building(42, 1, 1, 1, true)
	b.generate()

	var has_basement_layer := false
	for child in b.get_children():
		if child.name == "DynFloor_-1":
			has_basement_layer = true
	assert_true(has_basement_layer, "has_basement=true should create DynFloor_-1")
	b.free()


func test_basement_has_stair_up_tile() -> void:
	var b := _make_building(55, 1, 1, 1, true)
	b.generate()

	var up_positions := b.get_stair_up_positions(-1)
	assert_false(up_positions.is_empty(), "basement should have stair_up positions")

	var fl: TileMapLayer = null
	for child in b.get_children():
		if child.name == "DynFloor_-1" and child is TileMapLayer:
			fl = child
			break
	assert_not_null(fl)

	var pos := up_positions[0]
	assert_eq(fl.get_cell_source_id(pos), WfcRoomGenerator.STAIR_UP_SOURCE_ID,
		"basement stair_up position should hold STAIR_UP tile")
	b.free()


func test_ground_floor_has_stair_down_when_basement_present() -> void:
	var b := _make_building(55, 1, 1, 1, true)
	b.generate()

	var down_positions := b.get_stair_down_positions(0)
	assert_false(down_positions.is_empty(),
		"ground floor should have stair_down when basement exists")

	var fl: TileMapLayer = null
	for child in b.get_children():
		if child.name == "DynFloor_0" and child is TileMapLayer:
			fl = child
			break
	assert_not_null(fl)

	var pos := down_positions[0]
	assert_eq(fl.get_cell_source_id(pos), WfcRoomGenerator.STAIR_DOWN_SOURCE_ID,
		"ground floor stair_down position should hold STAIR_DOWN tile")
	b.free()


# ── Floor switching ───────────────────────────────────────────────────────────

func test_floor_switch_changes_active_floor() -> void:
	var b := _make_building(42, 1, 1, 2, false)
	b.generate()
	assert_eq(b.get_active_floor(), 0, "active floor after generate should be 0")
	b.switch_floor(1)
	assert_eq(b.get_active_floor(), 1, "active floor after switch_floor(1) should be 1")
	b.free()


func test_floor_switch_emits_signal() -> void:
	var b := _make_building(42, 1, 1, 2, false)
	b.generate()
	watch_signals(b)
	b.switch_floor(1)
	assert_signal_emitted_with_parameters(b, "floor_changed", [1])
	b.free()


func test_floor_switch_hides_inactive_floor_layers() -> void:
	var b := _make_building(42, 1, 1, 2, false)
	b.generate()
	# After generate, floor 0 is active.
	b.switch_floor(1)

	var floor0_visible := true
	var floor1_visible := false
	for child in b.get_children():
		if child.name == "DynFloor_0" and child is TileMapLayer:
			floor0_visible = (child as TileMapLayer).visible
		if child.name == "DynFloor_1" and child is TileMapLayer:
			floor1_visible = (child as TileMapLayer).visible

	assert_false(floor0_visible, "DynFloor_0 should be hidden after switching to floor 1")
	assert_true(floor1_visible,  "DynFloor_1 should be visible after switching to floor 1")
	b.free()


func test_get_floor_above_below_return_correct_indices() -> void:
	var b := _make_building(42, 1, 1, 3, false)
	b.generate()
	assert_eq(b.get_floor_above(0), 1, "floor above 0 should be 1")
	assert_eq(b.get_floor_above(1), 2, "floor above 1 should be 2")
	assert_eq(b.get_floor_below(1), 0, "floor below 1 should be 0")
	assert_eq(b.get_floor_below(2), 1, "floor below 2 should be 1")
	# Top floor has no floor above it.
	assert_eq(b.get_floor_above(2), 2, "floor above top should return self")
	b.free()


# ── Cross-floor reachability ──────────────────────────────────────────────────

func test_multifloor_stair_reachable_from_spawn_single_room() -> void:
	for seed in [1, 42, 99, 200]:
		var b := _make_building(seed, 1, 1, 2, false)
		b.generate()

		# Validate reachability manually: spawn can reach stair on floor 0.
		var fl: TileMapLayer = null
		for child in b.get_children():
			if child.name == "DynFloor_0" and child is TileMapLayer:
				fl = child
				break
		assert_not_null(fl, "seed=%d: DynFloor_0 should exist" % seed)

		var up_pos := b.get_stair_up_positions(0)
		assert_false(up_pos.is_empty(), "seed=%d: floor 0 needs stair-up" % seed)

		var spawn := b._find_floor_spawn(fl)
		assert_ne(spawn, Vector2i(-1, -1), "seed=%d: spawn should be found" % seed)
		assert_true(b._can_reach(fl, spawn, up_pos[0]),
			"seed=%d: stair at %s should be reachable from spawn %s" % [seed, up_pos[0], spawn])
		b.free()


# ── Building cache ────────────────────────────────────────────────────────────

func test_building_cache_hit_skips_regeneration() -> void:
	BuildingCache.clear()

	var b := _make_building(77, 1, 1, 2, false)
	b.generate()
	assert_true(BuildingCache.has_building(b.cache_key()),
		"cache should hold the building after generate")

	# Second generate() call should restore from cache (no crash / correct state).
	b.generate()
	assert_eq(b.get_active_floor(), 0, "active floor should remain 0 after cache restore")
	b.free()


func test_building_cache_snapshot_roundtrip() -> void:
	var layer := TileMapLayer.new()
	WfcRoomGenerator.generate(42, layer, Vector2i.ZERO, Vector2i(8, 8))

	var snapshot := BuildingCache.snapshot_layer(layer)
	var restored := TileMapLayer.new()
	BuildingCache.restore_layer(restored, snapshot)

	for cell in layer.get_used_cells():
		assert_eq(restored.get_cell_source_id(cell), layer.get_cell_source_id(cell),
			"restored cell at %s should match original" % str(cell))

	layer.free()
	restored.free()


func test_building_cache_restored_tiles_match_original() -> void:
	BuildingCache.clear()

	var b1 := _make_building(123, 1, 1, 2, false)
	b1.generate()

	# Snapshot floor 0 source IDs before freeing b1.
	var fl1: TileMapLayer = null
	for child in b1.get_children():
		if child.name == "DynFloor_0" and child is TileMapLayer:
			fl1 = child
			break
	assert_not_null(fl1)
	var id_before: Dictionary = {}
	for cell in fl1.get_used_cells():
		id_before[cell] = fl1.get_cell_source_id(cell)
	b1.free()

	# New building with same seed: should restore from cache.
	var b2 := _make_building(123, 1, 1, 2, false)
	b2.generate()

	var fl2: TileMapLayer = null
	for child in b2.get_children():
		if child.name == "DynFloor_0" and child is TileMapLayer:
			fl2 = child
			break
	assert_not_null(fl2)

	for cell in id_before:
		var v: Vector2i = cell
		assert_eq(fl2.get_cell_source_id(v), id_before[v],
			"restored cell at %s should match original source_id" % str(v))

	assert_eq(fl2.get_used_cells().size(), id_before.size(),
		"cached generation should produce same number of tiles as original")
	b2.free()
	BuildingCache.clear()


func test_building_cache_clear_forces_fresh_generation() -> void:
	BuildingCache.clear()
	var b := _make_building(88, 1, 1, 2, false)
	b.generate()
	assert_true(BuildingCache.has_building(b.cache_key()))
	BuildingCache.clear()
	assert_false(BuildingCache.has_building(b.cache_key()),
		"cache should be empty after clear()")
	b.free()


# ── Determinism ───────────────────────────────────────────────────────────────

func test_multifloor_is_deterministic() -> void:
	BuildingCache.clear()

	var b1 := _make_building(321, 1, 1, 2, false)
	b1.generate()
	var fl1: TileMapLayer = null
	for child in b1.get_children():
		if child.name == "DynFloor_0" and child is TileMapLayer:
			fl1 = child
			break

	BuildingCache.clear()
	var b2 := _make_building(321, 1, 1, 2, false)
	b2.generate()
	var fl2: TileMapLayer = null
	for child in b2.get_children():
		if child.name == "DynFloor_0" and child is TileMapLayer:
			fl2 = child
			break

	assert_not_null(fl1)
	assert_not_null(fl2)
	for cell in fl1.get_used_cells():
		var v: Vector2i = cell
		assert_eq(fl2.get_cell_source_id(v), fl1.get_cell_source_id(v),
			"cell %s should match between two generates with seed 321" % str(v))

	b1.free()
	b2.free()
	BuildingCache.clear()
