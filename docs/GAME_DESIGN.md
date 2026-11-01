# sNOw — game design

Status: initial design proposal. User requirements are recorded below; later sections recommend concrete defaults for a first playable version. Validate those defaults through prototypes and playtests.

An initial [technical art prototype](PROTOTYPE.md) implements part of this design. That document distinguishes working features from production plans and unvalidated platform assumptions.

## Core concept and requirements

You are a stubborn caretaker trying to prevent winter from arriving. Armed with a leaf blower, you move left and right beneath a single magical tree and blow its leaves back into the canopy. Leaves swirl through the air, collect around your feet when missed, and slow your movement as their piles grow.

The game must provide:

- A single-screen playfield designed for a phone held vertically.
- Android, iOS, and browser play.
- A retro, cartoony look with modern atmosphere, including lighting and fog.
- A title treatment emphasizing the stylized **NO** in **sNOw**.
- A welcoming main menu and three difficulties, each with separate high scores.
- Weeks as levels, with increasing autumn colour and challenge.
- Between-week upgrade tree: better boots, electric blower power and battery improvements, with equipment-weight versus agility tradeoffs.
- A loss sequence: the character looks skyward, clouds roll in, and snow covers the scene.
- A victory sequence: bright sunshine and blooming flowers show that winter has been prevented.

The paper-cut direction and between-week upgrades are selected features. Exact rendering implementation, upgrade balance, scoring, and temporary pickups remain design choices. The defaults below make a bounded, testable first version.

## The season tree — working mythos

One ancient tree, provisionally called the **Season Tree**, governs the seasons in the valley. Its leaves hold the last warmth of autumn; when the crown becomes bare, winter takes over. The caretaker uses a very ordinary electric blower to keep an extraordinary tree alive, making the modern rural setting and magical premise work together. The North Wind tries to strip its leaves in the finale. Victory restores sunlight and flowers around that same tree. The exact name and story presentation remain provisional; keep the premise visual rather than adding lengthy exposition.

## Player experience

An approachable opening gives way to increasingly frantic, readable leaf juggling. The fun comes from positioning beneath a falling cluster, catching it in a gust, and watching it click back into an empty branch position. The player should understand a miss immediately, recover from small mistakes, and see why a run ended.

Keep the camera fixed. No scrolling world, platforming, jumping, combat, or off-screen objectives. Seasonal changes, character reactions, and animated scenery make the same small space feel alive.

## Scene and visual direction

Selected creative direction: **Paper & Lanterns**, following the six-style comparison and four-state seasonal mockup review. Build illustrated 2D gameplay from layered cut-paper scenery, fibrous textures, folded edges, dimensional shadows, and warm backlighting. Use rounded silhouettes, restrained animation, and slightly exaggerated proportions. Retro character comes from shape language and timing; strict pixel art is not a requirement. The concept images establish mood, not production-ready sprites or a final HUD.

Place one large, naturally asymmetric textured tree as the central focal point, open air around its crown, and the character and accumulating leaves along the bottom. The character runs in front of the trunk and roots; they are scenery, not movement obstacles. Keep trunks, branches, and foreground props from hiding catchable leaves. Reserve the bottom safe area for controls and the top for a compact HUD.

Use a relatable modern rural setting: ordinary houses, wooden fences and optional solar panels, with distant forest and small mountains. No castle, medieval spires or stone bridge. Render the magical gameplay tree as one complete textured bare-tree sprite separately from the scenery, and place all their foliage as independent paper leaves. Attached, falling and piled leaves share the same textured cut-paper asset. The tree's visible emptiness reflects actual missing leaves, especially late in a struggling run; never paint a permanently full canopy into the backdrop.

Create depth with overlapping scenery planes, contact shadows, soft light shafts, a gentle canopy glow, and sparse fog. Fog stays behind important action or uses very low opacity. Colour and contrast must distinguish leaves from the backdrop, including during orange/red late weeks. Leaf shape, motion, and markings supplement colour cues.

