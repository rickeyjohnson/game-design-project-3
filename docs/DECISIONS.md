# Decisions log

Why things are the way they are. **Append; never rewrite an old entry.** To reverse one, add a new entry that says it supersedes the old one. Proposals that need sign-off go under "Proposed".

## Decided

**D-001 · 2026-10-09 · Rickey · Engine and web build**
Godot 4.7.2 standard, GDScript, Compatibility renderer. The web export goes to `docs/index.html` with thread support off, and GitHub Pages serves `main`, `/docs`, at https://rickeyjohnson.github.io/game-design-project-3/. `docs/index.pck` stays under 100 MB (Aiden's rule). *Affects:* everyone (`AGENTS.md` Rule 7).

**D-002 · 2026-10-09 · Rickey · Blackboard architecture**
The four systems talk only through one shared `Blackboard`, with one writer per value, and a `Director` that runs them in a fixed order (Hiding → Senses → Ruleset → Roaming). This replaces Project 2's signals and direct method calls so all four can build in parallel against stubs. *Affects:* everyone (`docs/ARCHITECTURE.md`).

**D-003 · 2026-10-09 · Rickey · Ownership is split by the four GDD systems**
Everything belongs to one of the four systems: Hiding (Lionel) gets the player body and hiding spots; Ruleset (Rickey) gets win/lose and the shared foundation in `systems/core/`; Roaming (Naomi) gets Ronald's body and pathfinding; Senses (Aiden) gets the level and lighting. *Affects:* everyone (`AGENTS.md`).

**D-004 · 2026-10-09 · Rickey · No branches; push only what works**
Everyone works on `main`. Pull with rebase before working, commit small, and push only after the full suite passes and the change runs locally. *Affects:* everyone (`AGENTS.md` Rule 6). **Superseded by D-012.**

**D-005 · 2026-10-09 · Rickey · Aiden's mock game is reference only**
The mock (`scripts/`, `scenes/`, `shaders/`, `tools/`) stays as a playable reference and as the current web build. The real game is built in `systems/`, borrowing the mock's assets, level import and performance tricks. *Affects:* Aiden especially.

**D-006 · 2026-10-09 · Rickey · Sources and precedence**
The submitted GDD, the Closing Time draft and the pitch notes are all source material (`docs/reference/`). Precedence: decisions here > GDD > Closing Time > pitch notes. Closing Time's rules and numbers are the recommended starting answers in each interview. *Affects:* everyone (`docs/GAME_SPEC.md`).

**D-007 · 2026-10-09 · Rickey · Ronald's look: PS1-style McDonald's clown**
Ronald is a low-poly, PS1-era horror version of Ronald McDonald (yellow jumpsuit, red-and-white striped sleeves, red hair, white face paint, red smile), from the reference image Rickey shared. This supersedes Closing Time's flat cardboard cutout. *Affects:* Naomi (Ronald's body), Rickey (rules that depended on the cutout), `docs/ART.md`.

**D-008 · 2026-10-09 · Rickey · A smaller McDonald's + PlayPlace map**
The map is smaller than the mock's and reads more clearly as a McDonald's with a PlayPlace, following the room order of Aiden's final floor plan. The walk-in freezer and back hall are proposed cuts. *Affects:* Aiden (the level), Naomi (patrol routes), Lionel (hiding spots).

**D-009 · 2026-10-09 · Rickey · System docs live with the code**
Each system keeps its docs next to its scripts: `systems/<system>/SYSTEM.md` (context, interview, build steps) and `PLAN.md` (written after the interview). This is lighter than Project 2's per-feature folders. *Affects:* everyone (`docs/WORKFLOW.md`).

**D-010 · 2026-10-09 · Rickey · Tests: GUT 9.7.1**
GUT is copied from Project 2 into `addons/gut/` and run headless (`AGENTS.md` Rule 5). The editor plugin isn't enabled, so `project.godot` is unchanged. It's excluded from the web export. *Affects:* everyone.

**D-011 · 2026-10-09 · Rickey (Claude Code) · Starting values go in `setup()`**
The first sandbox run showed Ronald seeing the player on frame one: Senses read his default position before Roaming had placed him. The Director now runs `setup(board)` for every system, in order, before the first frame. `tests/core/test_stub_pipeline.gd` guards this. *Affects:* everyone writing a system.

**D-012 · 2026-10-14 · Rickey · A branch per change, PRs into `main` (supersedes D-004)**
The team prefers branch work. Each change gets a short-lived branch cut from `main` (`<system>/<NN>-<slug>`), merged through a PR once the suite passes and the game runs. Nobody commits to `main` directly; no stacked PRs. Contract and `systems/core/` changes need Rickey's approval. The web export is never committed on feature branches (binary conflicts): whoever merges a player-visible change re-exports from `main` on a `web/<date>-export` branch. *Affects:* everyone (`AGENTS.md` Rules 6 and 7, `docs/WORKFLOW.md`).

