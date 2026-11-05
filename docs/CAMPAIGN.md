# sNOw — campaign and progression

The working title is **sNOw**. The selected cut-paper style is an art direction, not a subtitle or in-game brand.

## Twelve weeks and a final encounter

Play twelve main weeks, followed by the separately named North Wind final encounter. Temperature drops from 22°C to 0°C over the main weeks and reaches −2°C in the finale. Twelve outfit frames gradually add layers, a coat and scarf. Victory returns the caretaker to a happy T-shirt/shorts pose; defeat uses a sad, bundled pose. Authored turning/looking-up/celebration performances remain production work.

## Main menu and Challenge

**Continue** selects existing campaigns and is disabled when all slots are empty. **New Game** selects a slot and difficulty directly. Choosing an occupied slot opens naming/difficulty setup, then a replacement review showing the old save and the new week-one save. Keep my save returns to slot selection without writing; only Start fresh replaces the chosen slot. Other campaigns and high scores remain intact.

Defeating the North Wind permanently unlocks **Challenge** at the difficulty beaten and every easier difficulty. Harder choices remain visible but disabled. The start/restart paths enforce the same requirement.

| Highest campaign difficulty beaten | Challenge difficulties available |
| --- | --- |
| None | Locked |
| Easy | Easy |
| Medium | Easy, Medium |
| Hard | Easy, Medium, Hard |

The highest completed difficulty is shared local progress in the top-level `highest_completed_difficulty` field (`-1` through `2`), independent of the three slot records. It survives replacing every campaign, reopening the app, and subsequently winning on an easier difficulty. Saves from an older open session preserve any harder unlock already on disk. Native atomic saves/backups and browser localStorage retain this metadata alongside the slots; it does not require retaining a completed campaign.

Existing completed campaigns migrate using their recorded difficulty. An older `challenge_unlocked: true` record with no remaining completed campaign proves only an unspecified win, so it retains Easy access. New saves also retain the old boolean for compatibility, derived from the permanent completion level. Challenge runs never award campaign completion unlocks.

Challenge starts with all thirty upgrade nodes, a full battery and Whirlwind. It keeps the week-eight autumn foliage and active-anchor pool with a full canopy, no completion quota and no weekly rewards. **At most 200 leaves can be airborne:** ordinary shedding, North Wind packets and ground recovery share this budget. Each grounded leaf reserves a recovery slot, so new branch shedding stops at 200 minus the ground count. Whirlwind can therefore lift all nearby ground leaves even at the shedding limit. Blocked leaves stay on their branches. Full capacity cannot accumulate a catch-up burst. The campaign uses the same recovery reservation within its existing 1,500-leaf safety limit.

A shared 200-second calendar smoothly cycles day, dusk, night and dawn, with weather building from sun through clouds, wind, rain and storm before clearing again. Each night advances one lunar phase. During each of the two storms, the North Wind makes one brief, telegraphed pass, stripping at most 16 / 20 / 24 real leaves by difficulty, subject to the shared cap. The visit still occurs at full capacity and briefly increases downward pressure on existing leaves; its force and fall-speed allowance rise and ease off within the blast. These visits do not become campaign bosses or award boss rewards.

Real occupied leaves keep refilling the fall queue, so rescues can recur indefinitely. Ordinary arrivals form twenty-second waves: up to **30 / 40 / 50 leaves** on Easy / Medium / Hard during the first ten seconds, then a ten-second recovery gap. Packets contain 3 / 4 / 5 leaves at 1.00 / 0.95 / 0.90-second intervals. Unreleased leaves stay attached when the window ends; they never become a catch-up burst in the next wave. North Wind storm packets remain separate, bounded encounters and can occur during ordinary recovery gaps.

