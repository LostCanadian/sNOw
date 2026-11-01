# sNOw — campaign and progression

The working title is **sNOw**. The selected cut-paper style is an art direction, not a subtitle or in-game brand.

## Twelve weeks and a final encounter

Play twelve main weeks, followed by the separately named North Wind final encounter. Temperature drops from 22°C to 0°C over the main weeks and reaches −2°C in the finale. Twelve outfit frames gradually add layers, a coat and scarf. Victory returns the caretaker to a happy T-shirt/shorts pose; defeat uses a sad, bundled pose. Authored turning/looking-up/celebration performances remain production work.

## Persistent canopy with a recovery floor

A new campaign begins with **288 individually attached leaves** on the supplied textured ancient tree. Leaves originate at occupied twig positions, drift under gravity, and reattach only when lifted into a real vacant position. Any empty position may accept a leaf. The exact identities and occupancy of every position are saved.

**If every leaf is rescued in week one, week two still starts with all 288.** Nothing removes leaves simply because another week has begun. Seasonal colour advances and the next shedding schedule is harder. Misses leave persistent gaps; successful play preserves a fuller tree.

Danger is **weekly**. Reaching that week's miss allowance loses the level. Its completed checkpoint remains safe, and Retry restores that level's starting canopy, score, loadout, random state, clean path, full battery and zero weekly misses. Lifetime rescued/missed totals are tracked separately and do not consume the next week's allowance.

Before the next week begins, the tree regrows only enough missing leaves to reach a **96-leaf recovery floor**. It never refills a healthier crown. Regrowth restores missing identities into vacant slots and grants no rescue score, combo or upgrade points. A short start-of-week notice explains any regrowth. The workshop forecasts it. With the current profiles, 96 leaves exceed the largest scheduled final-encounter batch (84), guaranteeing a usable leaf supply without rewarding poor play.

Example: finish a week with 170 attached leaves → start the next with the same 170. Finish with 88 → eight leaves regrow, starting the next with 96. A retry uses that saved 96-leaf state; it does not repeatedly grow more leaves. This prevents resource depletion from making a campaign unrecoverable while preserving visible consequences.

| Difficulty | Weekly miss limit | First-week shedding | Added each week | Shedding interval | Wind | Fall factor |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Breezy | 18 | 24 | 2 | ×1.15 | ×0.70 | ×0.88 |
| Blustery | 14 | 30 | 2 | ×1.00 | ×1.00 | ×1.00 |
| Gale | 10 | 36 | 3 | ×0.85 | ×1.30 | ×1.12 |

The final encounter adds twelve scheduled leaves. All schedules are finite and bounded by attached leaves. The pressure-driven warning snow and loss condition use **weekly misses**, shown as Weekly Frost. No account or permanent stat grind is required. Numbers need human playtesting; the floor prevents a supply soft lock, not every possible player failure.

## Direction and airflow

The caretaker faces their movement direction and retains that facing when stopped. The barrel smoothly returns upright at rest and leans up to 32° while moving. The cutout pose, nozzle position, wind streaks, affected cone and force direction share geometry. Moving airflow can steer leaves sideways toward vacant branches. Pushing against a movement boundary does not count as running.

Leaves flutter and tumble with seeded variation in drag, phase and spin. A return breeze grows near the vertical edges. Leaves may briefly leave the viewport, but outward blower force fades there and the breeze draws them back; a last-resort bound sits 22 logical pixels beyond each edge. This geometry is identical on all screen shapes.

## Eighteen upgrades, twelve points

Boots, Blower and Battery each have six one-point ranks: **18 nodes**, with only **12 points** earned from the twelve main weeks. Previous rank in the branch is required. This yields **28 distinct full-budget final allocations**, plus many purchase orders and partially spent kits. Examples include 6/6/0, 6/0/6, 0/6/6 and 4/4/4. The boss awards no unusable extra upgrade point.

Tap any node to inspect it, including locked/owned ones. Its full description and prerequisite appear in a separate fixed card. Buying is a separate explicit action. Equipment icons identify the three lanes, connectors show prerequisites, and node hit areas do not overlap. Reset Kit freely refunds the earned budget in the workshop.

Boot ranks improve speed and reduce pile drag. Fan ranks add lift/reach but add weight and drain. Battery ranks add capacity/efficiency and reduce recharge time, with a small weight cost. All modeled builds retain movement above 60 logical units/second under maximum pile drag and useful burst time; actual winning strategy balance still needs human testing.

## Save Slots and compatibility

The menu calls them **Save Slots**, with three editable names. New defaults are Save 1–3; existing custom names are preserved. Difficulty stays fixed for a campaign. Autosaves occur at completed-week/workshop boundaries, next-week starts and victory, never mid-attempt. Exiting warns that current-level progress will be lost.

Native files are `user://campaigns.json`; browser checkpoints use `snow.campaigns.v1` plus backup. Container version stays compatible; checkpoint rules version 2 identifies the new canopy/weekly danger/upgrade economy. Previous 48-slot checkpoints keep their original positions, identities, campaign ID, completed weeks, score and earned point budget, with 240 additional canopy positions. An old two-rank purchase costing four points maps to rank four in its branch. Browser storage keys are unchanged. Native saves can still be read from the former application-data directory after the title change.

High scores are separate from campaign slots. Earlier rules' tables remain accessible under **Previous scores**; current rules do not overwrite or rank against them. A campaign contributes one best terminal result per rules version.

## Pause and later polish

Pause freezes physics, poses, weather, previews and endings. Switching away pauses automatically; returning requires Resume. All-screen pause and confirmed exit remain available.

Later scenery polish: slow clouds, squirrels on the ground/trunk, and a restrained night storm/lightning week. Dynamic lighting depth, artist-separated limbs, richer turns and authored ending performances remain later work. The textured whole-tree illustration stays authoritative; do not rebuild it from little line segments.
