extends GutTest

# Headless tests for WFC, seed persistence, WorldGen.generate integration,
# and BuildingGen.generate step-by-step outputs.
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


# ── Headless BuildingGen / WorldGen helpers ──────────────────────────────────

# Builds a BuildingGen with its four TileMapLayer exports wired up. No scene
# tree needed — TileMapLayer.set_cell works on detached nodes.
func _make_building(room_size: Vector2i = Vector2i(8, 8), is_goal: bool = false) -> BuildingGen:
	var b := BuildingGen.new()
	b.floor_layer = TileMapLayer.new()
	b.wall_layer = TileMapLayer.new()
	b.goal_layer = TileMapLayer.new()
	b.triggers_layer = TileMapLayer.new()
	b.add_child(b.floor_layer)
	b.add_child(b.wall_layer)
	b.add_child(b.goal_layer)
	b.add_child(b.triggers_layer)
	b.room_size = room_size
	b.is_goal = is_goal
	return b


# Builds a WorldGen with start + goal BuildingGen children and a world_layer.
func _make_worldgen(world_seed: int = 0, world_size: Vector2i = Vector2i(32, 32)) -> WorldGen:
	var wg := WorldGen.new()
	wg.world_seed = world_seed
	wg.world_size = world_size
	wg.world_layer = TileMapLayer.new()
	wg.add_child(wg.world_layer)
	wg.start_building_scene = _make_building()
	wg.goal_building_scene = _make_building()
	wg.add_child(wg.start_building_scene)
	wg.add_child(wg.goal_building_scene)
	return wg


# ── WorldGen.generate() integration ──────────────────────────────────────────

func test_worldgen_generate_fills_start_building_tiles() -> void:
	var wg := _make_worldgen(77)
	wg.generate()

	assert_gt(wg.start_building_scene.floor_layer.get_used_cells().size(), 0,
		"WorldGen.generate() should populate the start building's floor_layer")
	assert_gt(wg.start_building_scene.wall_layer.get_used_cells().size(), 0,
		"WorldGen.generate() should populate the start building's wall_layer")
	wg.free()


func test_worldgen_generate_assigns_building_seed() -> void:
	var wg := _make_worldgen(99)
	wg.generate()

	assert_ne(wg.start_building_scene.building_seed, 0,
		"WorldGen.generate() should assign a non-zero derived seed to start_building_scene")
	wg.free()


func test_worldgen_generate_flags_start_and_goal() -> void:
	var wg := _make_worldgen(7)
	# Pre-flip to prove generate() reassigns unconditionally.
	wg.start_building_scene.is_goal = true
	wg.goal_building_scene.is_goal = false
	wg.generate()

	assert_false(wg.start_building_scene.is_goal,
		"after generate() start_building_scene.is_goal should be false")
	assert_true(wg.goal_building_scene.is_goal,
		"after generate() goal_building_scene.is_goal should be true")
	wg.free()


func test_worldgen_generate_is_deterministic() -> void:
	var wg1 := _make_worldgen(77)
	wg1.generate()
	var cells1 := wg1.start_building_scene.floor_layer.get_used_cells().duplicate()

	var wg2 := _make_worldgen(77)
	wg2.generate()
	var cells2 := wg2.start_building_scene.floor_layer.get_used_cells()

	assert_eq(cells1.size(), cells2.size(),
		"same world_seed should produce the same start building floor cell count")
	wg1.free()
	wg2.free()


# ── BuildingGen.generate() step-by-step coverage ─────────────────────────────

func test_building_generate_fills_floor_layer_with_room_cells() -> void:
	var b := _make_building(Vector2i(8, 8))
	b.building_seed = 1234
	b.generate()

	assert_eq(b.floor_layer.get_used_cells().size(), 64,
		"8x8 room_size should fill floor_layer with exactly 64 cells")
	b.free()


