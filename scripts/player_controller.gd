class_name Player
extends CharacterBody2D

const WALK_FRAMES := [0, 1, 2, 1]
const ISOMETRIC_VERTICAL_WEIGHT := 0.5
const MOVE_ACTION_LEFT := "move_left"
const MOVE_ACTION_RIGHT := "move_right"
const MOVE_ACTION_UP := "move_up"
const MOVE_ACTION_DOWN := "move_down"
const MOVE_INPUT_DEADZONE := 0.2

@export var move_speed := 220.0
@export var animation_fps := 8.0

@onready var sprite: Sprite2D = $Sprite2D

var _animation_time := 0.0
var _facing_row := 0
var _scene_scale := 1.0
var _map_center := Vector2.ZERO
var _map_half_tile_size := Vector2.ONE
var _map_radius := 0.0
var _has_map_bounds := false


func _physics_process(delta: float) -> void:
	var raw_input := _read_input_vector()
	var is_moving := raw_input != Vector2.ZERO
	var previous_position := global_position

	if is_moving:
		velocity = _movement_vector_from_input(raw_input) * move_speed * _scene_scale
		_facing_row = _facing_row_from_input(raw_input)
		_animation_time += delta * animation_fps
	else:
		velocity = Vector2.ZERO
		_animation_time = 0.0

	move_and_slide()
	_update_sprite(is_moving)


func _read_input_vector() -> Vector2:
	return Input.get_vector(
		MOVE_ACTION_LEFT,
		MOVE_ACTION_RIGHT,
		MOVE_ACTION_UP,
		MOVE_ACTION_DOWN,
		MOVE_INPUT_DEADZONE
	)


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

func _update_sprite(is_moving: bool) -> void:
	var frame := 1
	if is_moving:
		frame = WALK_FRAMES[int(_animation_time) % WALK_FRAMES.size()]
	sprite.frame_coords = Vector2i(frame, _facing_row)


func set_scene_scale(scene_scale: float) -> void:
	_scene_scale = max(scene_scale, 0.25)
	scale = Vector2.ONE * _scene_scale


func set_map_bounds(map_center: Vector2, map_half_tile_size: Vector2, map_radius: float) -> void:
	_map_center = map_center
	_map_half_tile_size = Vector2(
		max(map_half_tile_size.x, 1.0),
		max(map_half_tile_size.y, 1.0)
	)
	_map_radius = max(map_radius, 0.0)
	_has_map_bounds = true


func get_map_ratio() -> Vector2:
	if not _has_map_bounds or _map_radius <= 0.0:
		return Vector2(0.5, 0.5)

	var grid_position := _screen_to_grid(global_position - _map_center)
	return Vector2(
		clampf((grid_position.x + _map_radius) / (_map_radius * 2.0), 0.0, 1.0),
		clampf((grid_position.y + _map_radius) / (_map_radius * 2.0), 0.0, 1.0)
	)


func set_map_ratio(ratio: Vector2) -> void:
	if not _has_map_bounds:
		return

	var clamped_ratio := Vector2(
		clampf(ratio.x, 0.0, 1.0),
		clampf(ratio.y, 0.0, 1.0)
	)
	var grid_position := Vector2(
		lerpf(-_map_radius, _map_radius, clamped_ratio.x),
		lerpf(-_map_radius, _map_radius, clamped_ratio.y)
	)
	global_position = _map_center + _grid_to_screen(grid_position)


func _grid_to_screen(grid_position: Vector2) -> Vector2:
	return Vector2(
		(grid_position.x - grid_position.y) * _map_half_tile_size.x,
		(grid_position.x + grid_position.y) * _map_half_tile_size.y
	)


func _screen_to_grid(screen_position: Vector2) -> Vector2:
	return Vector2(
		(screen_position.x / _map_half_tile_size.x + screen_position.y / _map_half_tile_size.y) * 0.5,
		(screen_position.y / _map_half_tile_size.y - screen_position.x / _map_half_tile_size.x) * 0.5
	)


func _is_inside_map_bounds(local_position: Vector2) -> bool:
	var extents := _get_map_screen_extents()
	var distance := absf(local_position.x) / extents.x + absf(local_position.y) / extents.y
	return distance <= 1.0


func _find_boundary_intersection(start_local: Vector2, end_local: Vector2) -> Vector2:
	var low := 0.0
	var high := 1.0
	for _step in 20:
		var mid := (low + high) * 0.5
		var point := start_local.lerp(end_local, mid)
		if _is_inside_map_bounds(point):
			low = mid
		else:
			high = mid
	return start_local.lerp(end_local, low)


func _resolve_edge_slide(start_local: Vector2, end_local: Vector2) -> Vector2:
	var contact_point := _find_boundary_intersection(start_local, end_local)
	var attempted_motion := end_local - start_local
	var remaining_distance := maxf(attempted_motion.length() - start_local.distance_to(contact_point), 0.0)
	if remaining_distance <= 0.001:
		return contact_point

	var slide_direction := _get_slide_direction(contact_point, attempted_motion)
	if slide_direction == Vector2.ZERO:
		return contact_point

	var slide_target := contact_point + slide_direction * remaining_distance
	if _is_inside_map_bounds(slide_target):
		return slide_target
	return _find_boundary_intersection(contact_point, slide_target)


func _clamp_local_position_to_bounds(local_position: Vector2) -> Vector2:
	var extents := _get_map_screen_extents()
	var distance := absf(local_position.x) / extents.x + absf(local_position.y) / extents.y
	if distance <= 1.0:
		return local_position
	return local_position / distance


func _get_map_screen_extents() -> Vector2:
	return Vector2(
		max(_map_half_tile_size.x * _map_radius * 2.0, 1.0),
		max(_map_half_tile_size.y * _map_radius * 2.0, 1.0)
	)


func _get_slide_direction(contact_point: Vector2, attempted_motion: Vector2) -> Vector2:
	var candidates := _get_edge_tangent_candidates(contact_point)
	var best_direction := Vector2.ZERO
	var best_alignment := 0.0

	for candidate in candidates:
		var alignment := attempted_motion.dot(candidate)
		if absf(alignment) <= best_alignment:
			continue
		best_alignment = absf(alignment)
		best_direction = candidate if alignment >= 0.0 else -candidate

	return best_direction


func _get_edge_tangent_candidates(contact_point: Vector2) -> Array[Vector2]:
	var extents := _get_map_screen_extents()
	var epsilon := 0.001
	var x_signs: Array[float] = []
	var y_signs: Array[float] = []

	if absf(contact_point.x) <= epsilon:
		x_signs = [-1.0, 1.0]
	else:
		x_signs = [signf(contact_point.x)]

	if absf(contact_point.y) <= epsilon:
		y_signs = [-1.0, 1.0]
	else:
		y_signs = [signf(contact_point.y)]

	var tangents: Array[Vector2] = []
	for x_sign in x_signs:
		for y_sign in y_signs:
			var tangent := Vector2(y_sign * extents.x, -x_sign * extents.y).normalized()
			var is_unique := true
			for existing in tangents:
				if existing.is_equal_approx(tangent) or existing.is_equal_approx(-tangent):
					is_unique = false
					break
			if is_unique:
				tangents.append(tangent)

	return tangents
