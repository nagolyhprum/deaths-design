extends CharacterBody2D

const WALK_FRAMES := [0, 1, 2, 1]

@export var move_speed := 220.0
@export var animation_fps := 8.0
@export var play_area_margin := Vector2(56.0, 92.0)

@onready var sprite: Sprite2D = $Sprite2D

var _animation_time := 0.0
var _facing_row := 0


func _physics_process(delta: float) -> void:
	var raw_input := _read_input_vector()
	var is_moving := raw_input != Vector2.ZERO

	if is_moving:
		velocity = _to_isometric_motion(raw_input) * move_speed
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


func _to_isometric_motion(input_vector: Vector2) -> Vector2:
	var mapped := Vector2(
		input_vector.x + input_vector.y,
		(input_vector.y - input_vector.x) * 0.5
	)
	return mapped.normalized()


func _facing_row_from_input(input_vector: Vector2) -> int:
	if input_vector.y > 0.0 and input_vector.x >= 0.0:
		return 0
	if input_vector.x < 0.0 and input_vector.y >= 0.0:
		return 1
	if input_vector.y < 0.0 and input_vector.x <= 0.0:
		return 2
	return 3


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	global_position = global_position.clamp(play_area_margin, viewport_size - play_area_margin)


func _update_sprite(is_moving: bool) -> void:
	var frame := 1
	if is_moving:
		frame = WALK_FRAMES[int(_animation_time) % WALK_FRAMES.size()]
	sprite.frame_coords = Vector2i(frame, _facing_row)

