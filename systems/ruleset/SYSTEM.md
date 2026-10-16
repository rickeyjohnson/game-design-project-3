# Enemy Ruleset (Rickey)

> **Agents:** read `AGENTS.md` first, then this whole file. The interview in §5 is optional: use it if the owner wants help deciding.

## 1. What the GDD says

- **System:** "Rickey - Enemy Ruleset: each mascot's/monster's rules."
- **Seam 2:** "Roaming Enemies must adhere to the Enemy Ruleset. The Enemy Ruleset writes the logic for the central monster, and the Roaming Enemies must read it and decide how to proceed within those constraints."
- **Which seam breaks first:** the GDD's answer is Seam 2 (the paragraph above repeats there).
- **Pitch notes, Ronald's rules:** he won't go into the ball pit; if you hide too long he finds you and says "I see you" first; a sound cue plays when he sees you; getting caught is a pre-death stare, then a jumpscare.

## 2. What this system covers

- **Ronald's modes** and what moves him between them: patrol, investigate, chase, and any you add.
- **His reactions** to detection, leaks and the ball pit.
- **Where he should go and how fast** (`target_position`, `move_speed`); Roaming does the walking.
- **Winning and losing:** caught or escaped (`game_state`), the lose and win screens, restarting.
- **The shared foundation** in `systems/core/`: the blackboard, Director, overlay, sandbox, and later `main.tscn`. You apply contract changes (`docs/BLACKBOARD.md`).

Not yours: noticing the player (Senses), the walking and pathfinding (Roaming), or the hiding (Hiding).

## 3. On the board

**You write** (only you):

| Value | Meaning |
|---|---|
| `ronald_mode` | `PATROL`, `INVESTIGATE` or `CHASE` (more after a contract change) |
| `target_position` | Where Ronald should go; ignored in PATROL |
| `move_speed` | How fast, m/s |
| `game_state` | `PLAYING`, `CAUGHT` or `ESCAPED` |

**You read:** `detection` and `last_known_position` (Senses); `location_leaked`, `hide_state`, `hide_spot`, `player_position` and `player_at_exit` (Hiding); `enemy_position` and `at_target` (Roaming).

## 4. Your stub (`ruleset_stub.gd`)

SEEN → CHASE the player at 3.5 m/s. HEARD → INVESTIGATE the last known position at 2.0 m/s. Leaked → INVESTIGATE the player's position. Lost sight while chasing → INVESTIGATE the last known position. Otherwise PATROL at 1.5 m/s. CAUGHT within 1 m while chasing; ESCAPED at the exit. Tests: `tests/ruleset/test_ruleset_stub.gd`. **Keep the stub working.**

## 5. Interview: questions for Rickey

One at a time, multiple choice, recommended option first. Recommendations come from the Closing Time draft unless noted.

