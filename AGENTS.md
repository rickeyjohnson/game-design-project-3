# Project memory

- The release Web export belongs in `docs/index.html` with its generated files beside it.
- After gameplay or asset changes, rebuild with `godot --headless --path . --export-release Web docs/index.html`.
- Keep `docs/index.pck` below 100 MB (100,000,000 bytes). Measure the generated file after each export.
- Keep reference photos, `docs/`, tests, review files, and unused audio out of the Web package through `export_presets.cfg`.
