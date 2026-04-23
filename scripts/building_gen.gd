@tool
class_name BuildingGen
extends Node2D

# Procedural building generator.
#
# Phase 1 (room_cols=1, room_rows=1): generates a single seeded room using
# WfcRoomGenerator then runs FurniturePass on a dedicated props layer.
#
# Phase 2 (room_cols>1 or room_rows>1): generates a multi-room floor plan via
# RoomGraph — each room gets its own WFC pass with door tiles as fixed constraints
# so adjacent rooms are stitched at their shared wall. FurniturePass runs per room
# using the room's assigned type. A flood-fill connectivity check validates the
# result.
#
# Phase 3 (num_floors>1 or has_basement): generates multiple stacked floors.
# Each floor is an independent TileMapLayer created dynamically. StairPlacer picks
# one stair position per adjacent floor pair; those positions become fixed WFC
# constraints (STAIR_UP on the lower floor, STAIR_DOWN on the upper floor at the
# same XY). switch_floor() toggles layer visibility. Generated tile data is cached
# by seed via BuildingCache so deaths don't retrigger generation.
#
# Phase 4 (hazards): HazardPass runs after FurniturePass per room with its own
# dedicated `hazards` RNG sub-stream. Placed hazards are stored in _placed_hazards
# and exposed via get_placed_hazards(floor). Register them into HazardManager after
# generation to enable the runtime trigger→warning→consequence→reset flow.

@export var building_seed: int = 0
@export var room_size:     Vector2i = Vector2i(8, 8)
@export var room_cols:     int = 1
@export var room_rows:     int = 1
@export var num_floors:    int = 1    # above-ground floors (>= 1)
@export var has_basement:  bool = false
# Archetype drives room-type distribution (via BuildingArchetype.room_weights_for).
# Set by WorldGen when placing buildings; can also be hand-set in the Inspector.
@export var archetype:     int = BuildingArchetype.ArchetypeID.HOUSE
# When true this building is the player's goal (the Store the player must reach).
@export var is_goal:       bool = false

@export var floor_layer: TileMapLayer
# Walls, windows, and doors all share this layer so they Y-sort together.
@export var wall_layer:  TileMapLayer

# Source IDs for tiles that replace walls. Adjust to match the authored tileset;
# both assume the atlas uses the same SWEN directional layout as walls so a wall
# tile's atlas coord can be reused when swapping in a window or door.
const WINDOW_SOURCE_ID := 24
const DOOR_SOURCE_ID   := 22
# Column tile placed at the four wall corners. Single variant assumed.
const COLUMN_SOURCE_ID := 5
const COLUMN_ATLAS     := Vector2i(0, 0)

@export_tool_button("Generate")       var _generate_btn  := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_building_seed

# Emitted whenever the active floor changes (floor switch or initial generate).
signal floor_changed(new_floor: int)

var _active_floor: int = 0

# Populated during multi-floor generation; empty in single-floor mode.
var _floor_layers:   Dictionary = {}  # floor_index (int) -> TileMapLayer
var _props_layers:   Dictionary = {}  # floor_index (int) -> TileMapLayer
var _hazards_layers: Dictionary = {}  # floor_index (int) -> TileMapLayer
var _stair_pairs:    Array      = []  # Array[StairPlacer.StairData]
# Accumulated across all generate() calls; key = floor_index.
var _placed_hazards: Dictionary = {}  # floor_index (int) -> Array[HazardPass.PlacedHazard]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if get_parent() is WorldGen:
		return
	generate()


func randomize_building_seed() -> void:
	building_seed = randi()
	generate()


func generate() -> void:
	if floor_layer == null:
		push_warning("BuildingGen: floor_layer is not assigned")
		return
	if wall_layer == null:
		push_warning("BuildingGen: wall_layer is not assigned")
		return

	var streams := RngStreams.new(building_seed)
	floor_layer.clear()
	wall_layer.clear()

	# Step 1: fill the room with random floor tiles, centred on (0, 0).
	_fill_floor(streams.stream("floor"))
	# Step 2: draw the wall border around the room.
	_fill_walls()
	# Step 3: swap 1–4 wall tiles out for windows.
	_replace_walls(streams.stream("windows"), 1, 4, WINDOW_SOURCE_ID)
	# Step 4: swap 1–2 wall tiles out for doors.
	_replace_walls(streams.stream("doors"), 1, 2, DOOR_SOURCE_ID)


