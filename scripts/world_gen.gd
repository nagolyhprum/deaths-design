@tool
class_name WorldGen
extends Node2D

# Top-level world orchestrator.
#
# Phase 1: derives a per-building seed from world_seed and forwards it to the
# single BuildingGen child.
#
# Phase 2: derives seeds for multiple BuildingGen children and routes a simple
# outdoor path on the outdoor TileMapLayer between building entrance tiles.
#
# Phase 5: assigns building archetypes (HOUSE, SHOP, APARTMENT, STORE) from
# BuildingArchetype, marks the last building as the goal (STORE archetype +
# is_goal=true), and emits goal_building_changed when the assignment is made.
# Outdoor routing draws a tile path between all consecutive building entrances.
#
# Seed persistence: on non-editor runs, world_seed is loaded from user:// on
# startup and saved whenever it changes.

const SAVE_PATH := "user://worldgen.cfg"

const OUTDOOR_FLOOR_SOURCE_ID := 0   # fallback; update when outdoor_tiles is authored
const OUTDOOR_FLOOR_ATLAS     := Vector2i(0, 0)
const TILE_SIZE = Vector2i(256, 128)

@export var world_seed: int = 0

# Both expected to be building_gen.tscn (or a variant).
@export_group("Generation Params")
@export var world_size:     Vector2i = Vector2i(8, 8)
@export_group("Player & Goal")
@export var player:               Player
@export var start_building_scene: BuildingGen
@export var goal_building_scene:  BuildingGen


@export_tool_button("Generate")       var _generate_btn  := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_world_seed

# Emitted when the goal (Store) building is identified during generation.
@warning_ignore("unused_signal")
signal goal_building_changed(building: BuildingGen)

# The building the player must reach (assigned during generate()).
var goal_building: BuildingGen = null
# The building where the player starts (first BuildingGen child).
var spawn_building: BuildingGen = null
# Extras spawned by _place_extras; freed on the next generate().
var _extra_buildings: Array[BuildingGen] = []
# Footprints (in world-tile coords) of every placed building this generation,
# used to reject overlapping placements.
var _occupied_rects: Array[Rect2i] = []

const INVALID_POS := Vector2i(-32768, -32768)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_load_seed()
	generate()


func randomize_world_seed() -> void:
	world_seed = randi()
	if not Engine.is_editor_hint():
		_save_seed()
	generate()


func generate() -> void:
	if start_building_scene == null:
		push_warning("WorldGen: start_building_scene is not assigned")
		return
	if goal_building_scene == null:
		push_warning("WorldGen: goal_building_scene is not assigned")
		return

	_clear_extras()
	_occupied_rects.clear()

	var streams := RngStreams.new(world_seed)

	# Step 1: place the start.
	_place_building(start_building_scene, streams.stream("start"), 6, 10)
	# Step 2: place the goal, keeping it at least half the shorter world
	#         dimension away from the start and not overlapping its footprint.
	@warning_ignore("integer_division")
	var min_endpoint_dist := mini(world_size.x, world_size.y) / 2
	_place_building(
		goal_building_scene, streams.stream("goal"), 6, 10,
		_grid_pos(start_building_scene), min_endpoint_dist
	)
	# Step 3: fill the world with a handful of extra random buildings.
	_place_extras(streams.stream("extras"))


# Picks a room size, finds a non-overlapping world position, applies everything
# to the building, and calls generate(). Returns true on success.
func _place_building(
	b:          BuildingGen,
	rng:        RandomNumberGenerator,
	min_dim:    int,
	max_dim:    int,
	avoid:      Vector2i = INVALID_POS,
	avoid_dist: int      = 0
) -> bool:
	var size := Vector2i(rng.randi_range(min_dim, max_dim), rng.randi_range(min_dim, max_dim))
	var pos := _find_free_position(rng, size, avoid, avoid_dist)
	if pos == INVALID_POS:
		push_warning("WorldGen: no free position for building with size %s" % size)
		return false

	b.room_size = size
	b.building_seed = rng.randi()
	b.global_position = Vector2(pos * TILE_SIZE)
	_occupied_rects.append(_footprint(pos, size))
	b.generate()
	return true


func _find_free_position(
	rng:        RandomNumberGenerator,
	size:       Vector2i,
	avoid:      Vector2i,
	avoid_dist: int,
	max_attempts: int = 64
) -> Vector2i:
	@warning_ignore("integer_division")
	var half := world_size / 2
	for attempt in max_attempts:
		var pos := _random_world_pos(rng, half)
		if avoid_dist > 0 and pos.distance_to(avoid) < avoid_dist:
			continue
		if _overlaps_any(_footprint(pos, size)):
			continue
		return pos
	return INVALID_POS


