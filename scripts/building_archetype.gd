class_name BuildingArchetype
extends RefCounted

# Building archetype definitions. Drives room-type distribution, floor count
# range, and basement probability for each building variety.
#
# Archetypes are assigned by WorldGen when placing buildings. The STORE archetype
# marks the goal building the player must reach. Pass the archetype to
# RoomGraph.generate() via the room_weights parameter so the WFC layout reflects
# the building's character.
#
# Usage:
#   var weights := BuildingArchetype.room_weights_for(BuildingArchetype.ArchetypeID.HOUSE)
#   var layout  := RoomGraph.generate(seed, room_size, cols, rows, weights)

enum ArchetypeID {
	HOUSE,      # Residential: kitchen, bedrooms, living room, bathroom
	SHOP,       # Street-level retail: open floor, storage, small office
	APARTMENT,  # Multi-unit: many bedrooms, shared hall, kitchenette
	STORE,      # Goal building: large open floor for the store the player reaches
}


# Returns a weight table (Dictionary[TileMeta.RoomType → float]) for the given
# archetype. RoomGraph uses these weights to select room types during layout
# generation. A weight of 0.0 means the room type will not appear.
static func room_weights_for(archetype: int) -> Dictionary:
	match archetype:
		ArchetypeID.HOUSE:
			return {
				TileMeta.RoomType.HALL:        2.0,
				TileMeta.RoomType.KITCHEN:     1.5,
				TileMeta.RoomType.BEDROOM:     2.0,
				TileMeta.RoomType.BATHROOM:    1.0,
				TileMeta.RoomType.LIVING_ROOM: 1.5,
				TileMeta.RoomType.STORE:       0.0,
			}
		ArchetypeID.SHOP:
			return {
				TileMeta.RoomType.HALL:        1.0,
				TileMeta.RoomType.KITCHEN:     0.5,
				TileMeta.RoomType.BEDROOM:     0.0,
				TileMeta.RoomType.BATHROOM:    0.5,
				TileMeta.RoomType.LIVING_ROOM: 3.0,  # repurposed as shop floor
				TileMeta.RoomType.STORE:       0.0,
			}
		ArchetypeID.APARTMENT:
			return {
				TileMeta.RoomType.HALL:        1.0,
				TileMeta.RoomType.KITCHEN:     1.0,
				TileMeta.RoomType.BEDROOM:     3.0,
				TileMeta.RoomType.BATHROOM:    2.0,
				TileMeta.RoomType.LIVING_ROOM: 1.0,
				TileMeta.RoomType.STORE:       0.0,
			}
		ArchetypeID.STORE:
			return {
				TileMeta.RoomType.HALL:        1.0,
				TileMeta.RoomType.KITCHEN:     0.5,
				TileMeta.RoomType.BEDROOM:     0.0,
				TileMeta.RoomType.BATHROOM:    0.5,
				TileMeta.RoomType.LIVING_ROOM: 0.5,
				TileMeta.RoomType.STORE:       4.0,  # dominant: goal building
			}
		_:
			return {}  # empty → all room types equally weighted


# Minimum number of above-ground floors for this archetype.
static func min_floors(archetype: int) -> int:
	match archetype:
		ArchetypeID.APARTMENT: return 2
		_:                     return 1


# Maximum number of above-ground floors for this archetype.
static func max_floors(archetype: int) -> int:
	match archetype:
		ArchetypeID.APARTMENT: return 4
		ArchetypeID.HOUSE:     return 2
		_:                     return 1


# Probability (0.0–1.0) that a building of this archetype has a basement.
static func basement_chance(archetype: int) -> float:
	match archetype:
		ArchetypeID.HOUSE:      return 0.3
		ArchetypeID.APARTMENT:  return 0.5
		_:                      return 0.0


# Pick a random floor count in [min_floors, max_floors] using the provided RNG.
static func random_floor_count(archetype: int, rng: RandomNumberGenerator) -> int:
	var lo := min_floors(archetype)
	var hi := max_floors(archetype)
	if lo >= hi:
		return lo
	return lo + rng.randi() % (hi - lo + 1)


# Returns a human-readable name for the archetype (useful for debug labels).
static func display_name(archetype: int) -> String:
	match archetype:
		ArchetypeID.HOUSE:     return "House"
		ArchetypeID.SHOP:      return "Shop"
		ArchetypeID.APARTMENT: return "Apartment"
		ArchetypeID.STORE:     return "Store"
		_:                     return "Building"