func _room_origin() -> Vector2i:
	@warning_ignore("integer_division")
	return -room_size / 2


func _fill_floor(rng: RandomNumberGenerator) -> void:
	var origin := _room_origin()
	for y in room_size.y:
		for x in room_size.x:
			var cell := origin + Vector2i(x, y)
			var variant := rng.randi_range(0, WfcRoomGenerator.FLOOR_VARIANT_COUNT - 1)
			floor_layer.set_cell(cell, WfcRoomGenerator.FLOOR_SOURCE_ID, Vector2i(variant, 0))


func _fill_walls() -> void:
	# Atlas x order is S, W, E, N.
	const WALL_SOUTH := Vector2i(2, 0)
	const WALL_WEST  := Vector2i(3, 0)
	const WALL_EAST  := Vector2i(0, 0)
	const WALL_NORTH := Vector2i(1, 0)

	var origin := _room_origin()
	var last := origin + room_size - Vector2i.ONE  # inclusive bottom-right corner
	for x in room_size.x:
		var top    := Vector2i(origin.x + x, origin.y - 1)
		var bottom := Vector2i(origin.x + x, last.y + 1)
		wall_layer.set_cell(top,    WfcRoomGenerator.WALL_SOURCE_ID, WALL_NORTH)
		wall_layer.set_cell(bottom, WfcRoomGenerator.WALL_SOURCE_ID, WALL_SOUTH)
	for y in range(0, room_size.y):
		var left  := Vector2i(origin.x - 1, origin.y + y)
		var right := Vector2i(last.x + 1,   origin.y + y)
		wall_layer.set_cell(left,  WfcRoomGenerator.WALL_SOURCE_ID, WALL_WEST)
		wall_layer.set_cell(right, WfcRoomGenerator.WALL_SOURCE_ID, WALL_EAST)

	# Cap the four corners with column tiles. Columns reuse the wall SWEN atlas,
	# so top corners face N and bottom corners face S.
	wall_layer.set_cell(Vector2i(origin.x - 1, origin.y - 1), COLUMN_SOURCE_ID, WALL_NORTH)
	wall_layer.set_cell(Vector2i(last.x + 1,   last.y + 1),   COLUMN_SOURCE_ID, WALL_SOUTH)
	wall_layer.set_cell(Vector2i(last.x + 1,   origin.y - 1), COLUMN_SOURCE_ID, WALL_EAST)
	wall_layer.set_cell(Vector2i(origin.x - 1, last.y + 1),   COLUMN_SOURCE_ID, WALL_WEST)


func _replace_walls(
	rng:       RandomNumberGenerator,
	count_min: int,
	count_max: int,
	source_id: int
) -> void:
	# Only consider plain wall tiles so later passes don't overwrite windows/doors.
	var wall_cells: Array = wall_layer.get_used_cells_by_id(WfcRoomGenerator.WALL_SOURCE_ID)
	if wall_cells.is_empty():
		return

	var count := rng.randi_range(count_min, count_max)
	count = mini(count, wall_cells.size())

	for i in count:
		var idx := rng.randi_range(0, wall_cells.size() - 1)
		var cell: Vector2i = wall_cells[idx]
		wall_cells.remove_at(idx)

		var atlas := wall_layer.get_cell_atlas_coords(cell)
		wall_layer.set_cell(cell, source_id, atlas)


# ── Single-room (Phase 1) ─────────────────────────────────────────────────────

func _generate_single_room(
	fl:            TileMapLayer,
	props_layer:   TileMapLayer,
	hazards_layer: TileMapLayer,
	streams:       RngStreams,
	floor_index:   int = 0
) -> void:
	WfcRoomGenerator.generate(
		streams.derive_seed("wfc"),
		fl,
		Vector2i.ZERO,
		room_size
	)

	if props_layer != null:
		FurniturePass.generate(
			streams.derive_seed("furniture"),
			fl,
			props_layer,
			Vector2i.ZERO,
			room_size,
			TileMeta.RoomType.GENERIC
		)

	if hazards_layer != null:
		var ph := HazardPass.generate(
			streams.derive_seed("hazards"),
			fl,
			hazards_layer,
			Vector2i.ZERO,
			room_size,
			TileMeta.RoomType.GENERIC
		)
		if not ph.is_empty():
			_placed_hazards[floor_index] = ph


