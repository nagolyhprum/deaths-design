Approved plan: update the username badge in `scripts/test_level.gd` so the responsive HUD layout places it in the lower-left corner instead of the lower-right, and switch the label alignment to match the new placement.

Implementation notes:
- Keep the existing badge sizing and viewport-scale behavior intact.
- Only change the badge's horizontal placement and text alignment so the rest of the username prompt flow remains untouched.
- Project validation still reports pre-existing parse errors from the bundled GUT editor plugin on Godot 4.4.1, but the editor exits successfully.
