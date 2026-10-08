# game-design-project-3

## Ronald's

A playable first-person horror game for **Godot 4.3 or newer** (tested with 4.7.2). Wake up in the ball pit of an abandoned birthday diner, pull a flashlight out of your pocket, and find a way outside.

### Play

Import `project.godot` in Godot, let the GLB/audio assets import, then press **F5**. The home screen shows Ronald's diner front; choose **Play** to begin the ball pit opening. Space or Enter skips the opening. **Options** and **Exit game** are stacked on the right of the home screen.

Collect three emergency fuses from two booth tables and the maintenance crate. Restore the breaker on the right wall beside the counter, then return to the front door behind the ball pit. After the first fuse, keep the creature in the flashlight beam to stop it. It follows you around obstacles when you look away.

| Control | Action |
|---|---|
| WASD / Mouse | Walk / look |
| Shift / Space | Run / jump |
| **F** | Toggle flashlight |
| **R** | Replace battery using a spare cell |
| E | Pick up / operate / open |
| Esc | Pause; the menu has Resume, Options, and Exit game |
| F11 | Fullscreen |
| F1 | Performance overlay |
| F3 | Switch standard / low graphics |

Four charge lights are mounted on the visible flashlight and change color as its battery drains. Charge drains only while the light is on; a full cell lasts about four minutes. You begin with two spares and can collect more from the booths. The Options screen, accessible from home or the pause menu, has volume, mouse sensitivity, reduced camera motion, and low graphics. The bottom control strip and spoken-text subtitles are absent. Progress resets on restart and returns to the home screen.

### Models and animation

- `Blender models/diningn area.glb`: supplied room, booths, counter, floor, and pit enclosure.
- `Blender models/ballpit.glb`: supplied ball geometry, instanced into the starting pit. The export's stacked display arrangement is replaced with a shallow, playable layout.
- `Blender models/tubes.glb`: supplied play tubes placed overhead along the side walls.
- `Blender models/textures.glb`: duplicates the diner export and is preserved, but is not loaded a second time.
- `scripts/player.gd`: editable `AnimationPlayer` tracks for waking, sitting/standing, drawing the flashlight from the pocket, and switching it. The visible hand, flashlight, and creature are additional Godot geometry; the supplied GLBs have no animation clips.
- `audio/`: original generated ambient drone, breath, footsteps, switches, and cues. Regenerate with `python tools/generate_audio.py` (Python standard library only).

### Performance

The Compatibility renderer keeps the project usable without Vulkan. On startup, the diner is combined by material and 6 m spatial cell: **528 imported mesh instances become 79 static batches** while retaining spatial culling. The **720 balls use one MultiMesh** with shared Blender geometry and per-instance colors. None are physics bodies. Collisions use simple boxes and one convex entry ramp. Only the flashlight casts dynamic shadows; other lights are short-range and unshadowed. Interaction checks run at 10 Hz and pathfinding at 2 Hz. The camera clips at 45 m. Low graphics disables flashlight shadows and renders 3D at 75% resolution while keeping the HUD sharp.

The rendered validation view reported about 90 draw calls on an AMD Radeon RX 6700S at 1280×720. This is a single desktop test scene, not a minimum hardware guarantee. Use F1 while playing to inspect actual performance on your machine.

### Checks

With `godot` on PATH:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/smoke.gd
godot --path . --script tests/visual.gd
```

The smoke test exercises the full opening, F toggle, battery drain/depletion/replacement, pause, pit exit, all fuse interactions, breaker, win/loss, creature freezing, pathfinding, and restart. The visual check saves opening/gameplay/settings captures and frame samples under `reviews/`. These generated review files are ignored by Git. The project is a short complete prototype; no save system or exported executable is included.

## Team

| # | Name |
|---|------|
| 1 | Rickey |
| 2 | Lionel |
| 3 | Aiden  |
| 4 | Naomi  |
