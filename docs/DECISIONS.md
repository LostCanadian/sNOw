# sNOw — decisions and open questions

This log separates the requested game from proposed implementation choices. “Recommended” does not mean approved through playtesting or already implemented.

| Topic | Current direction | Status / decision gate |
| --- | --- | --- |
| Format | Portrait, fixed single-screen arcade game | User requirement |
| Platforms | Android, iOS, browser | User requirement; device/export validation pending |
| Core action | Move horizontally and blow falling leaves into trees | User requirement |
| Seasonal arc | Days grow more autumnal and challenging | User requirement |
| Piles | Missed leaves collect locally and slow movement | User requirement |
| Endings | Look up → clouds → snow on loss; sun and flowers on victory | User requirement |
| Branding | sNOw with emphasized, stylized NO | User requirement; logo exploration pending |
| Difficulty | Three choices, each with its own score table | User requirement; names and balance recommended |
| Rendering | Paper & Lanterns: layered cut-paper 2D, textured materials, soft shadows and backlighting | User-selected creative direction; runtime/mobile-performance spike pending |
| Setting | Modern rural homes and optional solar roof, forest and small hills; no castle or stone bridge | User direction adopted in the revised backdrop |
| Canopy | Bare branch geometry plus separately rendered paper leaves; misses leave persistent gaps across days | Implemented; no overnight foliage refill |
| Reattachment | Lifted leaves fill nearby empty branch slots; occupied positions and arbitrary sky heights do not score | Implemented with swept capture and exactly-once occupancy |
| Blower visual | Short directional wind streaks and restrained leaf flutter | User-requested replacement for the earlier spiral effect |
| Warning weather | Small paper snowflakes begin before loss, increasing with winter pressure | User requirement; thresholds/readability to test |
| HUD symbols | Blower/fan gauge with battery charge; separate snowflake winter-pressure meter; no flame | Fan gauge accepted by user; charge behaviour proposed |
| Aspect ratios | Fixed logical 9:16 playfield, uniformly fit inside safe area, decorative margins only | Recommended fairness rule; device and control-size validation pending |
| Future ranked fairness | Versioned rules/challenge schedules, input-category policy, score verification | Deferred online design; same geometry alone is insufficient |
| True 2.5D models | Optional comparison, outside initial production scope | Open only if the art spike shows clear value |
| Engine | Godot 4.6.3 stable, GDScript, Compatibility renderer, single-threaded web export | Pinned for the working technical prototype; native/mobile-device gates still open |
| Alternative engine | Phaser/TypeScript with Capacitor | Fallback if the Godot web/platform spike fails |
| Touch control | Left direction pad, right hold-to-blow, assisted upward cone | Recommended; first greybox playtest |
| Blower power source | Electric battery blower; fuel-cell theme remains an alternative; no gasoline | User direction; rechargeable arcade energy replaces the earlier heat proposal |
| Day count | Seven-day run, approximately 8–12 minutes | Recommended; measure actual mobile sessions |
| Leaf lifecycle | Finite scheduled leaves, rescued once/day, grounded leaves stay grounded | Recommended; prevents score farming and endless days |
| Overnight piles | Clear local piles but retain cumulative winter pressure | Recommended; test clarity versus persistent piles |
| Score formula | Rescue points, capped combo, day capacity bonus, win bonus | Recommended; balance and exploit checks pending |
| Persistence | Local settings and three local top-ten initials tables | Recommended first version; no accounts or global services |
| Run saves | No durable mid-run resume initially | Recommended; reconsider after session-length tests |
| Temporary power-ups | Deferred until the upgrade tree is balanced; retire heat-based Cool Breeze | Scope recommendation |
| Between-day upgrades | Boots/agility, blower/strength, battery/endurance branches; stronger equipment adds weight | User-requested feature; nodes and balance proposed |
| Upgrade lifetime | Carry across days in one run; reset on a new run | Recommended default for comparable arcade starting conditions; cross-run progression remains a separate choice |
| Upgrade economy | One point per day 1–6, separate from score; tier costs 1 then 2; between-day reallocation | Proposed, to test; no score farming or permanent grind |

## Questions to resolve with evidence

1. **Which minimum devices and browser versions must work?** Start with representative older phones, then agree exact versions before committing to an engine release. Record any unavailable device/tooling as a validation gap.
2. **Does assisted aiming feel expressive enough?** Compare catch success, missed-input reports, and enjoyment in a short touch playtest. Add manual aim only if it solves a demonstrated problem.
3. **Does clearing piles overnight undermine the fantasy?** Compare the current rule with retained-but-reduced piles. Select the version that players understand without allowing a hopeless movement spiral.
4. **Does the selected paper style stay readable at phone scale?** The concept progression is liked; next review a moving vertical slice with late-autumn colours, fog, and warning snow enabled. Concept approval does not establish gameplay readability.
5. **Are sessions short enough without saves?** Measure completed runs and interruption rates. Add checkpointing only if shortening schedules cannot address the problem.
6. **Do upgrades create meaningful build choices?** Compare mobility, power, endurance, and mixed builds against identical schedules. Check weight/energy tradeoffs, clear previews, and reliable canopy captures at maximum force. Tune upgrade points and costs before considering temporary pickups.

When a choice is validated, record the result, relevant build/device or playtest evidence, and any consequences here. Change the design and plan together so they remain consistent.
