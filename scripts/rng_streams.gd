class_name RngStreams
extends RefCounted

# Splits a single base seed into deterministic named sub-streams, so every
# generation concern (layout, wfc, furniture, hazards, ...) draws from its own
# RNG without interfering with the others. Adding a new stream in the future
# does not perturb existing ones.
#
# Usage:
#   var streams := RngStreams.new(world_seed)
#   var layout_rng := streams.stream("layout")
#   var wfc_rng := streams.stream("wfc")
#   var building_seed := streams.derive_seed("building", Vector2i(2, 3))

var _base_seed: int


func _init(base_seed: int) -> void:
	_base_seed = base_seed


func stream(stream_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_base_seed, stream_name])
	return rng


func derive_seed(tag: String, extra: Variant = null) -> int:
	if extra == null:
		return hash([_base_seed, tag])
	return hash([_base_seed, tag, extra])


func base_seed() -> int:
	return _base_seed
