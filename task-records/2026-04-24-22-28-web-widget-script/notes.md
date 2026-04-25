Implemented by setting the Web export preset's `html/head_include` value in `export_presets.cfg` to inject:

`<script async src="https://vibej.am/2026/widget.js"></script>`

This keeps the standard Godot-generated HTML shell and ensures the script is included whenever the existing Web preset is used for export.

Validation note: opening the project headlessly still reports pre-existing parse errors from the bundled GUT editor plugin on Godot 4.4.1, but the editor exits successfully. Those errors were present before this change and were not modified as part of this task.
