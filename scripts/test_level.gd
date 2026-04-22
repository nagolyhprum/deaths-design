extends Node2D

const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const DEFAULT_PLAYER_RATIO := Vector2(0.5, 0.5)
const MIN_SCENE_SCALE := 0.25
const CONTENT_SCALE := 0.85
const TILE_HALF_WIDTH := 64.0
const TILE_HALF_HEIGHT := 32.0
const INTERIOR_TILE_TEXTURE := preload("res://assets/tiles/interiors/room_structure_tilesheet.png")
const INTERIOR_TILE_SIZE := Vector2i(128, 160)
const INTERIOR_TILE_ANCHOR := Vector2(64.0, 122.0)
const GRID_RADIUS := 5
const MAP_BOUND_RADIUS := GRID_RADIUS + 0.5
const GRID_CENTER_OFFSET := Vector2(0.0, 84.0)
const INSTRUCTIONS_POSITION := Vector2(24.0, 20.0)
const INSTRUCTIONS_SIZE := Vector2(469.0, 56.0)
const INSTRUCTIONS_FONT_SIZE := 18
const ROOM_LAYOUT := [
	{"atlas": Vector2i(1, 0), "grid": Vector2(-4, -4), "collision": "wall"},
	{"atlas": Vector2i(0, 0), "grid": Vector2(-3, -4), "collision": "wall"},
	{"atlas": Vector2i(3, 0), "grid": Vector2(-2, -4), "collision": "wall"},
	{"atlas": Vector2i(0, 2), "grid": Vector2(-1, -4), "collision": "wall"},
	{"atlas": Vector2i(3, 1), "grid": Vector2(0, -4), "collision": "wall"},
	{"atlas": Vector2i(1, 1), "grid": Vector2(1, -4), "collision": "wall"},
	{"atlas": Vector2i(2, 1), "grid": Vector2(2, -4), "collision": "wall"},
	{"atlas": Vector2i(1, 1), "grid": Vector2(3, -4), "collision": "wall"},
	{"atlas": Vector2i(1, 3), "grid": Vector2(-4, -2), "collision": "counter"},
	{"atlas": Vector2i(1, 2), "grid": Vector2(-3, -2), "collision": "counter"},
	{"atlas": Vector2i(1, 2), "grid": Vector2(-2, -2), "collision": "counter"},
	{"atlas": Vector2i(3, 3), "grid": Vector2(2, -2), "collision": ""},
	{"atlas": Vector2i(3, 3), "grid": Vector2(1, -1), "collision": ""},
	{"atlas": Vector2i(0, 3), "grid": Vector2(-4, 0), "collision": "plant"},
	{"atlas": Vector2i(3, 3), "grid": Vector2(-1, 0), "collision": ""},
	{"atlas": Vector2i(2, 2), "grid": Vector2(0, 1), "collision": ""},
	{"atlas": Vector2i(3, 2), "grid": Vector2(0, 1), "collision": "table"},
	{"atlas": Vector2i(3, 3), "grid": Vector2(2, 2), "collision": ""},
	{"atlas": Vector2i(2, 3), "grid": Vector2(2, 2), "collision": "small_table"},
	{"atlas": Vector2i(0, 3), "grid": Vector2(3, 1), "collision": "plant"},
]

@onready var player = $Player
@onready var room_decor: Node2D = $RoomDecor
@onready var room_collision: Node2D = $RoomCollision
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
	_rebuild_room_layout(map_center, tile_half_size)
	player.set_scene_scale(_scene_scale)
	player.set_map_bounds(map_center, tile_half_size, MAP_BOUND_RADIUS)
	player.set_map_ratio(player_ratio)
	_layout_instructions()
	queue_redraw()


func _layout_instructions() -> void:
	instructions.position = INSTRUCTIONS_POSITION * _scene_scale
	instructions.size = INSTRUCTIONS_SIZE * _scene_scale
	instructions.add_theme_font_size_override("font_size", maxi(int(round(INSTRUCTIONS_FONT_SIZE * _scene_scale)), 10))


func _rebuild_room_layout(map_center: Vector2, tile_half_size: Vector2) -> void:
	for child in room_decor.get_children():
		child.free()
	for child in room_collision.get_children():
		child.free()

	for item in ROOM_LAYOUT:
		var tile_center := map_center + _iso_to_screen(item["grid"], tile_half_size.x, tile_half_size.y)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = _build_atlas_texture(item["atlas"])
		sprite.position = tile_center - INTERIOR_TILE_ANCHOR * _scene_scale
		sprite.scale = Vector2.ONE * _scene_scale
		room_decor.add_child(sprite)

		if item["collision"] != "" and item["collision"] != "wall":
			room_collision.add_child(_build_collision_body(tile_center, tile_half_size))


func _build_atlas_texture(atlas_coords: Vector2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = INTERIOR_TILE_TEXTURE
	atlas.region = Rect2(
		Vector2(atlas_coords.x * INTERIOR_TILE_SIZE.x, atlas_coords.y * INTERIOR_TILE_SIZE.y),
		Vector2(INTERIOR_TILE_SIZE.x, INTERIOR_TILE_SIZE.y)
	)
	return atlas


func _build_collision_body(tile_center: Vector2, tile_half_size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape_node := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	body.position = tile_center
	body.add_child(shape_node)
	shape.points = PackedVector2Array([
		Vector2(0.0, -tile_half_size.y),
		Vector2(tile_half_size.x, 0.0),
		Vector2(0.0, tile_half_size.y),
		Vector2(-tile_half_size.x, 0.0),
	])
	shape_node.shape = shape

	return body


func _iso_to_screen(grid_position: Vector2, tile_half_width: float, tile_half_height: float) -> Vector2:
	return Vector2(
		(grid_position.x - grid_position.y) * tile_half_width,
		(grid_position.x + grid_position.y) * tile_half_height
	)