The mood transitions from late-summer gold through orange autumn to a blue-grey winter threat. Victory restores a warm, vibrant scene. The logo's **NO** could resemble a hand-painted protest stamp or two oversized frosty letters crossed by a warm gust; keep a legible plain-text version for small screens and accessibility.

True 3D models in a fixed 2D environment remain an optional visual experiment. Do not require model rigging, real-time 3D foliage, or a 3D physics stack for the first version. See the technology and art gates in the development plan.

## Controls

### Portrait touch default

- Left thumb: a two-direction pad in the lower-left safe area. Holding a direction moves; releasing stops. Sliding between directions changes movement without lifting.
- Right thumb: a large blower button in the lower-right safe area. Hold to blow; release to recharge.
- The nozzle points mostly upward. Movement gently biases the gust left or right; while stationary it recentres. A visible wind cone communicates the affected space. Prototype this before adding manual aiming.
- Movement and blowing work simultaneously with two touches. Track touches independently, cancel held inputs on focus loss or interruption, and never leave a button stuck after a touch leaves the screen.
- The pause button has its own top-corner target, outside the main play area. Use generous targets, at least roughly 48 logical pixels, adjusted for device density and safe-area insets.

This gives the player two deliberate choices—where to stand and when to blow—without requiring precise aiming on a small screen. If playtests show insufficient control, compare an optional right-thumb aim pad with the simpler default before changing the control scheme.

### Browser and accessibility

- Keyboard: A/D or Left/Right to move; Space to blow; Escape to pause. Enter confirms menu choices. Support keyboard focus and visible selection in menus.
- Mouse: pointer-operated direction and blower buttons provide a fallback; keyboard is the preferred desktop gameplay input.
- Offer an optional toggle-blower setting for players who cannot comfortably hold a button. Apply the same energy and recharge rules.
- Provide independent music/effects volume, reduced motion, reduced flashes, and optional haptics where available. Communicate charge, danger, and combos visually as well as audibly.
- Portrait is the intended playfield on every platform. On wide browser windows, centre it with side margins. On landscape phones, show a rotate hint with a usable portrait canvas; pause during disruptive resizing. Do not depend on browser orientation locking.

## Core simulation and game rules

### Leaf lifecycle

Each run starts with a finite set of leaf IDs attached to defined branch anchors. A seeded daily schedule detaches a subset of the remaining attached leaves in increasingly difficult patterns. A leaf can be attached, falling, airborne in a gust, or grounded. Shedding exposes its exact position; a miss leaves a persistent empty position. New weeks do not refill foliage lost earlier in the run. Cap the week's scheduled count by the number of attached leaves rather than inventing new leaves when the canopy is depleted.

The blower applies a cone-shaped upward force with a small sideways component and mild flutter. Show short outward-moving wind streaks with shallow bends, not spiral/helical ribbons. Wind and gravity continue outside the cone. A lifted, upward-moving leaf reattaches only when its path crosses the forgiving capture radius of an empty branch position; sweep the motion segment so upgraded speed does not skip it. Reaching the top of the screen or an occupied position does not score. Any empty position may receive a leaf, not just its original position. Snap the leaf into place, show a brief attachment pulse, and make the position occupied atomically so two leaves cannot fill it. Gusts do not detach attached leaves.

A returned leaf is marked rescued for that week and cannot shed again that week. A grounded leaf counts as missed once and remains in a local pile. Grounded leaves are not recoverable in version one; a later cleanup mechanic would need a separate balance pass. Decorative ambient particles never count toward scores, piles, or loss.

This bounded lifecycle prevents endless juggling from extending a week forever or farming score. Keep gameplay state independent from visual particles; pool both and cap visual effects on lower-powered devices.

### Blower and leaf piles

Use a quiet, stylized electric blower, with a rechargeable battery as the recommended first-version power source. A fictional fuel-cell variant remains possible; there is no gasoline, combustion, or engine roar. Keep a soft electric whirr and airy gust sound with independently adjustable volume.