Weather pressure replaces accelerating leaf volume. Six-second seeded ambient wind segments retain the opening six-second calm period. Localized squalls then repeat every sixteen seconds: a short quiet lead-in precedes a smoothly rising/falling blast, with recovery gaps afterward. The affected column changes deterministically between gusts. Downdrafts affect leaf motion only, with no text overlay or decorative weather lines. High leaves inside it receive the strongest downward pressure; close-range airflow and movement remain useful. Ambient wind and squall strength increase by 18% every fifty seconds, easing through each step over six seconds, to a 2.25-times pressure ceiling. Falling acceleration and fall-speed limits also rise 3% per fifty-second step to 30% extra. Escalation therefore continues beyond the old three-minute plateau while staying bounded. All weather calculations are shared per tick and consume no leaf RNG. Difficulty's normal fall factor and miss allowance still apply. Winter ends the run at that allowance; pause freezes waves, wind and escalation. Scoring retains the usual rescue/combo rules and existing score tables remain available.

In both modes, outward blower airflow near a side reflects inward. A returning leaf retains that reflected direction until it clears the side channel, rather than immediately meeting the same outward force again. Wall overshoot mirrors position and returns horizontal momentum inward. The reflection affects leaf physics only; visible blower streaks continue offscreen without turning at the sides. Ground scuffing retains its existing softer edge force.

Each run is a fresh attempt with separate per-difficulty Challenge top tens and initials. Native scores use `challenge_scores.json`; web scores use `snow.challenge_scores.v1`. Campaign score data is unchanged. Challenge has no campaign checkpoint, editable workshop or saved continuation. Restart and Play again create a new run with zero score and every upgrade; exiting an unfinished attempt confirms that its score will be lost.

Validation: `tests/test_challenge_unlocks.gd` checks every completion/access combination, disabled buttons and guarded start paths, all-slot replacement, lower/higher later wins, migration, malformed metadata, backup recovery and stale-session writes. `tests/test_challenge.gd` exercises quota-free refills, all-upgrade starts, bounded waves, loss, unlock migration/persistence, overwrite cancellation/confirmation, focus pause, retry and isolated score storage. `tests/test_balance_pacing.gd` checks wave totals and gaps, full-cap recovery, quiet lead-in before force, close versus distant actual airflow, pressure beyond three minutes, smooth transitions and campaign progression. `tests/browser_challenge.py` exercises the menu and Challenge through browser input using the validated `challenge-fixture.json` from `tests/visual_fixture.gd`.

## Persistent canopy with a recovery floor

A new campaign begins with **2,160 individually attached leaves** on the supplied textured ancient tree. Leaves originate at occupied twig positions, drift under gravity, and reattach only when lifted into a real vacant position. Only the level’s active empty anchors may accept a leaf; other bare positions remain unavailable until selected for the pool. The exact identities and occupancy of every position are saved.

Healthy crowns now thin in twig clusters between weeks, from 2,160 leaves initially to a ceiling of 960 by week twelve and the finale. The ceilings are 2,160 / 2,080 / 2,000 / 1,900 / 1,800 / 1,680 / 1,560 / 1,440 / 1,320 / 1,200 / 1,080 / 960 / 960. Player misses can leave a sparser tree. Seasonal losses have their own saved counter, do not count toward weekly frost or award points, and do not repeat on Retry.

Landing now keeps the original leaf in a physical ground pile. Walking disturbs it; the unlocked Whirlwind can return it to the air and remove its frost penalty while it is in play. Points still require actual reattachment. See [abilities and story](ABILITIES_AND_STORY.md).

Danger is **weekly**. Reaching that week's miss allowance loses the level. Its completed checkpoint remains safe, and Retry restores that level's starting canopy, score, loadout, random state, clean path, full battery and zero weekly misses. Campaign rescue/unrecovered-miss totals are tracked separately and do not consume the next week's allowance.

Before the next week begins, the tree regrows only enough missing leaves to reach a **720-leaf recovery floor**. It never refills a healthier crown. Regrowth restores missing identities into vacant slots and grants no rescue score, combo or upgrade points. A short start-of-week notice explains any regrowth. The workshop forecasts it. With the current profiles, 720 leaves exceed the largest final-encounter quota (636), guaranteeing a usable leaf supply without rewarding poor play.

Example: a healthy crown above the coming week’s ceiling sheds to that ceiling. Finish below that ceiling with 800 → keep those 800. Finish with 660 → sixty leaves regrow, starting the next with 720. A retry uses that saved 720-leaf state; it does not repeatedly grow more leaves. This prevents resource depletion from making a campaign unrecoverable while preserving visible consequences.

