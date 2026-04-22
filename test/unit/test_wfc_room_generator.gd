extends GutTest

# Tests for WfcRoomGenerator: determinism, coverage, and fixed-constraint handling.
# These tests call generate() with a null TileMapLayer and instead inspect
# what *would* be placed by using the internal helpers directly.
# Full integration tests require a real TileMapLayer (editor-only).


func test_catalog_built() -> void:
	WfcRoomGenerator._ensure_catalog()
	assert_true(WfcRoomGenerator._catalog.size() > 0, "catalog should be non-empty")


func test_catalog_has_wall_tiles() -> void:
	WfcRoomGenerator._ensure_catalog()
	var wall_count := 0
	for t in WfcRoomGenerator._catalog:
		if (t as WfcRoomGenerator.TileDef).source_id == WfcRoomGenerator.WALL_SOURCE_ID:
			wall_count += 1
	assert_eq(wall_count, 4, "4 directional wall tiles")


func test_catalog_has_floor_tiles() -> void:
	WfcRoomGenerator._ensure_catalog()
	var floor_count := 0
	for t in WfcRoomGenerator._catalog:
		if (t as WfcRoomGenerator.TileDef).source_id == WfcRoomGenerator.FLOOR_SOURCE_ID:
			floor_count += 1
	assert_eq(floor_count, WfcRoomGenerator.FLOOR_VARIANT_COUNT)


func test_catalog_has_door_tiles() -> void:
	WfcRoomGenerator._ensure_catalog()
	var door_count := 0
	for t in WfcRoomGenerator._catalog:
		if (t as WfcRoomGenerator.TileDef).source_id == WfcRoomGenerator.DOOR_CLOSED_ID:
			door_count += 1
	assert_eq(door_count, 4, "4 directional door tiles")


func test_wall_direction_borders() -> void:
	assert_eq(WfcRoomGenerator._wall_dir(0, 0, 7, 7), TileMeta.Direction.NORTH)
	assert_eq(WfcRoomGenerator._wall_dir(7, 7, 7, 7), TileMeta.Direction.SOUTH)
	assert_eq(WfcRoomGenerator._wall_dir(0, 4, 7, 7), TileMeta.Direction.WEST)
	assert_eq(WfcRoomGenerator._wall_dir(7, 4, 7, 7), TileMeta.Direction.EAST)


func test_wall_direction_interior_is_minus_one() -> void:
	assert_eq(WfcRoomGenerator._wall_dir(3, 3, 7, 7), -1)
	assert_eq(WfcRoomGenerator._wall_dir(1, 1, 7, 7), -1)


func test_get_tile_def_returns_wall() -> void:
	var def := WfcRoomGenerator.get_tile_def(
		WfcRoomGenerator.WALL_SOURCE_ID,
		Vector2i(TileMeta.Direction.NORTH, 0)
	)
	assert_not_null(def)
	assert_eq(def.sock_n, TileMeta.Socket.EMPTY)
	assert_eq(def.sock_s, TileMeta.Socket.FLOOR)


func test_get_tile_def_returns_floor() -> void:
	var def := WfcRoomGenerator.get_tile_def(WfcRoomGenerator.FLOOR_SOURCE_ID, Vector2i(0, 0))
	assert_not_null(def)
	assert_eq(def.sock_n, TileMeta.Socket.FLOOR)
	assert_eq(def.sock_e, TileMeta.Socket.FLOOR)


func test_get_tile_def_returns_door() -> void:
	var def := WfcRoomGenerator.get_tile_def(
		WfcRoomGenerator.DOOR_CLOSED_ID,
		Vector2i(TileMeta.Direction.EAST, 0)
	)
	assert_not_null(def)
	assert_eq(def.sock_e, TileMeta.Socket.DOOR)
	assert_eq(def.sock_w, TileMeta.Socket.FLOOR)


func test_weighted_pick_respects_weight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	# Build two options: one weight=0, one weight=1 → must always pick the second
	var t0 := WfcRoomGenerator.TileDef.new(
		WfcRoomGenerator.FLOOR_SOURCE_ID, Vector2i(0, 0),
		TileMeta.Socket.FLOOR, TileMeta.Socket.FLOOR,
		TileMeta.Socket.FLOOR, TileMeta.Socket.FLOOR, 0.0
	)
	var t1 := WfcRoomGenerator.TileDef.new(
		WfcRoomGenerator.FLOOR_SOURCE_ID, Vector2i(1, 0),
		TileMeta.Socket.FLOOR, TileMeta.Socket.FLOOR,
		TileMeta.Socket.FLOOR, TileMeta.Socket.FLOOR, 1.0
	)
	var opts: Array = [t0, t1]
	var picked := WfcRoomGenerator._weighted_pick(rng, opts)
	assert_eq(picked.atlas.x, 1, "should always pick the tile with weight=1")