The blower/fan gauge shows available energy with a small battery symbol and a clear “Recharging” state. Holding the blower spends charge; releasing allows automatic recharge after a brief delay. This is an arcade abstraction, not a claim that real batteries recharge by resting. Empty charge briefly disables the gust but never movement or recovery; require release before recharge in both hold and toggle modes, and show a clear release-to-recharge prompt. Refill at week boundaries. Start testing with roughly six seconds of base continuous use, a half-second recharge delay, and three seconds to refill from empty; tune these values alongside upgrades. No disposable fuel, purchasable refills, or extra heat meter in version one. This replaces the earlier motor-heat proposal with one understandable resource. Winter pressure has its own snowflake meter.

Grounded leaves increase pile depth in horizontal ground segments. Movement speed depends on the depth directly beneath the character. Smooth the transitions between segments and cap slowdown so movement never becomes a complete soft lock. Begin testing at a maximum 40% slowdown.

Pile artwork must reflect the same depth that affects movement. A shared ground-capacity meter represents overall winter danger; local piles communicate where movement is hardest. Do not add a separate hidden timer or unexplained failure condition.

### Winter warning before defeat

As cumulative winter pressure approaches capacity, start small folded-paper snowflakes falling. Increase their frequency and cool the distant light as danger grows, building urgency before the final winter animation. Initial tuning proposal: first sparse flakes at 60% pressure, more at 80%, and an urgent but readable warning at 95%. Drive this from missed-leaf pressure, not week number or blower charge, so the weather honestly communicates the risk of losing.

Warning flakes are decorative: no collisions, slowdown, scoring, or extra loss conditions. Keep them small and low-contrast behind gameplay leaves; save large intricate sixfold paper snowflakes and thick snow cover for the defeat cinematic. Reduced-effects mode preserves the same warning stages through the snowflake meter and static sky changes. Snow warnings must not make it harder to see or catch leaves. Panic is emotional feedback, not an instruction to raise the character's movement speed.

### Week and campaign boundaries

- The main campaign has **12 weeks**, followed by a separately named **final boss encounter**, The North Wind. Do not label the finale “Week 13.”
- Each week schedules a finite subset of remaining leaves. Completing it once awards its score bonus and one upgrade point, then opens the workshop and autosaves. Week 12 leads to the boss through that workshop; only defeating the boss triggers victory.
- Current temperature falls from 22°C by 2°C per week, reaching 0°C in week 12 and −2°C during the finale. This is an illustrative seasonal scale, not a real weather forecast. Clothing adds warmth each week, beginning in T-shirt/shorts and ending in a coat, mittens, hat and scarf. No stat bonus or movement penalty comes from cosmetic clothing.
- The cumulative winter-pressure threshold still governs failure. Missed foliage stays missing between weeks; paths clear and the battery refills. Retry restores the exact level-start canopy, score, equipment, schedule and random state, so repeated failures cannot duplicate rewards.
- Three locally named campaign slots autosave completed weeks, workshop choices, next-level start checkpoints, and victory. An attempt in progress is never saved as completed. Losing offers Retry Current Level rather than forcing a new campaign.
- Pause freezes gameplay, weather, previews and ending timelines. Switching away automatically pauses and returning never resumes without player action. Exiting warns: “Are you sure you want to exit? Current level progress will be lost.” Completed progress remains saved.
- On victory, return to shorts and a T-shirt for the flowers/sun celebration. On defeat, show a sad, heavily bundled character beneath the snow.

See [campaign details](CAMPAIGN.md) for the state flow, storage semantics, and final-encounter proposal.

## Difficulty and level progression

Use three difficulties, provisionally **Breezy**, **Blustery**, and **Gale**. Keep control rules identical. Separate local score tables make score multipliers unnecessary.

| Parameter | Breezy | Blustery | Gale |
| --- | --- | --- | --- |
| Shed leaves/week, initial tuning | 30 → 60 | 40 → 80 | 50 → 100 |
| Cumulative misses allowed before loss | 100 | 80 | 65 |
| Wind patterns | Gentle, long warnings | Alternating gusts | Stronger crosswinds, shorter warnings |
| Opening assistance | Tutorial prompts, wider catches | Brief prompts | Minimal prompts |

