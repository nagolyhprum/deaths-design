Added project-level movement actions so keyboard, d-pad, and the left analog stick all share one input path.

Implementation notes:
- Keep the existing screen-relative movement scheme so controller input matches keyboard behavior.
- Use a modest analog deadzone to avoid drift on Steam Deck and worn sticks.
- Update the instruction label so controller support is discoverable in-game.
