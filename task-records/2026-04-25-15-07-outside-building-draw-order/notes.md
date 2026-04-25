This task only targets the outdoor draw-order problem. Indoor building layering was left alone because it was already behaving correctly.

The alternating outside-order bug pointed to the outdoor isometric TileMap layer rather than the player or building wall data. The fix was to enable `x_draw_order_reversed` on `WorldTileMapLayer` in `scenes/main.tscn` so isometric outdoor tiles sort consistently against the player around building exteriors.