These numbers are hypotheses. Capacity is a count, not a percentage; display “misses / capacity” consistently and preview that capacity on difficulty selection. Test all twelve weeks and the final encounter at every difficulty before treating any setting as balanced.

| Weeks | Seasonal presentation | Challenge / clothing direction |
| --- | --- | --- |
| 1–3 | Green and gold; 22°C → 18°C | Learn catching and charge; T-shirt, shorts, light layers |
| 4–6 | Yellow/orange; 16°C → 12°C | More scheduled leaves; long sleeves, trousers, sweater and vest |
| 7–9 | Predominantly orange/red; 10°C → 6°C | Crosswinds and overlapping lanes; hoodie, jacket and gloves |
| 10–12 | Deep autumn; 4°C → 0°C | Learned patterns combined; wool hat, scarf and winter coat |
| Final encounter | The North Wind; −2°C | Telegraph → downward gust/snow → recovery; no extra numbered week |

More leaves change colour each week, as requested. Most colour changes are seasonal presentation; if heavy leaves behave differently, give them a distinct curled silhouette and introduction cue. Never encode weight solely by red versus green.

Keep the number of scheduled leaves, fall speed, clustering, wind, and blower reach in data-driven week profiles. Change a small number of parameters at a time. Telegraph gusts through canopy movement and a short directional cue before they affect gameplay.

## Upgrade tree and character progression

The player chooses upgrades between weeks. Boots improve mobility, stronger blowers move leaves more effectively, and battery upgrades change endurance. Heavier equipment creates an agility-versus-strength tradeoff: a powerful gust helps with clusters, but a bulky blower takes longer to carry across the screen.

Recommended scope: upgrades last for the current saved campaign and reset when starting a new run. Everyone begins a difficulty with the same equipment. Permanent cross-run stat upgrades are not assumed by this proposal; that would change persistence and high-score comparisons. Save the completed run's build with its score record so the player can revisit successful strategies.

### Branches and initial nodes

Three branches begin from the same starter kit. Tier 2 requires Tier 1 in its branch. All effects and numbers remain tuning hypotheses.

| Branch | Tier 1 — costs 1 point | Tier 2 — costs 3 additional points | Tradeoff / role |
| --- | --- | --- | --- |
| Boots / agility | Trail Boots: increase unloaded running speed, initially +10% | Sure Footing: reduce the maximum pile penalty, initially from 40% to 30% | Better repositioning and movement through missed leaves; less investment in gust strength |
| Blower / strength | High-Torque Fan: more upward force, with modest added weight and energy draw | Heavy-Duty Blower: further force and a wider effective cone, with greater weight and energy draw | Holds heavier clusters aloft, but is slower to carry and drains charge faster |
| Battery / endurance | Efficient Motor: less energy spent per second at the same force | High-Capacity Pack: more stored charge, with a small weight increase | Longer bursts; larger packs trade some mobility for endurance |

Prototype a modest movement penalty for blower weight, roughly 5–10% per power tier, and a smaller penalty for the large battery. Compute effective speed from base speed, boots, equipment load, and local pile depth using a documented, bounded formula. Preview the combined result, not only each node's advertised benefit. Enforce a minimum usable movement speed for every legal build under the deepest piles.

Keep leaf capture reliable at maximum power: stronger upward force must not repeatedly fling leaves through canopy regions too fast to attach. Test the top-speed and top-force builds against identical schedules; upgrades must support different strategies, not reveal one universally superior route.

### Earning and spending

