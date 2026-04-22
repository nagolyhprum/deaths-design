Task summary:
- Add a playable 2D main scene that immediately launches when the project starts.
- Place the existing main-character sprite in the scene and animate it while moving.
- Support both WASD and arrow keys for movement so the user can test without changing input settings in the editor.

Implementation notes:
- Main scene path: `res://scenes/main.tscn`
- Player scene path: `res://scenes/player.tscn`
- Controller script: `res://scripts/player_controller.gd`
- Environment script: `res://scripts/test_level.gd`

Control and animation rationale:
- The sprite sheet only contains four diagonal-isometric facings, so movement input is mapped into an isometric-style motion plane rather than a top-down cardinal one.
- Arrow keys and WASD are read directly in script to keep the project immediately playable without requiring extra editor setup.
- The walk cycle uses the existing 3-frame rows in a short ping-pong sequence so the test scene feels more alive while staying readable.

Scene layout notes:
- The floor is a simple drawn isometric grid instead of level art so the user can quickly verify movement, facing, and footing.
- The player is clamped to the visible play area to keep the test loop short and avoid moving off-screen.
