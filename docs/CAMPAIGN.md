# Campaign, saving, and paper art

This supersedes the original seven-day arcade-run proposal. Current prototype scope is described here; numerical balance and the boss's final identity/art remain provisional.

## Twelve weeks and a final encounter

The main campaign contains **12 weeks**, followed by **The North Wind**, a separately named boss encounter. The UI never calls it Week 13. Temperature drops 2°C each week from 22°C to 0°C; the finale shows −2°C. These temperatures provide seasonal feedback alongside clothing, cooler lighting and pressure-driven warning snow. Clothing is cosmetic and does not alter speed or energy.

Each of the twelve main weeks has its own outfit in the wardrobe atlas: T-shirt/shorts, light neck layer, vest, long sleeves, sweater, padded vest, hoodie, windbreaker, thicker jacket/gloves, hat/scarf, winter coat, then the heaviest bundled outfit. Victory switches to a happy T-shirt/shorts celebration; defeat switches to a separate sad, bundled pose. A basic distance-driven cutout leg rig and blower vibration now animate these outfits. Artist-separated limb rigs and bespoke ending animation remain production work.

The prototype boss is a mischievous paper cloud. Its repeating cycle gives 1.5 seconds of warning, then a 2.5-second downward gust with quicker shedding and snow, followed by a 3.5-second recovery window. All detached leaves still come from the actual canopy: the boss cannot invent extra leaf IDs or award repeated rescue points. Snow is a readable visual cue; the gust is the mechanical hazard. Final enemy art, sound and tuning need playtesting.

The cumulative winter-pressure budget and persistent bare spots currently carry across all weeks. This makes later levels demanding; checkpoints permit repeated attempts from the same starting state. Difficulty curves and the budget must be tuned for the longer campaign rather than assumed balanced from the earlier prototype.

## Local campaign flow

Main menu → three named gardens → new campaign or saved checkpoint → week → automatic save → workshop → next week. Week 12's workshop opens the final encounter; defeating it saves campaign completion and opens the sunny ending. Losing opens Retry Current Level and Main Menu.

- Exactly three slots, each with an editable name of up to 18 characters. Names are plain display text, never file paths.
- New campaigns are created in empty slots. Replacing an existing campaign requires an explicit confirmation; renaming does not replace progress.
- A level-start checkpoint contains the current week/finale, score, rescue/miss totals, equipment, point ledger, canopy occupancy, shedding order and exact random state. The battery and walking path start fresh.
- Completing a level saves its workshop boundary and rewards once. Buying/reallocating equipment saves that workshop state. Starting the next level saves the new retry checkpoint.
- Losing never overwrites the prior level-start checkpoint. Retry restores it completely, including score and foliage, so attempts cannot accumulate rewards or damage.
- Foreground app switching pauses the current in-memory attempt. Reloading or process termination returns to the latest saved boundary; unfinished level progress is intentionally lost.
- No accounts, cloud synchronization or server storage. Browser saves belong to that browser and origin; clearing site data removes them. Native saves are local to the install.

Storage uses versioned JSON. Native installs use a temporary-file replacement and recovery backup under Godot's `user://` directory. Browser exports use atomic, synchronous `localStorage` value replacement (`snow.campaigns.v1`) plus a separate backup value, rather than depending on virtual-filesystem synchronization. Checkpoints validate level bounds, phase, equipment costs, leaf uniqueness/conservation, combo state and exact random-state encoding. Unsupported/malformed data is retained separately rather than silently trusted; valid other slots and backups remain available. Unavailable storage or quota failures produce a visible message. Actual browser reloads validate persistence. Clearing browser/site data still removes local saves; these are not cloud backups.

Native campaign files are under Godot's `user://` storage, outside the checkout; browser saves are local to the page's origin. The three campaign slots are distinct from the three separate local per-difficulty high-score tables.

## Pause and exit contract

Escape or the top-right pause button pauses **any screen**, including the workshop, naming flow, art preview and both ending timelines. The previous screen and its controls are retained and restored on Resume. Held movement/blower input clears on pause.

Switching apps/tabs, hiding the document or losing window focus automatically pauses. Focus returning never resumes it. Native window-close and in-game Exit show: **“Are you sure you want to exit? Current level progress will be lost.”** Completed progress stays saved. Browser close/reload uses the browser's standard confirmation where supported; browsers control that wording and may suppress the dialog. Saving boundaries, rather than relying on a close dialog, protects completed progress.

## Art correction

The composition uses **one central magical tree**, using a transparent adaptation of the richly textured, asymmetric ancient tree attached by the user. It is not the later simplified line-style tree, a mirrored pair, or a silhouette reconstructed from little branch polygons. The background frames a quiet central clearing, with houses moved to the far sides. Twig attachment metadata is authored against actual opaque points in that image; leaf stems meet the wood and blades face outward, rather than receiving arbitrary random rotations.

Its leaves hold autumn in the valley: the Season Tree is a provisional name for this visual mythos. The caretaker moves in front of the roots without collision, and the North Wind threatens the same focal tree.

All 48 slot identities are retained so existing saved weeks, builds and missing-leaf counts survive the composition change; positions map onto the new tree. The same paper leaf texture appears attached, in flight and in piles. Smooth linear filtering with mipmaps reduces aliasing as large cutouts scale down. There is no integer pixel snapping or deliberate pixel-art filter. Phone-size screenshots and moving builds, not isolated source images, determine whether the result is acceptable.

## Upgrade pacing

The twelve main weeks award one point each. First-tier nodes cost one; second-tier nodes cost three additional points. Each branch costs four total, so all three can be finished before the boss while the order creates different mid-campaign builds. The finale awards no unused point. This revises the old seven-day economy; values remain provisional.

## Later environment polish — planned, not implemented

1. Slow layered cloud drift and very subtle background weather, independently pausable.
2. Occasional squirrels crossing the path or climbing trunks. Keep them behind gameplay leaves, noncolliding and outside essential touch zones; no fake pickups or score effects.
3. A possible night/storm week with cooler paper layers, window lights, rain and distant lightning. Choose its placement after the twelve-week pacing test; the prototype does not yet have a night level.
4. Reduced-motion/effects and reduced-flash options must preserve readable leaf silhouettes and warnings. Lightning must be restrained and replaceable with a gentle sky change. Ambient effects must not alter gameplay physics or future ranked scoring.

Profile the effects on minimum phones, cap their frequency/particles and pause them with gameplay. Do not trade touch responsiveness or falling-leaf contrast for scenery activity.

New gardens choose a fixed difficulty. Existing saves migrate to Blustery. Campaign checkpoints now retain a stable identity and difficulty; a garden contributes one best terminal result to its difficulty’s table, with better retries replacing the earlier entry. See [scores and licenses](SCORES_AND_LICENSES.md).