| Difficulty | Weekly miss limit | First-week quota | Added each week | Shedding interval | Wind | Fall factor |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Easy | 135 | 180 | 15 | ×1.15 | ×0.70 | ×0.88 |
| Medium | 105 | 225 | 15 | ×1.00 | ×1.00 | ×1.00 |
| Hard | 95 | 270 | 23 | ×0.95 | ×1.30 | ×1.12 |

Hard's shedding interval was increased from ×0.85 to ×0.95, reducing its ordinary leaf arrival rate by about 10.5%. Week one releases four leaves per batch, approximately every 1.66 / 1.44 / 1.37 seconds on Easy / Medium / Hard after the shared opening delay. Later weeks increase batch size and shorten the common interval. Quotas, miss limits, fall factors and wind strength are unchanged by this adjustment.

The final encounter adds 90 leaves to the quota. The North Wind crosses the crown every 4.8 seconds: a 0.8-second approach, 2.1-second curved sweep, and 1.9-second recovery window. It strips only scheduled real leaves inside its swept path, up to 48 / 56 / 64 per pass by difficulty, and curls nearby airborne leaves through the same local force field. Passes alternate direction and choose a lane covering the fullest remaining scheduled foliage. A lane histogram is computed once per pass, and release packets are capped at four leaves and spaced at least 50 milliseconds apart to spread the gust through the crown. Sixteen original paper curl poses crossfade at 18 fps along the shared physics path. Ordinary batches of three leaves continue between passes at 2.4 times the usual shedding interval; they share the continuing fall queue with gusts. Dust and chaff remain cosmetic. There is no face character or text panel behind the tree. The queue refills from real occupied branches until the completion quota is reached; concurrent leaves remain bounded. The pressure-driven warning snow and loss condition use **weekly misses**, shown by the growing, pulsing snowflake. No account or permanent stat grind is required. Numbers need human playtesting; the floor prevents a supply soft lock, not every possible player failure.

## Completion quota and continuing falls (rules 12)

The table describes each level’s fixed completion quota, independently of the number currently falling. The first resolution of a fall—rescue or landing—advances that quota once. Whirlwind can still refund frost by recovering a ground leaf; lifting it does not rewind progress, and its later rescue cannot count the same fall twice. A leaf that is attached and subsequently detached begins a new fall.

Ordinary batches and North Wind packets continue until the quota is met. The visible-first, colour-weighted queue refills in batches of up to 64 from real occupied branches, excluding identities already pending. A reattached leaf may fall again. The existing active-leaf cap, miss allowance and two Gold Leaves per successful main week remain. Reaching the miss limit loses even when the same landing reaches the quota.

Completion occurs in the physics step that reaches the quota; it never waits for the airborne pool to empty. Unfinished leaves finish falling cosmetically during the weekly closing scene without score, frost or progress changes. The completed checkpoint preserves those identities on the next starting tree, without awarding rescues or regrowth. Saving does not change their current visible poses. Once the decorative piles settle, the renderer caches them. A pause freezes the closing motion.

Rules 12 saves the completed quota counter and retains older campaigns and unified high scores. The live refill queue remains transient; retries derive it from the saved initial plan and random state. Intro cards remain narrative only.

## Direction and airflow

The caretaker faces their movement direction and retains that facing when stopped. The barrel smoothly returns upright at rest and leans up to 32° while moving. The cutout pose, nozzle position, wind streaks, affected cone and force direction share geometry. Moving airflow can steer leaves sideways toward vacant branches. A freshly vacated attachment spot cools for five seconds before accepting any leaf; older active gaps remain available to eligible leaves. Newly detached leaves also wait two seconds before they can attach anywhere; airflow still affects them during that time. Each leaf has a deterministic lift response and upward speed limit, mixed independently of its colour/depth, so a clump spreads vertically in full-power airflow. Lift force, sideways steering and maximum upward speed taper smoothly with distance along the aimed cone, reaching 28% at full reach. Reach upgrades extend this taper. The low-power draft retains gravity support while its small upward surplus fades with distance. Pushing against a movement boundary does not count as running.