**D-024 · 2026-10-16 · Rickey · No team process rules (supersedes D-005, and the sign-offs in P-001)**
Everyone was working their own way, so the process rules are gone: no folder ownership limits, the mock isn't reference only, board changes need no sign-off (P-001 and later proposals count as adopted), and interviewing and planning before code are optional. Kept: talk through the board, tests pass before merging, a branch and PR per change into `main`, the web export rules, Godot 4 syntax. *Affects:* everyone (`AGENTS.md`, `docs/WORKFLOW.md`, `docs/BLACKBOARD.md`).

## Proposed (need sign-off)

**P-001 · 2026-10-09 · Rickey · Blackboard contract v0.1**
`docs/BLACKBOARD.md` as written. Each owner signs here after reviewing their values. Changes found in interviews come back as their own proposals.
- [ ] Lionel (Hiding)
- [ ] Rickey (Ruleset)
- [ ] Naomi (Roaming)
- [ ] Aiden (Senses)

**P-002 · 2026-10-14 · Rickey · Contract v0.2: what the Ruleset interview needs**
From `systems/ruleset/SYSTEM.md` §6. **Adopted 2026-10-16** with no sign-offs (D-024).
- **`BoardTypes.Mode` gains five modes (eight in all):** `DORMANT` (not active yet; Roaming keeps his body hidden and still), `POSE` (frozen on a bench like a statue), `SEEK` (walking to the player's leaked hiding spot after "I see you"), `CAMP` (waiting at the ball-pit rim) and `CATCH` (the stare, then the sprint). In `DORMANT` and `POSE`, Roaming ignores `target_position` (as in `PATROL`); in `POSE`, `at_target` is true once he's seated.
- **New Hiding values:** `fuses_collected: int` (0–3) and `breaker_on: bool`, written by Hiding because the player does the picking up. Read by the Ruleset (wake Ronald at the first fuse; escaping needs the breaker) and by display code (HUD, lights).
- **New Roaming value:** `target_unreachable: bool`, true when Ronald can't reach `target_position` and went to the nearest reachable point instead (the ball pit). Read by the Ruleset (switch to CAMP).
- **A rule, not a value:** Hiding locks the player's controls while `ronald_mode == CATCH`.

## Open questions

The team-level ones are in `docs/GAME_SPEC.md` §9 (Q1–Q7). The ones for each system are in that system's `SYSTEM.md` §5.

**D-013 - 2026-10-15 - Lionel - Approved current F5 gameplay revision**
Lionel explicitly approved table-only hiding, fixing the black table view, a timeout voice, chase music, moving Ronald animation/taps, faster battery drain, and double speed outside flashlight illumination. Apply this to the integrated legacy F5 game without changing the shared board or teammates' stubs. Table entry must avoid the imported central pedestal. Battery drain is doubled to 1.68 percent/s; Ronald moves 3.3 m/s outside the flashlight beam and still freezes within it. Treat new audio/animation as presentation of existing leak/chase/movement states. This supersedes the earlier active ball pit/booth/tube hiding selection for now; it does not remove the level scenery or reusable spot types. Implementation and human playtest notes live in Lionel's PROGRESS section and systems/hiding/PLAN.md. No web release requested.

**D-014 - 2026-10-15 - Lionel - Horror presentation events in the current F5 game**
Lionel requested a catch jumpscare and scream, random face/static GUI warnings saying you better hide, and a tall black bloody-smile figure behind the player that vanishes on observation. Implement these as presentation only: existing Ronald model for the face, a non-colliding apparition with no damage or AI, and local event timers. Keep the original Ronald animation and shared board contract. Pause cancels the overlays; existing Reduced Motion suppresses random face bursts and catch jitter. No additional enemy system or web release is introduced. Tuning and validation are recorded in systems/hiding/SYSTEM.md and Lionel's PROGRESS section.

**D-015 - 2026-10-15 - Lionel - Persistent apparition, chase static, and temporary timeout sprint**
Lionel requested the figure remain until seen, a GUI flash on seeing it, chase-screen static, and a timeout cutaway watching Ronald turn, say I see you, and sprint briefly before restoring the player view. This supersedes the unseen apparition timeout in D-014. The sprint boost and faster playback are limited to the 0.75 s cinematic sprint; normal speed/animation return afterward. The cutaway uses a separate camera and cannot catch the player while control is away; 0.6 s reaction grace follows return. Pause/finish cancel and restore state. This remains the explicitly requested legacy F5 integration with no blackboard-contract or shared-system changes.

**D-016 - 2026-10-15 - Lionel - Actual catch leap; warning flashes only after spawn**
Lionel replaced the catch GUI with a real cutscene of Ronald jumping into the camera and filling the view. Use the existing live actor, preserve the scream, and delay the normal death screen until the 3D leap ends. Warning portraits now say you better run and appear only occasionally after Ronald spawns, not during catches or apparition reveals. This supersedes the catch-GUI and turn-triggered warning choices in D-014/D-015. Both timeout and catch cutscenes must work after normal in-game spawning; the live integration preview verifies first-fuse spawn, real hide timeout and AI catch callback. No shared blackboard change or web release.

**D-017 - 2026-10-15 - Lionel - Hidden light immunity, investigation, rarer screams, and grapple escape**
Lionel requested the hidden flashlight not affect Ronald, continued checking of discovered hiding areas, less frequent warning scares with scream, and punishment for holding a face beam too long. Use 45-80 s warning spacing; a continuous exposed 4 s beam triggers jump/pin with 12 distinct Space presses in 4 s. Win gives a shove and 3 s escape window; fail plays a bite and death. This is the explicitly requested legacy F5 integration and overlaps legacy enemy rules/movement as already audited; teammate system implementations and shared contract stay unchanged. Tuning is recorded in Lionel's SYSTEM section 6 and live validation in PLAN/PROGRESS.

**D-018 - 2026-10-15 - Lionel - Final hiding/scare revisions and PR handoff**
Lionel's later requests supersede the timing/animation/voice details of D-013 through D-017: original imported animation and original I see you audio; six-second continuous exposed beam before pounce; 50% warning chance per thirteen eligible seconds after spawn; 35% figure chance per eligible turnaround with three-second cooldown. The figure matches the player's height, lunges toward the live camera and disappears without control takeover, and plays Ronald's current jumpscare scream on spawn. After the timeout line finishes, show 0.5 s of Ronald running, then restore player view/control while he continues to the captured reachable spotted area. Grapple win restores a charged flashlight and usable toggling. The existing battery GUI includes live R / Reload Batteries(amount/maxamount), with maximum derived from the four obtainable spare cells. All seven standalone and five booth tables now support hiding, with three additional prep-counter covers, clear per-furniture cameras and nearby E / HIDE markers; ball-pit hiding remains disabled. These are authorized legacy F5 changes, not new blackboard values or teammate-system implementations. Full feature/revision/impact record is systems/hiding/CHANGELOG.md. Lionel explicitly requested documenting all changes and creating a PR into main; merging and web export are separate work.

**D-019 · 2026-10-14 · Rickey (Ruleset interview) · Escape: 3 fuses, the breaker, then the exit**
The player collects 3 fuses, restores the breaker, then leaves through the exit, as in the demo. This deliberately goes against the GDD's inventory cut (decisions outrank the GDD, D-006): the only "inventory" is a fuse count, with no storage or crafting. Ronald stays dormant until the first fuse is picked up. Answers GAME_SPEC Q1. *Affects:* Lionel (fuse and breaker interactions), Aiden (placing the fuses, breaker and exit; lights come on with the breaker), Naomi (Ronald's hidden, dormant body).

