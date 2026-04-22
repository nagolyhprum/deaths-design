Task summary:
- Change keyboard movement so the player moves in screen space instead of along the isometric floor axes.
- Keep the existing four-direction sprite sheet and remap its diagonal facings in a stable way for vertical and horizontal movement.
- Preserve the playable boot flow so the project still opens directly into the test scene.

Implementation notes:
- Updated controller: `res://scripts/player_controller.gd`
- Updated scene messaging: `res://scenes/main.tscn`

Control rationale:
- Input now maps directly to screen-space motion: up is screen-up, down is screen-down, left is screen-left, and right is screen-right.
- Because the art only includes four diagonal facings, pure horizontal and vertical movement reuses the closest diagonal row with a stable bias based on the current facing family.
- The walk animation remains unchanged so the change focuses on predictability, not on reworking the sprite timing.
