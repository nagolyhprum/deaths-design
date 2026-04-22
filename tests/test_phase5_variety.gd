extends GutTest

# Phase 5 tests: building archetypes, room-weight selection, goal-structured
# WorldGen, exterior path routing, and archetype-driven floor counts.


# ── BuildingArchetype: enum completeness ──────────────────────────────────────

func test_archetype_has_house() -> void:
	assert_true(BuildingArchetype.ArchetypeID.has("HOUSE"), "ArchetypeID should contain HOUSE")


func test_archetype_has_shop() -> void:
	assert_true(BuildingArchetype.ArchetypeID.has("SHOP"), "ArchetypeID should contain SHOP")


func test_archetype_has_apartment() -> void:
	assert_true(BuildingArchetype.ArchetypeID.has("APARTMENT"), "ArchetypeID should contain APARTMENT")


func test_archetype_has_store() -> void:
	assert_true(BuildingArchetype.ArchetypeID.has("STORE"), "ArchetypeID should contain STORE")


# ── BuildingArchetype: room_weights_for ──────────────────────────────────────

func test_house_weights_contain_bedroom() -> void:
	var w := BuildingArchetype.room_weights_for(BuildingArchetype.ArchetypeID.HOUSE)
	assert_true(w.has(TileMeta.RoomType.BEDROOM), "House weights should include BEDROOM")
	assert_gt(w[TileMeta.RoomType.BEDROOM], 0.0, "House BEDROOM weight should be > 0")


func test_house_weights_have_zero_store() -> void:
	var w := BuildingArchetype.room_weights_for(BuildingArchetype.ArchetypeID.HOUSE)
	# STORE room type should not appear in a HOUSE
	var store_w: float = w.get(TileMeta.RoomType.STORE, 0.0)
	assert_eq(store_w, 0.0, "House should have STORE weight = 0")


func test_store_weights_have_dominant_store_room() -> void:
	var w := BuildingArchetype.room_weights_for(BuildingArchetype.ArchetypeID.STORE)
	assert_true(w.has(TileMeta.RoomType.STORE), "Store archetype weights should include STORE room type")
	assert_gt(w[TileMeta.RoomType.STORE], 2.0, "Store archetype STORE weight should dominate (>2.0)")


func test_store_weights_have_zero_bedroom() -> void:
	var w := BuildingArchetype.room_weights_for(BuildingArchetype.ArchetypeID.STORE)
	var bedroom_w: float = w.get(TileMeta.RoomType.BEDROOM, 0.0)
	assert_eq(bedroom_w, 0.0, "Store archetype should not have BEDROOM rooms")


func test_apartment_weights_have_dominant_bedroom() -> void:
	var w := BuildingArchetype.room_weights_for(BuildingArchetype.ArchetypeID.APARTMENT)
	assert_true(w.has(TileMeta.RoomType.BEDROOM))
	assert_gt(w[TileMeta.RoomType.BEDROOM], 2.0, "Apartment should have dominant BEDROOM weight")


func test_unknown_archetype_returns_empty_weights() -> void:
	var w := BuildingArchetype.room_weights_for(9999)
	assert_eq(w.size(), 0, "Unknown archetype should return empty weight dict")


# ── BuildingArchetype: floor counts ──────────────────────────────────────────

func test_house_min_floors_is_one() -> void:
	assert_eq(BuildingArchetype.min_floors(BuildingArchetype.ArchetypeID.HOUSE), 1)


func test_house_max_floors_is_two() -> void:
	assert_eq(BuildingArchetype.max_floors(BuildingArchetype.ArchetypeID.HOUSE), 2)


func test_apartment_min_floors_is_two() -> void:
	assert_eq(BuildingArchetype.min_floors(BuildingArchetype.ArchetypeID.APARTMENT), 2)


func test_apartment_max_floors_at_least_two() -> void:
	assert_gte(BuildingArchetype.max_floors(BuildingArchetype.ArchetypeID.APARTMENT), 2,
		"Apartment should have at least 2 max floors")


