Implemented the room collision update by replacing the per-object collider presets in `scripts/test_level.gd` with a single tile-shaped blocker for every non-empty collision entry in `ROOM_LAYOUT`.

The blocker now matches the exact diamond footprint of the isometric tile using the current responsive tile half-size. This keeps collision readability aligned with the visible grid and makes level planning simpler because any tile marked as collidable is fully blocked edge-to-edge.
