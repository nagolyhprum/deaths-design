Plan approved: add a lightweight name prompt to the main UI layer, wait until `GameParams` finishes loading startup query parameters, skip the prompt when `GameParams.username` is already populated, and otherwise write the submitted name back through `GameParams` so gameplay reads a single shared value.

Implementation notes:
- Keep the prompt readable over the isometric scene with a centered overlay on the existing `CanvasLayer`.
- Disable player movement while the prompt is visible so keyboard input goes into the name field instead of moving the character.
- Cover the new global username helpers with GUT unit tests.
