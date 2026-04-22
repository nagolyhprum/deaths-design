Task summary:
- Fix the interior wall variants so windows, doors, and picture frames sit flush with the wall faces.
- Preserve the current wall taxonomy, atlas layout, furniture art, and furnished scene usage.
- Save the updated Pillow generator script with the task record for future regeneration.

Implementation notes:
- Asset path: `assets/tiles/interiors/room_structure_tilesheet.png`
- Generator script: `task-records/2026-04-21-23-58-flush-wall-inserts/generate_room_structure_tilesheet.py`

Flush-wall approach:
- Redraw the wall inserts as inset or mounted panels inside the wall-face boundaries instead of as free-floating foreground quads.
- Add visible wall borders around windows, doors, and picture frames so the pieces read as part of the wall plane.
- Keep atlas coordinates stable so the furnished test scene does not need another layout remap.
