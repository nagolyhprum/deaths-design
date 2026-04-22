extends CharacterBody2D

const WALK_FRAMES := [0, 1, 2, 1]
const ISOMETRIC_VERTICAL_WEIGHT := 0.5

@export var move_speed := 220.0
@export var animation_fps := 8.0
@export var play_area_margin := Vector2(56.0, 92.0)

@onready var sprite: Sprite2D = $Sprite2D

var _animation_time := 0.0
var _facing_row := 0
var _scene_scale := 1.0


func _physics_process(delta: float) -> void:
	var raw_input := _read_input_vector()
	var is_moving := raw_input != Vector2.ZERO

	if is_moving:
		velocity = _movement_vector_from_input(raw_input) * move_speed * _scene_scale
		_facing_row = _facing_row_from_input(raw_input)
		_animation_time += delta * animation_fps
	else:
		velocity = Vector2.ZERO
		_animation_time = 0.0

	move_and_slide()
	_clamp_to_viewport()
	_update_sprite(is_moving)


func _read_input_vector() -> Vector2:
	var x := int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var y := int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	return Vector2(x, y)


func _movement_vector_from_input(input_vector: Vector2) -> Vector2:
	var weighted_input := Vector2(input_vector.x, input_vector.y * ISOMETRIC_VERTICAL_WEIGHT)
	return weighted_input.normalized()


func _facing_row_from_input(input_vector: Vector2) -> int:
	if input_vector.y > 0.0:
		if input_vector.x < 0.0:
			return 1
		return 0
	if input_vector.y < 0.0:
		if input_vector.x <= 0.0:
			return 2
		return 3
	if input_vector.x < 0.0:
		if _facing_row in [2, 3]:
			return 2
		return 1
	if _facing_row in [2, 3]:
		return 3
	return 0


func _clamp_to_viewport() -> void:
	var play_area := get_play_area_rect(get_viewport_rect().size)
	set_position_ratio(play_area, get_position_ratio(play_area))


func _update_sprite(is_moving: bool) -> void:
	var frame := 1
	if is_moving:
		frame = WALK_FRAMES[int(_animation_time) % WALK_FRAMES.size()]
	sprite.frame_coords = Vector2i(frame, _facing_row)


func set_scene_scale(scene_scale: float) -> void:
	_scene_scale = max(scene_scale, 0.25)
	scale = Vector2.ONE * _scene_scale


func get_play_area_margin() -> Vector2:
	return play_area_margin * _scene_scale


func get_play_area_rect(viewport_size: Vector2) -> Rect2:
	var margin := get_play_area_margin()
	return Rect2(
		margin,
		Vector2(
			max(viewport_size.x - margin.x * 2.0, 1.0),
			max(viewport_size.y - margin.y * 2.0, 1.0)
		)
	)


func get_position_ratio(play_area: Rect2) -> Vector2:
	return Vector2(
		clampf((global_position.x - play_area.position.x) / play_area.size.x, 0.0, 1.0),
		clampf((global_position.y - play_area.position.y) / play_area.size.y, 0.0, 1.0)
	)


func set_position_ratio(play_area: Rect2, ratio: Vector2) -> void:
	global_position = play_area.position + play_area.size * Vector2(
		clampf(ratio.x, 0.0, 1.0),
		clampf(ratio.y, 0.0, 1.0)
	)
