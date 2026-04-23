class_name RoomGraph
extends RefCounted

# Tier-1 layout generator for Phase 2 multi-room buildings.
#
# Produces a grid of rooms (room_cols × room_rows), assigns a RoomType to each,
# places a door connection between every pair of adjacent rooms, and exposes the
# fixed-tile constraints needed by WfcRoomGenerator for each room.
#
# Door convention: the shared wall between two adjacent rooms has a door tile on
# each side — DOOR_E on room A's east border and DOOR_W on room B's west border
# (or DOOR_S/DOOR_N for north-south adjacency). Both tiles are walkable, giving
# a two-tile-wide passage.
#
# Usage:
#   var graph := RoomGraph.generate(seed, Vector2i(8,8), 2, 2)
#   for i in graph.rooms.size():
#       var constraints := graph.door_constraints_for(i)
#       WfcRoomGenerator.generate(room_seed, layer, graph.rooms[i].origin, room_size, constraints)

const DOOR_CLOSED_SOURCE_ID := 22


class RoomData extends RefCounted:
	var index: int
	var grid_pos: Vector2i     # Position in the room grid (col, row)
	var origin: Vector2i       # Top-left tile coordinate in TileMapLayer space
	var size: Vector2i
	var type: int              # TileMeta.RoomType

	func rect() -> Rect2i:
		return Rect2i(origin, size)


class ConnectionData extends RefCounted:
	var room_a: int            # Index into RoomGraph.rooms
	var room_b: int
	# The two door tile positions (one per room, adjacent cells on shared wall)
	var tile_a: Vector2i       # In TileMapLayer space; belongs to room_a
	var tile_b: Vector2i       # Belongs to room_b
	var dir_a: int             # TileMeta.Direction for the door facing in room_a
	var dir_b: int             # Opposite direction in room_b


var rooms: Array[RoomData] = []
var connections: Array[ConnectionData] = []


# Generate a room_cols × room_rows building layout.
# room_size:    size of each individual room in tiles (includes wall border).
# room_weights: optional Dict[TileMeta.RoomType → float].
#               Empty or null → equal-weight default selection.
static func generate(
	seed: int,
	room_size: Vector2i,
	room_cols: int,
	room_rows: int,
	room_weights: Dictionary = {}
) -> RoomGraph:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var graph := RoomGraph.new()
	var room_types := _shuffled_room_types(rng, room_cols * room_rows, room_weights)

	# Create rooms in a grid
	for row in room_rows:
		for col in room_cols:
			var r := RoomData.new()
			r.index = row * room_cols + col
			r.grid_pos = Vector2i(col, row)
			r.origin = Vector2i(col * room_size.x, row * room_size.y)
			r.size = room_size
			r.type = room_types[r.index]
			graph.rooms.append(r)

	# Connect all horizontally adjacent pairs (east-west)
	for row in room_rows:
		for col in range(room_cols - 1):
			var idx_a := row * room_cols + col
			var idx_b := row * room_cols + (col + 1)
			var ra: RoomData = graph.rooms[idx_a]
			var rb: RoomData = graph.rooms[idx_b]

			# Pick a door Y in the middle third of the shared wall
			var door_y := _pick_door_pos(rng, ra.origin.y, room_size.y)

			var conn := ConnectionData.new()
			conn.room_a = idx_a
			conn.room_b = idx_b
			# Room A's east wall: x = ra.origin.x + room_size.x - 1
			conn.tile_a = Vector2i(ra.origin.x + room_size.x - 1, door_y)
			# Room B's west wall: x = rb.origin.x
			conn.tile_b = Vector2i(rb.origin.x, door_y)
			conn.dir_a = TileMeta.Direction.EAST
			conn.dir_b = TileMeta.Direction.WEST
			graph.connections.append(conn)

	# Connect all vertically adjacent pairs (north-south)
	for row in range(room_rows - 1):
		for col in room_cols:
			var idx_a := row * room_cols + col
			var idx_b := (row + 1) * room_cols + col
			var ra: RoomData = graph.rooms[idx_a]
			var rb: RoomData = graph.rooms[idx_b]

			var door_x := _pick_door_pos(rng, ra.origin.x, room_size.x)

			var conn := ConnectionData.new()
			conn.room_a = idx_a
			conn.room_b = idx_b
			# Room A's south wall: y = ra.origin.y + room_size.y - 1
			conn.tile_a = Vector2i(door_x, ra.origin.y + room_size.y - 1)
			# Room B's north wall: y = rb.origin.y
			conn.tile_b = Vector2i(door_x, rb.origin.y)
			conn.dir_a = TileMeta.Direction.SOUTH
			conn.dir_b = TileMeta.Direction.NORTH
			graph.connections.append(conn)

	return graph


