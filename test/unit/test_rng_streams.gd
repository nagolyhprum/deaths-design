extends GutTest

# Exercises the core determinism guarantee: same base seed must produce
# identical sub-streams, derived seeds, and RNG sequences across runs.
# Different seeds or different stream names must produce different values.


func test_same_seed_same_stream_produces_same_sequence() -> void:
	var a := RngStreams.new(12345).stream("layout")
	var b := RngStreams.new(12345).stream("layout")
	for i in range(10):
		assert_eq(a.randi(), b.randi(), "stream %d" % i)


func test_different_seeds_diverge() -> void:
	var a := RngStreams.new(1).stream("layout")
	var b := RngStreams.new(2).stream("layout")
	var any_divergence := false
	for i in range(10):
		if a.randi() != b.randi():
			any_divergence = true
			break
	assert_true(any_divergence, "different seeds should produce different sequences")


func test_different_stream_names_diverge() -> void:
	var a := RngStreams.new(42).stream("layout")
	var b := RngStreams.new(42).stream("wfc")
	var any_divergence := false
	for i in range(10):
		if a.randi() != b.randi():
			any_divergence = true
			break
	assert_true(any_divergence, "different stream names should produce different sequences")


func test_derive_seed_is_deterministic() -> void:
	var s1 := RngStreams.new(777).derive_seed("building", 3)
	var s2 := RngStreams.new(777).derive_seed("building", 3)
	assert_eq(s1, s2)


func test_derive_seed_varies_with_extra() -> void:
	var a := RngStreams.new(777).derive_seed("building", 0)
	var b := RngStreams.new(777).derive_seed("building", 1)
	assert_ne(a, b)


func test_derive_seed_varies_with_tag() -> void:
	var a := RngStreams.new(777).derive_seed("building", 0)
	var b := RngStreams.new(777).derive_seed("street", 0)
	assert_ne(a, b)


func test_derive_seed_no_extra() -> void:
	var a := RngStreams.new(777).derive_seed("outdoor")
	var b := RngStreams.new(777).derive_seed("outdoor")
	assert_eq(a, b)