func test_building_generate_draws_wall_border() -> void:
	var b := _make_building(Vector2i(8, 8))
	b.building_seed = 1234
	b.generate()

	# Room is centred on (0, 0); for an 8x8 room the origin is (-4, -4) so the
	# wall border sits one tile outside the room's 8x8 floor area.
	var origin := Vector2i(-4, -4)
	var last := Vector2i(3, 3)

	# North and south rows (8 tiles each, along the room's width).
	for x in 8:
		var north := Vector2i(origin.x + x, origin.y - 1)
		var south := Vector2i(origin.x + x, last.y + 1)
		assert_ne(b.wall_layer.get_cell_source_id(north), -1,
			"north border cell %s should be painted" % str(north))
		assert_ne(b.wall_layer.get_cell_source_id(south), -1,
			"south border cell %s should be painted" % str(south))

	# West and east columns (8 tiles each, along the room's height).
	for y in 8:
		var west := Vector2i(origin.x - 1, origin.y + y)
		var east := Vector2i(last.x + 1,   origin.y + y)
		assert_ne(b.wall_layer.get_cell_source_id(west), -1,
			"west border cell %s should be painted" % str(west))
		assert_ne(b.wall_layer.get_cell_source_id(east), -1,
			"east border cell %s should be painted" % str(east))
	b.free()


func test_building_generate_places_a_door_and_two_triggers() -> void:
	var b := _make_building(Vector2i(6, 6))
	b.building_seed = 42
	b.generate()

	# _replace_walls picks at least 1 wall for doors; each door paints two
	# triggers (inside + outside) on triggers_layer.
	var door_cells := b.wall_layer.get_used_cells_by_id(BuildingGen.DOOR_SOURCE_ID)
	assert_gt(door_cells.size(), 0,
		"at least one wall cell should be swapped to a door for a 6x6 room")

	var trigger_cells := b.triggers_layer.get_used_cells()
	assert_gte(trigger_cells.size(), 2,
		"each door should paint inside + outside trigger tiles (>= 2 total)")
	b.free()


func test_building_generate_places_switch_when_is_goal() -> void:
	var b := _make_building(Vector2i(8, 8), true)
	b.building_seed = 1
	b.generate()

	assert_gt(b.goal_layer.get_used_cells().size(), 0,
		"with is_goal = true, goal_layer should have at least one switch tile")
	b.free()


func test_building_generate_leaves_goal_layer_empty_when_not_goal() -> void:
	var b := _make_building(Vector2i(8, 8), false)
	b.building_seed = 1
	b.generate()

	assert_eq(b.goal_layer.get_used_cells().size(), 0,
		"with is_goal = false, goal_layer should be empty")
	b.free()


# ── WorldGen helper coverage ─────────────────────────────────────────────────

func test_worldgen_footprint_includes_wall_border() -> void:
	var wg := WorldGen.new()
	# A 6x6 room centred at (0, 0) has origin (-3, -3); the footprint (which
	# wraps the 1-tile wall border) should therefore start at (-4, -4) with an
	# 8x8 extent.
	var rect := wg._footprint(Vector2i.ZERO, Vector2i(6, 6))
	assert_eq(rect, Rect2i(Vector2i(-4, -4), Vector2i(8, 8)),
		"footprint should wrap the 1-tile wall border around the room")
	wg.free()


func test_worldgen_footprint_at_non_origin() -> void:
	var wg := WorldGen.new()
	var rect := wg._footprint(Vector2i(10, 5), Vector2i(4, 4))
	# Room at (10, 5) with size 4: origin = (10-2, 5-2) = (8, 3); minus one
	# for the wall border = (7, 2); extent = 4 + 2 = 6.
	assert_eq(rect, Rect2i(Vector2i(7, 2), Vector2i(6, 6)),
		"footprint should offset correctly for non-origin positions")
	wg.free()


func test_worldgen_find_free_position_returns_invalid_when_too_small() -> void:
	var wg := WorldGen.new()
	# World is 4x4 but the building footprint for a 6x6 room would be 8x8 —
	# no candidate position can ever fit, so every attempt fails.
	wg.world_size = Vector2i(4, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var pos := wg._find_free_position(rng, Vector2i(6, 6), WorldGen.INVALID_POS, 0)
	assert_eq(pos, WorldGen.INVALID_POS,
		"_find_free_position should return INVALID_POS when the world is too small")
	wg.free()
