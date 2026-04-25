Implementation notes for the P-key mobile navigation toggle:

- Keep the existing mobile and touchscreen auto-show behavior for the on-screen navigation buttons.
- Add a desktop testing override so pressing `P` toggles the D-pad on and off without needing a mobile device.
- Do not let the override bypass the username prompt: if the prompt is visible, the D-pad should stay hidden.
- Preserve the existing touch-button input handling and release any synthetic presses when the controls are hidden.
