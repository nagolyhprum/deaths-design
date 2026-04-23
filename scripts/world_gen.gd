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

@export var world_seed: int = 0

@export_tool_button("Generate")       var _generate_btn  := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_world_seed

# Emitted when the goal (Store) building is identified during generation.
signal goal_building_changed(building: BuildingGen)

# The building the player must reach (assigned during generate()).
var goal_building: BuildingGen = null
# The building where the player starts (first BuildingGen child).
var spawn_building: BuildingGen = null


func _ready() -> void:
	# if Engine.is_editor_hint():
	# 	return
	# _load_seed()
	# generate()
	pass


func randomize_world_seed() -> void:
	world_seed = randi()
	if not Engine.is_editor_hint():
		_save_seed()
	generate()


func generate() -> void:
	var streams := RngStreams.new(world_seed)
	var arch_rng := streams.stream("archetypes")

	# Collect all BuildingGen children in scene order.
	var buildings: Array[BuildingGen] = []
	for child in get_children():
		if child is BuildingGen:
			buildings.append(child as BuildingGen)

	# Assign archetypes and seeds. First building = spawn, last = goal (STORE).
	for i in buildings.size():
		var building: BuildingGen = buildings[i]
		building.building_seed = streams.derive_seed("building", i)

		if buildings.size() == 1:
			# Single-building mode: it is both spawn and destination.
			building.archetype = BuildingArchetype.ArchetypeID.HOUSE
			building.is_goal   = false
		elif i == buildings.size() - 1:
			# Last building is always the STORE goal.
			building.archetype = BuildingArchetype.ArchetypeID.STORE
			building.is_goal   = true
		else:
			building.archetype = _pick_archetype(arch_rng, i)
			building.is_goal   = false

		building.generate()

	# Track spawn and goal references.
	spawn_building = buildings[0] if not buildings.is_empty() else null
	goal_building  = null
	for b in buildings:
		if b.is_goal:
			goal_building = b
			break
	if goal_building != null:
		goal_building_changed.emit(goal_building)

	_generate_outdoor(streams, buildings)


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