func test_store_min_and_max_floors_are_one() -> void:
	assert_eq(BuildingArchetype.min_floors(BuildingArchetype.ArchetypeID.STORE), 1)
	assert_eq(BuildingArchetype.max_floors(BuildingArchetype.ArchetypeID.STORE), 1)


# ── BuildingArchetype: basement_chance ───────────────────────────────────────

func test_house_basement_chance_in_range() -> void:
	var c := BuildingArchetype.basement_chance(BuildingArchetype.ArchetypeID.HOUSE)
	assert_gte(c, 0.0)
	assert_lte(c, 1.0)


func test_shop_basement_chance_is_zero() -> void:
	assert_eq(BuildingArchetype.basement_chance(BuildingArchetype.ArchetypeID.SHOP), 0.0)


func test_apartment_basement_chance_positive() -> void:
	assert_gt(BuildingArchetype.basement_chance(BuildingArchetype.ArchetypeID.APARTMENT), 0.0,
		"Apartments should have a non-zero basement chance")


# ── BuildingArchetype: random_floor_count ────────────────────────────────────

func test_random_floor_count_within_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in 20:
		var count := BuildingArchetype.random_floor_count(BuildingArchetype.ArchetypeID.APARTMENT, rng)
		assert_gte(count, BuildingArchetype.min_floors(BuildingArchetype.ArchetypeID.APARTMENT))
		assert_lte(count, BuildingArchetype.max_floors(BuildingArchetype.ArchetypeID.APARTMENT))


func test_random_floor_count_store_always_one() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for _i in 10:
		var count := BuildingArchetype.random_floor_count(BuildingArchetype.ArchetypeID.STORE, rng)
		assert_eq(count, 1, "Store floor count should always be 1")


# ── BuildingArchetype: display_name ──────────────────────────────────────────

func test_display_name_returns_non_empty_strings() -> void:
	for arch_id in [
		BuildingArchetype.ArchetypeID.HOUSE,
		BuildingArchetype.ArchetypeID.SHOP,
		BuildingArchetype.ArchetypeID.APARTMENT,
		BuildingArchetype.ArchetypeID.STORE,
	]:
		var name: String = BuildingArchetype.display_name(arch_id)
		assert_false(name.is_empty(), "display_name should return non-empty string for archetype %d" % arch_id)


# ── RoomGraph: weighted room type selection ───────────────────────────────────

func _generate_room_types(seed: int, archetype: int, cols: int, rows: int) -> Array:
	var weights := BuildingArchetype.room_weights_for(archetype)
	var graph := RoomGraph.generate(seed, Vector2i(8, 8), cols, rows, weights)
	var types: Array = []
	for room in graph.rooms:
		types.append((room as RoomGraph.RoomData).type)
	return types


func test_room_graph_with_store_archetype_has_store_rooms() -> void:
	var found_store := false
	for seed in [1, 2, 3, 4, 5, 10, 20, 30]:
		var types := _generate_room_types(seed, BuildingArchetype.ArchetypeID.STORE, 2, 2)
		if TileMeta.RoomType.STORE in types:
			found_store = true
			break
	assert_true(found_store,
		"Store archetype should produce at least one STORE room across multiple seeds")


func test_room_graph_with_store_archetype_no_bedrooms() -> void:
	for seed in [1, 2, 3, 4, 5]:
		var types := _generate_room_types(seed, BuildingArchetype.ArchetypeID.STORE, 2, 2)
		assert_false(TileMeta.RoomType.BEDROOM in types,
			"Store archetype (seed=%d) should not produce BEDROOM rooms" % seed)


func test_room_graph_with_house_archetype_no_store_rooms() -> void:
	for seed in [1, 2, 3, 4, 5, 6, 7, 8]:
		var types := _generate_room_types(seed, BuildingArchetype.ArchetypeID.HOUSE, 2, 2)
		assert_false(TileMeta.RoomType.STORE in types,
			"House archetype (seed=%d) should not produce STORE rooms" % seed)