# ── Multi-room (Phase 2) ──────────────────────────────────────────────────────

func _generate_multi_room(
	fl:            TileMapLayer,
	props_layer:   TileMapLayer,
	hazards_layer: TileMapLayer,
	streams:       RngStreams,
	floor_index:   int = 0
) -> void:
	var weights := BuildingArchetype.room_weights_for(archetype)
	var layout := RoomGraph.generate(
		streams.derive_seed("layout"),
		room_size,
		room_cols,
		room_rows,
		weights
	)

	var wfc_base    := streams.derive_seed("wfc")
	var furn_base   := streams.derive_seed("furniture")
	var hazard_base := streams.derive_seed("hazards")

	var floor_placed: Array = []

	for i in layout.rooms.size():
		var room: RoomGraph.RoomData = layout.rooms[i]
		var constraints := layout.door_constraints_for(i)

		WfcRoomGenerator.generate(
			hash([wfc_base, i]),
			fl,
			room.origin,
			room.size,
			constraints
		)

		if props_layer != null:
			FurniturePass.generate(
				hash([furn_base, i]),
				fl,
				props_layer,
				room.origin,
				room.size,
				room.type
			)

		if hazards_layer != null:
			var ph := HazardPass.generate(
				hash([hazard_base, i]),
				fl,
				hazards_layer,
				room.origin,
				room.size,
				room.type
			)
			floor_placed.append_array(ph)

	if not floor_placed.is_empty():
		_placed_hazards[floor_index] = floor_placed

	if not _validate_connectivity(fl, layout):
		push_warning("BuildingGen: connectivity check failed for seed %d" % building_seed)


# ── Multi-floor (Phase 3) ─────────────────────────────────────────────────────

func _generate_multifloor(streams: RngStreams) -> void:
	var floor_indices := _get_floor_indices()

	# Restore from cache if available — avoids regeneration on death.
	if BuildingCache.has_building(cache_key()):
		_restore_from_cache(floor_indices)
		return

	# Determine stair positions before WFC so they can be passed as constraints.
	_stair_pairs = StairPlacer.place(
		streams.derive_seed("stairs"),
		room_size,
		room_cols,
		room_rows,
		floor_indices
	)

	var wfc_base    := streams.derive_seed("wfc")
	var furn_base   := streams.derive_seed("furniture")
	var hazard_base := streams.derive_seed("hazards")

	for f in floor_indices:
		_ensure_dynamic_layers(f)

	for f in floor_indices:
		var fl: TileMapLayer = _floor_layers[f]
		var pl: TileMapLayer = _props_layers[f]
		var hl: TileMapLayer = _hazards_layers[f]
		fl.clear()
		pl.clear()
		hl.clear()

		var stair_fixed := _stair_constraints_for_floor(f)

		if room_cols > 1 or room_rows > 1:
			_generate_floor_multi_room(fl, pl, hl, wfc_base, furn_base, hazard_base, f, stair_fixed)
		else:
			_generate_floor_single_room(fl, pl, hl, wfc_base, furn_base, hazard_base, f, stair_fixed)

	if not _validate_multifloor_reachability(floor_indices):
		push_warning("BuildingGen: multi-floor reachability failed for seed %d" % building_seed)

	_store_to_cache(floor_indices)
	switch_floor(0)


func _generate_floor_single_room(
	fl:           TileMapLayer,
	pl:           TileMapLayer,
	hl:           TileMapLayer,
	wfc_base:     int,
	furn_base:    int,
	hazard_base:  int,
	floor_index:  int,
	stair_fixed:  Dictionary
) -> void:
	WfcRoomGenerator.generate(
		hash([wfc_base, floor_index]),
		fl,
		Vector2i.ZERO,
		room_size,
		stair_fixed
	)
	FurniturePass.generate(
		hash([furn_base, floor_index]),
		fl, pl,
		Vector2i.ZERO,
		room_size,
		_room_type_for_floor(floor_index)
	)
	var ph := HazardPass.generate(
		hash([hazard_base, floor_index]),
		fl, hl,
		Vector2i.ZERO,
		room_size,
		_room_type_for_floor(floor_index)
	)
	if not ph.is_empty():
		_placed_hazards[floor_index] = ph