Leaves flutter and tumble with seeded variation in drag, phase and spin. An independent identity-based sideways drift and stronger smooth blower turbulence spread overlapping leaves into different paths without per-frame random samples or pairwise leaf comparisons. Near the vertical edges, both the local drift and blower force carry returning leaves toward the clearing until they leave the side channel. Wall overshoot reflects position and horizontal momentum at the leaf-radius boundary. This physics geometry is identical on all screen shapes; visible blower streaks continue offscreen without reflecting.

Campaign weeks one to three retain their original falling acceleration and weather. From week four, falling acceleration and speed limits gain three percentage points per week, reaching **27% extra in week twelve**. Localized crosswinds and downdrafts also become stronger and more frequent over those weeks: their cycle shortens from about 23 to 18 seconds, while the downward force ramps toward the late-game maximum. These gusts favour high leaves, requiring more repositioning as upgrades improve coverage. The finale retains the week-twelve fall multiplier and its existing North Wind attacks, without stacking additional localized squalls. Battery behaviour, upgrade effects and weekly loss allowances are unchanged by this progression.

## Active anchors and leaf cooldowns (rules 11)

The active pool counts empty attachment targets, independently of how many leaves remain on the tree. Its maximum decreases each week:

| Week | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | North Wind |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Anchor limit | 64 | 60 | 56 | 52 | 48 | 44 | 40 | 36 | 32 | 28 | 24 | 20 | 16 |

There can be fewer active anchors if fewer gaps exist. Existing targets stay in place until filled. Filling one replaces it with a spread-out empty target; the three most recently filled areas are also considered when choosing its replacement. A newly vacated spot joins the pool only when there is room, and its five-second spot cooldown still applies. Cooling targets count toward the cap, so cooling cannot open an unlimited second set of targets. A spot outside the pool can stay inactive even after its cooldown expires.

The leaf’s separate two-second cooldown starts when it detaches and blocks all attachment, including at older ready gaps. It does not block lift or steering. Ground recovery does not restart this timer. Twinkles cycle through at most five ready active targets; an unlit active target still accepts an eligible leaf.

The pool is derived deterministically at level preparation and checkpoint restore without consuming simulation randomness. Rules 11 retains older saves, foliage counts, earned upgrades and unified high scores. Live airborne state and anchor timers are not added to boundary checkpoints. The initial limits and cooldown need human campaign playtesting.

## Thirty upgrades, twenty-four Gold Leaves

Boots, Blower and Battery each have a ten-node branching tree. Two Gold Leaves are earned for each of twelve main weeks, for a 24-leaf budget competing with 41 leaves of upgrades. Nodes have explicit prerequisites and costs; Whirlwind requires Torque fan and three additional Gold Leaves. The boss awards no unusable currency. See [current beta progression](BETA_POLISH.md).

Tap any node to inspect it, including locked/owned ones. Its full description and prerequisite appear in a separate fixed card. Buying is a separate explicit action. Equipment icons identify the three lanes, connectors show prerequisites, and node hit areas do not overlap. The reset icon asks Reset all upgrades or Cancel; confirmation refunds the earned budget.

Boot ranks improve speed and reduce pile drag. Fan ranks add lift/reach but add weight and drain. Battery ranks add capacity/efficiency and reduce recharge time, with a small weight cost. All modeled builds retain movement above 25 logical units/second under maximum pile drag and useful burst time; actual winning strategy balance still needs human testing.

Easy campaign uses a 2.25-second base battery charging phase instead of 3 seconds. With the existing half-second release delay, an empty starting battery takes about 2.75 seconds to refill after releasing the blower, versus 3.5 on Medium and Hard. Battery recharge upgrades multiply that base normally; held low-power charging retains its existing 55% rate. Challenge keeps the original base on every difficulty because it already starts with all upgrades. Burst length, loss allowances and Whirlwind cooldowns are unchanged.

## Save Slots and compatibility

The menu calls them **Save Slots**, with three editable names. New defaults are Save 1–3; existing custom names are preserved. Difficulty stays fixed for a campaign. Autosaves occur at completed-week/workshop boundaries, next-week starts and victory, never mid-attempt. Exiting warns that current-level progress will be lost.