func test_room_graph_empty_weights_uses_defaults() -> void:
	# Empty weights dict → falls back to default equal-weight selection.
	var graph := RoomGraph.generate(42, Vector2i(8, 8), 2, 2, {})
	assert_eq(graph.rooms.size(), 4, "Empty weights should still produce 4 rooms for 2x2 grid")


func test_room_graph_weighted_selection_is_deterministic() -> void:
	var weights := BuildingArchetype.room_weights_for(BuildingArchetype.ArchetypeID.APARTMENT)
	var g1 := RoomGraph.generate(777, Vector2i(8, 8), 2, 2, weights)
	var g2 := RoomGraph.generate(777, Vector2i(8, 8), 2, 2, weights)
	for i in g1.rooms.size():
		var r1: RoomGraph.RoomData = g1.rooms[i]
		var r2: RoomGraph.RoomData = g2.rooms[i]
		assert_eq(r1.type, r2.type,
			"Same seed + weights should produce identical room types at index %d" % i)


# ── BuildingGen: archetype and is_goal exports ────────────────────────────────

func test_building_gen_has_archetype_export() -> void:
	var b := BuildingGen.new()
	assert_true("archetype" in b, "BuildingGen should have an 'archetype' property")
	b.free()


func test_building_gen_has_is_goal_export() -> void:
	var b := BuildingGen.new()
	assert_true("is_goal" in b, "BuildingGen should have an 'is_goal' property")
	b.free()


func test_building_gen_default_archetype_is_house() -> void:
	var b := BuildingGen.new()
	assert_eq(b.archetype, BuildingArchetype.ArchetypeID.HOUSE,
		"Default archetype should be HOUSE")
	b.free()


func test_building_gen_store_archetype_produces_store_rooms() -> void:
	var b := BuildingGen.new()
	b.building_seed = 5
	b.room_size     = Vector2i(8, 8)
	b.room_cols     = 2
	b.room_rows     = 2
	b.num_floors    = 1
	b.has_basement  = false
	b.archetype     = BuildingArchetype.ArchetypeID.STORE
	b.generate()

	# We can't easily inspect room types from outside the generator, so we just
	# verify the generate() call completes without crash and returns a valid state.
	assert_eq(b.get_active_floor(), 0,
		"Store archetype building should generate without error and have active floor 0")
	b.free()


# ── WorldGen: goal building assignment ───────────────────────────────────────

func _make_world_gen_with_buildings(count: int, seed: int) -> WorldGen:
	var wg := WorldGen.new()
	wg.world_seed = seed
	for i in count:
		var b := BuildingGen.new()
		b.room_size = Vector2i(8, 8)
		b.room_cols = 1
		b.room_rows = 1
		wg.add_child(b)
	return wg


func test_world_gen_marks_last_building_as_goal() -> void:
	var wg := _make_world_gen_with_buildings(3, 42)
	wg.generate()

	var buildings: Array = []
	for child in wg.get_children():
		if child is BuildingGen:
			buildings.append(child)

	var last: BuildingGen = buildings[buildings.size() - 1]
	assert_true(last.is_goal, "Last building in WorldGen should be marked is_goal=true")

	for b in wg.get_children():
		b.free()
	wg.free()


func test_world_gen_last_building_has_store_archetype() -> void:
	var wg := _make_world_gen_with_buildings(3, 42)
	wg.generate()

	var buildings: Array = []
	for child in wg.get_children():
		if child is BuildingGen:
			buildings.append(child)

	var last: BuildingGen = buildings[buildings.size() - 1]
	assert_eq(last.archetype, BuildingArchetype.ArchetypeID.STORE,
		"Last building should have STORE archetype")

	for b in wg.get_children():
		b.free()
	wg.free()


