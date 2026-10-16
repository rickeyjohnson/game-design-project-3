# Hiding From Enemies (Lionel)

> **Agents:** read `AGENTS.md` first, then this whole file. The interview in §5 is optional: use it if the owner wants help deciding.

## 1. What the GDD says

- **System:** "Lionel - Hiding From Enemies: whether the player is hidden and where."
- **Scope:** "The system tracks whether the player is hidden, which hiding spot they occupy and how long they have stayed there. There will also be a limit to how long a player can hide until the location is leaked to the enemy."
- **Seam 1:** "The seam occurs where the Hiding from Enemies system and Enemy Senses system exchange the player's visibility and detection states. One system determines how hidden the player is, while the other reads that information to decide how the enemy should react."
- **Camera and framing (Lionel):** "first-person perspective. Everything will appear larger than the character due to being the size of a child. Tight framing inside the play tubes and ball pit limits visibility, while views beneath tables let the player watch roaming mascots from hiding spots."
- **Palette (Lionel):** `#731F24`, `#B39839`, `#C9C1A5`, `#242522`, `#91CBA5` (see `docs/ART.md`).

## 2. What this system covers

- **The player's body:** a `CharacterBody3D` with a child-height first-person camera, walking (plus running and crouching if you choose), and mouse look.
- **Hiding spots:** a reusable `HideSpot` scene (an `Area3D` with an id and a type) that Aiden places in the level; climbing in and out.
- **The hide timer and the leak limit** (GDD scope).
- **How loud the player is** (`player_noise`), which Senses uses for hearing.
- **The exit zone,** until the team decides how escaping works (GAME_SPEC Q1).
- **The view from hiding:** tight framing in tubes and the ball pit, peeking out from under tables.

Not yours: whether Ronald *notices* you (Senses), what he *does* about it (Ruleset), or the level geometry (Senses / Aiden).

## 3. On the board

**You write** (only you):

| Value | Meaning |
|---|---|
| `player_position` | The player's feet, world space |
| `player_noise` | 0 to 1, how loud the player is this frame |
| `hide_state` | `EXPOSED` or `HIDDEN` |
| `hide_spot` | Id of the spot you're in; `&""` when exposed |
| `hide_time` | Seconds in the current spot |
| `location_leaked` | True once you've hidden past the limit |
| `player_at_exit` | The player is in the exit zone (placeholder) |

