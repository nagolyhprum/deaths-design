class_name FurniturePass
extends RefCounted

# Furniture/prop placement pass. Runs after WFC has filled the floor layer.
#
# Phase 1: infrastructure only — the PROP_PALETTE is empty until prop tile
# assets are added to building_tiles.tres. The flood-fill walkability check
# is exercised even with no props (it should pass trivially).
#
# Phase 2: per-room-type palettes are consulted; actual prop tiles are
# populated once assets exist.
#
# Usage:
#   FurniturePass.generate(seed, floor_layer, props_layer, origin, size, room_type)

const MAX_RETRIES := 3

const FLOOR_SOURCE_ID := 9
const WALL_SOURCE_ID  := 4
const DOOR_CLOSED_ID  := 22
const DOOR_OPEN_ID    := 23


# Descriptor for one prop tile in the palette.
class PropDef extends RefCounted:
	var source_id: int
	var atlas: Vector2i
	var anchor: int        # TileMeta.Anchor
	var room_types: Array  # Array[TileMeta.RoomType]; empty = any
	var weight: float = 1.0
	var clearance: int = 1 # Minimum free tiles around this prop

	func matches_room(room_type: int) -> bool:
		return room_types.is_empty() or room_type in room_types


# ── Prop palette (empty for Phase 1; fill in when assets are added) ───────────
#
# Example entry once a plant tile exists at source=9, atlas=(4,0):
#   PropDef.new() with source_id=9, atlas=Vector2i(4,0),
#   anchor=TileMeta.Anchor.WALL_N, room_types=[], weight=1.0, clearance=1
#
static var PROP_PALETTE: Array = []


# ── Public API ────────────────────────────────────────────────────────────────

# Place props on `props_layer` for the room defined by origin+size.
# `floor_layer` is read-only (used to determine walkable cells).
# Returns true if placement passes walkability validation (or palette is empty).
static func generate(
	seed: int,
	floor_layer: TileMapLayer,
	props_layer: TileMapLayer,
	origin: Vector2i,
	size: Vector2i,
	room_type: int = TileMeta.RoomType.GENERIC
) -> bool:
	if PROP_PALETTE.is_empty():
		return true  # Nothing to place; walkability trivially valid.

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	for attempt in MAX_RETRIES:
		# Clear any previous attempt's props for this room area
		_clear_room_props(props_layer, origin, size)

		if _try_place(rng, floor_layer, props_layer, origin, size, room_type):
			return true

		rng.seed = hash([seed, "retry", attempt])

	_clear_room_props(props_layer, origin, size)
	return false


# ── Internal helpers ──────────────────────────────────────────────────────────

static func _try_place(
	rng: RandomNumberGenerator,
	floor_layer: TileMapLayer,
	props_layer: TileMapLayer,
	origin: Vector2i,
	size: Vector2i,
	room_type: int
) -> bool:
	var interior_cells := _interior_cells(origin, size)
	var wall_cells := _border_cells(floor_layer, origin, size)
	var door_cells := _door_cells(floor_layer, origin, size)

	# Collect eligible props for this room type
	var eligible: Array = []
	for p in PROP_PALETTE:
		if p.matches_room(room_type):
			eligible.append(p)

	if eligible.is_empty():
		return true

	# Try to place each eligible prop once (weighted selection of position)
	var placed_cells: Array[Vector2i] = []

	for prop in eligible:
		var candidates := _candidates_for_anchor(
			prop.anchor, interior_cells, wall_cells, door_cells, origin, size
		)
		if candidates.is_empty():
			continue

		# Shuffle candidates deterministically, pick first that has clearance
		_shuffle(rng, candidates)
		for cell in candidates:
			if _has_clearance(cell, prop.clearance, placed_cells, floor_layer, origin, size):
				props_layer.set_cell(cell, prop.source_id, prop.atlas)
				placed_cells.append(cell)
				break

	# Validate walkability: all reachable floor cells before placement are still
	# reachable after. Spawn point = first interior cell.
	var spawn := _first_interior(origin, size)
	if spawn == Vector2i(-1, -1):
		return true  # Degenerate room; skip validation.

	var reachable := _flood_fill(floor_layer, props_layer, spawn, origin, size)
	var all_floor := _all_walkable(floor_layer, origin, size)
	return reachable.size() >= all_floor.size()


