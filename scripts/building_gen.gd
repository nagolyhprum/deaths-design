@tool
class_name BuildingGen
extends Node2D

# Chunk 1 trivial generator: floor fill with a ring of walls. No WFC yet.
# Replaced in Chunk 2 with the real tile-WFC generator.

const FLOOR_SOURCE_ID := 9
const FLOOR_ROW := 0
const FLOOR_VARIANT_COUNT := 4

const WALL_SOURCE_ID := 4
const WALL_ROW := 0

@export var building_seed: int = 0
@export var room_size: Vector2i = Vector2i(8, 8)

@export_tool_button("Generate") var _generate_btn := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_building_seed


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Skip self-generation when a WorldGen parent will orchestrate us. Otherwise
	# (running this scene standalone) generate with whatever seed is set.
	if get_parent() is WorldGen:
		return
	generate()


func randomize_building_seed() -> void:
	building_seed = randi()
	generate()


func generate() -> void:
	var layer := _get_tile_map_layer()
	if layer == null:
		push_warning("BuildingGen: expected a TileMapLayer child")
		return
	layer.clear()

	var streams := RngStreams.new(building_seed)
	var floor_rng := streams.stream("floor_variants")

	var max_x := room_size.x - 1
	var max_y := room_size.y - 1
	for y in range(room_size.y):
		for x in range(room_size.x):
			var cell := Vector2i(x, y)
			var wall_dir := _wall_direction(x, y, max_x, max_y)
			if wall_dir != -1:
				layer.set_cell(cell, WALL_SOURCE_ID, Vector2i(wall_dir, WALL_ROW))
			else:
				var variant: int = floor_rng.randi() % FLOOR_VARIANT_COUNT
				layer.set_cell(cell, FLOOR_SOURCE_ID, Vector2i(variant, FLOOR_ROW))


# Returns the atlas x-coord of the wall direction at this cell, or -1 if the
# cell is interior. Direction index follows TileMeta.Direction (N=0, W=1, E=2, S=3).
func _wall_direction(x: int, y: int, max_x: int, max_y: int) -> int:
	if y == 0:
		return TileMeta.Direction.NORTH
	if y == max_y:
		return TileMeta.Direction.SOUTH
	if x == 0:
		return TileMeta.Direction.WEST
	if x == max_x:
		return TileMeta.Direction.EAST
	return -1


func _get_tile_map_layer() -> TileMapLayer:
	for child in get_children():
		if child is TileMapLayer:
			return child
	return null
