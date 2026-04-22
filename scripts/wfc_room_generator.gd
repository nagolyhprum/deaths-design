class_name WfcRoomGenerator
extends RefCounted

# Pure WFC room tile generator.
#
# Phase 1: pre-constrains border cells to directional wall tiles and fills the
# interior with randomly weighted floor variants. The socket/adjacency table is
# in place for when more interior tile variety is added.
#
# Phase 2: accepts `fixed_constraints` so the caller can pin specific cells to
# door (or stair) tiles before the WFC runs. This is how rooms are stitched at
# shared walls across a multi-room floor plan.
#
# Usage:
#   var ok := WfcRoomGenerator.generate(seed, layer, Vector2i.ZERO, Vector2i(8,8))
#   var ok := WfcRoomGenerator.generate(seed, layer, origin, size, door_constraints)

const MAX_RETRIES := 5

const WALL_SOURCE_ID        := 4
const FLOOR_SOURCE_ID       := 9
const DOOR_CLOSED_ID        := 22
const DOOR_OPEN_ID          := 23
# ⚠️ MANUAL EDITOR STEP REQUIRED — create stair tiles in the TileSet with these
# source IDs before gameplay. Placeholder values; update if your TileSet uses
# different IDs. See planning/world_gen.md Phase 3 notes.
const STAIR_UP_SOURCE_ID    := 30
const STAIR_DOWN_SOURCE_ID  := 31

const FLOOR_VARIANT_COUNT := 4
const WALL_ROW := 0


# Descriptor for one tile option in the WFC catalog.
class TileDef extends RefCounted:
	var source_id: int
	var atlas: Vector2i
	var sock_n: int   # TileMeta.Socket value
	var sock_s: int
	var sock_w: int
	var sock_e: int
	var weight: float = 1.0

	func _init(src: int, atl: Vector2i, n: int, s: int, w: int, e: int, wt: float = 1.0) -> void:
		source_id = src
		atlas = atl
		sock_n = n
		sock_s = s
		sock_w = w
		sock_e = e
		weight = wt


# Pre-built catalog shared across calls.
static var _catalog: Array = []
static var _catalog_by_key: Dictionary = {}  # "src:ax:ay" -> TileDef


static func _ensure_catalog() -> void:
	if not _catalog.is_empty():
		return

	var E := TileMeta.Socket.EMPTY
	var F := TileMeta.Socket.FLOOR
	var W := TileMeta.Socket.WALL
	var D := TileMeta.Socket.DOOR

	# Walls — direction encoded as atlas x (NWES = 0123)
	_add(TileDef.new(WALL_SOURCE_ID, Vector2i(TileMeta.Direction.NORTH, 0), E, F, W, W))
	_add(TileDef.new(WALL_SOURCE_ID, Vector2i(TileMeta.Direction.WEST,  0), W, W, E, F))
	_add(TileDef.new(WALL_SOURCE_ID, Vector2i(TileMeta.Direction.EAST,  0), W, W, F, E))
	_add(TileDef.new(WALL_SOURCE_ID, Vector2i(TileMeta.Direction.SOUTH, 0), F, E, W, W))

	# Floor variants — all FLOOR sockets, weight spread so variety is visible
	for v in FLOOR_VARIANT_COUNT:
		_add(TileDef.new(FLOOR_SOURCE_ID, Vector2i(v, 0), F, F, F, F, 1.0))

	# Door (closed) — same socket pattern as walls on three sides, DOOR on the open side
	_add(TileDef.new(DOOR_CLOSED_ID, Vector2i(TileMeta.Direction.NORTH, 0), D, F, W, W))
	_add(TileDef.new(DOOR_CLOSED_ID, Vector2i(TileMeta.Direction.WEST,  0), W, W, D, F))
	_add(TileDef.new(DOOR_CLOSED_ID, Vector2i(TileMeta.Direction.EAST,  0), W, W, F, D))
	_add(TileDef.new(DOOR_CLOSED_ID, Vector2i(TileMeta.Direction.SOUTH, 0), F, D, W, W))

	# Stair tiles — walkable on all sides (placed only as fixed constraints, never
	# spontaneously by WFC). Must be in catalog so _run() can resolve the TileDef
	# when a fixed constraint references these source IDs.
	_add(TileDef.new(STAIR_UP_SOURCE_ID,   Vector2i(0, 0), F, F, F, F))
	_add(TileDef.new(STAIR_DOWN_SOURCE_ID, Vector2i(0, 0), F, F, F, F))


static func _add(t: TileDef) -> void:
	_catalog.append(t)
	_catalog_by_key["%d:%d:%d" % [t.source_id, t.atlas.x, t.atlas.y]] = t


