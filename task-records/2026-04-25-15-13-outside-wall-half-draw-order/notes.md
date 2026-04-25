This fix targets the left/right asymmetry on building walls when the player is outside. Indoor wall ordering was already acceptable and should stay unchanged.

The previous outdoor-wide `WorldTileMapLayer.x_draw_order_reversed` setting was too broad and pushed the left/right ordering problem onto the whole outside layer. The tighter fix removes that world-layer override and enables `x_draw_order_reversed` only on `BuildingGen`'s `WallLayer`, alongside the existing wall `y_sort_origin`, so the two wall halves sort consistently against the player around the building exterior.
