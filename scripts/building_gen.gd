@tool
class_name BuildingGen
extends Node2D

# Procedural building generator.
#
# generate() runs a single fixed 5-step pass over four TileMapLayers
# (floor / wall / goal / triggers). All RNG draws go through RngStreams so
# each step is reproducible from building_seed alone:
#
#   Step 1 — fill the room with random floor tiles centred on (0, 0).
#   Step 2 — draw the wall border (N / S / E / W) plus four column corners.
#   Step 3 — swap 1–4 wall tiles out for windows.
#   Step 4 — swap 1–2 wall tiles out for doors; each door also paints an
#            inside/outside trigger tile on triggers_layer.
#   Step 5 — if is_goal is true, place a switch tile against the N or E
#            interior wall on goal_layer.

@export var building_seed: int = 0
@export_group("Generation Params")
@export var room_size:     Vector2i = Vector2i(8, 8)
# When true this building is the player's goal (the Store the player must reach).
@export var is_goal:       bool = false

@export_group("TileMapLayers")
@export var floor_layer: TileMapLayer
# Walls, windows, and doors all share this layer so they Y-sort together.
@export var wall_layer:  TileMapLayer
@export var goal_layer:  TileMapLayer
@export var triggers_layer:  TileMapLayer

# Source IDs for tiles that replace walls. Adjust to match the authored tileset;
# both assume the atlas uses the same SWEN directional layout as walls so a wall
# tile's atlas coord can be reused when swapping in a window or door.
const WINDOW_SOURCE_ID    := 24
const DOOR_SOURCE_ID      := 22
const DOOR_OPEN_SOURCE_ID := 23
# Scene Collection source IDs on triggers_layer. Each tile should be a scene
# carrying an Area2D (plus diamond CollisionShape2D) that fires on body enter.
const INSIDE_DOOR_TRIGGER_SOURCE_ID  := 14
const OUTSIDE_DOOR_TRIGGER_SOURCE_ID := 15
# Column tile placed at the four wall corners. Single variant assumed.
const COLUMN_SOURCE_ID := 5
# Switch tile placed inside goal buildings along the north or west wall.
# SWITCH_ON_SOURCE_ID is reserved for the future switch-on state.
const SWITCH_OFF_SOURCE_ID := 11
const SWITCH_ON_SOURCE_ID  := 12

@export_group("Debug")
@export_tool_button("Generate")       var _generate_btn  := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_building_seed


func _ready() -> void:
	add_to_group(&"building_gens")
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
	if goal_layer != null:
		goal_layer.clear()
	if triggers_layer != null:
		triggers_layer.clear()

	# Step 1: fill the room with random floor tiles, centred on (0, 0).
	_fill_floor(streams.stream("floor"))
	# Step 2: draw the wall border around the room.
	_fill_walls()
	# Step 3: swap 1–4 wall tiles out for windows.
	_replace_walls(streams.stream("windows"), 1, 4, WINDOW_SOURCE_ID)
	# Step 4: swap 1–2 wall tiles out for doors (also paints door triggers).
	_replace_walls(streams.stream("doors"), 1, 2, DOOR_SOURCE_ID)
	# Step 5: if this building is the goal, drop a switch against N or W wall.
	if is_goal:
		if goal_layer == null:
			push_warning("BuildingGen: is_goal is true but goal_layer is not assigned")
		else:
			_place_switch(streams.stream("switch"))


# Offset (in tile coords) from a door cell to the first interior floor cell.
# Atlas x encodes which wall the door sits on: E=0, N=1, S=2, W=3.
func _door_inside_offset(atlas: Vector2i) -> Vector2i:
	if atlas.x == 0: return Vector2i(-1, 0)  # east wall  → inside is west
	if atlas.x == 1: return Vector2i(0, -1)   # north wall → inside is south
	if atlas.x == 2: return Vector2i(0, -1)  # south wall → inside is north
	if atlas.x == 3: return Vector2i(-1, 0)   # west wall  → inside is east
	return Vector2i.ZERO


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


func _place_switch(rng: RandomNumberGenerator) -> void:
	const SWITCH_NORTH := Vector2i(2, 0)
	const SWITCH_WEST  := Vector2i(0, 0)

	var origin := _room_origin()
	var last := origin + room_size - Vector2i.ONE - Vector2i.ONE

	# Collect interior cells whose adjacent wall tile is still a plain wall
	# (windows and doors have replaced the wall's source id, so they're skipped).
	var candidates: Array = []
	for x in range(origin.x, last.x + 1):
		if wall_layer.get_cell_source_id(Vector2i(x, origin.y - 1)) == WfcRoomGenerator.WALL_SOURCE_ID:
			candidates.append([Vector2i(x, origin.y), SWITCH_NORTH])
	for y in range(origin.y, last.y + 1):
		if wall_layer.get_cell_source_id(Vector2i(origin.x - 1, y)) == WfcRoomGenerator.WALL_SOURCE_ID:
			candidates.append([Vector2i(origin.x, y), SWITCH_WEST])

	if candidates.is_empty():
		push_warning("BuildingGen: no plain wall tiles available on N/W edges for switch")
		return

	var pick: Array = candidates[rng.randi_range(0, candidates.size() - 1)]
	goal_layer.set_cell(pick[0], SWITCH_OFF_SOURCE_ID, pick[1])


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

		# Doors also drop inside/outside trigger tiles on triggers_layer.
		if source_id == DOOR_SOURCE_ID and triggers_layer != null:
			var offset := _door_inside_offset(atlas)
			triggers_layer.set_cell(cell + offset, INSIDE_DOOR_TRIGGER_SOURCE_ID,  Vector2i.ZERO)
			triggers_layer.set_cell(cell - offset, OUTSIDE_DOOR_TRIGGER_SOURCE_ID, Vector2i.ZERO)