static func get_tile_def(source_id: int, atlas: Vector2i) -> TileDef:
	_ensure_catalog()
	return _catalog_by_key.get("%d:%d:%d" % [source_id, atlas.x, atlas.y], null)


# ── Public API ────────────────────────────────────────────────────────────────

# Generate tiles for a rectangular room on `layer`.
# origin   — top-left tile coordinate (in TileMapLayer space)
# size     — room dimensions in tiles (includes wall border)
# fixed    — Dictionary[Vector2i → Dictionary{"source_id":int,"atlas":Vector2i}]
#            Pre-set tiles that override WFC (e.g. door positions from the room graph).
# Returns true on success; falls back to trivial fill and returns false on repeated
# WFC contradiction (shouldn't happen with current Phase-1 tile set).
static func generate(
	seed: int,
	layer: TileMapLayer,
	origin: Vector2i,
	size: Vector2i,
	fixed: Dictionary = {}
) -> bool:
	_ensure_catalog()

	for attempt in MAX_RETRIES:
		var attempt_seed := hash([seed, "wfc_attempt", attempt]) if attempt > 0 else seed
		if _run(attempt_seed, layer, origin, size, fixed):
			return true

	_trivial_fill(layer, origin, size, fixed)
	return false


# ── Internal helpers ──────────────────────────────────────────────────────────

static func _run(
	seed: int,
	layer: TileMapLayer,
	origin: Vector2i,
	size: Vector2i,
	fixed: Dictionary
) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var max_x := size.x - 1
	var max_y := size.y - 1

	# Build a per-cell option set. Each cell holds an Array[TileDef].
	# Border cells start constrained to the correct wall direction.
	# Interior cells start with all floor variants.
	var grid: Array = []  # grid[y][x] = Array[TileDef]
	grid.resize(size.y)
	for y in size.y:
		var row: Array = []
		row.resize(size.x)
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			if fixed.has(cell):
				# Fully constrained by caller
				var f: Dictionary = fixed[cell]
				var def := get_tile_def(f.source_id, f.atlas)
				row[x] = [def] if def != null else []
			else:
				var wall_dir := _wall_dir(x, y, max_x, max_y)
				if wall_dir != -1:
					var def := get_tile_def(WALL_SOURCE_ID, Vector2i(wall_dir, 0))
					row[x] = [def] if def != null else []
				else:
					# Interior: all floor variants are options
					var opts: Array = []
					for t in _catalog:
						if t.source_id == FLOOR_SOURCE_ID:
							opts.append(t)
					row[x] = opts
		grid[y] = row

	# Collapse all cells. Iterate in row-major order; propagation is implicit
	# because interior cells are independent (all floors are pairwise compatible).
	for y in size.y:
		for x in size.x:
			var opts: Array = grid[y][x]
			if opts.is_empty():
				return false  # contradiction
			if opts.size() == 1:
				continue  # already determined
			# Weighted random pick
			var chosen := _weighted_pick(rng, opts)
			if chosen == null:
				return false
			grid[y][x] = [chosen]

	# Write collapsed tiles to the layer
	for y in size.y:
		for x in size.x:
			var opts: Array = grid[y][x]
			if opts.is_empty():
				return false
			var t: TileDef = opts[0]
			layer.set_cell(origin + Vector2i(x, y), t.source_id, t.atlas)

	return true


static func _weighted_pick(rng: RandomNumberGenerator, opts: Array) -> TileDef:
	var total := 0.0
	for t in opts:
		total += (t as TileDef).weight
	if total <= 0.0:
		return opts[0]
	var roll := rng.randf() * total
	var acc := 0.0
	for t in opts:
		acc += (t as TileDef).weight
		if roll <= acc:
			return t
	return opts[opts.size() - 1]


static func _trivial_fill(
	layer: TileMapLayer,
	origin: Vector2i,
	size: Vector2i,
	fixed: Dictionary
) -> void:
	var max_x := size.x - 1
	var max_y := size.y - 1
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			if fixed.has(cell):
				var f: Dictionary = fixed[cell]
				layer.set_cell(cell, f.source_id, f.atlas)
				continue
			var wall_dir := _wall_dir(x, y, max_x, max_y)
			if wall_dir != -1:
				layer.set_cell(cell, WALL_SOURCE_ID, Vector2i(wall_dir, 0))
			else:
				layer.set_cell(cell, FLOOR_SOURCE_ID, Vector2i(0, 0))


static func _wall_dir(x: int, y: int, max_x: int, max_y: int) -> int:
	if y == 0:      return TileMeta.Direction.NORTH
	if y == max_y:  return TileMeta.Direction.SOUTH
	if x == 0:      return TileMeta.Direction.WEST
	if x == max_x:  return TileMeta.Direction.EAST
	return -1
