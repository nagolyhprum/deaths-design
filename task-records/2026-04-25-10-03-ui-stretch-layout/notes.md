Approved plan: replace the manual viewport-driven HUD scaling with Godot stretch settings plus a full-rect `Control` HUD layout so existing and future UI controls resize with the window without custom per-node code.

Implementation notes:
- Set the project's base size to `1280x720` and enable `canvas_items` stretch with `expand` aspect handling.
- Move the top-left instructions and bottom-left username badge under a `Control`/container hierarchy in `scenes/main.tscn`.
- Remove the resize listener and manual font/position scaling from `scripts/test_level.gd`, keeping only the username prompt flow and badge visibility updates.
- The change is intended for HUD/UI controls; gameplay `Node2D` content keeps its normal world behavior.
