# Ambient world

Implemented: paper wildlife, thirteen weekly atmosphere profiles, painted overcast/dusk/night backgrounds, gentle fog, rain, breeze rustling and background sun rays. Creatures stay behind the playable path and foliage. The original proposals below explain the art direction; native-device performance and the subjective mix still need playtesting.

## Seasons and wildlife

- Keep the planned squirrels: occasional ground crossings and short climbs up/down the trunk.
- Add a rabbit whose coat gradually changes from summer brown to winter white over the twelve weeks. Use several painted coat stages or a soft masked transition, not an abrupt whole-sprite colour swap. This quietly supports the clothing and seasonal progression. Restore its summer appearance during the warm victory; use its winter coat in the snow-covered loss scene.
- An owl appears during nighttime scenes, perched clear of useful branch gaps.
- On a randomly selected **full-moon night only**, a wolf may replace the rabbit. A bat may appear on those nights too. Keep the encounter rare, atmospheric and non-hostile. The owl can remain; daytime scenes never select this variant.

## Time of day and sky

Weeks **1 and 2 are daytime**. Vary other weeks between daylight, evening and night; do not make every later week night. Week 12 and the final North Wind encounter should preferably be daytime too, with darker, thicker clouds for the finale. Treat those late-daytime choices as art direction to validate, rather than a restriction on the earlier night/storm idea.

Move the sun to different plausible positions between daylight weeks, coordinating the painted sky, light direction, haze and shadows. Nighttime scenes may show a moon with a randomly chosen crescent/phase and orientation. Include an explicitly selectable, uncommon full-moon phase so the wolf/bat variant can actually occur. Cloud cover may obscure the moon visually, but the selected phase determines the variant. Reserve a night storm/lightning scene among the middle weeks.

The current backdrop has baked lighting, so this needs separate sky/sun/moon/cloud layers and artist-authored daylight/dusk/night grading. Merely placing a moon over the current sunny painting is not the intended result.

## Small reactions

Animals mostly continue their quiet routines. A blower held directly beneath the owl can trigger one brief wing beat, followed by a reaction cooldown. Similar restrained ear/head turns or a short rabbit hop are possible. Avoid constant startle loops. Creatures never block movement, detach/capture leaves, affect score, alter danger, or reveal hidden gameplay information.

## Implementation and review

Use a separate cosmetic random seed, independent of the leaf simulation. Select a week's sky/phase/wildlife variant at its boundary and retain it for retries/reloads; store the cosmetic seed or selected variant when this feature ships. Cosmetic randomness must not change difficulty or future ranked fairness. Pause ambient animation and reaction timers with the game; suppress extra motion and lightning in Soft effects. Keep silhouettes and contrast subordinate to airborne leaves and test on physical phones. Cap simultaneous creatures and avoid unnecessary animation work offscreen.

## Runtime and review

`world_profile.gd` derives each week's cosmetic variation from the already-saved campaign ID and week, independently of the gameplay RNG. Retries/reloads keep the chosen sun position, moon phase and rare wildlife. The sequence is sunny, sunny, overcast, dusk, rain, night, sunny, night storm, fog, dusk, rain, sunny, then the cloudy daytime North Wind.

`ambient_world.gd` draws behind the tree; separate paper paintings replace the sunny valley for overcast, twilight and night. Sun/moon, paper storm clouds, soft gradient fog, stars, rain and feathered rays form independent layers. Rays remain behind the tree/player. Wind bends independently phased leaves throughout the crown at 15 Hz by less than a pixel, with stronger intermittent finale rustles; it never changes an attachment, force or miss. Pause freezes all clocks; the internal reduced-effects mode stops extra animal/rustle motion and suppresses lightning.

Four textured paper animation atlases now contain seventy-two poses: sixteen squirrel frames, sixteen front-view owl frames, three eight-frame rabbit coats, and eight poses each for the wolf and bat. Rabbit coats crossfade gradually. Full moon (one of eight phases, night only) replaces the rabbit with a wolf and bat. At most three species appear together. A directly held blower can trigger one owl wing beat per twelve seconds; creatures never interact with leaf physics.

Explore the seasons now has previous/next week arrows to review all thirteen atmospheres, alongside the existing warning, winter and victory previews. `tests/test_ambient_world.gd` covers persistence, gameplay RNG isolation, pause, coat blending, rarity and bounded actors; `tests/browser_ambient.py` exercises the real scene controls and pause/resume. Browser captures: [rain](images/ambient-rain.png), [moonlight](images/ambient-night.png), [sunlight](images/ambient-day.png).

## Branch residents and animal routines

The unchanged tree now has a fully planted paper meadow bank in front of its lower root fan. Bark draws first, then tree residents, then the meadow; foliage and the player draw above them. Ground visitors stay in the valley.

The owl chooses among verified painted boughs, favoring fewer nearby occupied leaf positions at the level boundary. It remains on that branch through the attempt while leaves can obscure it naturally. Five front-view head directions track the player, with blinks, a relaxed pose and an eight-frame perched wingbeat. Occasional flaps happen independently of blower reactions; reaction cooldowns and all animation clocks freeze on pause.

The squirrel runs to the trunk, climbs the painted bark path, makes a short curved jump to a bough, and stays there. Four running, four climbing and four jumping poses lead into alert/nibbling frames. It does not loop back down the trunk. Rabbits alternate four-frame hops and grazing poses; after leaving the screen they return facing the other way. Coat changes crossfade matching animation phases. Wolves use six trotting and two sniffing poses; bats use eight wing phases. Stable source-space anchors and shared body scale keep wings and ears from resizing the animal between frames.

In nighttime Explore the seasons scenes, **Full moon** resets the cosmetic preview so the wolf and bat can be reviewed directly. It does not change the campaign's selected moon or its save. `tests/test_wildlife_polish.gd` covers bark placement, sparse perches, path continuity, complete routines, gaze, frame variety, coat blending and preview isolation. `tests/browser_wildlife_polish.py` observes real frames and inputs through climbing, landing, return travel, owl gaze and rare-visitor playback.
