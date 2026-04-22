extends Node

# Project-wide tile metadata enums. Registered as the `TileMeta` autoload.
#
# Values are the integers stored in TileSet custom-data layers. Keep the
# underlying int values stable once a TileSet has been authored with them —
# renaming an enum member is fine, but reordering breaks existing data.

enum Category {
	FLOOR,
	WALL,
	DOOR,
	FURNITURE,
	HAZARD,
	STAIR_UP,
	STAIR_DOWN,
}

enum Socket {
	EMPTY,
	FLOOR,
	WALL,
	DOOR,
}

# Atlas x-coord encodes direction for every atlas source in the project:
# N=0, W=1, E=2, S=3 (NWES). Pass a Direction rather than a raw int so the
# convention is enforced in one place.
enum Direction {
	NORTH = 0,
	WEST = 1,
	EAST = 2,
	SOUTH = 3,
}
