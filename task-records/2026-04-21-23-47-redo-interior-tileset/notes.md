Task summary:
- Redo the interior tileset around modular wall variants.
- Keep the furniture pieces that already look good, especially the plant, tables, and counter.
- Update the furnished test scene to use the revised atlas coordinates.

Implementation notes:
- Asset path: `assets/tiles/interiors/room_structure_tilesheet.png`
- Generator script: `task-records/2026-04-21-23-47-redo-interior-tileset/generate_room_structure_tilesheet.py`
- Atlas layout target: 4 columns x 4 rows, 128 x 160 per cell.

Tile order:
1. Upper-left wall
2. Upper-left wall with window
3. Upper-left wall with door
4. Upper-left wall with picture
5. Upper-right wall
6. Upper-right wall with window
7. Upper-right wall with door
8. Upper-right wall with picture
9. Upper-left/right corner wall
10. Counter
11. Rug
12. Table
13. Potted plant
14. Counter corner
15. Small side table
16. Accent rug

Art direction:
- Keep the existing muted indoor palette and readable 2.5D isometric silhouettes.
- Anchor every tile to the same 128 x 64 floor diamond footprint used by the current map.