func _generate_floor_multi_room(
	fl:          TileMapLayer,
	pl:          TileMapLayer,
	hl:          TileMapLayer,
	wfc_base:    int,
	furn_base:   int,
	hazard_base: int,
	floor_index: int,
	stair_fixed: Dictionary
) -> void:
	var weights := BuildingArchetype.room_weights_for(archetype)
	var layout := RoomGraph.generate(
		hash([wfc_base, "layout", floor_index]),
		room_size,
		room_cols,
		room_rows,
		weights
	)

	var floor_placed: Array = []

	for i in layout.rooms.size():
		var room: RoomGraph.RoomData = layout.rooms[i]
		var constraints := layout.door_constraints_for(i)

		# Merge stair constraints that fall inside this room.
		for k: Vector2i in stair_fixed:
			if room.rect().has_point(k):
				constraints[k] = stair_fixed[k]

		WfcRoomGenerator.generate(
			hash([wfc_base, floor_index, i]),
			fl,
			room.origin,
			room.size,
			constraints
		)

		FurniturePass.generate(
			hash([furn_base, floor_index, i]),
			fl, pl,
			room.origin,
			room.size,
			room.type
		)

		var ph := HazardPass.generate(
			hash([hazard_base, floor_index, i]),
			fl, hl,
			room.origin,
			room.size,
			room.type
		)
		floor_placed.append_array(ph)

	if not floor_placed.is_empty():
		_placed_hazards[floor_index] = floor_placed

	if not _validate_connectivity(fl, layout):
		push_warning("BuildingGen: floor %d connectivity failed for seed %d" % [floor_index, building_seed])


func _stair_constraints_for_floor(floor_index: int) -> Dictionary:
	var fixed: Dictionary = {}
	for pair in _stair_pairs:
		var sd: StairPlacer.StairData = pair
		if sd.floor_from == floor_index:
			fixed[sd.tile_pos] = {
				"source_id": WfcRoomGenerator.STAIR_UP_SOURCE_ID,
				"atlas":     Vector2i(0, 0),
			}
		elif sd.floor_to == floor_index:
			fixed[sd.tile_pos] = {
				"source_id": WfcRoomGenerator.STAIR_DOWN_SOURCE_ID,
				"atlas":     Vector2i(0, 0),
			}
	return fixed


func _room_type_for_floor(floor_index: int) -> int:
	# Basements use GENERIC; future work may add STORAGE or UTILITY biases.
	return TileMeta.RoomType.GENERIC


func _get_floor_indices() -> Array[int]:
	var indices: Array[int] = []
	if has_basement:
		indices.append(-1)
	for f in num_floors:
		indices.append(f)
	return indices


# ── Floor switching ───────────────────────────────────────────────────────────

func switch_floor(floor_index: int) -> void:
	for f in _floor_layers:
		(_floor_layers[f] as TileMapLayer).visible = false
	for f in _props_layers:
		(_props_layers[f] as TileMapLayer).visible = false
	for f in _hazards_layers:
		(_hazards_layers[f] as TileMapLayer).visible = false

	if not _floor_layers.has(floor_index):
		push_warning("BuildingGen: floor %d has no layer" % floor_index)
		return

	(_floor_layers[floor_index] as TileMapLayer).visible = true
	(_props_layers[floor_index] as TileMapLayer).visible = true
	if _hazards_layers.has(floor_index):
		(_hazards_layers[floor_index] as TileMapLayer).visible = true

	_active_floor = floor_index
	floor_changed.emit(floor_index)


func get_active_floor() -> int:
	return _active_floor


# Returns all hazards placed on `floor_index` (Array[HazardPass.PlacedHazard]).
func get_placed_hazards(floor_index: int) -> Array:
	return _placed_hazards.get(floor_index, [])


