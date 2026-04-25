# Notes

- Added `GameParams` as an autoload singleton so any gameplay script can read the parsed launch parameters at runtime.
- `GameParams` normalizes:
  - `username` to a trimmed string
  - `color` to a `Color` plus `has_player_color`
  - `speed` to a non-negative float plus `has_speed`
  - `ref` to `referrer_url`
- Web builds read `window.location.search`. Non-web runs can simulate the same input by passing query-style user args such as `?username=Casey&color=green` or `username=Casey color=green` after `--`.
- The singleton stores values but does not automatically alter movement speed or sprite tint yet; gameplay code can opt into those values explicitly where it makes sense.