- Award one upgrade point after each of weeks 1–12, regardless of score or rescue rate. No points after the final week, since the run is over.
- Twelve points are available before the finale. Fully upgrading a branch costs four (one plus three), so all three branches can be completed by the boss. The order creates build choices through the campaign; costs and the all-upgrades finale balance remain tuning hypotheses.
- Points are separate from arcade score. Never force the player to reduce a high score to buy equipment, and do not reward repeated juggling or replaying a week with extra points.
- Unspent points carry forward within the run. Allow free reallocation only between weeks, refunding dependents when removing a prerequisite. Confirm a complete valid build before starting the next week; no changes during active play.
- Starting a new campaign clears its points and build. Retrying a level restores its checkpoint, including the awarded-point ledger, rather than clearing completed progress or retaining attempt rewards. Workshop edits autosave.

### Between-week workshop UX

Flow: week summary → **paper workshop upgrade tree** → next-week forecast → Start Week. Show three vertical branches connected by cut-paper paths, large boots/fan/battery icons, owned/available/locked states, points remaining, and readable prerequisites. Avoid colour-only state cues.

Selecting a node previews “current → proposed” run speed, gust force/reach, continuous burst duration, recharge duration, and pile resistance. Explicitly label drawbacks, such as “Stronger gust; heavier to carry.” Include Confirm and Undo/Reallocate; Start Week can keep an existing build or bank points. Avoid auto-spending or a real-time decision countdown. After the boss encounter, go directly to the ending/results, not another workshop.

Temporary pickups are deferred until the upgrade tree is balanced. If revisited, avoid duplicating upgrade identities or adding several competing resource meters. The earlier Cool Breeze heat pickup is retired with the heat system.

## Points and high scores

- Award 100 base points for each rescued leaf, once per leaf per week. No points for merely touching a leaf, blowing, or collecting a power-up.
- Consecutive rescues build a combo: ×1 for rescues 1–4, ×2 for 5–9, ×3 for 10–14, and ×4 from 15 onward. A miss resets the chain; inactivity alone does not. Process simultaneous rescues by stable leaf ID.
- On week completion, add 500 points plus 50 per remaining unit of cumulative ground capacity. This intentionally rewards preserving capacity across weeks; display this calculation in the summary.
- Add 5,000 for completing the whole run. Do not add a time bonus that rewards rushing menus or penalizes reduced-motion settings.
- Snapshot score on loss or victory before the cinematic. Scores use nonnegative integers and bounded multipliers.

Store the top ten scores **separately for each difficulty**, with three initials, score, highest week, win/loss, a scoring-rules version, and the completed build. Sort descending by score, then highest week; preserve earlier records for exact ties. Give the planned high-score initials entry a large touch-friendly alphabet selector and keyboard support; allow A–Z, default to AAA, and provide a skip option. Display initials as plain text.

Use local campaign saves and separate local arcade high scores rather than accounts or global services. The three **save slots** are named campaigns; the three **difficulty score tables** are separate local records, now implemented. Each garden contributes its best terminal score, with better retries replacing its earlier result. See [scores and licenses](SCORES_AND_LICENSES.md) for the implementation and current difficulty profiles. Version and validate checkpoint data, keep backup recovery, and indicate storage failure instead of claiming success. Browser saves are local to the browser/origin and can be cleared; native and browser installations do not share them. No cloud saves or login is needed.

Save only level boundaries/workshop edits. Foreground resume preserves a paused in-memory attempt, but reload or OS process death restores the latest saved checkpoint. Retrying rolls back attempt score, misses and resources together. A future leaderboard must define how checkpoint retries and campaign rules versions are compared.

## UX and UI flows

### Main menu

Show the sNOw logo, a lightly animated tree scene, **Play**, **High Scores**, **How to Play**, **License**, and **Settings**. Avoid a separate mandatory account, splash interaction, or lengthy intro. The first intentional tap/click can also enable browser audio.

Play opens a difficulty selector with a short description and that difficulty's best score. Remember the last choice. Start week one with three brief contextual lessons: move, hold to blow, and avoid burying the path. Let returning players skip them. Delay real pressure until the player has used the controls.

### In-game HUD

Display week out of twelve (or “Final Encounter”), temperature, score, winter-pressure meter, and blower charge with the fan/battery gauge. Place combo indicators close to the action without covering falling leaves. Use large readable numerals and restrained animation. Keep pause always accessible; difficulty can remain in pause rather than cluttering the HUD.

