@tool
class_name BuildingGen
extends Node2D

# Procedural building generator.
#
# Phase 1 (room_cols=1, room_rows=1): generates a single seeded room using
# WfcRoomGenerator then runs FurniturePass on a dedicated props layer.
#
# Phase 2 (room_cols>1 or room_rows>1): generates a multi-room floor plan via
# RoomGraph — each room gets its own WFC pass with door tiles as fixed constraints
# so adjacent rooms are stitched at their shared wall. FurniturePass runs per room
# using the room's assigned type. A flood-fill connectivity check validates the
# result.

@export var building_seed: int = 0
@export var room_size: Vector2i = Vector2i(8, 8)
@export var room_cols: int = 1
@export var room_rows: int = 1

@export_tool_button("Generate")       var _generate_btn       := generate
@export_tool_button("Randomize Seed") var _randomize_btn      := randomize_building_seed


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Skip self-generation when WorldGen parent will orchestrate us.
	if get_parent() is WorldGen:
		return
	generate()


func randomize_building_seed() -> void:
	building_seed = randi()
	generate()


func generate() -> void:
	var floor_layer := _get_floor_layer()
	if floor_layer == null:
		push_warning("BuildingGen: expected a TileMapLayer child (floor)")
		return

	var props_layer := _get_props_layer()

	floor_layer.clear()
	if props_layer != null:
		props_layer.clear()

	var streams := RngStreams.new(building_seed)

	if room_cols > 1 or room_rows > 1:
		_generate_multi_room(floor_layer, props_layer, streams)
	else:
		_generate_single_room(floor_layer, props_layer, streams)


# ── Single-room (Phase 1) ─────────────────────────────────────────────────────

func _generate_single_room(
	floor_layer: TileMapLayer,
	props_layer: TileMapLayer,
	streams: RngStreams
) -> void:
	WfcRoomGenerator.generate(
		streams.derive_seed("wfc"),
		floor_layer,
		Vector2i.ZERO,
		room_size
	)

	if props_layer != null:
		FurniturePass.generate(
			streams.derive_seed("furniture"),
			floor_layer,
			props_layer,
			Vector2i.ZERO,
			room_size,
			TileMeta.RoomType.GENERIC
		)


# ── Multi-room (Phase 2) ──────────────────────────────────────────────────────

func _generate_multi_room(
	floor_layer: TileMapLayer,
	props_layer: TileMapLayer,
	streams: RngStreams
) -> void:
	var layout := RoomGraph.generate(
		streams.derive_seed("layout"),
		room_size,
		room_cols,
		room_rows
	)

	var wfc_base    := streams.derive_seed("wfc")
	var furn_base   := streams.derive_seed("furniture")

	for i in layout.rooms.size():
		var room: RoomGraph.RoomData = layout.rooms[i]
		var constraints := layout.door_constraints_for(i)

		WfcRoomGenerator.generate(
			hash([wfc_base, i]),
			floor_layer,
			room.origin,
			room.size,
			constraints
		)

		if props_layer != null:
			FurniturePass.generate(
				hash([furn_base, i]),
				floor_layer,
				props_layer,
				room.origin,
				room.size,
				room.type
			)

	if not _validate_connectivity(floor_layer, layout):
		push_warning("BuildingGen: connectivity check failed for seed %d" % building_seed)


func _validate_connectivity(floor_layer: TileMapLayer, layout: RoomGraph) -> bool:
	# Flood-fill from the first room's interior; all walkable cells should be reachable.
	if layout.rooms.is_empty():
		return true

	var first_room: RoomGraph.RoomData = layout.rooms[0]
	var spawn := first_room.origin + Vector2i(1, 1)
	if first_room.size.x <= 2 or first_room.size.y <= 2:
		return true

	var bounds := layout.footprint()
	var visited: Array[Vector2i] = []
	var queue: Array[Vector2i] = [spawn]
	var walkable_total := 0

	# Count all walkable cells
	for room in layout.rooms:
		var r: RoomGraph.RoomData = room
		for y in r.size.y:
			for x in r.size.x:
				var cell := r.origin + Vector2i(x, y)
				var src := floor_layer.get_cell_source_id(cell)
				if src != -1 and src != WfcRoomGenerator.WALL_SOURCE_ID:
					walkable_total += 1

	# Flood-fill
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell in visited:
			continue
		if not bounds.has_point(cell):
			continue
		var src := floor_layer.get_cell_source_id(cell)
		if src == -1 or src == WfcRoomGenerator.WALL_SOURCE_ID:
			continue
		visited.append(cell)
		queue.append(cell + Vector2i(1, 0))
		queue.append(cell + Vector2i(-1, 0))
		queue.append(cell + Vector2i(0, 1))
		queue.append(cell + Vector2i(0, -1))

	return visited.size() >= walkable_total


# ── Node helpers ──────────────────────────────────────────────────────────────

func _get_floor_layer() -> TileMapLayer:
	for child in get_children():
		if child is TileMapLayer and child.name == "TileMapLayer":
			return child
	# Fallback: first TileMapLayer child
	for child in get_children():
		if child is TileMapLayer:
			return child
	return null


func _get_props_layer() -> TileMapLayer:
	for child in get_children():
		if child is TileMapLayer and child.name == "PropsLayer":
			return child
	return null
