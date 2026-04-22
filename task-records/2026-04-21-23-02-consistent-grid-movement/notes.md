Task summary:
- Tune movement so diagonal input stays visually aligned with the isometric floor.
- Preserve the current screen-relative controls and four-direction animation behavior.
- Keep the change local to the player controller so the responsive scene setup remains intact.

Implementation notes:
- Updated controller: `res://scripts/player_controller.gd`

Movement rationale:
- The floor uses a 2:1 isometric diamond, so fully screen-normalized diagonal movement overemphasizes vertical travel.
- Diagonal input now applies a vertical compression factor before normalization, which keeps combinations like up+left and up+right closer to a stable grid diagonal.
- Cardinal movement remains predictable because single-axis input still resolves to full horizontal or vertical travel.
