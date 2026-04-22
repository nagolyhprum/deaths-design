extends GutTest

# Phase 1: Furniture pass walkability validation.
#
# FurniturePass.PROP_PALETTE is empty until prop tile assets are authored, so
# "no props placed on non-walkable tiles" is verified by:
#   a) the empty-palette fast-path returning true, and
#   b) directly exercising the internal flood-fill and walkability helpers.


# ── Empty palette fast-path ───────────────────────────────────────────────────

func test_empty_palette_returns_true() -> void:
	var floor_l := TileMapLayer.new()
	var props_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	var ok := FurniturePass.generate(42, floor_l, props_l, Vector2i.ZERO, Vector2i(8, 8))
	assert_true(ok, "empty palette should trivially pass walkability check")
	floor_l.free()
	props_l.free()


func test_empty_palette_leaves_props_layer_empty() -> void:
	var floor_l := TileMapLayer.new()
	var props_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	FurniturePass.generate(42, floor_l, props_l, Vector2i.ZERO, Vector2i(8, 8))
	assert_eq(props_l.get_used_cells().size(), 0,
		"props layer should be empty when palette is empty")
	floor_l.free()
	props_l.free()


# ── Walkability helpers ───────────────────────────────────────────────────────

func test_floor_cell_is_walkable() -> void:
	var floor_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	assert_true(
		FurniturePass._is_walkable(floor_l, null, Vector2i(1, 1)),
		"interior floor cell should be walkable"
	)
	floor_l.free()


func test_wall_cell_is_not_walkable() -> void:
	var floor_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	assert_false(
		FurniturePass._is_walkable(floor_l, null, Vector2i(0, 0)),
		"border wall cell should not be walkable"
	)
	floor_l.free()


func test_empty_cell_is_not_walkable() -> void:
	var floor_l := TileMapLayer.new()
	assert_false(
		FurniturePass._is_walkable(floor_l, null, Vector2i(3, 3)),
		"empty cell (source_id=-1) should not be walkable"
	)
	floor_l.free()


func test_prop_blocks_walkability() -> void:
	var floor_l := TileMapLayer.new()
	var props_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	props_l.set_cell(Vector2i(2, 2), WfcRoomGenerator.FLOOR_SOURCE_ID, Vector2i(0, 0))
	assert_false(
		FurniturePass._is_walkable(floor_l, props_l, Vector2i(2, 2)),
		"interior cell occupied by a prop should not be walkable"
	)
	floor_l.free()
	props_l.free()


func test_all_walkable_counts_only_floor_cells() -> void:
	var floor_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	var walkable := FurniturePass._all_walkable(floor_l, Vector2i.ZERO, Vector2i(8, 8))
	# 8x8 room: 6x6=36 interior floor cells; 28 border wall cells (not walkable)
	assert_eq(walkable.size(), 36,
		"8x8 room with no doors should have exactly 36 walkable interior cells")
	floor_l.free()


# ── Flood-fill reachability ───────────────────────────────────────────────────

func test_flood_fill_all_interior_reachable_with_no_props() -> void:
	var floor_l := TileMapLayer.new()
	var props_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	var reachable := FurniturePass._flood_fill(
		floor_l, props_l, Vector2i(1, 1), Vector2i.ZERO, Vector2i(8, 8)
	)
	var all_walkable := FurniturePass._all_walkable(floor_l, Vector2i.ZERO, Vector2i(8, 8))
	assert_eq(reachable.size(), all_walkable.size(),
		"flood-fill from (1,1) should reach all 36 walkable cells when no props are placed")
	floor_l.free()
	props_l.free()


func test_flood_fill_blocked_by_prop_row() -> void:
	var floor_l := TileMapLayer.new()
	var props_l := TileMapLayer.new()
	WfcRoomGenerator.generate(42, floor_l, Vector2i.ZERO, Vector2i(8, 8))
	for x in range(1, 7):
		props_l.set_cell(Vector2i(x, 3), WfcRoomGenerator.FLOOR_SOURCE_ID, Vector2i(0, 0))
	var reachable := FurniturePass._flood_fill(
		floor_l, props_l, Vector2i(1, 1), Vector2i.ZERO, Vector2i(8, 8)
	)
	var all_walkable := FurniturePass._all_walkable(floor_l, Vector2i.ZERO, Vector2i(8, 8))
	assert_lt(reachable.size(), all_walkable.size(),
		"blocking an entire interior row with props should make cells below unreachable")
	floor_l.free()
	props_l.free()


# ── Candidate cells ───────────────────────────────────────────────────────────

func test_interior_cells_are_strictly_inside_border() -> void:
	var interior := FurniturePass._interior_cells(Vector2i.ZERO, Vector2i(8, 8))
	assert_eq(interior.size(), 36, "interior should be 6x6=36 cells for an 8x8 room")
	for cell in interior:
		var c: Vector2i = cell
		assert_true(
			c.x > 0 and c.x < 7 and c.y > 0 and c.y < 7,
			"interior cell %s should be strictly inside the border" % str(c)
		)


func test_first_interior_returns_correct_cell() -> void:
	assert_eq(FurniturePass._first_interior(Vector2i.ZERO, Vector2i(8, 8)), Vector2i(1, 1))


func test_first_interior_degenerate_room() -> void:
	assert_eq(
		FurniturePass._first_interior(Vector2i.ZERO, Vector2i(2, 2)),
		Vector2i(-1, -1),
		"degenerate 2x2 room (no interior) should return the sentinel (-1,-1)"
	)
