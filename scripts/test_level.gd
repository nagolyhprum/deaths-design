extends Node2D

const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const DEFAULT_PLAYER_RATIO := Vector2(0.5, 0.5)
const MIN_SCENE_SCALE := 0.25
const CONTENT_SCALE := 0.85
const TILE_HALF_WIDTH := 64.0
const TILE_HALF_HEIGHT := 32.0
const GRID_RADIUS := 5
const MAP_BOUND_RADIUS := GRID_RADIUS + 0.5
const GRID_CENTER_OFFSET := Vector2(0.0, 84.0)
const INSTRUCTIONS_POSITION := Vector2(24.0, 20.0)
const INSTRUCTIONS_SIZE := Vector2(469.0, 56.0)
const INSTRUCTIONS_FONT_SIZE := 18

@onready var player = $Player
@onready var instructions: Label = $CanvasLayer/Instructions

var _scene_scale := 1.0


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_responsive_layout(false)


func _draw() -> void:
	var viewport_rect := get_viewport_rect()
	draw_rect(viewport_rect, Color("1d2230"))

	var tile_half_width := TILE_HALF_WIDTH * _scene_scale
	var tile_half_height := TILE_HALF_HEIGHT * _scene_scale
	var center := viewport_rect.size * 0.5 + GRID_CENTER_OFFSET * _scene_scale
	for grid_y in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for grid_x in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var tile_center := center + _iso_to_screen(Vector2(grid_x, grid_y), tile_half_width, tile_half_height)
			var points := PackedVector2Array([
				tile_center + Vector2(0.0, -tile_half_height),
				tile_center + Vector2(tile_half_width, 0.0),
				tile_center + Vector2(0.0, tile_half_height),
				tile_center + Vector2(-tile_half_width, 0.0),
			])
			var base_color := Color("2d3748")
			if (grid_x + grid_y) % 2 == 0:
				base_color = Color("344155")
			draw_colored_polygon(points, base_color)
			draw_polyline(points + PackedVector2Array([points[0]]), Color("4b5d76"), max(_scene_scale * 2.0, 1.0), true)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout(true)


func _apply_responsive_layout(preserve_player_position: bool) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return

	var player_ratio := DEFAULT_PLAYER_RATIO
	if preserve_player_position:
		player_ratio = player.get_map_ratio()

	_scene_scale = max(min(viewport_size.x / BASE_VIEWPORT_SIZE.x, viewport_size.y / BASE_VIEWPORT_SIZE.y) * CONTENT_SCALE, MIN_SCENE_SCALE)
	var tile_half_size := Vector2(TILE_HALF_WIDTH, TILE_HALF_HEIGHT) * _scene_scale
	var map_center := viewport_size * 0.5 + GRID_CENTER_OFFSET * _scene_scale
	player.set_scene_scale(_scene_scale)
	player.set_map_bounds(map_center, tile_half_size, MAP_BOUND_RADIUS)
	player.set_map_ratio(player_ratio)
	_layout_instructions()
	queue_redraw()


func _layout_instructions() -> void:
	instructions.position = INSTRUCTIONS_POSITION * _scene_scale
	instructions.size = INSTRUCTIONS_SIZE * _scene_scale
	instructions.add_theme_font_size_override("font_size", maxi(int(round(INSTRUCTIONS_FONT_SIZE * _scene_scale)), 10))


func _iso_to_screen(grid_position: Vector2, tile_half_width: float, tile_half_height: float) -> Vector2:
	return Vector2(
		(grid_position.x - grid_position.y) * tile_half_width,
		(grid_position.x + grid_position.y) * tile_half_height
	)
