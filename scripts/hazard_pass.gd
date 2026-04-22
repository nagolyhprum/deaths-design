class_name HazardPass
extends RefCounted

# Hazard placement pass. Runs after FurniturePass using a dedicated `hazards`
# RNG sub-stream so adding/removing hazards never perturbs furniture layouts.
#
# Hazards are a prop subtype: same anchor/room_type/clearance placement rules
# plus extra fields that drive the runtime trigger→warning→consequence→reset flow.
#
# Phase 4 palette is empty until hazard tile assets are added to the TileSet.
# The telegraph-visibility validator and state registration API are in place.
#
# Usage:
#   var placed := HazardPass.generate(seed, floor_layer, hazards_layer,
#                                     origin, size, room_type)
#   # Returns Array[PlacedHazard] (may be empty if palette is empty or
#   # no valid placements exist). Register each in HazardManager after generation.

const MAX_RETRIES := 3

const FLOOR_SOURCE_ID := 9
const WALL_SOURCE_ID  := 4
const DOOR_CLOSED_ID  := 22
const DOOR_OPEN_ID    := 23


# Descriptor for one hazard type in the palette.
class HazardDef extends RefCounted:
	var source_id:      int
	var atlas:          Vector2i
	var anchor:         int          # TileMeta.Anchor
	var room_types:     Array        # Array[TileMeta.RoomType]; empty = any
	var weight:         float = 1.0
	var clearance:      int   = 1    # Minimum free tiles around this hazard
	var hazard_type:    int          # TileMeta.HazardType
	var trigger_radius: int   = 1    # Cells from center that activate the hazard
	# Relative offsets where telegraph/warning tiles appear (relative to hazard cell).
	# At least one must land on a walkable floor cell for the placement to be valid.
	var warning_offsets: Array[Vector2i] = []
	var consequence:    String = "death"   # What happens on trigger
	var reset_mode:     String = "respawn" # When hazard resets: "respawn", "checkpoint", "never"

	func matches_room(room_type: int) -> bool:
		return room_types.is_empty() or room_type in room_types


# Result of a successful hazard placement.
class PlacedHazard extends RefCounted:
	var cell:       Vector2i
	var hazard_def: HazardDef


# ── Hazard palette ─────────────────────────────────────────────────────────────
#
# Empty until hazard tile assets are added to building_tiles.tres.
# Example entry for a kitchen stove-fire hazard (once source_id is known):
#
#   var stove := HazardDef.new()
#   stove.source_id    = 40          # ⚠️ placeholder — update with real TileSet ID
#   stove.atlas        = Vector2i(0, 0)
#   stove.anchor       = TileMeta.Anchor.WALL_N
#   stove.room_types   = [TileMeta.RoomType.KITCHEN]
#   stove.weight       = 1.0
#   stove.clearance    = 1
#   stove.hazard_type  = TileMeta.HazardType.STOVE_FIRE
#   stove.trigger_radius  = 1
#   stove.warning_offsets = [Vector2i(0, 1)]  # tile in front of stove
#   stove.consequence  = "death"
#   stove.reset_mode   = "respawn"
#   HAZARD_PALETTE.append(stove)
#
static var HAZARD_PALETTE: Array = []


# ── Public API ─────────────────────────────────────────────────────────────────

# Place hazards on `hazards_layer` for the room defined by origin+size.
# `floor_layer` is read-only (determines walkable cells for telegraph validation).
# Returns Array[PlacedHazard] — empty if palette is empty or no valid placements.
static func generate(
	seed:         int,
	floor_layer:  TileMapLayer,
	hazards_layer: TileMapLayer,
	origin:       Vector2i,
	size:         Vector2i,
	room_type:    int = TileMeta.RoomType.GENERIC
) -> Array:
	if HAZARD_PALETTE.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	for attempt in MAX_RETRIES:
		_clear_room_hazards(hazards_layer, origin, size)
		var placed := _try_place(rng, floor_layer, hazards_layer, origin, size, room_type)
		if placed != null:
			return placed
		rng.seed = hash([seed, "hazard_retry", attempt])

	_clear_room_hazards(hazards_layer, origin, size)
	return []


