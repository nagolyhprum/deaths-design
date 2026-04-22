@tool
class_name WorldGen
extends Node2D

# Orchestrates building generation across the world. For Chunk 1 this just
# iterates any BuildingGen children in the scene, derives each one a seed
# from the single world seed, and asks them to regenerate.

@export var world_seed: int = 0

@export_tool_button("Generate") var _generate_btn := generate
@export_tool_button("Randomize Seed") var _randomize_btn := randomize_world_seed


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	generate()


func randomize_world_seed() -> void:
	world_seed = randi()
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
