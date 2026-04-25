Approved implementation direction:

- Move the player and building wall-like tiles into one shared Y-sorted stack.
- Remove fixed z-index overrides that currently force some tiles or the player above others regardless of relative position.
- Validate the project with headless Godot after the scene and tileset changes.

Investigation notes:

- `scenes/main.tscn` had the player instance pinned to `z_index = 2`.
- `assets/tiles/building_tiles.tres` had explicit `z_index` values on wall, door, window, column, and wall-mounted switch tiles.
- Those overrides can prevent pure position-based ordering, which is the behavior needed for consistent isometric overlap.
