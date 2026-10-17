# Project instructions

- This is a Godot 4.7.2 / GDScript Windows single-player cultivation game.
- Keep gameplay rules, data definitions and presentation separate.
- Preserve existing player saves. Optional new fields need defaults and validation before restoring.
- The user explicitly requested background testing: all automated test launches must use --headless and must not open or focus a visible game/editor window.
- Do not start visible graphical tests unless the user explicitly asks to see/run them. Existing saved captures and user-launched preview launchers can be used for review.
- Inspect tool output for script errors as well as exit codes; Godot can continue after a presentation error.
- Use the existing 2D hand-drawn character style, clear outlines, flat colors and restrained shadows. Avoid drifting into realistic character rendering.
- Never write files to the C drive (it is nearly full): temporary files, logs, screenshots and copies go in the project's `.tmp/` (ignored by git and Godot). `check.cmd` and `tools/capture.ps1` already do; the Godot in `.tools/godot` runs self-contained (`._sc_`), so editor data stays in `.tools/godot/editor_data`.
