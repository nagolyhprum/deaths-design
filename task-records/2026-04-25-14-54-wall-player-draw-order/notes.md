Diagnosed the issue as a wall-layer Y-sort threshold problem rather than inconsistent wall tile metadata. The building tiles already share a consistent per-tile `y_sort_origin = -64`, but the wall layer itself had no compensating layer offset, so tall wall art could compare against the player too high up the sprite.

Implemented a scene-level fix by setting `WallLayer.y_sort_origin = 64` in `scenes/building_gen.tscn`. This moves the wall layer's effective sort point back to the wall base so the player should stay behind walls when north of them and in front when south of them.