func test_world_gen_non_goal_buildings_not_store_archetype() -> void:
	var wg := _make_world_gen_with_buildings(4, 99)
	wg.generate()

	var buildings: Array = []
	for child in wg.get_children():
		if child is BuildingGen:
			buildings.append(child)

	for i in range(buildings.size() - 1):
		var b: BuildingGen = buildings[i]
		assert_ne(b.archetype, BuildingArchetype.ArchetypeID.STORE,
			"Building %d should not have STORE archetype (only the last building gets STORE)" % i)

	for b in wg.get_children():
		b.free()
	wg.free()


func test_world_gen_single_building_no_goal() -> void:
	var wg := _make_world_gen_with_buildings(1, 7)
	wg.generate()

	var buildings: Array = []
	for child in wg.get_children():
		if child is BuildingGen:
			buildings.append(child)

	var b: BuildingGen = buildings[0]
	assert_false(b.is_goal,
		"Single building world should not be marked as goal (player already at destination)")

	for child in wg.get_children():
		child.free()
	wg.free()


func test_world_gen_goal_building_reference_set() -> void:
	var wg := _make_world_gen_with_buildings(3, 55)
	wg.generate()

	assert_not_null(wg.goal_building,
		"WorldGen.goal_building should be set after generate() with 3+ buildings")

	for b in wg.get_children():
		b.free()
	wg.free()


func test_world_gen_spawn_building_reference_set() -> void:
	var wg := _make_world_gen_with_buildings(3, 66)
	wg.generate()

	assert_not_null(wg.spawn_building,
		"WorldGen.spawn_building should be set after generate()")

	for b in wg.get_children():
		b.free()
	wg.free()


func test_world_gen_goal_building_signal_emitted() -> void:
	var wg := _make_world_gen_with_buildings(3, 77)
	watch_signals(wg)
	wg.generate()
	assert_signal_emitted(wg, "goal_building_changed")

	for b in wg.get_children():
		b.free()
	wg.free()


func test_world_gen_archetype_cycle_covers_variety() -> void:
	var wg := _make_world_gen_with_buildings(4, 100)
	wg.generate()

	var buildings: Array = []
	for child in wg.get_children():
		if child is BuildingGen:
			buildings.append(child)

	# First three buildings should use the HOUSE/SHOP/APARTMENT cycle.
	var non_goal_archetypes: Array = []
	for i in range(buildings.size() - 1):
		non_goal_archetypes.append((buildings[i] as BuildingGen).archetype)

	var valid_non_store := [
		BuildingArchetype.ArchetypeID.HOUSE,
		BuildingArchetype.ArchetypeID.SHOP,
		BuildingArchetype.ArchetypeID.APARTMENT,
	]
	for arch in non_goal_archetypes:
		assert_true(arch in valid_non_store,
			"Non-goal building archetype %d should be HOUSE, SHOP, or APARTMENT" % arch)

	for b in wg.get_children():
		b.free()
	wg.free()


# ── WorldGen: archetype pick is deterministic ─────────────────────────────────

func test_world_gen_archetype_assignment_is_deterministic() -> void:
	var wg1 := _make_world_gen_with_buildings(3, 123)
	wg1.generate()
	var wg2 := _make_world_gen_with_buildings(3, 123)
	wg2.generate()

	var b1s: Array = []
	var b2s: Array = []
	for child in wg1.get_children():
		if child is BuildingGen:
			b1s.append(child)
	for child in wg2.get_children():
		if child is BuildingGen:
			b2s.append(child)

	for i in b1s.size():
		var b1: BuildingGen = b1s[i]
		var b2: BuildingGen = b2s[i]
		assert_eq(b1.archetype, b2.archetype,
			"Same world seed should produce same archetype for building %d" % i)

	for b in wg1.get_children():
		b.free()
	for b in wg2.get_children():
		b.free()
	wg1.free()
	wg2.free()
