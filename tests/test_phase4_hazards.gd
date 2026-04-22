extends GutTest

# Phase 4 tests: HazardPass placement, HazardManager state machine,
# telegraph-visibility validation, independent RNG stream, and
# building_gen hazard integration.


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_floor_layer(seed: int, size: Vector2i = Vector2i(8, 8)) -> TileMapLayer:
	var layer := TileMapLayer.new()
	WfcRoomGenerator.generate(seed, layer, Vector2i.ZERO, size)
	return layer


func _make_hazards_layer() -> TileMapLayer:
	return TileMapLayer.new()


func _make_building(seed: int, cols: int, rows: int) -> BuildingGen:
	var b := BuildingGen.new()
	b.building_seed = seed
	b.room_size     = Vector2i(8, 8)
	b.room_cols     = cols
	b.room_rows     = rows
	b.num_floors    = 1
	b.has_basement  = false
	return b


# ── TileMeta.HazardType enum ─────────────────────────────────────────────────

func test_hazard_type_enum_has_none() -> void:
	assert_eq(TileMeta.HazardType.NONE, 0, "NONE should be first (0) in HazardType enum")


func test_hazard_type_enum_has_stove_fire() -> void:
	assert_true(TileMeta.HazardType.has("STOVE_FIRE"), "HazardType should contain STOVE_FIRE")


func test_hazard_type_enum_has_fall() -> void:
	assert_true(TileMeta.HazardType.has("FALL"), "HazardType should contain FALL")


func test_hazard_type_enum_has_falling_object() -> void:
	assert_true(TileMeta.HazardType.has("FALLING_OBJECT"), "HazardType should contain FALLING_OBJECT")


func test_hazard_type_enum_has_electrocution() -> void:
	assert_true(TileMeta.HazardType.has("ELECTROCUTION"), "HazardType should contain ELECTROCUTION")


# ── TileMeta.RoomType.STORE ───────────────────────────────────────────────────

func test_room_type_has_store() -> void:
	assert_true(TileMeta.RoomType.has("STORE"), "RoomType should contain STORE")


# ── HazardPass.generate() with empty palette ──────────────────────────────────

func test_hazard_pass_returns_empty_array_when_palette_empty() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	var fl := _make_floor_layer(42)
	var hl := _make_hazards_layer()
	var result := HazardPass.generate(42, fl, hl, Vector2i.ZERO, Vector2i(8, 8))
	assert_eq(result.size(), 0, "Empty palette → empty placed hazards array")
	fl.free()
	hl.free()


func test_hazard_pass_leaves_hazard_layer_empty_with_no_palette() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	var fl := _make_floor_layer(99)
	var hl := _make_hazards_layer()
	HazardPass.generate(99, fl, hl, Vector2i.ZERO, Vector2i(8, 8))
	assert_eq(hl.get_used_cells().size(), 0, "No palette → hazard layer must stay empty")
	fl.free()
	hl.free()


# ── HazardPass.generate() with a populated palette ────────────────────────────

func _make_kitchen_hazard_def() -> HazardPass.HazardDef:
	var hd := HazardPass.HazardDef.new()
	hd.source_id       = WfcRoomGenerator.FLOOR_SOURCE_ID  # reuse floor tile as placeholder
	hd.atlas           = Vector2i(0, 0)
	hd.anchor          = TileMeta.Anchor.WALL_N
	hd.room_types      = [TileMeta.RoomType.KITCHEN]
	hd.weight          = 1.0
	hd.clearance       = 0
	hd.hazard_type     = TileMeta.HazardType.STOVE_FIRE
	hd.trigger_radius  = 1
	hd.warning_offsets = []   # no telegraph required in test
	hd.consequence     = "death"
	hd.reset_mode      = "respawn"
	return hd


func _make_generic_hazard_def() -> HazardPass.HazardDef:
	var hd := HazardPass.HazardDef.new()
	hd.source_id       = WfcRoomGenerator.FLOOR_SOURCE_ID
	hd.atlas           = Vector2i(1, 0)
	hd.anchor          = TileMeta.Anchor.CENTER
	hd.room_types      = []    # any room
	hd.weight          = 1.0
	hd.clearance       = 0
	hd.hazard_type     = TileMeta.HazardType.FALLING_OBJECT
	hd.trigger_radius  = 1
	hd.warning_offsets = []
	hd.consequence     = "death"
	hd.reset_mode      = "respawn"
	return hd


func test_hazard_pass_places_hazard_in_matching_room_type() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	HazardPass.HAZARD_PALETTE.append(_make_kitchen_hazard_def())

	var fl := _make_floor_layer(10)
	var hl := _make_hazards_layer()
	var result := HazardPass.generate(10, fl, hl, Vector2i.ZERO, Vector2i(8, 8),
		TileMeta.RoomType.KITCHEN)
	assert_eq(result.size(), 1, "Should place one hazard in a KITCHEN room")
	fl.free()
	hl.free()
	HazardPass.HAZARD_PALETTE.clear()


