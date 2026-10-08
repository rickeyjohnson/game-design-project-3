# Project 3 Checkpoint: Game Design Document

> Text transcription of [`Project 3 Checkpoint - Game Design Document.pdf`](Project%203%20Checkpoint%20-%20Game%20Design%20Document.pdf), the version the team submitted. The PDF is the source of truth; this copy exists so tools and agents can read it. Bracketed names are the section authors.

October 7th, 2026
COMP440 Game Design

## a. Core Loop in one sentence

The player has to avoid monsters while trying to escape McRonald's (McDonald's).

## b. The Four Systems [Rickey]

1. Lionel - Hiding From Enemies: whether the player is hidden and where.
2. Rickey - Enemy Ruleset: each mascot's/monster's rules.
3. Naomi - Roaming Enemies: each mascot's position and patrol state.
4. Aiden - Enemy Senses: what each mascot can see and hear: enemy_position, enemy_movement.

## c. The Seams

1. The seam occurs where the Hiding from Enemies system and Enemy Senses system exchange the player's visibility and detection states. One system determines how hidden the player is, while the other reads that information to decide how the enemy should react.
2. Roaming Enemies must adhere to the Enemy Ruleset. The Enemy Ruleset writes the logic for the central monster, and the Roaming Enemies must read it and decide how to proceed within those constraints.

## d. Art Direction

- **The world, in one sentence.** A regular McDonald's that has a play place ball pit in a normal world.
- **Palette** [Lionel]. Five colors with hex values. One is the accent, and it appears in almost nothing.
  - `#731F24`
  - `#B39839`
  - `#C9C1A5`
  - `#242522`
  - `#91CBA5`
- **Camera and framing** [Lionel]. The angle will be viewed from a first-person perspective. Everything will appear larger than the character due to being the size of a child. Tight framing inside the play tubes and ball pit limits visibility, while views beneath tables let the player watch roaming mascots from hiding spots.
- **Light** [Aiden]. Dark and cold, with bright white or orange lights towards or on the ceiling to lighten areas that aren't dark. A mixture of both hard and soft lighting and no filling in of shadows.
- **Edge and detail** [Naomi]. The player character is the central subject, with the small amount of lighting coalescing in front of them. The rest of the environment is warped and stretched in the darkness, making the subject (and the viewer, by extension) feel small and confused. Detail exists right in front, but rapidly fades further out, leaving monsters and furniture alike as vague silhouettes, their vagueness utilizing the full extent of the viewer's imagination.
- **Mood, in three words** [Aiden]. Grim, Anxiety, Hysteria.

## e. Scope [Lionel]

**What is in.** Hiding System: the system tracks whether the player is hidden, which hiding spot they occupy, and how long they have stayed there. There will also be a limit to how long a player can hide until the location is leaked to the enemy.

**Three cuts**

- **Combat system:** No weapons or fighting; the player survives by hiding and escaping.
- **Inventory and crafting system:** No item storage, material collection, or crafting.
- **Additional locations:** The game takes place entirely inside one McRonald's restaurant; outdoor areas and other buildings are cut.

## Which seam breaks first

> Transcriber's note: the PDF has no heading here. This paragraph follows the cuts, in the position of the template's "Which Seam Breaks First" section.

Roaming Enemies must adhere to the Enemy Ruleset. The Enemy Ruleset writes the logic for the central monster, and the Roaming Enemies must read it and decide how to proceed within those constraints.
