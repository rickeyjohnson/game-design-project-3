# Web export

**Fact or rule:** The Godot Web release belongs in `docs/index.html`. Keep `docs/index.pck` below 100 MB (100,000,000 bytes). The export preset excludes reference photos, generated docs, tests, reviews, and unused room audio.

**Why:** The user requested an optimized `docs/` export with a package under 100 MB. The 2026-10-09 export measured 9,327,884 bytes.

**How to apply:** After gameplay or asset changes, rebuild with `godot --headless --path . --export-release Web docs/index.html`, then measure the generated `docs/index.pck`. Report the actual size and any export or runtime test results.