**D-020 · 2026-10-14 · Rickey (Ruleset interview) · Ronald is the only monster**
One monster in v1. His numbers live in a data resource, so a second mascot later is new data, not new code. The board stays single-enemy. Answers GAME_SPEC Q2. *Affects:* everyone.

**D-021 · 2026-10-14 · Rickey (Ruleset interview) · The flashlight never freezes Ronald**
The demo's freeze-in-the-beam rule is dropped. Whether the flashlight exists is still team question Q4 (Lionel and Aiden); if it stays, it's only light and makes the player easier to spot. *Affects:* Lionel, Aiden.

**D-022 · 2026-10-14 · Rickey (Ruleset interview) · Opening and ending**
Keep the demo's opening (waking up in the ball pit). When the player escapes, a short non-interactive reveal: the lights come on and a real man in a cheap clown suit stands where Ronald was. Needs a second character model; who makes it is open. Answers GAME_SPEC Q7. *Affects:* Naomi and Aiden (the model), Rickey (game flow).

**D-023 · 2026-10-16 · Rickey · The F5 game runs the Ruleset**
Ronald in the F5 game and the web build now does what the Ruleset says. `scripts/game.gd`'s Director holds `LegacyHiding` (Lionel's `HidingSystem` plus the game's fuses, breaker and exit), `LegacySenses` and `LegacyRoaming` (stand-ins built on the mock), and the real `RulesetSystem`; the run ends on the board's `game_state`. The mock Ronald's own brain stays in `stalker.gd` but is off while `driven`, so the flashlight freeze and the 6 s beam pounce from D-013 to D-018 no longer happen (D-021). Lionel's cutscenes, voice, chase music and catch leap stay as presentation. *Affects:* everyone; Lionel reviews the updated `tests/hiding/test_main_hiding.gd`; Aiden and Naomi replace the stand-ins with their systems; the smoke test's checks for the old brain are updated to the rules.

### 2026-10-16: Lionel-authorized chase and warning repair
Safe table hiding immediately ends pursuit/search and resumes patrol. SEEK now waits the full existing 5 s warning instead of subtracting travel time. F5 roaming honors the actor's cinematic turn/voice hold so board movement cannot bypass it. Lionel explicitly authorized ruleset and shared integration edits; no board contract change. Ball-pit CAMP remains unchanged.
