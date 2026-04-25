# Notes

- Implement the portal redirect in `scripts/game_params.gd`, since `GameParams` is already an autoload singleton.
- Build the target URL from the current `username`, `speed_meters_per_second`, and `player_color` fields instead of passing separate arguments around.
- Preserve readable color values by emitting existing named colors (`red`, `green`, `yellow`) when possible; otherwise emit lowercase hex so the existing parser can read it back.
- Redirect the current page in web builds and use `OS.shell_open` as the desktop fallback.
- Add focused unit coverage in `test/unit/test_game_params.gd` for URL generation and color serialization.