# Returns a Dictionary[Vector2i → {"source_id":int,"atlas":Vector2i}] of fixed
# door constraints for the room at `room_index`. Pass this to WfcRoomGenerator.
func door_constraints_for(room_index: int) -> Dictionary:
	var constraints: Dictionary = {}
	for conn in connections:
		if conn.room_a == room_index:
			constraints[conn.tile_a] = {
				"source_id": DOOR_CLOSED_SOURCE_ID,
				"atlas": Vector2i(conn.dir_a, 0)
			}
		elif conn.room_b == room_index:
			constraints[conn.tile_b] = {
				"source_id": DOOR_CLOSED_SOURCE_ID,
				"atlas": Vector2i(conn.dir_b, 0)
			}
	return constraints


# Returns all door tile positions across all rooms (for connectivity flood-fill).
func all_door_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for conn in connections:
		tiles.append(conn.tile_a)
		tiles.append(conn.tile_b)
	return tiles


# Returns the total bounding rect of the building in tile coordinates.
func footprint() -> Rect2i:
	if rooms.is_empty():
		return Rect2i()
	var r: RoomData = rooms[0]
	var result := r.rect()
	for i in range(1, rooms.size()):
		result = result.merge((rooms[i] as RoomData).rect())
	return result


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _pick_door_pos(rng: RandomNumberGenerator, origin_axis: int, length: int) -> int:
	# Place door in the middle third to avoid corners
	var lo: int = origin_axis + max(1, length / 3)
	var hi: int = origin_axis + min(length - 2, (length * 2) / 3)
	if lo >= hi:
		lo = origin_axis + 1
		hi = origin_axis + length - 2
	return lo + rng.randi() % max(1, hi - lo)


static func _shuffled_room_types(
	rng:          RandomNumberGenerator,
	count:        int,
	room_weights: Dictionary = {}
) -> Array[int]:
	var pool: Array[int] = []

	if room_weights.is_empty():
		# Default equal-weight selection: one HALL guaranteed, then KITCHEN/BEDROOM/BATHROOM/LIVING_ROOM
		pool.append(TileMeta.RoomType.HALL)
		var others := [
			TileMeta.RoomType.KITCHEN,
			TileMeta.RoomType.BEDROOM,
			TileMeta.RoomType.BATHROOM,
			TileMeta.RoomType.LIVING_ROOM,
		]
		while pool.size() < count:
			pool.append(others[rng.randi() % others.size()])
	else:
		# Archetype-weighted selection. Build a weighted pick list from non-zero types.
		var weighted_types: Array[int] = []
		var weights: Array[float]      = []
		for rt: int in room_weights:
			var w: float = room_weights[rt]
			if w > 0.0:
				weighted_types.append(rt)
				weights.append(w)

		if weighted_types.is_empty():
			# Fallback: all room types equal weight.
			for rt in TileMeta.RoomType.values():
				weighted_types.append(rt)
				weights.append(1.0)

		# Guarantee at least one HALL (if HALL has non-zero weight in this archetype).
		var hall_weight: float = room_weights.get(TileMeta.RoomType.HALL, -1.0)
		if hall_weight > 0.0:
			pool.append(TileMeta.RoomType.HALL)

		while pool.size() < count:
			pool.append(_weighted_pick_room(rng, weighted_types, weights))

	# Shuffle
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	return pool


static func _weighted_pick_room(
	rng:   RandomNumberGenerator,
	types: Array[int],
	wts:   Array[float]
) -> int:
	var total := 0.0
	for w in wts:
		total += w
	if total <= 0.0:
		return types[rng.randi() % types.size()]
	var roll := rng.randf() * total
	var acc  := 0.0
	for i in types.size():
		acc += wts[i]
		if roll <= acc:
			return types[i]
	return types[types.size() - 1]
