class_name StairPlacer
extends RefCounted

# Picks stair tile positions for each adjacent floor pair in a multi-floor
# building. Each pair shares the same XY tile coordinate:
#   floor_from → STAIR_UP at tile_pos
#   floor_to   → STAIR_DOWN at tile_pos
#
# Stair positions are interior cells (not wall borders) placed in a randomly
# chosen room of the grid. Pass them as fixed constraints to WfcRoomGenerator.
#
# Usage:
#   var pairs := StairPlacer.place(seed, room_size, cols, rows, [-1, 0, 1])
#   for pair in pairs:
#       var sd: StairPlacer.StairData = pair
#       # sd.floor_from, sd.floor_to, sd.tile_pos


class StairData extends RefCounted:
	var floor_from: int    # lower floor index
	var floor_to:   int    # upper floor index (floor_from + 1)
	var tile_pos:   Vector2i


# Returns Array[StairData] with one entry per adjacent floor pair.
# floor_indices must be sorted ascending (e.g. [-1, 0, 1, 2]).
static func place(
	seed:          int,
	room_size:     Vector2i,
	room_cols:     int,
	room_rows:     int,
	floor_indices: Array[int]
) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var result: Array = []

	for i in range(floor_indices.size() - 1):
		var f_from := floor_indices[i]
		var f_to   := floor_indices[i + 1]

		# Pick a random room in the grid
		var col:     int = rng.randi() % maxi(1, room_cols)
		var row:     int = rng.randi() % maxi(1, room_rows)
		var room_origin := Vector2i(col * room_size.x, row * room_size.y)

		# Pick an interior cell (avoid the one-tile wall border)
		var inner_w: int = maxi(1, room_size.x - 2)
		var inner_h: int = maxi(1, room_size.y - 2)
		var ix:      int = 1 + rng.randi() % inner_w
		var iy:      int = 1 + rng.randi() % inner_h

		var sd := StairData.new()
		sd.floor_from = f_from
		sd.floor_to   = f_to
		sd.tile_pos   = room_origin + Vector2i(ix, iy)
		result.append(sd)

	return result