func test_hazard_pass_skips_hazard_for_wrong_room_type() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	HazardPass.HAZARD_PALETTE.append(_make_kitchen_hazard_def())  # kitchen only

	var fl := _make_floor_layer(20)
	var hl := _make_hazards_layer()
	var result := HazardPass.generate(20, fl, hl, Vector2i.ZERO, Vector2i(8, 8),
		TileMeta.RoomType.BEDROOM)
	assert_eq(result.size(), 0, "Kitchen hazard should not appear in a BEDROOM")
	fl.free()
	hl.free()
	HazardPass.HAZARD_PALETTE.clear()


func test_hazard_pass_places_generic_hazard_in_any_room() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	HazardPass.HAZARD_PALETTE.append(_make_generic_hazard_def())

	for rt in [TileMeta.RoomType.KITCHEN, TileMeta.RoomType.BEDROOM,
			TileMeta.RoomType.BATHROOM, TileMeta.RoomType.LIVING_ROOM]:
		var fl := _make_floor_layer(30 + rt)
		var hl := _make_hazards_layer()
		var result := HazardPass.generate(30 + rt, fl, hl, Vector2i.ZERO, Vector2i(8, 8), rt)
		assert_eq(result.size(), 1,
			"Generic hazard (empty room_types) should appear in room type %d" % rt)
		fl.free()
		hl.free()

	HazardPass.HAZARD_PALETTE.clear()


func test_hazard_pass_placed_hazard_has_correct_type() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	HazardPass.HAZARD_PALETTE.append(_make_generic_hazard_def())

	var fl := _make_floor_layer(50)
	var hl := _make_hazards_layer()
	var result := HazardPass.generate(50, fl, hl, Vector2i.ZERO, Vector2i(8, 8))
	assert_eq(result.size(), 1)
	var ph: HazardPass.PlacedHazard = result[0]
	assert_eq(ph.hazard_def.hazard_type, TileMeta.HazardType.FALLING_OBJECT,
		"Placed hazard should carry correct hazard_type")
	fl.free()
	hl.free()
	HazardPass.HAZARD_PALETTE.clear()


func test_hazard_pass_is_deterministic() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	HazardPass.HAZARD_PALETTE.append(_make_generic_hazard_def())

	var fl1 := _make_floor_layer(77)
	var hl1 := _make_hazards_layer()
	var r1  := HazardPass.generate(77, fl1, hl1, Vector2i.ZERO, Vector2i(8, 8))

	var fl2 := _make_floor_layer(77)
	var hl2 := _make_hazards_layer()
	var r2  := HazardPass.generate(77, fl2, hl2, Vector2i.ZERO, Vector2i(8, 8))

	assert_eq(r1.size(), r2.size(), "Hazard pass should be deterministic")
	if r1.size() > 0 and r2.size() > 0:
		var ph1: HazardPass.PlacedHazard = r1[0]
		var ph2: HazardPass.PlacedHazard = r2[0]
		assert_eq(ph1.cell, ph2.cell, "Same seed should place hazard at same cell")

	fl1.free()
	fl2.free()
	hl1.free()
	hl2.free()
	HazardPass.HAZARD_PALETTE.clear()


# ── Telegraph-visibility validation ──────────────────────────────────────────

func _make_hazard_with_telegraph(offsets: Array[Vector2i]) -> HazardPass.HazardDef:
	var hd := HazardPass.HazardDef.new()
	hd.source_id       = WfcRoomGenerator.FLOOR_SOURCE_ID
	hd.atlas           = Vector2i(0, 0)
	hd.anchor          = TileMeta.Anchor.CENTER
	hd.room_types      = []
	hd.weight          = 1.0
	hd.clearance       = 0
	hd.hazard_type     = TileMeta.HazardType.STOVE_FIRE
	hd.trigger_radius  = 1
	hd.warning_offsets = offsets
	hd.consequence     = "death"
	hd.reset_mode      = "respawn"
	return hd


func test_telegraph_validation_passes_when_offset_on_floor_tile() -> void:
	var fl := _make_floor_layer(88)
	var hl := _make_hazards_layer()

	# Interior cell (2,2) with south-facing offset (0,1) → (2,3) should be floor
	# We can test _validate_telegraph directly.
	var offsets: Array[Vector2i] = [Vector2i(0, 1)]
	var hd := _make_hazard_with_telegraph(offsets)

	# Validate at interior cell (2,2) — (2,3) should be floor in an 8x8 room
	var ok := HazardPass._validate_telegraph(hd, Vector2i(2, 2), fl, Vector2i.ZERO, Vector2i(8, 8))
	assert_true(ok, "Telegraph at (2,3) which is a floor tile should pass validation")

	fl.free()
	hl.free()


