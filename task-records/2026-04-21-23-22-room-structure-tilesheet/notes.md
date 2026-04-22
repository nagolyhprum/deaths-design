Task summary:
- Create a starter isometric 2.5D interior tilesheet aligned to the current floor grid.
- Include modular room pieces for walls, windows, doors, rugs, tables, counters, wall art, and plants.
- Keep the atlas reusable for later scene building instead of baking pieces into one composition.

Implementation notes:
- Asset path: `assets/tiles/interiors/room_structure_tilesheet.png`
- Atlas layout target: 4 columns x 3 rows.
- Cell size target: 128 x 160 pixels, with each tile anchored to a 128 x 64 isometric floor diamond.

Planned tile order:
1. Plain wall
2. Window wall
3. Door wall
4. Counter
5. Rug
6. Table
7. Potted plant
8. Wall picture
9. Corner wall
10. Double window wall
11. Counter corner
12. Small side table

Art direction:
- Use muted indoor colors with enough contrast for wall faces, tops, and floor contact shadows to stay readable in the current camera.
- Keep every piece snapped to the existing isometric footprint so future scenes can mix and match them on the same diamond grid without manual offsets.
