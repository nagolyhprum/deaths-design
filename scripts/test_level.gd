extends Node2D

const TILE_HALF_WIDTH := 64.0
const TILE_HALF_HEIGHT := 32.0
const GRID_RADIUS := 5

@onready var player: Node2D = $Player


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	player.position = get_viewport_rect().size * 0.5 + Vector2(0.0, 32.0)
	queue_redraw()


func _draw() -> void:
	var viewport_rect := get_viewport_rect()
	draw_rect(viewport_rect, Color("1d2230"))

	var center := viewport_rect.size * 0.5 + Vector2(0.0, 84.0)
	for grid_y in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for grid_x in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var tile_center := center + _iso_to_screen(Vector2(grid_x, grid_y))
			var points := PackedVector2Array([
				tile_center + Vector2(0.0, -TILE_HALF_HEIGHT),
				tile_center + Vector2(TILE_HALF_WIDTH, 0.0),
				tile_center + Vector2(0.0, TILE_HALF_HEIGHT),
				tile_center + Vector2(-TILE_HALF_WIDTH, 0.0),
			])
			var base_color := Color("2d3748")
			if (grid_x + grid_y) % 2 == 0:
				base_color = Color("344155")
			draw_colored_polygon(points, base_color)
			draw_polyline(points + PackedVector2Array([points[0]]), Color("4b5d76"), 2.0, true)


func _iso_to_screen(grid_position: Vector2) -> Vector2:
	return Vector2(
		(grid_position.x - grid_position.y) * TILE_HALF_WIDTH,
		(grid_position.x + grid_position.y) * TILE_HALF_HEIGHT
	)
