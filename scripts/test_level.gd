extends Node2D

# Main scene coordinator. World/building rendering is handled by the WorldGen
# child (world_gen.tscn). This script manages viewport-responsive UI layout.

const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const INSTRUCTIONS_FONT_SIZE := 18

@onready var instructions: Label = $CanvasLayer/Instructions


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_layout_instructions()


func _on_viewport_size_changed() -> void:
	_layout_instructions()


func _layout_instructions() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	var scale := maxf(viewport_size.x / BASE_VIEWPORT_SIZE.x, 0.25)
	instructions.position = Vector2(24.0, 20.0) * scale
	instructions.add_theme_font_size_override(
		"font_size", maxi(int(INSTRUCTIONS_FONT_SIZE * scale), 10)
	)