# Footprint of a building centered at `pos` with the given interior room size.
# Includes the 1-tile wall border BuildingGen draws around the room.
func _footprint(pos: Vector2i, size: Vector2i) -> Rect2i:
	@warning_ignore("integer_division")
	return Rect2i(pos - size / 2 - Vector2i.ONE, size + Vector2i(2, 2))


func _overlaps_any(rect: Rect2i) -> bool:
	for r in _occupied_rects:
		if rect.intersects(r):
			return true
	return false


func _grid_pos(b: BuildingGen) -> Vector2i:
	return Vector2i(
		roundi(b.global_position.x / TILE_SIZE.x),
		roundi(b.global_position.y / TILE_SIZE.y),
	)


func _place_extras(rng: RandomNumberGenerator) -> void:
	var scene_path: String = start_building_scene.scene_file_path
	if scene_path.is_empty():
		push_warning("WorldGen: start_building_scene has no scene_file_path; cannot spawn extras")
		return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return

	var count := rng.randi_range(3, 6)
	for i in count:
		var extra: BuildingGen = scene.instantiate() as BuildingGen
		add_child(extra)
		_extra_buildings.append(extra)
		# Extras can be as small as 2x2; floor set by user request.
		if not _place_building(extra, rng, 2, 8):
			extra.queue_free()
			_extra_buildings.pop_back()


func _clear_extras() -> void:
	for b in _extra_buildings:
		if is_instance_valid(b):
			b.queue_free()
	_extra_buildings.clear()


func _random_world_pos(rng: RandomNumberGenerator, half: Vector2i) -> Vector2i:
	return Vector2i(
		rng.randi_range(-half.x, half.x - 1),
		rng.randi_range(-half.y, half.y - 1),
	)


# ── Archetype selection ───────────────────────────────────────────────────────

# Pick a non-goal archetype for building at index i.
# Cycles through HOUSE → SHOP → APARTMENT to give variety across a street.
static func _pick_archetype(rng: RandomNumberGenerator, index: int) -> int:
	var pool := [
		BuildingArchetype.ArchetypeID.HOUSE,
		BuildingArchetype.ArchetypeID.SHOP,
		BuildingArchetype.ArchetypeID.APARTMENT,
	]
	return pool[index % pool.size()]


# ── Outdoor generation ────────────────────────────────────────────────────────

func _generate_outdoor(streams: RngStreams, buildings: Array[BuildingGen]) -> void:
	var outdoor_layer := _get_outdoor_layer()
	if outdoor_layer == null:
		return

	outdoor_layer.clear()

	if buildings.size() < 2:
		return

	# Collect entrance positions from each building (south-centre of ground floor).
	var entrances: Array[Vector2i] = []
	for b in buildings:
		entrances.append(_building_entrance(b))

	# Route a straight (axis-aligned) path between every consecutive entrance pair.
	for i in range(entrances.size() - 1):
		_route_path(outdoor_layer, entrances[i], entrances[i + 1])

	# Mark the goal building's entrance tile distinctively.
	# Uses a different atlas coord (1,0) so it can be styled separately in the TileSet.
	if goal_building != null:
		var goal_entrance := _building_entrance(goal_building)
		outdoor_layer.set_cell(goal_entrance, OUTDOOR_FLOOR_SOURCE_ID, Vector2i(1, 0))


func _building_entrance(b: BuildingGen) -> Vector2i:
	# Use the south-centre tile of the building as its street entrance.
	var total_h := b.room_size.y * b.room_rows
	var total_w := b.room_size.x * b.room_cols
	var bpos := Vector2i(int(b.global_position.x), int(b.global_position.y))
	return bpos + Vector2i(total_w / 2, total_h - 1)


func _route_path(layer: TileMapLayer, from_tile: Vector2i, to_tile: Vector2i) -> void:
	# Axis-aligned L-shaped path: go horizontal first, then vertical.
	var cur := from_tile
	while cur.x != to_tile.x:
		layer.set_cell(cur, OUTDOOR_FLOOR_SOURCE_ID, OUTDOOR_FLOOR_ATLAS)
		cur.x += 1 if to_tile.x > cur.x else -1
	while cur.y != to_tile.y:
		layer.set_cell(cur, OUTDOOR_FLOOR_SOURCE_ID, OUTDOOR_FLOOR_ATLAS)
		cur.y += 1 if to_tile.y > cur.y else -1
	layer.set_cell(cur, OUTDOOR_FLOOR_SOURCE_ID, OUTDOOR_FLOOR_ATLAS)


func _get_outdoor_layer() -> TileMapLayer:
	for child in get_children():
		if child is TileMapLayer:
			return child
	return null


# ── Seed persistence ──────────────────────────────────────────────────────────

func _save_seed() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("world", "seed", world_seed)
	cfg.save(SAVE_PATH)


func _load_seed() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	world_seed = cfg.get_value("world", "seed", world_seed)
