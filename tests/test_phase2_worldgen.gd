extends GutTest

# RoomGraph tests: room type assignment and door socket matching on shared
# walls. BuildingGen no longer supports multi-room layouts — the former
# _validate_connectivity tests have been removed. RoomGraph itself is still
# exercised here because it is still a live module used by other tooling.


# ── RoomGraph: room type assignment ──────────────────────────────────────────

func test_room_graph_all_rooms_have_valid_type() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 2, 2)
	for room in g.rooms:
		var r: RoomGraph.RoomData = room
		assert_true(r.type >= TileMeta.RoomType.GENERIC,
			"room %d should have a valid RoomType (>= GENERIC)" % r.index)


func test_room_graph_contains_exactly_one_hall() -> void:
	for s in [1, 42, 123, 999]:
		var g := RoomGraph.generate(s, Vector2i(8, 8), 3, 2)
		var hall_count := 0
		for room in g.rooms:
			if (room as RoomGraph.RoomData).type == TileMeta.RoomType.HALL:
				hall_count += 1
		assert_eq(hall_count, 1, "seed=%d: exactly one HALL per building" % s)


func test_room_graph_non_hall_rooms_have_valid_types() -> void:
	var valid: Array[int] = [
		TileMeta.RoomType.GENERIC,
		TileMeta.RoomType.HALL,
		TileMeta.RoomType.KITCHEN,
		TileMeta.RoomType.BEDROOM,
		TileMeta.RoomType.BATHROOM,
		TileMeta.RoomType.LIVING_ROOM,
	]
	var g := RoomGraph.generate(7, Vector2i(8, 8), 3, 2)
	for room in g.rooms:
		var r: RoomGraph.RoomData = room
		assert_true(r.type in valid,
			"room %d has type %d which is outside the valid RoomType enum" % [r.index, r.type])


# ── Door stitching: matching sockets on shared walls ─────────────────────────

func test_ew_door_sockets_are_both_door_type() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 2, 1)
	for conn in g.connections:
		var c: RoomGraph.ConnectionData = conn
		if c.dir_a != TileMeta.Direction.EAST:
			continue
		var def_a := WfcRoomGenerator.get_tile_def(
			RoomGraph.DOOR_CLOSED_SOURCE_ID, Vector2i(c.dir_a, 0))
		var def_b := WfcRoomGenerator.get_tile_def(
			RoomGraph.DOOR_CLOSED_SOURCE_ID, Vector2i(c.dir_b, 0))
		assert_not_null(def_a, "DOOR_EAST tile def should exist in catalog")
		assert_not_null(def_b, "DOOR_WEST tile def should exist in catalog")
		assert_eq(def_a.sock_e, TileMeta.Socket.DOOR,
			"DOOR_EAST facing socket should be DOOR")
		assert_eq(def_b.sock_w, TileMeta.Socket.DOOR,
			"DOOR_WEST facing socket should be DOOR")
		assert_eq(def_a.sock_e, def_b.sock_w,
			"E-W shared wall sockets should match")


func test_ns_door_sockets_are_both_door_type() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 1, 2)
	for conn in g.connections:
		var c: RoomGraph.ConnectionData = conn
		if c.dir_a != TileMeta.Direction.SOUTH:
			continue
		var def_a := WfcRoomGenerator.get_tile_def(
			RoomGraph.DOOR_CLOSED_SOURCE_ID, Vector2i(c.dir_a, 0))
		var def_b := WfcRoomGenerator.get_tile_def(
			RoomGraph.DOOR_CLOSED_SOURCE_ID, Vector2i(c.dir_b, 0))
		assert_not_null(def_a, "DOOR_SOUTH tile def should exist in catalog")
		assert_not_null(def_b, "DOOR_NORTH tile def should exist in catalog")
		assert_eq(def_a.sock_s, TileMeta.Socket.DOOR,
			"DOOR_SOUTH facing socket should be DOOR")
		assert_eq(def_b.sock_n, TileMeta.Socket.DOOR,
			"DOOR_NORTH facing socket should be DOOR")
		assert_eq(def_a.sock_s, def_b.sock_n,
			"N-S shared wall sockets should match")


func test_all_connections_in_2x2_have_matching_sockets() -> void:
	var g := RoomGraph.generate(42, Vector2i(8, 8), 2, 2)
	assert_eq(g.connections.size(), 4, "2x2 grid should have 4 connections")
	for conn in g.connections:
		var c: RoomGraph.ConnectionData = conn
		var def_a := WfcRoomGenerator.get_tile_def(
			RoomGraph.DOOR_CLOSED_SOURCE_ID, Vector2i(c.dir_a, 0))
		var def_b := WfcRoomGenerator.get_tile_def(
			RoomGraph.DOOR_CLOSED_SOURCE_ID, Vector2i(c.dir_b, 0))
		assert_not_null(def_a)
		assert_not_null(def_b)
		var sock_a: int
		var sock_b: int
		match c.dir_a:
			TileMeta.Direction.EAST:
				sock_a = def_a.sock_e
				sock_b = def_b.sock_w
			TileMeta.Direction.SOUTH:
				sock_a = def_a.sock_s
				sock_b = def_b.sock_n
			_:
				fail_test("unexpected dir_a=%d in connection" % c.dir_a)
				return
		assert_eq(sock_a, TileMeta.Socket.DOOR,
			"room_a facing socket should be DOOR for dir_a=%d" % c.dir_a)
		assert_eq(sock_a, sock_b,
			"door sockets on shared wall should match for dir_a=%d" % c.dir_a)


func test_door_tiles_placed_at_wfc_fixed_positions() -> void:
	var floor_l := TileMapLayer.new()
	var g := RoomGraph.generate(42, Vector2i(8, 8), 2, 1)
	assert_eq(g.connections.size(), 1)
	var conn: RoomGraph.ConnectionData = g.connections[0]

	WfcRoomGenerator.generate(
		hash([1, 0]), floor_l,
		g.rooms[0].origin, g.rooms[0].size,
		g.door_constraints_for(0)
	)
	WfcRoomGenerator.generate(
		hash([1, 1]), floor_l,
		g.rooms[1].origin, g.rooms[1].size,
		g.door_constraints_for(1)
	)

	assert_eq(floor_l.get_cell_source_id(conn.tile_a), RoomGraph.DOOR_CLOSED_SOURCE_ID,
		"tile_a at %s should be a door in the floor layer" % str(conn.tile_a))
	assert_eq(floor_l.get_cell_source_id(conn.tile_b), RoomGraph.DOOR_CLOSED_SOURCE_ID,
		"tile_b at %s should be a door in the floor layer" % str(conn.tile_b))
	floor_l.free()
