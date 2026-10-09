# game-design-project-3

## Ronald's

A playable first-person horror game for **Godot 4.3 or newer** (tested with 4.7.2). Wake up in the ball pit of an abandoned birthday diner, pull a flashlight out of your pocket, and find a way outside.

### Play

Import `project.godot` in Godot, let the GLB/audio assets import, then press **F5**. The home screen shows Ronald's diner front; choose **Play** to begin the ball pit opening. Space or Enter skips the opening. **Options** and **Exit game** are stacked on the right of the home screen.

The rebuilt map uses the new Blender diner: a large play place, dining booths, kitchen, cold storage, and a back hall leading to the restrooms. Walk out through the gap in the ball pit rim. Collect three emergency fuses from a booth along the divider, a kitchen assembly table, and the cold-storage crate. Enter the kitchen through the opening to the left of the order counter, restore the breaker on its far right wall, then reach the west entrance. After the first fuse, keep the creature in the flashlight beam to stop it. It follows you around obstacles when you look away.

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

Four charge lights are mounted on the visible flashlight and change color as its battery drains. Charge drains only while the light is on; a full cell lasts about four minutes. You begin with two spares and can collect more from a dining table and the restroom side vanity. The building lights start off and come on when the breaker is restored. The Options screen, accessible from home or the pause menu, has volume, mouse sensitivity, reduced camera motion, and low graphics. The bottom control strip and spoken-text subtitles are absent. Progress resets on restart and returns to the home screen.

### Models and animation

- `Blender models/ronalds.glb`: the diner shell, bathroom, freezer fittings, and play structure.
- `Blender models/appliances.glb`: the placed booths, dining tables, chairs, prep counters, grill, fryers, drink machines, refrigerators, and ice machine. The freezer door frame fits the cold-storage entrance.
- `Blender models/PLay place.glb`: supplies the Blender ball mesh used throughout the playable pit. The main map already includes the play structure, so the standalone room is not overlaid on it.
- `scripts/world.gd`: map assembly and named gameplay landmarks. The kitchen wall has a service opening; the freezer is moved out of the overlapping bathroom to the right of the kitchen. Export helper volumes and original furniture are omitted. The play-place perimeter and red enclosure use see-through glass, appliance pieces get collision and navigation clearance, the bathroom has an open entrance and stalls, and the upper play modules have supporting floors and a climbable entry. The original GLBs are preserved.
- `scripts/player.gd`: editable `AnimationPlayer` tracks for waking, sitting/standing, drawing the flashlight from the pocket, and switching it. The visible hand, flashlight, and creature are additional Godot geometry; the supplied GLBs have no animation clips.
- `audio/background soundtrack/`: supplied looping MP3 used as the game's background track. Other sound effects, including the impact-sensitive landing cue, can be regenerated with `python tools/generate_audio.py` (Python standard library only).

### Furniture and appliance layout

The [supplied final floor plan](<Reference photos/Final top down layout.png>) sets the room order: play place to the north, tables in the middle, kitchen to the south, bathroom at the left, and freezer to the kitchen's right. The [earlier floor plan](<Reference photos/First top down layout.png>) and [play-place photo](<Reference photos/Upper play place area.png>) provide additional context. Public [dining-room photos](https://www.flickr.com/photos/ryanrules/albums/72177720307101321/), a [drink-station photo](https://www.mortarr.com/photo/view/images/project_gallery_images/fast-food-restaurant-drink-station-mcdonalds-tamlyn/52612), and a [kitchen equipment photo](https://vistex.ru/blog/makdonalds/) informed the grouping of furniture and machines. The result is a playable interpretation of the supplied plan.

| Area | Models and placement |
|---|---|
| Dining room | Seven tables with fourteen chairs beside the play place; five booths in a row beside a half-wall divider; an order counter at the kitchen service wall, with a beverage system and post-mix soda fountain near its right end. |
| Kitchen | Two clamshell grills, two deep fryers, the fry station, and a combi oven along the rear cooking line. Three assembly tables, two UHC cabinets, a microwave, coffee urns, a post-mix soda fountain, and a soft-serve machine occupy the prep and service side. |
| Freezer | Two reach-in refrigerators against the rear wall and an ice machine against the side wall, leaving an aisle to the fuse crate. It opens from the right side of the kitchen. |

The placements are editable in `scripts/world.gd` under `_import_appliances()`. Collision and enemy navigation are built from the placed models.

### Performance

The Compatibility renderer keeps the project usable without Vulkan. The diner and placed appliance kit contribute **1,558 source mesh instances**; selected geometry is combined by material and 8 m spatial cell into **201 static batches**. The **3,600 balls use one MultiMesh** with shared Blender geometry and individual colors. Nearby balls shift and settle as the player moves; none are physics bodies. Collisions use boxes fitted to furniture and triangle meshes for climbing ramps. Navigation covers the larger floor plan with clearance around obstacles. Only the flashlight casts dynamic shadows; other lights are unshadowed. Interaction checks run at 10 Hz and enemy pathfinding at 2 Hz. The camera clips at 85 m. Low graphics disables flashlight shadows and renders 3D at 75% resolution while keeping the HUD sharp.

Use F1 while playing to inspect performance on your machine. The visual check records a frame sample, but it is not a hardware performance guarantee.

### Web export

Export the playable Web build to `docs/` with `godot --headless --path . --export-release Web docs/index.html`. The preset excludes reference photos, build output, tests, reviews, and unused room audio. Keep `docs/index.pck` below 100,000,000 bytes; the current export is **9,327,884 bytes**. The packaged data includes the supplied soundtrack and landing effect.

### Checks

With `godot` on PATH:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script tests/smoke.gd
godot --path . --script tests/visual.gd
```

The smoke test exercises the full opening, F toggle, battery drain/depletion/replacement, pause, jump and fall landings, pit exit, ball movement, the upper climb and crossing, bathroom and stall entry, physical walking routes to every fuse and battery, their interactions, the kitchen breaker, the west exit, win/loss, creature freezing, pathfinding, and restart. The visual check saves home, opening, dining, beverage, service counter, ball-pit, play-place, glass walls, bathroom entrance, kitchen, freezer, restroom, and settings captures and frame samples under `reviews/`. Menu buttons use the pickup sound as their click. These generated review files are ignored by Git. The project is a short complete prototype; no save system or exported executable is included.

## Team

| # | Name |
|---|------|
| 1 | Rickey |
| 2 | Lionel |
| 3 | Aiden  |
| 4 | Naomi  |