static func _clear_room_props(props_layer: TileMapLayer, origin: Vector2i, size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			props_layer.erase_cell(origin + Vector2i(x, y))


static func _interior_cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			cells.append(origin + Vector2i(x, y))
	return cells


static func _border_cells(floor_layer: TileMapLayer, origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if y == 0 or y == size.y - 1 or x == 0 or x == size.x - 1:
				var cell := origin + Vector2i(x, y)
				var src := floor_layer.get_cell_source_id(cell)
				if src == WfcRoomGenerator.WALL_SOURCE_ID:
					cells.append(cell)
	return cells


static func _door_cells(floor_layer: TileMapLayer, origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			var src := floor_layer.get_cell_source_id(cell)
			if src == DOOR_CLOSED_ID or src == DOOR_OPEN_ID:
				cells.append(cell)
	return cells


static func _candidates_for_anchor(
	anchor: int,
	interior: Array[Vector2i],
	walls: Array[Vector2i],
	doors: Array[Vector2i],
	origin: Vector2i,
	size: Vector2i
) -> Array[Vector2i]:
	match anchor:
		TileMeta.Anchor.CENTER:
			return interior.duplicate()
		TileMeta.Anchor.WALL_N:
			# Interior cells on row 1 (just inside north wall)
			var c: Array[Vector2i] = []
			for cell in interior:
				if cell.y == origin.y + 1:
					c.append(cell)
			return c
		TileMeta.Anchor.WALL_S:
			var c: Array[Vector2i] = []
			for cell in interior:
				if cell.y == origin.y + size.y - 2:
					c.append(cell)
			return c
		TileMeta.Anchor.WALL_W:
			var c: Array[Vector2i] = []
			for cell in interior:
				if cell.x == origin.x + 1:
					c.append(cell)
			return c
		TileMeta.Anchor.WALL_E:
			var c: Array[Vector2i] = []
			for cell in interior:
				if cell.x == origin.x + size.x - 2:
					c.append(cell)
			return c
		TileMeta.Anchor.CORNER:
			var corners: Array[Vector2i] = [
				origin + Vector2i(1, 1),
				origin + Vector2i(size.x - 2, 1),
				origin + Vector2i(1, size.y - 2),
				origin + Vector2i(size.x - 2, size.y - 2),
			]
			var valid: Array[Vector2i] = []
			for c in corners:
				if c in interior:
					valid.append(c)
			return valid
		TileMeta.Anchor.DOOR_ADJACENT:
			var c: Array[Vector2i] = []
			var offsets: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
			for door in doors:
				for off in offsets:
					var adj := door + off
					if adj in interior and adj not in c:
						c.append(adj)
			return c
	return []


static func _has_clearance(
	cell: Vector2i,
	clearance: int,
	placed: Array[Vector2i],
	floor_layer: TileMapLayer,
	origin: Vector2i,
	size: Vector2i
) -> bool:
	if clearance <= 0:
		return true
	var offsets: Array[Vector2i] = []
	for dy in range(-clearance, clearance + 1):
		for dx in range(-clearance, clearance + 1):
			if dx == 0 and dy == 0:
				continue
			offsets.append(Vector2i(dx, dy))
	for off in offsets:
		var neighbor := cell + off
		if neighbor in placed:
			return false
	return true


static func _flood_fill(
	floor_layer: TileMapLayer,
	props_layer: TileMapLayer,
	start: Vector2i,
	origin: Vector2i,
	size: Vector2i
) -> Array[Vector2i]:
	var visited: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	var bounds := Rect2i(origin, size)

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell in visited:
			continue
		if not bounds.has_point(cell):
			continue
		if not _is_walkable(floor_layer, props_layer, cell):
			continue
		visited.append(cell)
		queue.append(cell + Vector2i(1, 0))
		queue.append(cell + Vector2i(-1, 0))
		queue.append(cell + Vector2i(0, 1))
		queue.append(cell + Vector2i(0, -1))

	return visited


static func _all_walkable(floor_layer: TileMapLayer, origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			if _is_walkable(floor_layer, null, cell):
				cells.append(cell)
	return cells


static func _is_walkable(floor_layer: TileMapLayer, props_layer: TileMapLayer, cell: Vector2i) -> bool:
	var src := floor_layer.get_cell_source_id(cell)
	if src == -1:
		return false
	# Walkable: floor tiles and door tiles; not wall tiles
	if src == WALL_SOURCE_ID:
		return false
	# A cell with a prop on it is blocked
	if props_layer != null and props_layer.get_cell_source_id(cell) != -1:
		return false
	return true


static func _first_interior(origin: Vector2i, size: Vector2i) -> Vector2i:
	if size.x <= 2 or size.y <= 2:
		return Vector2i(-1, -1)
	return origin + Vector2i(1, 1)


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