### Aspect ratios and fair play

Use one fixed logical 9:16 gameplay rectangle across all devices, initially 360 × 640 design units. Uniformly fit the entire rectangle inside the available safe area. Never crop the canopy, expand movement range, reveal additional incoming leaves, or alter physics to fill a taller or wider screen. Fill unused space with noninteractive paper borders or decoration that reveals no gameplay information. Keep the HUD and default control positions anchored to the same logical composition; test their physical touch sizes on the smallest supported screen before locking the layout.

Screen pixels and refresh rate must not affect speed, wind, energy use, scoring, or time limits. Use fixed simulation steps and convert input into logical coordinates. Cosmetic quality can vary without changing gameplay or warning information. Verify identical seeded scenarios and scripted inputs across aspect ratios and frame rates; fixed-step simulation alone does not guarantee cross-platform determinism.

If global leaderboards are added later, compare only compatible difficulty, rules version, and challenge seed or schedule. Decide separate input categories or an explicit policy for keyboard versus touch advantages. Equal geometry is necessary but does not solve input differences, modified clients, or score verification; a ranked service needs its own validation design. This does not add accounts or online services to version one.

At a week boundary show rescued/missed leaves, score breakdown, cumulative danger, a one-line next-week forecast, and Open Workshop (weeks 1–12). Confirm the build and start the next week explicitly. The player chooses when play resumes. Pause offers Resume, Restart Current Level and Exit to Menu. Confirm actions that discard the current run.

### Loss sequence

Disable gameplay input, settle the character, and have them look up. Roll in blue-grey clouds, dim the warm light, then build snowfall and a snow-cover overlay on the ground, trees, and character. Transition into a result panel showing score, week reached, difficulty, initials entry when eligible, Retry Current Level, and Main Menu. The tone is gently comic, not punitive.

### Victory sequence

Part the clouds, brighten the sun, let the character celebrate, and bloom flowers across the ground. A warm gust restores the scene. Show “Winter can wait!” with the final score, difficulty, qualifying initials entry, Replay, and Main Menu.

Aim for roughly 5–8 seconds per full cinematic, with an accessible Skip after a short opening beat. Reduced motion uses short dissolves and static celebration/end-state art. The result and score must be identical whether watched, skipped, interrupted, or reduced.

## Audio and feedback

Use a soft electric blower whirr and airy gust loop, leaf rustles, a distinct canopy-reattachment pop, a grounded-leaf crunch, and a low-charge warning. Wind cues communicate upcoming direction. Add short seasonal music variations, a winter sting, and a sunny victory flourish. Cap overlapping leaf sounds and duck music for important cues. No essential information relies on sound or vibration.

## First-version scope

Required: one polished scene, one character with weekly outfits, 12 configured weeks plus a final encounter, three difficulties, touch and keyboard controls, leaf physics and captures, local piles and slowdown, rechargeable blower energy, between-week upgrade tree with weight tradeoffs, readable scoring, local per-difficulty high scores, menus/settings/tutorial, three named local campaign saves, a final encounter, and both ending sequences. Temporary pickups are deferred until the upgrade progression is balanced.

Deferred: global leaderboards, accounts, cloud saves, permanent cross-run stat progression, endless mode, multiplayer, multiple biomes, elaborate narrative, monetization, and full 3D assets. A satisfying complete run matters more than breadth.

### Current motion prototype

Use the supplied ancient, asymmetric tree as the authoritative visual reference. Keep rural houses at the sides of an open central clearing. The implemented cutout rig drives stance from actual ground distance, including pile slowdown, equipment weight, reverse travel and boundaries. The electric blower vibrates while running, and short wind streaks advance from its nozzle. Leaves combine gravity and drag with individually seeded flutter, wind drift, tumble and foreshortening; upward airflow retains lateral drift. Pause freezes the animation clocks alongside physics. Artist-separated limbs, richer turning and bespoke ending performances remain planned.
