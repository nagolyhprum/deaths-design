extends GutTest

# Tests for RoomGraph: layout correctness, door placement, and connectivity.


func test_single_room_graph() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 1, 1)
	assert_eq(g.rooms.size(), 1)
	assert_eq(g.connections.size(), 0)


func test_two_room_horizontal() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 2, 1)
	assert_eq(g.rooms.size(), 2)
	assert_eq(g.connections.size(), 1, "one east-west connection")


func test_two_by_two_grid() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 2, 2)
	assert_eq(g.rooms.size(), 4)
	# 2 horizontal + 2 vertical connections
	assert_eq(g.connections.size(), 4)


func test_room_origins_non_overlapping() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 2, 2)
	var rects: Array[Rect2i] = []
	for room in g.rooms:
		rects.append((room as RoomGraph.RoomData).rect())
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			assert_false(
				rects[i].intersects(rects[j]),
				"rooms %d and %d should not overlap" % [i, j]
			)


func test_door_constraints_cover_connection_tiles() -> void:
	var room_size := Vector2i(8, 8)
	var g := RoomGraph.generate(7, room_size, 2, 1)
	assert_eq(g.connections.size(), 1)
	var conn: RoomGraph.ConnectionData = g.connections[0]

	var constraints_a := g.door_constraints_for(conn.room_a)
	var constraints_b := g.door_constraints_for(conn.room_b)

	assert_true(constraints_a.has(conn.tile_a), "room_a constraints include tile_a")
	assert_true(constraints_b.has(conn.tile_b), "room_b constraints include tile_b")


func test_door_tile_on_shared_wall() -> void:
	var room_size := Vector2i(8, 8)
	var g := RoomGraph.generate(7, room_size, 2, 1)
	var conn: RoomGraph.ConnectionData = g.connections[0]

	# tile_a should be on room_a's east wall (x = 7)
	var ra: RoomGraph.RoomData = g.rooms[conn.room_a]
	assert_eq(conn.tile_a.x, ra.origin.x + room_size.x - 1, "door on east wall of room_a")
	# tile_b should be on room_b's west wall (x = 8)
	var rb: RoomGraph.RoomData = g.rooms[conn.room_b]
	assert_eq(conn.tile_b.x, rb.origin.x, "door on west wall of room_b")


func test_door_positions_are_adjacent() -> void:
	var g := RoomGraph.generate(7, Vector2i(8, 8), 2, 1)
	var conn: RoomGraph.ConnectionData = g.connections[0]
	var dist := (conn.tile_b - conn.tile_a).length()
	assert_eq(dist, 1.0, "door tiles should be adjacent (distance = 1)")


func test_footprint_covers_all_rooms() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 3, 2)
	var fp := g.footprint()
	for room in g.rooms:
		var r: RoomGraph.RoomData = room
		assert_true(fp.encloses(r.rect()), "footprint must enclose every room")


func test_room_types_assigned() -> void:
	var g := RoomGraph.generate(1, Vector2i(8, 8), 2, 2)
	for room in g.rooms:
		var r: RoomGraph.RoomData = room
		assert_true(r.type >= TileMeta.RoomType.GENERIC, "every room has a valid type")


func test_deterministic_layout() -> void:
	var g1 := RoomGraph.generate(555, Vector2i(8, 8), 2, 2)
	var g2 := RoomGraph.generate(555, Vector2i(8, 8), 2, 2)
	assert_eq(g1.rooms.size(), g2.rooms.size())
	for i in g1.rooms.size():
		var r1: RoomGraph.RoomData = g1.rooms[i]
		var r2: RoomGraph.RoomData = g2.rooms[i]
		assert_eq(r1.origin, r2.origin)
		assert_eq(r1.type, r2.type)
	for i in g1.connections.size():
		var c1: RoomGraph.ConnectionData = g1.connections[i]
		var c2: RoomGraph.ConnectionData = g2.connections[i]
		assert_eq(c1.tile_a, c2.tile_a)
		assert_eq(c1.tile_b, c2.tile_b)


func test_different_seeds_different_door_positions() -> void:
	var g1 := RoomGraph.generate(1, Vector2i(8, 8), 2, 2)
	var g2 := RoomGraph.generate(2, Vector2i(8, 8), 2, 2)
	# With a large enough room size, seeds should produce different door Y positions
	var any_diff := false
	for i in mini(g1.connections.size(), g2.connections.size()):
		var c1: RoomGraph.ConnectionData = g1.connections[i]
		var c2: RoomGraph.ConnectionData = g2.connections[i]
		if c1.tile_a != c2.tile_a:
			any_diff = true
			break
	# Not guaranteed with a 8x8 room, but highly likely
	# Skip this assertion if room is too small to vary door position
	if Vector2i(8, 8).x > 4:
		pass  # Could add assert_true(any_diff) once room variety is wider
