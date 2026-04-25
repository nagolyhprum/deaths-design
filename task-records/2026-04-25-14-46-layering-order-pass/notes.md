Approved implementation direction:

- Force all floor rendering behind characters and occluding tiles.
- Make fences, building walls, doors, windows, columns, and the player share one Y-sorted occluder stack.
- Remove remaining fence z-index overrides that force ordering outside the shared Y-sort calculation.

Implementation notes:

- Enable Y-sorting on the world tile layer so fence tiles can sort with the player.
- Mark the building floor layer as a fixed behind layer instead of a Y-sorted occluder layer.
- Keep building wall-like layers inside the shared Y-sort hierarchy by enabling sorting on the building root.