# ── Internal helpers ───────────────────────────────────────────────────────────

static func _try_place(
	rng:           RandomNumberGenerator,
	floor_layer:   TileMapLayer,
	hazards_layer: TileMapLayer,
	origin:        Vector2i,
	size:          Vector2i,
	room_type:     int
) -> Array:
	var interior_cells := _interior_cells(origin, size)
	var wall_cells     := _border_cells(floor_layer, origin, size)
	var door_cells     := _door_cells(floor_layer, origin, size)

	var eligible: Array[HazardDef] = []
	for h in HAZARD_PALETTE:
		if h.matches_room(room_type):
			eligible.append(h)

	if eligible.is_empty():
		return []

	var placed_cells: Array[Vector2i] = []
	var placed_hazards: Array = []

	for hazard in eligible:
		var candidates := _candidates_for_anchor(
			hazard.anchor, interior_cells, wall_cells, door_cells, origin, size
		)
		if candidates.is_empty():
			continue

		_shuffle(rng, candidates)
		for cell in candidates:
			if not _has_clearance(cell, hazard.clearance, placed_cells, origin, size):
				continue
			if not _validate_telegraph(hazard, cell, floor_layer, origin, size):
				continue
			hazards_layer.set_cell(cell, hazard.source_id, hazard.atlas)
			placed_cells.append(cell)
			var ph := PlacedHazard.new()
			ph.cell       = cell
			ph.hazard_def = hazard
			placed_hazards.append(ph)
			break

	return placed_hazards


# Telegraph-visibility validation:
# For each hazard, at least one warning_offset must land on a walkable floor cell.
# This guarantees the player can see the telegraph indicator before entering
# the trigger radius.
static func _validate_telegraph(
	hazard:      HazardDef,
	cell:        Vector2i,
	floor_layer: TileMapLayer,
	origin:      Vector2i,
	size:        Vector2i
) -> bool:
	if hazard.warning_offsets.is_empty():
		return true  # No telegraph required for this hazard type.

	var bounds := Rect2i(origin, size)
	for offset in hazard.warning_offsets:
		var warn_cell := cell + offset
		if not bounds.has_point(warn_cell):
			continue
		var src := floor_layer.get_cell_source_id(warn_cell)
		if src == FLOOR_SOURCE_ID:
			return true  # At least one warning tile is on a visible floor cell.

	return false  # No valid telegraph position; reject this placement.


static func _clear_room_hazards(hazards_layer: TileMapLayer, origin: Vector2i, size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			hazards_layer.erase_cell(origin + Vector2i(x, y))


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
				if floor_layer.get_cell_source_id(cell) == WfcRoomGenerator.WALL_SOURCE_ID:
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
	anchor:   int,
	interior: Array[Vector2i],
	walls:    Array[Vector2i],
	doors:    Array[Vector2i],
	origin:   Vector2i,
	size:     Vector2i
) -> Array[Vector2i]:
	match anchor:
		TileMeta.Anchor.CENTER:
			return interior.duplicate()
		TileMeta.Anchor.WALL_N:
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
			var offsets: Array[Vector2i] = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]
			for door in doors:
				for off in offsets:
					var adj := door + off
					if adj in interior and adj not in c:
						c.append(adj)
			return c
	return []


static func _has_clearance(
	cell:    Vector2i,
	clearance: int,
	placed:  Array[Vector2i],
	origin:  Vector2i,
	size:    Vector2i
) -> bool:
	if clearance <= 0:
		return true
	for dy in range(-clearance, clearance + 1):
		for dx in range(-clearance, clearance + 1):
			if dx == 0 and dy == 0:
				continue
			if cell + Vector2i(dx, dy) in placed:
				return false
	return true


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