Native files are `user://campaigns.json`; browser checkpoints use `snow.campaigns.v1` plus backup. Container version stays compatible. Checkpoint rules version 2 introduced the canopy/weekly danger/upgrade economy; version 3 adds grounded-leaf recovery and slow abilities. Previous 48-slot checkpoints keep their original positions, identities, campaign ID, completed weeks, score and earned point budget, with 240 additional canopy positions. An old two-rank purchase costing four points maps to rank four in its branch. Browser storage keys are unchanged. Native saves can still be read from the former application-data directory after the title change.

High scores are separate from campaign slots. All previous scores join one top ten per difficulty. Earlier score scales normalize on import and each campaign contributes its best result, with no version labels or archived tables.

## Pause and later polish

Pause freezes physics, poses, weather, previews and endings. Switching away pauses automatically; returning requires Resume. All-screen pause and confirmed exit remain available.

Later scenery polish: slow clouds, squirrels on the ground/trunk, and a restrained night storm/lightning week. Dynamic lighting depth, richer turns and authored ending performances remain later work. The textured whole-tree illustration stays authoritative; do not rebuild it from little line segments.

Brief unique openings and congratulations frame every week, with gameplay clocks frozen while the panel is readable. The role of the tree is suggested rather than explained in player-facing text. Achievements are [future work](ACHIEVEMENTS.md); rescue-streak callouts are removed.

Completed weeks lead to [animated results](HUD_AND_RESULTS.md) with exact week/temperature and weekly leaf/point totals. Upgrades are available from results, Continue and restart review; Done returns to the originating screen. Next Week and Main Menu live on results. Loading a completed checkpoint returns to results. The gameplay HUD uses score, snowflake danger and a filled battery icon, leaving numeric seasonal details to results.

The [future ambient-world plan](AMBIENT_WORLD.md) covers a rabbit changing coat, night owl reactions, full-moon wolf/bat variants, varied daylight/night skies and a darker cloudy daytime finale. These remain deferred art and animation work.

Checkpoint rules 8 uses 2,160 leaves, including additional central attachments, at 30% larger size. Older 48-, 288- and 2,880-leaf checkpoints retain the proportion of gaps and scale leaf counters to the new density. Score, campaign identity, week and purchased upgrades remain; playing schedules regenerate deterministically from saved randomness. Saving writes the new density so conversion cannot repeat.

To change difficulty in an occupied slot: Save Slots → Edit → Start fresh… → choose a difficulty/name → Review fresh start → confirm. Cancellation preserves the original campaign. Confirmation resets that slot to week 1 with a new campaign identity and chosen difficulty; other saves and score tables remain intact. Difficulty stays fixed during an existing campaign.

Rules 5 change the seasonal colour mix, weighted selection and cadence; week-one events contain four leaves and late events ten. [Motion/season rules](MOTION_AND_SEASONS.md) cover exact colour weights, rigid limb animation, the airborne Surge, knee-height scuffs, leaf-first winter and score conversion. Earlier campaign totals and score-table values divide by ten once during import. One-use upgrade items such as coffee remain [future work](CONSUMABLES.md).

Beta checkpoint UX: loading a playing checkpoint offers Continue, which begins the saved level from the start. Resume/Restart remain live-pause actions, where they refer to genuinely different choices. Results and menus never auto-pause on focus loss. See [beta polish](BETA_POLISH.md).

Starting speed is 50 logical units/second (previously 100). Trail soles adds 10%; Quick stride adds another 12%, raising two early boot purchases to 61 before load weight. Later speed branches add 12%, 6%, 16% and 10%, alongside the existing grip and weight-management choices.

The first crown relocates 280 redundant outer sprays onto middle-right branches and the central fork. The tree artwork and total of 2,160 leaf identities are unchanged. Rules-7-and-earlier playing checkpoints adopt the current seasonal ceiling once and regenerate a deterministic schedule; score, campaign identity and purchased upgrades are retained.


## Lingering after an ending

Loss completes its falling leaves, snow and short hold before showing Continue at bottom right. Victory completes its growth, flowers, hold and closing card before showing the same action. Neither ending advances to Results automatically. Wildlife, snow and music continue while the player stays; pause and focus loss still freeze the scene. Continue opens Results without changing the score or granting rewards again.
