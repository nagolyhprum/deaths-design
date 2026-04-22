Task summary:
- Replace the hard stop at map contact with consistent-speed sliding along all four edges of the isometric diamond.
- Preserve the current zoom, resize behavior, map footprint, and screen-relative control scheme.
- Keep the change local to the player controller.

Implementation notes:
- Updated controller: `res://scripts/player_controller.gd`

Sliding rationale:
- The previous update found the first boundary contact point and stopped there, which fixed uneven reprojection but removed edge sliding entirely.
- The new behavior uses the contact point to identify the touched diamond edge, then spends the remaining movement distance along that edge's tangent.
- Tangent direction is chosen from the attempted motion, so pushing from left, right, up, or down on any side of the map produces the appropriate along-edge slide at the same speed.