1. **How does the player escape?** (team Q1) A. Find your shoes (each spawns in one of about 8 spots), then push the emergency exit. B. Just reach the exit. C. The mock's fuses and breaker (conflicts with the GDD's inventory cut).
2. **Which modes does Ronald have?** A. Add SEEK ("I see you"), CAMP (waits at the ball-pit rim) and CATCH (stare, then jumpscare) to today's PATROL, INVESTIGATE and CHASE (a contract change). B. Keep only the three. C. The full Closing Time set, including POSE.
3. **The ball pit** (pitch rule 1): A. He never enters it. If you hide in the pit too long, he walks to the rim, faces you for 10 s (CAMP), then goes back to patrolling. B. He never enters, and that's all. C. No ball-pit rule.
4. **Hiding too long** (pitch rule 2): A. "I see you" is whispered from right behind the player's head, then he walks straight to the spot, with at least 5 s of warning before he arrives. B. Instant chase.
5. **Being seen** (pitch rule 3): A. A cue (two clown-horn honks), then a chase at 4.2 m/s; the kid runs at 3.8. B. A slower chase that you can outrun.
6. **Getting caught** (pitch rule 4): A. Within 3 m: the controls lock, he stares for 2 s in silence, then sprints at you screaming. B. Touching distance means an instant jumpscare.
7. **Losing track:** A. 2 s out of sight → INVESTIGATE the last known position. B. 5 s. C. He never gives up until you hide.
8. **More than one monster?** (team Q2) A. Ronald only in v1. B. Ronald plus statues that only look scary.
9. **Posing** (Closing Time's R5, adapted to the 3D Ronald): A. Cut for v1. B. Sometimes he freezes like a Ronald bench statue, and wakes when you get close.
10. **Speeds:** A. Patrol 1.4, investigate/seek 2.0, chase 4.2 m/s. B. Slower overall (a smaller map).
11. **Opening and ending** (team Q7): A. A short wake-up in the pit, and the intruder-reveal ending. B. Later.

## 6. Answers

*Filled in during the interview. Tuning numbers live here too.*

| # | Answer | Date |
|---|---|---|
| 1 | **C. The mock's fuses and breaker.** Collect 3 fuses, restore the breaker, then leave through the exit. This goes against the GDD's inventory cut; it's a deliberate choice (log it in `DECISIONS.md`). Needs shared values for fuses and the breaker (a contract proposal at the end of the interview). | 2026-10-14 |
| 2 | **A. Six modes:** PATROL, INVESTIGATE, CHASE, plus SEEK (the "I see you" walk to your spot), CAMP (waits at the ball-pit rim) and CATCH (the stare, then the jumpscare). Adding the three new modes is a contract change to `BoardTypes.Mode`. | 2026-10-14 |
| 2a | *(Added after Q1.)* **A. The flashlight never freezes Ronald.** If Lionel and Aiden keep the flashlight (team Q4), it's only light and makes the player easier to spot: it helps find fuses but gives you away. The mock's freeze-in-the-beam rule is dropped. Tell Lionel and Aiden (Hiding may need to publish whether the flashlight is on, for Senses). | 2026-10-14 |
| 3 | **A. He never enters the ball pit, and camps at the rim.** If the player's hiding leaks while they're in the pit, he walks to the nearest point on the rim, faces them for **10 s** (CAMP), then goes back to PATROL. No fuse is ever placed in the pit, so waiting there never wins. The pit's id comes from Hiding (`hide_spot`); Roaming finds the nearest reachable point (agree with Naomi on a `target_unreachable`-style value). | 2026-10-14 |
| 4 | **A. "I see you", then SEEK to the exact spot.** When `location_leaked` turns true, play the "I see you" whisper (from right behind the player's head) and switch to SEEK with the target at the player's spot. **At least 5 s** between the whisper and his arrival: if he's closer than that, he waits before walking. Still in the spot when he arrives → CATCH. Spot empty → INVESTIGATE around it. SEEK fires **once per visit** to a spot (Ruleset remembers the visit; it never writes Hiding's timer). In the ball pit, Q3 applies (CAMP instead). | 2026-10-14 |
| 5 | **A. A cue, then a chase about 10% faster than the player's run** (Closing Time: 4.2 m/s against 3.8; set the real number once Lionel picks the run speed). You can't outrun him in a straight line; you escape by breaking line of sight or diving into the ball pit. The cue (two clown-horn honks) plays when he enters CHASE from any other mode, so the Ruleset plays it. Tell Aiden (his Senses Q6). | 2026-10-14 |
| 6 | **A. Catch range 3 m, a 2 s stare, then a sprint.** CATCH starts when he's within **3 m** during a chase, or reaches the spot while the player is still in it (Q4). He stops, faces the player and stares in total silence for **2 s**, then sprints at them screaming; the screen cuts to black and `game_state` becomes CAUGHT when the sprint arrives. Hiding locks the player's controls while `ronald_mode == CATCH` (tell Lionel). The run then restarts. | 2026-10-14 |
| 7 | **A. 2 s out of sight, then search.** After **2 s** without SEEN during a chase, switch to INVESTIGATE at `last_known_position`: walk there and look around for about **5 s**, then PATROL. Hearing something (HEARD) uses the same search. | 2026-10-14 |
| 8 | **A. Ronald only.** One monster in v1. Ronald's numbers (ranges, times, speeds) live in a data resource (for example `ronald_rules.tres`), not hard-coded, so a second mascot later is new data, not new code. The board stays single-enemy. | 2026-10-14 |
| 9 | **B. Statue posing is in.** A seventh mode, POSE (add it to the Q2 contract change). On about **1 in 4** patrol loops, the Ruleset switches to POSE; Roaming walks him to a bench pose spot (pose spots belong to the patrol route, so Roaming picks one and ignores `target_position`, as in PATROL) and he sits frozen like a statue for **20–40 s**, then back to PATROL. If the player comes within **1 m**, he wakes (**1 s**) and goes to CHASE. Needs: bench pose spots in the level (Aiden), a seated/statue pose for the model (Naomi), optionally a real decoy statue nearby (Aiden). | 2026-10-14 |
| 10 | **A. Closing Time's speeds:** patrol **1.4 m/s**, INVESTIGATE and SEEK **2.0 m/s**, CHASE **about 10% over the kid's run** (Q5), CATCH sprint **about 8 m/s**. All of them live in Ronald's data resource (Q8) and get tuned in playtests. | 2026-10-14 |
| 11 | **C. Keep the mock's opening (waking in the ball pit), and a full intruder reveal ending.** When the player escapes, the lights come on and a real man in a cheap clown suit is standing where Ronald was. Non-interactive, a few seconds, then the win screen. Needs a second character model (a man in a cheap clown suit); decide who makes it with Naomi and Aiden. | 2026-10-14 |
| 12a | *(Added after Q1.)* **B. Ronald is dormant until the first fuse,** like the mock. The opening stretch is safe exploration; picking up the first fuse wakes him into PATROL. Needs a way to say "not active yet" (proposed: an eighth mode, DORMANT, in which Roaming keeps his body hidden and still). | 2026-10-14 |

## 7. Suggested build steps (starting point for `PLAN.md`)

1. **Test scene:** copy the sandbox to `systems/ruleset/test/ruleset_test.tscn`.
2. **Rules as a plain class:** `RonaldRules` (`RefCounted`) takes the board's inputs and returns mode, target and speed. Test every transition.
3. **The `RulesetSystem`** (`SimSystem`, id `ruleset`): reads the board, calls `RonaldRules`, writes the board.
4. **Contract change** for the new modes (and `target_unreachable` with Naomi), then the SEEK, CAMP and CATCH rules.
5. **Win and lose:** `game_state`, the stare-then-jumpscare timing, lose and win screens, and restart.
6. **Escaping,** per Q1.
7. **`systems/core/main.tscn`:** the level, the Director with the real systems, and UI; point `project.godot` at it once it's playable.

## 8. Tests to write

- Every mode change: seen → chase; heard → investigate; leaked → seek or investigate; lost for N s → investigate; at the target with nothing found → patrol.
- Catch distance and timing; escaping ends the run; nothing changes after the run ends.
- The ball-pit case: a target inside the pit → CAMP, never an endless walk.
- One-off cues ("I see you", the honk) fire once per event, not every frame.

## 9. Seams and risks

- **Seam 2 breaks first** (GDD, and Closing Time §6): "never enters the pit" plus "comes to your spot" means Ronald is sent somewhere he can't go. Agree with Naomi on `target_unreachable` (or something like it) before building SEEK.
- **Don't move Ronald yourself.** Only Roaming writes `enemy_position`.
- **You own the foundation too.** Treat contract changes as their own commits, and keep every stub green.

## 10. Reuse from the mock

`scripts/stalker.gd` (the catch distance and the `caught` flow) and `scripts/game.gd` (the phases, win and loss, restart, the pause menu, home screen and options). The game flow and menus are a good start for the lose and win screens.

## 11. Done means

`docs/WORKFLOW.md` "Done means".

Lionel-authorized integration correction (2026-10-16): safe table hiding immediately returns CHASE/INVESTIGATE to PATROL, ignoring stale detection while protected. SEEK waits the full seek_min_warning (5 s) before moving, regardless of distance; the F5 actor also remains stationary throughout the camera turn and voice. Ball-pit CAMP behavior remains unchanged.