**You read:** `game_state` (lock the controls when it isn't `PLAYING`). Anything else is fine to read for display, for example `ronald_mode` for a heartbeat sound.

## 4. Your stub (`hiding_stub.gd`)

The player is a point on the floor that starts at `(0,0,4)`. WASD moves at 3 m/s, H hides or comes out (spot `stub_spot`), hold X to stand in the exit zone. The timer counts while hidden, the spot leaks after 10 s, and moving makes 0.5 noise. Tests: `tests/hiding/test_hiding_stub.gd`. **Keep the stub working**: the others build against it.

## 5. Interview: questions for Lionel

One at a time, multiple choice, recommended option first. Recommendations come from the Closing Time draft (`docs/reference/closing-time-gdd.md`) unless noted.

1. **How do you get into a hiding spot?** A. Press E at the spot; climbing in takes 0.5 s and makes noise. B. Walk or crouch into it and you're hidden automatically. C. Hold crouch inside the spot's area.
2. **Which spots are in v1?** (pick several) Ball pit, play tubes, under tables, booths, bathroom stall, under the counter. Recommended for the smaller map: ball pit, tubes, under tables, booths.
3. **How long until your spot leaks?** A. 20 s in one spot. B. 10 s. C. Different per spot (for example, longer in the ball pit). You decide *when* it leaks; Rickey decides what Ronald does next.
4. **Leaving a spot and coming back:** A. The timer is per spot and resets only when you enter a *different* spot, so ducking out and back in doesn't reset it. B. It resets whenever you leave. C. It drains slowly while you're out.
5. **While hidden, can you:** A. Look around but not move (peek). B. Nothing: fixed view. C. Move slowly inside big spots like the ball pit.
6. **The ball pit:** A. Submerged means safe, but your view shrinks to slits between the balls and sound is muffled. B. It's the same as any other spot.
7. **What makes noise?** A. Crouch-walk 0.1, walk 0.3, wading into or out of the ball pit 0.6, bumping a chair 0.8, running 1.0. B. Only running. C. Nothing in v1.
8. **How does the player move?** A. Walk, run and crouch (the kid runs 3.8 m/s; Ronald chases at 4.2). B. Walk and crouch only. C. Like the mock: walk 2.5, run 4.2, jump.
9. **Camera height:** A. 1.0 m standing, 0.55 m crouched, 0.35 m submerged in the pit; about 80° field of view. B. Keep the mock's values.
10. **Does being in a lit area make you easier to see?** A. Not in v1. B. Yes: add `player_in_light` to the board (a contract change, agreed with Aiden).
11. **The mock's flashlight** (team Q4, with Aiden): A. Cut it. B. Keep it, but it makes you easier to see. C. Keep it as in the mock.
12. **Palette roles:** the GDD lists five colors but not which is the accent. A. Use the proposal in `docs/ART.md` (mint `#91CBA5` = exit sign only). B. A different accent or roles.

## 6. Answers

*Filled in during the interview. Tuning numbers live here too.*

| # | Answer | Date |
|---|---|---|
| 1 | Press E; climb in over 0.5 s with a little noise (A). | 2026-10-14 |
| 2 | Tables, ball pit, play tubes, and booths (B). | 2026-10-14 |
| 3 | 7 s hide limit; show a remaining-time bar while hidden and leak the location when time runs out. | 2026-10-14 |
| 4 | Remaining hide time slowly refills outside hiding (C): empty to full in 14 s, recovering 0.5 s of hiding budget per second outside. | 2026-10-14 |
| 5 | Look around while hidden, but stay in place (A). | 2026-10-14 |
| 6 | Ball pit lowers the view between the balls and muffles sound; same 7 s hide limit (A). | 2026-10-14 |
| 7 | Noise: crouch-walk 0.1, walk 0.3, entering/leaving ball pit 0.6, bumping chairs 0.8, running 1.0 (A). Entry noise for other spots still to be tuned. | 2026-10-14 |
| 8 | Walk, run, and crouch; running speed 3.8 m/s (A). Walking and crouching speeds still to be tuned. | 2026-10-14 |
| 9 | Keep the mock game's camera settings (B); ball-pit lowered view remains as chosen in answer 6. | 2026-10-14 |
| 10 | No extra visibility effect from standing in a lit area in v1 (A); no player_in_light contract addition. | 2026-10-14 |
| 11 | Keep the flashlight working as in the mock (C); Lionel's choice, pending coordination with Aiden on team Q4. | 2026-10-14 |

Scope clarification (2026-10-14): Lionel requested focusing on the supplied hiding mechanics; unrelated art interview questions are deferred. The initial hiding plan excludes new movement, flashlight, and art features. Earlier answers remain recorded for later work.

Integration authorization (2026-10-14): Lionel reported hiding was missing from the main game and explicitly authorized integration with every reader's agreement. The main game now reuses its existing player/flashlight and enemy, adds hiding zones from actual furniture placements, and makes the enemy read hidden/leaked board values. Main table/booth eye height is 0.4 m, tube 0.4 m, pit 0.25 m. Interaction zones use the main player's collision layer 2. The ball pit keeps the player's position and lowers the camera rather than teleporting to its center. Main ambient tracks use a dedicated low-pass bus while hidden in the pit.

Approved plan implementation tuning (2026-10-14): entry takes 0.5 s; table/tube/booth entry and exit noise is 0.3, ball-pit entry and exit noise is 0.6. The test body walks at 2.5 m/s, with a 0.98 m standing camera and 76-degree field of view, using mouse sensitivity 0.002 radians per pixel. Test hiding eye heights: table 0.45 m, booth 0.55 m, tube 0.4 m, ball pit 0.25 m. The shared budget carries across all spots; current-visit hide_time resets on leaving. At zero budget remain hidden but leak; leaving clears the leak, and re-entering with zero budget leaks immediately. Entry is a stationary 0.5 s delay; the budget does not refill during entry. These values are local hiding behavior and do not alter the contract.

Horror presentation request and tuning (2026-10-15): catch shows a close-up of the original Ronald model with a synthesized scream and static for 1.15 s, then reveals the normal death screen. Random GUI face/static bursts say exactly "you better hide", last 0.28 s, and occur 18-35 s apart during play. Reduced Motion suppresses random bursts and removes catch-screen jitter. Pausing cancels active overlays and static.

The new black apparition is a non-colliding visual hallucination, not another enemy. First attempt is 25-45 s into eligible play, then 35-65 s between appearances. It is placed 4.5 m behind the camera only on a clear floor with room for its 3.2 m body and unobstructed sight. It does not appear while hiding or chased. It vanishes 0.55 s after the camera sees it, after 8 s unseen, on pause/menu/win/catch, or if the player moves over 12 m away. Blocked placement retries after 6 s. Shared board and system stubs remain unchanged.

Superseding horror-event tuning (2026-10-15): the unseen apparition no longer times out or disappears at distance. It follows camera translation with its original behind-direction preserved, checking clear floor/space before moving; it does not rotate away when the player turns. Seeing it triggers one 0.28 s GUI face/static flash, then it vanishes after 0.55 s. Normal menu/catch cleanup still applies. Chasing displays translucent interference with faint -25 dB static; the room remains visible. Reduced Motion holds the grain pattern steady.

Timeout cutscene (requested 2026-10-15): once per leak, switch to a separate camera watching Ronald turn from away to face the player over 0.65 s. Then play the existing I see you voice at pitch 0.76, and sprint for only 0.75 s at 6.6 m/s using the original animation at rate 2.0. Actor cannot catch during the cutaway and ignores the flashlight only during this scripted sprint. Return the unchanged player camera and controls, restore normal 3.3 m/s movement and original animation rate 1.0, and give 0.6 s reaction grace before a catch. Pause/finish/cancellation restore camera/flags/speed and stop the line; one cutscene per hiding visit, no repeat while the same leak stays true. The old feedback observer still counts leak events but delegates the timed voice to the cutscene to avoid duplicate lines.

Latest catch/warning revision (2026-10-15): Lionel requested a real jump cutscene rather than a GUI face on catch. The existing live actor leaps over 0.55 s with a 0.65 m vertical arc, reaching head-to-lens distance 0.34 m, then holds close for 0.75 s. A separate camera shows this in the actual diner; no warning text/portrait/static overlay is drawn during catch. The legacy game uses phase caught during the leap, then dead after its completion callback; controls/AI stay stopped and the existing scream fires once. Warning GUI now says you better run and is eligible only during play after Ronald is active/visible, at the existing 18-35 s spacing. No warning is triggered by apparition observation; its persistent reveal/vanish behavior otherwise remains. The timeout turn/voice/brief sprint still restores normal speed and player camera. Normal first-fuse spawn and real AI catch are covered by the live graphical harness.

Latest light/grapple tuning (2026-10-15): the flashlight cannot freeze or charge a pounce while the player is hiding/entering hiding. A revealed location remains a five-second investigation target even after the player leaves sight, so Ronald continues checking the area. Warning GUI scares now occur 45-80 s apart after spawn and scream at -9 dB.

An uninterrupted exposed face beam for 4.0 s triggers one pounce and a -2 dB scream. Breaking the beam or hiding resets exposure; cinematic/escape grace does not charge it. The real actor leaps (0.55 s plus 0.08 s hold), then pins the player under a separate ground camera. Twelve distinct Space presses within 4.0 s win; held keys and repeat events do not count. A 0.7 s shove restores the original camera, controls, original pose/rate, and gives 3.0 s escape grace; the knocked-away flashlight turns off and the light-attack counter resets. Failure plays a 1.0 s closing-jaw bite with crunch audio before death. Pause freezes the struggle and hides its UI, then resumes without losing time. Source hand model is hidden during the grapple and restored afterward; no warning portrait overlays these cutscenes. This is an explicitly requested legacy F5 state (grapple), not a shared board/teammate-system change.

Latest apparition tuning (2026-10-15): replaces timed spawning with a 35% chance per eligible horizontal turn of at least 150 degrees. Each detected turn consumes the attempt, with a 3 s cooldown tracking the current heading to prevent repeated rolls from jitter. Spawn is 4.5 m behind the original heading, in the direction newly revealed by the turn, subject to existing floor/clearance/sight checks. No retries from waiting alone. Hiding, chasing, menus and cutscenes reset turn tracking; an existing figure prevents further rolls. Unseen persistence and 0.55 s observed vanish remain. Warning GUI timing is unchanged.

Latest scare revision (2026-10-15, Lionel): apparition nominal height matches the player's 1.12 m capsule. On observation its body jumps over a 0.55 s arc toward the live camera (face approaches 0.18 m) and disappears; player look/movement and camera remain active. Existing 35% turn chance/3 s cooldown and unseen persistence remain. Clearance and sight probes now match the smaller body. Ronald's exposed continuous flashlight threshold is 6.0 s; grapple Space requirements are unchanged. Warning GUI rolls once at 50% every 13 eligible seconds after spawn, resetting the interval on failure too. Reduced Motion still suppresses warning flashes.

Timeout presentation keeps the turn and one whispered I see you, then sprints at 6.6 m/s until within 0.6 m horizontally of the captured spotted area (table open-side offset 1.5 m). The target is captured at timeout rather than tracking later player movement. Original view/control, normal speed/rate and 0.6 s reaction grace return on arrival; menu/finish cancellation remains. New terror_scream.wav replaces catch/attack/flash playback at 0/0/-2 dB; whisper_see_you.wav replaces the old pitched spoken line at pitch 1.0. New assets are locally generated in the hiding folder; source audio remains intact. Shared board and teammate systems are unchanged; legacy scripts/stalker.gd movement/beam behavior is affected by explicit request.




Latest control/audio correction (2026-10-15, Lionel): restore original i_see_you.wav at pitch 0.76 for both timeout and fallback feedback. Only turn/voice locks the camera and controls. At sprint start the player camera, controls and E/R interaction return immediately; Ronald independently keeps the captured destination and sprint speed until reaching the spotted area. Arrival/cancellation no longer overwrites player look/control after that early restoration. The sprint retains its no-catch approach, followed by normal catch behavior and reaction grace on arrival. Horror overlays resume normally after the camera cut ends. Revised scream, 6 s beam threshold, figure lunge and 50%/13 s flashes remain.

Latest timing refinement (2026-10-15, Lionel): after the original I see you finishes, show Ronald running for 0.5 s before returning the player camera/control/interaction. He continues running independently to the captured spotted area afterward. If he arrives early, retain the brief 0.5 s view before ending the sequence; no catch during the approach. Cancellation still restores immediately. RUN_VIEW_SECONDS is 0.5; all other timing and audio stay as above.

Latest scream/UI/escape correction (2026-10-15, Lionel): successful black-figure spawn plays the same terror_scream.wav as Ronald's catch, at 0 dB, once per appearance. Blocked/failed spawns do not scream; observation does not replay it. Main hiding HUD includes a persistent R / Reload batteries hint below the other controls during play. Winning the grapple now turns the flashlight back on if charge remains and resets toggle cooldown, replacing the earlier deliberate knocked-off behavior. Battery charge/spares are preserved; an empty battery still needs R. Normal F toggling remains available immediately after escape.

Latest battery GUI refinement (2026-10-15, Lionel): remove the separate hiding-HUD reload label and put R / Reload Batteries(amount/maxamount) inside the existing top-right flashlight panel, using its gold control styling. Amount reads current spare_cells live. Since existing gameplay has no carry cap, maximum is the total obtainable spares for this run (starting two plus two level pickups = four); no pickup/reload balance change. Panel grows from 70 to 96 px high to fit the row. Counter redraws with the existing HUD refresh.

Latest coverage/camera refinement (2026-10-15, Lionel): all seven standalone dining tables plus five booth tables support hiding; three kitchen prep counters provide cover behind their solid bases, fifteen total spots. Dining/booth interaction areas grow to 4 x 4 / 4.8 x 4 m horizontally; prep areas are 5 x 2 m. Standing-height reach rejects walls without a pedestal blocking the far side of a table. Gold E / HIDE markers name the furniture within 8 m, hide within 1.5 m, respect depth/occlusion, and hide during player hiding, menus, pause or locked cutaway. Main E prompt names the furniture. No ball-pit or elevated-tube hiding is enabled.

Dining cameras retain feet Z +0.57 and world eye 0.5 m, facing +Z. Booth feet are X +0.25 / Z -0.57, eyes 0.5 m, facing -Z into the dining aisle; this avoids both the pedestal and divider view. Prep cover is behind the cabinet at Z +1.35, with 0.5 m eyes facing +Z into the kitchen aisle. Per-spot outward_yaw replaces fixed facing; horizontal look remains free and level. Ronald chooses/caches one of four open nearby approach points using low reach and navigation checks, rather than assuming +Z for every furniture layout. Timeout captures the same reachable approach. This changes only the authorized legacy integration and owned hiding code, with no new blackboard value.

## 7. Suggested build steps (starting point for `PLAN.md`)

1. **Test scene:** copy `systems/core/sandbox/sandbox.tscn` to `systems/hiding/test/hiding_test.tscn`. Add a floor, a table and a box for the ball pit (greybox).
2. **Player body:** a `HidingSystem` (`SimSystem`, id `hiding`) with a `CharacterBody3D` child and a child-height camera; movement inside `tick()`; writes `player_position` (and sets its start in `setup()`).
3. **Noise:** a pure function from movement state to `player_noise`, with tests.
4. **Hide timer:** a plain `HideTimer` class (`RefCounted`): enter spot, leave, advance time, leaked. Unit-test the per-spot rule and the limit.
5. **Hiding spots:** a `HideSpot` scene (`Area3D` plus `spot_id` and `spot_type`). Getting in and out writes `hide_state` and `hide_spot`. Test with a fake overlap.
6. **Views:** peeking, tube and ball-pit framing.
7. **Exit zone:** `player_at_exit` (or whatever Q1 becomes).
8. **Swap in:** your real system replaces the stub in your test scene, then in `main.tscn` when it exists.

## 8. Tests to write

- Noise for each movement state.
- The hide timer counts only while hidden, follows your chosen per-spot rule, and leaks exactly at the limit.
- Entering and leaving a spot sets `hide_state` and `hide_spot`.
- Controls are locked when `game_state` isn't `PLAYING`.

## 9. Seams and risks

- **You are the only authority on "hidden."** Senses trusts `hide_state` and never runs its own "is the player hidden?" check. If Aiden finds he needs one, raise it as a contract question.
- **Noise isn't hidden.** Climbing into the ball pit next to Ronald should still make noise.
- **Exploit:** stepping out of a spot and back in to reset the timer. Question 4 decides this.
- **The leak hands off to the Ruleset.** You set `location_leaked`; Rickey decides the reaction ("I see you"). Agree on what happens after a leak, for example whether it stays true until you change spots.

## 10. Reuse from the mock

- `scripts/player.gd`: walking, running and jumping, mouse look with sensitivity, head bob and the reduced-motion option, the wake-up and sit/stand animation tracks (an opening in the ball pit).
- `scripts/world.gd`: the ball-pit collision and the "nearby balls shift" effect.

## 11. Done means

`docs/WORKFLOW.md` "Done means": the tests pass, it works in your test scene with the other three as stubs, it's merged into `main` through a PR, and `PROGRESS.md` is updated.

Table view request (2026-10-15): table hiding locks vertical look at pitch 0 radians while allowing free horizontal look. Ball pit views and other hiding types are unchanged.

Superseding F5 revision (2026-10-15, Lionel explicitly approved all requested changes): tables are the only active hiding spots in both the main game and local scene. Ball pit, booths, and tubes remain scenery; their reusable spot types are retained for possible later use. Imported tables have a 0.2 m central pedestal and a tabletop underside at 0.715 m. Hiding feet are placed 0.57 m toward +Z from the table center at y=0.12; eye height 0.38 m gives world y=0.5. Entry faces outward (+Z), pitch stays zero, horizontal look remains free. A shadowless 2.5 m local fill at energy 0.35 makes foreground visible even with the flashlight off; it is enabled only while table-hidden.

Approved F5 tuning: battery drain 1.68 percent/second while on (about 59.5 seconds from full), none while off. Ronald moves at 3.3 m/s outside the flashlight beam, twice the old 1.65 m/s; direct flashlight illumination still freezes him. Chase requires an exposed player within 12 m and clear sight, or an existing location leak. The seven-second leak plays one low-pitched synthesized "I see you" per visit; detection/chase plays an original eight-second looping horror pulse. Running cycle is 0.64 s at 3.3 m/s, with positional sole taps every 0.9 m traveled; animation and taps stop at rest, in the beam, or at game end. These are current legacy F5 behavior, not changes to teammates' stubs or the board contract.

Superseding animation choice (2026-10-15): Lionel requested the old animation back. Use the original imported clip at speed_scale 1.0; remove generated running animation. Keep movement-linked footsteps and beam freezing.

Table timeout catch tuning (2026-10-15): after the budget expires Ronald can catch the hidden player from within 2.0 m with a clear below-table reach ray; approach target is hidden feet plus Vector3(0, 0, 1.5), on the open side. Normal exposed catch distance stays 0.85 m. Hiding protects until exhaustion; timeout is not instant death at a distance. Beam freezing still applies.

Chase/warning correction (Lionel, 2026-10-16): safe table hiding abandons chase/search and resumes patrol immediately. Timeout warning now holds Ronald stationary for the full 5 s before approach; F5 roaming also respects the entire cutscene turn and spoken line. Existing ball-pit camping remains.
