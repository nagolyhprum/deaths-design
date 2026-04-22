extends GutTest

# Phase 1 tests: WFC produces a valid room grid, seed persistence.
#
# TileMapLayer.set_cell / get_cell_source_id work without the node being in the
# scene tree (data is stored internally), so all tests run fully headless with
# plain TileMapLayer.new() instances freed at the end of each test.


# ── WFC grid correctness ──────────────────────────────────────────────────────

func test_wfc_border_is_all_walls() -> void:
	var layer := TileMapLayer.new()
	WfcRoomGenerator.generate(42, layer, Vector2i.ZERO, Vector2i(8, 8))
	for x in 8:
		assert_eq(layer.get_cell_source_id(Vector2i(x, 0)), WfcRoomGenerator.WALL_SOURCE_ID,
			"north border x=%d should be wall" % x)
	for x in 8:
		assert_eq(layer.get_cell_source_id(Vector2i(x, 7)), WfcRoomGenerator.WALL_SOURCE_ID,
			"south border x=%d should be wall" % x)
	for y in range(1, 7):
		assert_eq(layer.get_cell_source_id(Vector2i(0, y)), WfcRoomGenerator.WALL_SOURCE_ID,
			"west border y=%d should be wall" % y)
	for y in range(1, 7):
		assert_eq(layer.get_cell_source_id(Vector2i(7, y)), WfcRoomGenerator.WALL_SOURCE_ID,
			"east border y=%d should be wall" % y)
	layer.free()


func test_wfc_interior_is_all_floor() -> void:
	var layer := TileMapLayer.new()
	WfcRoomGenerator.generate(42, layer, Vector2i.ZERO, Vector2i(8, 8))
	for y in range(1, 7):
		for x in range(1, 7):
			assert_eq(layer.get_cell_source_id(Vector2i(x, y)), WfcRoomGenerator.FLOOR_SOURCE_ID,
				"interior cell (%d,%d) should be floor" % [x, y])
	layer.free()


func test_wfc_no_empty_cells() -> void:
	var layer := TileMapLayer.new()
	WfcRoomGenerator.generate(42, layer, Vector2i.ZERO, Vector2i(8, 8))
	for y in 8:
		for x in 8:
			assert_ne(layer.get_cell_source_id(Vector2i(x, y)), -1,
				"cell (%d,%d) should not be empty after generate" % [x, y])
	layer.free()


func test_wfc_generate_returns_true() -> void:
	var layer := TileMapLayer.new()
	var ok := WfcRoomGenerator.generate(42, layer, Vector2i.ZERO, Vector2i(8, 8))
	assert_true(ok, "generate() should return true for a solvable 8x8 room")
	layer.free()


func test_wfc_non_zero_origin() -> void:
	var layer := TileMapLayer.new()
	var origin := Vector2i(10, 5)
	WfcRoomGenerator.generate(42, layer, origin, Vector2i(8, 8))
	assert_ne(layer.get_cell_source_id(origin), -1, "origin cell should be set")
	assert_eq(layer.get_cell_source_id(Vector2i(9, 5)), -1,
		"cell before origin should be empty")
	layer.free()


# ── Determinism ───────────────────────────────────────────────────────────────

func test_wfc_same_seed_same_grid() -> void:
	var l1 := TileMapLayer.new()
	var l2 := TileMapLayer.new()
	WfcRoomGenerator.generate(12345, l1, Vector2i.ZERO, Vector2i(8, 8))
	WfcRoomGenerator.generate(12345, l2, Vector2i.ZERO, Vector2i(8, 8))
	for y in 8:
		for x in 8:
			var cell := Vector2i(x, y)
			assert_eq(l1.get_cell_source_id(cell), l2.get_cell_source_id(cell),
				"source_id mismatch at (%d,%d)" % [x, y])
			assert_eq(l1.get_cell_atlas_coords(cell), l2.get_cell_atlas_coords(cell),
				"atlas mismatch at (%d,%d)" % [x, y])
	l1.free()
	l2.free()


func test_wfc_different_seeds_differ() -> void:
	var l1 := TileMapLayer.new()
	var l2 := TileMapLayer.new()
	WfcRoomGenerator.generate(1, l1, Vector2i.ZERO, Vector2i(8, 8))
	WfcRoomGenerator.generate(2, l2, Vector2i.ZERO, Vector2i(8, 8))
	var any_diff := false
	for y in range(1, 7):
		for x in range(1, 7):
			if l1.get_cell_atlas_coords(Vector2i(x, y)) != l2.get_cell_atlas_coords(Vector2i(x, y)):
				any_diff = true
				break
		if any_diff:
			break
	assert_true(any_diff, "different seeds should produce different floor variant patterns")
	l1.free()
	l2.free()


# ── Fixed constraints (door stitching) ───────────────────────────────────────

func test_wfc_fixed_door_constraint_honored() -> void:
	var layer := TileMapLayer.new()
	var door_pos := Vector2i(4, 0)
	var fixed := {
		door_pos: {
			"source_id": WfcRoomGenerator.DOOR_CLOSED_ID,
			"atlas": Vector2i(TileMeta.Direction.NORTH, 0)
		}
	}
	WfcRoomGenerator.generate(42, layer, Vector2i.ZERO, Vector2i(8, 8), fixed)
	assert_eq(layer.get_cell_source_id(door_pos), WfcRoomGenerator.DOOR_CLOSED_ID,
		"fixed door constraint should override the default wall tile")
	assert_eq(layer.get_cell_atlas_coords(door_pos), Vector2i(TileMeta.Direction.NORTH, 0),
		"fixed door atlas should match the constraint")
	layer.free()


func test_wfc_fixed_constraint_leaves_other_border_as_wall() -> void:
	var layer := TileMapLayer.new()
	var door_pos := Vector2i(4, 0)
	var fixed := {
		door_pos: {
			"source_id": WfcRoomGenerator.DOOR_CLOSED_ID,
			"atlas": Vector2i(TileMeta.Direction.NORTH, 0)
		}
	}
	WfcRoomGenerator.generate(42, layer, Vector2i.ZERO, Vector2i(8, 8), fixed)
	for x in [0, 1, 2, 3, 5, 6, 7]:
		assert_eq(layer.get_cell_source_id(Vector2i(x, 0)), WfcRoomGenerator.WALL_SOURCE_ID,
			"non-door north border x=%d should remain a wall" % x)
	layer.free()


# ── Seed persistence ──────────────────────────────────────────────────────────

func test_seed_save_and_load_roundtrip() -> void:
	var wg := WorldGen.new()
	wg.world_seed = 0xC0FFEE
	wg._save_seed()
	wg.world_seed = 0
	wg._load_seed()
	assert_eq(wg.world_seed, 0xC0FFEE, "seed should survive save/load roundtrip")
	wg.free()


func test_seed_load_missing_file_keeps_current() -> void:
	if FileAccess.file_exists(WorldGen.SAVE_PATH):
		var da := DirAccess.open("user://")
		if da:
			da.remove(WorldGen.SAVE_PATH.get_file())
	var wg := WorldGen.new()
	wg.world_seed = 42
	wg._load_seed()
	assert_eq(wg.world_seed, 42, "missing save file should not change the current seed")
	wg.free()


func test_seed_second_save_overwrites_first() -> void:
	var wg := WorldGen.new()
	wg.world_seed = 111
	wg._save_seed()
	wg.world_seed = 999
	wg._save_seed()
	wg.world_seed = 0
	wg._load_seed()
	assert_eq(wg.world_seed, 999, "second save should overwrite the first")
	wg.free()
