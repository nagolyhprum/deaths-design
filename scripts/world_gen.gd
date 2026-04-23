@tool
class_name WorldGen
extends Node2D

# Top-level world orchestrator. generate() runs a single fixed 6-step pass
# that lays out two scene-authored BuildingGen children (start + goal), drops
# a handful of extra BuildingGen instances for decoration, positions the
# player, and paints the ground and perimeter fence onto world_layer:
#
#   Step 1 — place the start building at a random world-grid position.
#   Step 2 — place the goal building, keeping it at least half the shorter
#            world dimension away from the start.
#   Step 3 — spawn 3–6 extra random buildings that don't overlap.
#   Step 4 — drop the player at the start building's position.
#   Step 5 — paint the world interior with dirt / dirt-farmland tiles.
#   Step 6 — ring the world perimeter with fence tiles.
#
# Seed persistence: on non-editor runs, world_seed is loaded from user:// on
# startup and saved whenever it changes.

const SAVE_PATH := "user://worldgen.cfg"

# Source IDs for the ground tiles painted onto world_layer in step 5.
# Adjust to match the authored tileset.
const DIRT_SOURCE_ID          := 9
const DIRT_FARMLAND_SOURCE_ID := 8
# Fence tiles painted around the world perimeter in step 6.
const FENCE_SOURCE_ID    := [26, 27, 28, 29]

@export var world_seed: int = 0

# Both expected to be building_gen.tscn (or a variant).
@export_group("Generation Params")
@export var world_size:     Vector2i = Vector2i(8, 8)
@export_group("Player & Goal")
@export var player:               Player
@export var start_building_scene: BuildingGen
@export var goal_building_scene:  BuildingGen
@export var world_layer: TileMapLayer


@export_group("Debug")
@export_tool_button("Generate")       var _generate_btn  := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_world_seed

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
	if world_layer == null:
		push_warning("WorldGen: world_layer is not assigned")
		return

	_clear_extras()
	_occupied_rects.clear()

	start_building_scene.is_goal = false
	goal_building_scene.is_goal = true

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
	# Step 4: drop the player at the centre of the start building.
	if player != null:
		player.global_position = start_building_scene.global_position
	# Step 5: paint the ground with dirt / dirt-farmland tiles.
	_fill_world(streams.stream("world"))
	# Step 6: ring the world with fence tiles.
	_fill_perimeter_fence(streams.stream("fence"))


func _fill_world(rng: RandomNumberGenerator) -> void:
	if world_layer == null:
		push_warning("WorldGen: world_layer is not assigned")
		return
	world_layer.clear()

	@warning_ignore("integer_division")
	var half := world_size / 2
	for y in range(-half.y+1, world_size.y - half.y - 1):
		for x in range(-half.x+1, world_size.x - half.x - 1):
			var source := DIRT_SOURCE_ID if rng.randi_range(0, 1) == 0 else DIRT_FARMLAND_SOURCE_ID
			world_layer.set_cell(Vector2i(x, y), source, Vector2i(0, 0))


func _fill_perimeter_fence(rng: RandomNumberGenerator) -> void:
	@warning_ignore("integer_division")
	var half := world_size / 2
	var min_x := -half.x
	var min_y := -half.y
	var max_x := world_size.x - half.x - 1  # inclusive
	var max_y := world_size.y - half.y - 1  # inclusive
	const FENCE_NORTH_ATLAS  := Vector2i(1, 0)
	const FENCE_EAST_ATLAS   := Vector2i(0, 0)
	const FENCE_SOUTH_ATLAS  := Vector2i(2, 0)
	const FENCE_WEST_ATLAS   := Vector2i(3, 0)

	# Top and bottom rows (include corners, which end up horizontal).
	for x in range(min_x +1, max_x):
		world_layer.set_cell(Vector2i(x, min_y), _random_fence_id(rng), FENCE_NORTH_ATLAS)
		world_layer.set_cell(Vector2i(x, max_y), _random_fence_id(rng), FENCE_SOUTH_ATLAS)
	# Left and right columns (skip corners, already set above).
	for y in range(min_y + 1, max_y):
		world_layer.set_cell(Vector2i(min_x, y), _random_fence_id(rng), FENCE_WEST_ATLAS)
		world_layer.set_cell(Vector2i(max_x, y), _random_fence_id(rng), FENCE_EAST_ATLAS)


func _random_fence_id(rng: RandomNumberGenerator) -> int:
	return FENCE_SOURCE_ID[rng.randi_range(0, FENCE_SOURCE_ID.size() - 1)]


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
	b.global_position = world_layer.to_global(world_layer.map_to_local(pos))
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
	var world_rect := Rect2i(-half, world_size)
	for attempt in max_attempts:
		var pos := _random_world_pos(rng, half)
		if avoid_dist > 0 and pos.distance_to(avoid) < avoid_dist:
			continue
		var fp := _footprint(pos, size)
		if not world_rect.encloses(fp):
			continue
		if _overlaps_any(fp):
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
	return world_layer.local_to_map(world_layer.to_local(b.global_position))


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
		extra.is_goal = false
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