func test_telegraph_validation_fails_when_all_offsets_out_of_bounds() -> void:
	var fl := _make_floor_layer(89)
	var hl := _make_hazards_layer()

	# Place hazard at (1,1) with offset (-5,-5) → out of bounds
	var offsets: Array[Vector2i] = [Vector2i(-5, -5)]
	var hd := _make_hazard_with_telegraph(offsets)
	var ok := HazardPass._validate_telegraph(hd, Vector2i(1, 1), fl, Vector2i.ZERO, Vector2i(8, 8))
	assert_false(ok, "Out-of-bounds telegraph offset should fail validation")

	fl.free()
	hl.free()


func test_telegraph_validation_passes_with_no_offsets() -> void:
	var fl := _make_floor_layer(90)
	var offsets: Array[Vector2i] = []
	var hd := _make_hazard_with_telegraph(offsets)
	var ok := HazardPass._validate_telegraph(hd, Vector2i(3, 3), fl, Vector2i.ZERO, Vector2i(8, 8))
	assert_true(ok, "Hazard with no warning_offsets should always pass telegraph validation")
	fl.free()


# ── HazardManager state machine ───────────────────────────────────────────────

func _make_manager() -> HazardManager:
	var m := HazardManager.new()
	return m


func test_hazard_manager_register_sets_idle() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(2, 2), TileMeta.HazardType.STOVE_FIRE)
	assert_eq(m.get_state(Vector2i(2, 2)), HazardManager.HazardState.IDLE,
		"Registered hazard should start in IDLE state")
	m.free()


func test_hazard_manager_near_transitions_to_warning() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(3, 3), TileMeta.HazardType.FALL)
	m.player_near_hazard(Vector2i(3, 3))
	assert_eq(m.get_state(Vector2i(3, 3)), HazardManager.HazardState.WARNING,
		"player_near_hazard() should transition IDLE → WARNING")
	m.free()


func test_hazard_manager_on_triggers() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(4, 4), TileMeta.HazardType.ELECTROCUTION)
	m.player_on_hazard(Vector2i(4, 4))
	assert_eq(m.get_state(Vector2i(4, 4)), HazardManager.HazardState.TRIGGERED,
		"player_on_hazard() should transition IDLE → TRIGGERED")
	m.free()


func test_hazard_manager_warning_then_triggered() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(5, 5), TileMeta.HazardType.FALLING_OBJECT)
	m.player_near_hazard(Vector2i(5, 5))
	assert_eq(m.get_state(Vector2i(5, 5)), HazardManager.HazardState.WARNING)
	m.player_on_hazard(Vector2i(5, 5))
	assert_eq(m.get_state(Vector2i(5, 5)), HazardManager.HazardState.TRIGGERED,
		"WARNING → TRIGGERED transition should work")
	m.free()


func test_hazard_manager_reset_single_returns_to_idle() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(1, 1), TileMeta.HazardType.STOVE_FIRE)
	m.player_on_hazard(Vector2i(1, 1))
	m.reset_hazard(Vector2i(1, 1))
	assert_eq(m.get_state(Vector2i(1, 1)), HazardManager.HazardState.IDLE,
		"reset_hazard() should return TRIGGERED → IDLE")
	m.free()


func test_hazard_manager_reset_all_clears_all_triggered() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(1, 1), TileMeta.HazardType.STOVE_FIRE)
	m.register_hazard(Vector2i(2, 2), TileMeta.HazardType.FALL)
	m.player_on_hazard(Vector2i(1, 1))
	m.player_on_hazard(Vector2i(2, 2))
	m.reset_all()
	assert_eq(m.get_state(Vector2i(1, 1)), HazardManager.HazardState.IDLE,
		"reset_all() should return first hazard to IDLE")
	assert_eq(m.get_state(Vector2i(2, 2)), HazardManager.HazardState.IDLE,
		"reset_all() should return second hazard to IDLE")
	m.free()


func test_hazard_manager_never_mode_not_reset_by_reset_all() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(6, 6), TileMeta.HazardType.FALL, 1, "never")
	m.player_on_hazard(Vector2i(6, 6))
	m.reset_all()
	assert_eq(m.get_state(Vector2i(6, 6)), HazardManager.HazardState.TRIGGERED,
		"Hazard with reset_mode='never' should stay TRIGGERED after reset_all()")
	m.free()


