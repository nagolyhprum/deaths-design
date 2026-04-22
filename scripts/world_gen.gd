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
# Seed persistence: on non-editor runs, world_seed is loaded from user:// on
# startup and saved whenever it changes.

const SAVE_PATH := "user://worldgen.cfg"

const OUTDOOR_FLOOR_SOURCE_ID := 0   # fallback; update when outdoor_tiles is authored
const OUTDOOR_FLOOR_ATLAS     := Vector2i(0, 0)

@export var world_seed: int = 0

@export_tool_button("Generate")       var _generate_btn  := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_world_seed


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
	var streams := RngStreams.new(world_seed)
	var index := 0

	for child in get_children():
		if child is BuildingGen:
			var building: BuildingGen = child
			building.building_seed = streams.derive_seed("building", index)
			building.generate()
			index += 1

	_generate_outdoor(streams)


# ── Outdoor generation (Phase 2 placeholder) ─────────────────────────────────

func _generate_outdoor(streams: RngStreams) -> void:
	var outdoor_layer := _get_outdoor_layer()
	if outdoor_layer == null:
		return

	outdoor_layer.clear()

	# Collect entrance positions from each BuildingGen child
	var entrances: Array[Vector2i] = []
	for child in get_children():
		if child is BuildingGen:
			var b: BuildingGen = child
			entrances.append(_building_entrance(b))

	# Route a straight outdoor path between consecutive building entrances
	if entrances.size() < 2:
		return

	for i in range(entrances.size() - 1):
		_route_path(outdoor_layer, entrances[i], entrances[i + 1])


func _building_entrance(b: BuildingGen) -> Vector2i:
	# Use the south-centre tile of the building as its street entrance.
	var total_h := b.room_size.y * b.room_rows
	var total_w := b.room_size.x * b.room_cols
	var bpos := Vector2i(int(b.global_position.x), int(b.global_position.y))
	return bpos + Vector2i(total_w / 2, total_h - 1)


func _route_path(layer: TileMapLayer, from_tile: Vector2i, to_tile: Vector2i) -> void:
	# Bresenham-style straight path (axis-aligned segments) between two tiles.
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
