Task summary:
- Make movement against the edge of the test map feel consistent regardless of which side is being hit.
- Preserve the current zoom level, map footprint, resize behavior, and screen-relative controls.
- Fix the edge response locally in the player controller.

Implementation notes:
- Updated controller: `res://scripts/player_controller.gd`

Clamp rationale:
- The previous logic converted the current position into map coordinates, clamped the coordinates, and rebuilt a screen position. That reprojection could create different sideways motion depending on the edge orientation.
- The new logic keeps the same playable diamond, but clamps by finding the first boundary contact along the attempted movement segment.
- When the player pushes into the map edge now, they stop at a consistent boundary point instead of inheriting uneven slide from the remap math.