# Returns Vector2i positions of STAIR_UP tiles on `floor_index`.
func get_stair_up_positions(floor_index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pair in _stair_pairs:
		var sd: StairPlacer.StairData = pair
		if sd.floor_from == floor_index:
			result.append(sd.tile_pos)
	return result


# Returns Vector2i positions of STAIR_DOWN tiles on `floor_index`.
func get_stair_down_positions(floor_index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pair in _stair_pairs:
		var sd: StairPlacer.StairData = pair
		if sd.floor_to == floor_index:
			result.append(sd.tile_pos)
	return result


# Returns the floor index reached by ascending from `floor_index` (or floor_index if no stair up).
func get_floor_above(floor_index: int) -> int:
	for pair in _stair_pairs:
		var sd: StairPlacer.StairData = pair
		if sd.floor_from == floor_index:
			return sd.floor_to
	return floor_index


# Returns the floor index reached by descending from `floor_index` (or floor_index if no stair down).
func get_floor_below(floor_index: int) -> int:
	for pair in _stair_pairs:
		var sd: StairPlacer.StairData = pair
		if sd.floor_to == floor_index:
			return sd.floor_from
	return floor_index


# ── Multi-floor reachability ──────────────────────────────────────────────────

func _validate_multifloor_reachability(floor_indices: Array[int]) -> bool:
	for f in floor_indices:
		if not _floor_layers.has(f):
			continue
		var fl: TileMapLayer = _floor_layers[f]

		# Collect all stair positions on this floor (up + down).
		var stair_positions: Array[Vector2i] = []
		stair_positions.append_array(get_stair_up_positions(f))
		stair_positions.append_array(get_stair_down_positions(f))

		if stair_positions.is_empty():
			continue

		var spawn := _find_floor_spawn(fl)
		if spawn == Vector2i(-1, -1):
			continue

		for stair_pos in stair_positions:
			if not _can_reach(fl, spawn, stair_pos):
				return false

	return true


func _find_floor_spawn(layer: TileMapLayer) -> Vector2i:
	# Walk the interior of the first room to find any non-wall cell.
	for y in range(1, room_size.y - 1):
		for x in range(1, room_size.x - 1):
			var cell := Vector2i(x, y)
			var src := layer.get_cell_source_id(cell)
			if src != -1 and src != WfcRoomGenerator.WALL_SOURCE_ID:
				return cell
	return Vector2i(-1, -1)


func _can_reach(layer: TileMapLayer, start: Vector2i, target: Vector2i) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if visited.has(cell):
			continue
		var src := layer.get_cell_source_id(cell)
		if src == -1 or src == WfcRoomGenerator.WALL_SOURCE_ID:
			continue
		visited[cell] = true
		if cell == target:
			return true
		queue.append(cell + Vector2i(1,  0))
		queue.append(cell + Vector2i(-1, 0))
		queue.append(cell + Vector2i(0,  1))
		queue.append(cell + Vector2i(0, -1))
	return false


# ── Building cache ────────────────────────────────────────────────────────────

func cache_key() -> int:
	# Include floor count + basement flag so different configs don't share entries.
	return hash([building_seed, num_floors, int(has_basement)])


func _store_to_cache(floor_indices: Array[int]) -> void:
	var snapshots: Dictionary = {}
	for f in floor_indices:
		snapshots[f] = {
			"floor":   BuildingCache.snapshot_layer(_floor_layers[f]),
			"props":   BuildingCache.snapshot_layer(_props_layers[f]),
			"hazards": BuildingCache.snapshot_layer(_hazards_layers[f]),
		}
	snapshots["_stair_pairs"] = _serialize_stair_pairs()
	BuildingCache.store(cache_key(), snapshots)


func _restore_from_cache(floor_indices: Array[int]) -> void:
	var cached := BuildingCache.load_building(cache_key())

	if cached.has("_stair_pairs"):
		_stair_pairs = _deserialize_stair_pairs(cached["_stair_pairs"])

	for f in floor_indices:
		_ensure_dynamic_layers(f)
		if not cached.has(f):
			continue
		var entry: Dictionary = cached[f]
		BuildingCache.restore_layer(_floor_layers[f],   entry.get("floor",   []))
		BuildingCache.restore_layer(_props_layers[f],   entry.get("props",   []))
		BuildingCache.restore_layer(_hazards_layers[f], entry.get("hazards", []))

	switch_floor(0)


func _serialize_stair_pairs() -> Array:
	var result: Array = []
	for pair in _stair_pairs:
		var sd: StairPlacer.StairData = pair
		result.append({
			"from": sd.floor_from,
			"to":   sd.floor_to,
			"pos":  { "x": sd.tile_pos.x, "y": sd.tile_pos.y },
		})
	return result


func _deserialize_stair_pairs(data: Array) -> Array:
	var result: Array = []
	for entry in data:
		var sd := StairPlacer.StairData.new()
		sd.floor_from = entry["from"]
		sd.floor_to   = entry["to"]
		sd.tile_pos   = Vector2i(entry["pos"]["x"], entry["pos"]["y"])
		result.append(sd)
	return result


# ── Dynamic layer management ─────────────────────────────────────────────────

func _ensure_dynamic_layers(floor_index: int) -> void:
	var fl_name := "DynFloor_%d" % floor_index
	var pr_name := "DynProps_%d" % floor_index
	var hz_name := "DynHazards_%d" % floor_index

	if not _floor_layers.has(floor_index):
		var fl := _find_or_create_layer(fl_name)
		_floor_layers[floor_index] = fl

	if not _props_layers.has(floor_index):
		var pl := _find_or_create_layer(pr_name)
		_props_layers[floor_index] = pl

	if not _hazards_layers.has(floor_index):
		var hl := _find_or_create_layer(hz_name)
		_hazards_layers[floor_index] = hl


func _find_or_create_layer(layer_name: String) -> TileMapLayer:
	for child in get_children():
		if child.name == layer_name and child is TileMapLayer:
			return child as TileMapLayer
	var layer := TileMapLayer.new()
	layer.name = layer_name
	# Inherit tileset from the existing scene-authored floor layer so rendering
	# works when the game runs. No-op in headless unit tests (tile_set stays null).
	var ref := _get_floor_layer()
	if ref != null:
		layer.tile_set = ref.tile_set
	add_child(layer)
	return layer


# ── Connectivity validation (single-floor) ───────────────────────────────────

func _validate_connectivity(fl: TileMapLayer, layout: RoomGraph) -> bool:
	if layout.rooms.is_empty():
		return true

	var first_room: RoomGraph.RoomData = layout.rooms[0]
	var spawn := first_room.origin + Vector2i(1, 1)
	if first_room.size.x <= 2 or first_room.size.y <= 2:
		return true

	var bounds := layout.footprint()
	var visited: Array[Vector2i] = []
	var queue: Array[Vector2i] = [spawn]
	var walkable_total := 0

	for room in layout.rooms:
		var r: RoomGraph.RoomData = room
		for y in r.size.y:
			for x in r.size.x:
				var cell := r.origin + Vector2i(x, y)
				var src := fl.get_cell_source_id(cell)
				if src != -1 and src != WfcRoomGenerator.WALL_SOURCE_ID:
					walkable_total += 1

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell in visited:
			continue
		if not bounds.has_point(cell):
			continue
		var src := fl.get_cell_source_id(cell)
		if src == -1 or src == WfcRoomGenerator.WALL_SOURCE_ID:
			continue
		visited.append(cell)
		queue.append(cell + Vector2i(1, 0))
		queue.append(cell + Vector2i(-1, 0))
		queue.append(cell + Vector2i(0, 1))
		queue.append(cell + Vector2i(0, -1))

	return visited.size() >= walkable_total


# ── Node helpers ──────────────────────────────────────────────────────────────

func _get_floor_layer() -> TileMapLayer:
	if floor_layer != null:
		return floor_layer
	# Fallback: scan children for legacy scenes that haven't wired the export.
	for child in get_children():
		if child is TileMapLayer and child.name == "TileMapLayer":
			return child
	for child in get_children():
		if child is TileMapLayer:
			return child
	return null


func _get_props_layer() -> TileMapLayer:
	for child in get_children():
		if child is TileMapLayer and child.name == "PropsLayer":
			return child
	return null


func _get_hazards_layer() -> TileMapLayer:
	for child in get_children():
		if child is TileMapLayer and child.name == "HazardsLayer":
			return child
	return null
