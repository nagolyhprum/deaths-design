Task summary:
- Zoom the playable test scene out slightly.
- Make movement bounds follow the edge of the isometric test map instead of the viewport.
- Preserve the current responsive layout behavior while storing player position relative to the map.

Implementation notes:
- Updated scene layout: `res://scripts/test_level.gd`
- Updated controller bounds logic: `res://scripts/player_controller.gd`

Map-bound rationale:
- The test floor is a procedurally drawn isometric diamond grid, so the player can be constrained in continuous grid coordinates instead of a screen-space rectangle.
- Resize preservation now uses normalized map coordinates, which keeps the character in the same relative place on the map when the window changes size.
- A small content-scale reduction zooms the scene out without adding a dedicated camera or breaking the existing UI scaling.
