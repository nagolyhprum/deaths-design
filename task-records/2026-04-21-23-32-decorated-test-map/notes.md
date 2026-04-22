Task summary:
- Use the generated interior room tiles to decorate the existing test map.
- Add collisions to the solid tiles that should block movement, including props like the table and plant.
- Preserve the responsive map layout so decor and collisions stay aligned on resize.

Implementation notes:
- Updated scene: `res://scenes/main.tscn`
- Updated layout script: `res://scripts/test_level.gd`

Layout and collision rationale:
- The room decor is placed in the upper half of the diamond map so the lower half remains open for movement testing.
- The furnished room uses atlas-sliced sprites from the generated tilesheet instead of drawing placeholder geometry.
- Collisions are applied only to solid pieces such as wall segments, counters, tables, and the potted plant, while rugs remain non-blocking.
