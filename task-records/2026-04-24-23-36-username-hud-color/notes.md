Approved plan: add a lower-right HUD label that reads from `GameParams.username`, tint it with `GameParams.player_color`, and keep it positioned responsively inside the existing `CanvasLayer` so it stays readable in the isometric play view.

Implementation notes:
- Preserve the existing username prompt flow and refresh the badge once startup query parameters finish loading.
- Generate a bright random fallback player color when no valid color query parameter is supplied, while keeping `has_player_color` false unless the query explicitly provides a valid color.
- Extend the existing `GameParams` unit coverage for the new default-color behavior.