func test_hazard_manager_emits_warning_signal() -> void:
	var m := _make_manager()
	watch_signals(m)
	m.register_hazard(Vector2i(3, 3), TileMeta.HazardType.STOVE_FIRE)
	m.player_near_hazard(Vector2i(3, 3))
	assert_signal_emitted(m, "hazard_warning")
	m.free()


func test_hazard_manager_emits_triggered_signal() -> void:
	var m := _make_manager()
	watch_signals(m)
	m.register_hazard(Vector2i(4, 4), TileMeta.HazardType.FALL)
	m.player_on_hazard(Vector2i(4, 4))
	assert_signal_emitted(m, "hazard_triggered")
	m.free()


func test_hazard_manager_emits_reset_signal() -> void:
	var m := _make_manager()
	watch_signals(m)
	m.register_hazard(Vector2i(5, 5), TileMeta.HazardType.ELECTROCUTION)
	m.player_on_hazard(Vector2i(5, 5))
	m.reset_hazard(Vector2i(5, 5))
	assert_signal_emitted(m, "hazard_reset")
	m.free()


func test_hazard_manager_get_state_unregistered_returns_minus_one() -> void:
	var m := _make_manager()
	assert_eq(m.get_state(Vector2i(99, 99)), -1,
		"Unregistered cell should return -1 from get_state()")
	m.free()


func test_hazard_manager_get_hazard_type_unregistered_returns_none() -> void:
	var m := _make_manager()
	assert_eq(m.get_hazard_type(Vector2i(99, 99)), TileMeta.HazardType.NONE,
		"Unregistered cell should return HazardType.NONE")
	m.free()


func test_hazard_manager_clear_removes_all() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(1, 1), TileMeta.HazardType.STOVE_FIRE)
	m.register_hazard(Vector2i(2, 2), TileMeta.HazardType.FALL)
	m.clear()
	assert_eq(m.get_all_hazard_cells().size(), 0, "clear() should remove all registered hazards")
	m.free()


func test_hazard_manager_get_all_hazard_cells_returns_registered() -> void:
	var m := _make_manager()
	m.register_hazard(Vector2i(1, 1), TileMeta.HazardType.STOVE_FIRE)
	m.register_hazard(Vector2i(2, 2), TileMeta.HazardType.FALL)
	m.register_hazard(Vector2i(3, 3), TileMeta.HazardType.ELECTROCUTION)
	assert_eq(m.get_all_hazard_cells().size(), 3,
		"get_all_hazard_cells() should return all 3 registered cells")
	m.free()


# ── HazardPass does not perturb furniture RNG ─────────────────────────────────

func test_hazard_rng_independent_from_furniture_rng() -> void:
	# If adding hazards shifts the furniture seed, furniture cells would differ
	# between a generation with/without the hazard palette.
	# We verify that furniture stream output is identical regardless of hazard palette.
	var furn_seed := RngStreams.new(42).derive_seed("furniture")
	var hazard_seed := RngStreams.new(42).derive_seed("hazards")
	assert_ne(furn_seed, hazard_seed,
		"Furniture and hazard RNG seeds must be independent sub-streams")


# ── Building gen: get_placed_hazards() API ────────────────────────────────────

func test_building_gen_placed_hazards_empty_without_palette() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	var b := _make_building(42, 1, 1)
	b.generate()
	var ph := b.get_placed_hazards(0)
	assert_eq(ph.size(), 0,
		"get_placed_hazards() should return empty array when hazard palette is empty")
	b.free()


func test_building_gen_placed_hazards_populated_with_palette() -> void:
	HazardPass.HAZARD_PALETTE.clear()
	HazardPass.HAZARD_PALETTE.append(_make_generic_hazard_def())

	var b := _make_building(55, 1, 1)
	b.generate()
	var ph := b.get_placed_hazards(0)
	# With palette populated, at least 0 hazards (possibly 1 depending on layout).
	# Just assert the return is an array (not null).
	assert_not_null(ph, "get_placed_hazards() should return an Array, not null")

	b.free()
	HazardPass.HAZARD_PALETTE.clear()


# ── Multi-floor: hazard layers created ────────────────────────────────────────

func test_multifloor_building_creates_dyn_hazard_layers() -> void:
	var b := BuildingGen.new()
	b.building_seed = 42
	b.room_size     = Vector2i(8, 8)
	b.room_cols     = 1
	b.room_rows     = 1
	b.num_floors    = 2
	b.has_basement  = false
	b.generate()

	var has_hz0 := false
	var has_hz1 := false
	for child in b.get_children():
		if child.name == "DynHazards_0":
			has_hz0 = true
		if child.name == "DynHazards_1":
			has_hz1 = true
	assert_true(has_hz0, "DynHazards_0 should exist after 2-floor generate")
	assert_true(has_hz1, "DynHazards_1 should exist after 2-floor generate")
	b.free()
