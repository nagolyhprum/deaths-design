class_name BuildingCache
extends RefCounted

# Per-seed cache of generated floor tile data.
# Prevents regeneration on player death within the same session.
# Keys are building seeds; values are Dictionary{ floor_index -> entry }.
# Each entry holds "floor" and "props" Array snapshots plus "_stair_pairs".
#
# Clear with BuildingCache.clear() on new game or world-seed change.

static var _cache: Dictionary = {}


static func has_building(seed: int) -> bool:
	return _cache.has(seed)


static func store(seed: int, floor_snapshots: Dictionary) -> void:
	_cache[seed] = floor_snapshots


static func load_building(seed: int) -> Dictionary:
	return _cache.get(seed, {})


static func clear() -> void:
	_cache.clear()


# Capture all used cells of a TileMapLayer into a plain Array.
static func snapshot_layer(layer: TileMapLayer) -> Array:
	var result: Array = []
	for cell in layer.get_used_cells():
		result.append({
			"coord":     cell,
			"source_id": layer.get_cell_source_id(cell),
			"atlas":     layer.get_cell_atlas_coords(cell),
		})
	return result


# Restore a TileMapLayer from a snapshot produced by snapshot_layer().
static func restore_layer(layer: TileMapLayer, snapshot: Array) -> void:
	layer.clear()
	for entry in snapshot:
		layer.set_cell(entry["coord"], entry["source_id"], entry["atlas"])
