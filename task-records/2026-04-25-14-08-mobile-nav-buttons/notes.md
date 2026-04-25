Implementation notes for mobile navigation HUD:

- Rework the existing bottom HUD row into a dedicated controls column so the username badge sits above the navigation pad.
- Show the D-pad only when a mobile or touchscreen environment is detected, keeping the desktop HUD unchanged.
- Use the existing `move_left`, `move_right`, `move_up`, and `move_down` actions so touch movement matches keyboard and controller movement.
- Size the buttons as a square cluster: long up button, split left/right middle row, and long down button.
- Release synthetic movement actions whenever the controls are hidden or blocked by the username prompt to avoid stuck input.
