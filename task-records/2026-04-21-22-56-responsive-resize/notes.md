Task summary:
- Make the playable test scene responsive to window resizing.
- Keep the player in the same relative location within the playable area when the screen size changes.
- Scale the floor, character, and UI together so the scene feels coherent at different window sizes.

Implementation notes:
- Responsive layout script: `res://scripts/test_level.gd`
- Scale-aware player controller: `res://scripts/player_controller.gd`

Resize rationale:
- The player's position now remaps between the previous and current playable bounds using a normalized ratio instead of preserving a stale absolute pixel offset.
- A shared scene scale derived from the viewport size drives the floor tile dimensions, the player node scale and movement speed, the clamp margins, and the instruction label sizing.
- The result keeps the current lightweight playtest scene while making the resize behavior feel deliberate instead of accidental.
