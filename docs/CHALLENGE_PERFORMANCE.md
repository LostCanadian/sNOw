# Challenge leaf performance

## Investigation and changes

The November 4, 2026 investigation first removed avoidable CPU work while retaining the original 1,500-leaf airborne budget. The table below records that optimization pass. Current rules 13 tuning caps Challenge at **200 airborne leaves**, with shared shedding/Whirlwind/North Wind accounting, recovery reservations and bounded waves. The 500-leaf pass and measurements below are historical. The tree still has 2,160 identities. Difficulty labels are Easy, Medium and Hard; numeric difficulty indices, saves and existing score tables remain readable.

- Capture queries now visit spatial cells containing active catching spots, rather than all 2,160 branch positions. The existing cooldowns, nearest-segment test and tie-breaking remain in effect. The spatial index updates as catching spots are filled and replenished.
- Frame-wide wind, blower and Whirlwind calculations move outside the per-leaf loop. Typed local values reduce repeated dictionary reads and arithmetic. Airborne leaves above the highest pile skip detailed ground queries, using a conservative bound updated on every deposit. Filtering the airborne array only happens when a leaf resolves.
- Ordinary detachments and captures patch changed identities in the cached crown instead of rebuilding all its leaf geometry and colours. Seasonal changes, previews and victory growth retain complete rebuilds.
- Moving leaves update transforms independently of colours. Unchanged palette textures stay on the GPU. Attachment completion restores the exact branch pose and its cosmetic rustle; ground/front/rear transitions preserve one rendered instance per identity.
- Challenge now samples smooth seeded gusts once per tick, with intermittent downdrafts and brief North Wind fall surges. All airborne sources share the 200-leaf limit, and full capacity does not accumulate overdue shedding. The North Wind's path, tangent and spin are calculated once per tick and shared by the affected leaves.
- Blower reflections carry side leaves back into the clearing. A controlled campaign test with a fully upgraded blower at x=140 moved its left-edge leaf to approximately x=130 after three seconds; the previous force left it near x=35. This isolates the boundary response, not a complete human-played level.

## Measurements

The same Godot 4.6.3 desktop binary ran both versions headlessly. These are synthetic CPU measurements, excluding GPU rendering, the rest of the scene, audio and phone-specific effects. They are not phone FPS predictions or a debug-versus-release comparison.

Each case starts with the stated number of fully upgraded Easy Challenge leaves, a fixed seed, disabled ordinary shedding, and a held stationary blower. It measures 90 physics ticks and corresponding leaf-buffer updates. The capture case permits reattachment; the juggling case delays it to keep every leaf airborne. Both versions produced identical rescue, miss and final airborne counts.

Mean physics plus leaf visual update time per tick:

| Initial airborne leaves | Juggling before | Juggling after | Capturing before | Capturing after |
| --- | ---: | ---: | ---: | ---: |
| 100 | 1.38 ms | 0.98 ms | 6.21 ms | 1.79 ms |
| 500 | 5.91 ms | 3.80 ms | 22.22 ms | 6.61 ms |
| 1,000 | 12.03 ms | 7.42 ms | 42.86 ms | 12.09 ms |
| 1,500 | 17.47 ms | 11.24 ms | 64.17 ms | 19.01 ms |

Capture-heavy CPU work fell about 70–72%. At 1,500 initial leaves, the optimized capture case still has a 30.7 ms physics p95, before rendering. Crowded rescues and replacement-anchor selection can still cause spikes. A 60 FPS frame has a total budget of 16.7 ms, so native phone profiling remains necessary.

Run the reusable benchmark with a matching Godot executable:

```sh
bash tools/godot.sh --headless --script tools/profile_challenge.gd
```

The current benchmark uses 50 / 100 / 200 leaves and reports separate mean/p95 physics and presentation costs, the actual airborne limit, and outcome counts. Add `-- --storm` for a North Wind workload. The larger historical cases in the table predate the new cap. Optional user arguments `--loop=res://path.gd` and `--main=res://path.gd` select comparison scripts. To compare versions, use independent copies of their helper scripts as well.

Historical rules 13 measurements at the former 500-leaf limit, using the same desktop CPU-only study:

| Workload | Mean physics | Mean leaf visual updates | Combined mean |
| --- | ---: | ---: | ---: |
| Juggling | 3.17 ms | 0.93 ms | 4.10 ms |
| Capturing | 4.79 ms | 1.94 ms | 6.73 ms |
| North Wind, juggling | 4.22 ms | 1.12 ms | 5.34 ms |
| North Wind, capturing | 7.57 ms | 1.92 ms | 9.49 ms |

In that historical study, the storm case allowed the real North Wind to release additional leaves when rescues free budget slots; the airborne population remained at or below 500. Timing still excludes actual GPU work and phone hardware, and averages do not rule out occasional queue-refill or rescue spikes.

Validation includes the native regression suite, incremental versus complete geometry/palette rebuilds, palette-upload checks, swept capture versus exhaustive geometry, both ground lanes and attachment completion. A separate investigation compared the original and optimized simulations through campaign, juggling, capture and Whirlwind scenarios, including leaf motion, counters, active anchors and RNG state; it found no differences within the checked tolerances.

## Ground recovery and dispersion follow-up

Grounded leaves now reserve recovery slots within the existing airborne limit. Branch shedding and North Wind packets leave that space available, allowing Whirlwind to recover every nearby ground identity even at the shedding limit. The same rule applies to Campaign's 1,500-leaf limit. Pickup clears the pile immediately, launches leaves upward and outward at varied speeds, and preserves upward motion for 0.65 seconds through the rotating nozzle's downward phase. Recovery still preserves identities, refunds only actual misses and awards no pickup points.

Additional sideways dispersion uses each leaf's existing flutter strength and an identity-based drift bias. Stronger smooth blower turbulence separates paths without pairwise leaf comparisons or per-frame RNG calls. Free-fall drift stays weaker so natural back-and-forth flutter remains visible; returning leaves carry that drift inward until clear of the side channel. Blower streak rendering is unchanged.

Before the 200-leaf change, a desktop CPU-only follow-up with 500 initial leaves measured 3.48 ms mean physics plus 0.94 ms leaf updates while juggling, and 5.17 ms plus 1.88 ms while capturing. These are single-run observations, not phone FPS or a controlled performance comparison. Native regressions cover reserved recovery at both limits, upward clearance through both spin directions, deterministic clump dispersion, capture/edge-return behavior, and real touch dispatch outside the visible arrow buttons. A rendered 32-ground-leaf fixture recovered all 32 without a new miss through the complete tumble.

## Wave and weather balance

The current Challenge ceiling is 200, with 30 / 40 / 50-leaf ordinary waves and ten-second recovery gaps. Grounded leaves keep their recovery reservations. North Wind packets remain bounded additions during storms. Pressure rises in eased fifty-second stages: wind and localized squalls reach 2.25 times their initial strength; falling acceleration/speed can reach 30% extra. Each squall has a quiet lead-in before its force ramps up; it is communicated only through leaf motion, without text or decorative weather lines. Later campaign weeks gain 3% falling pressure per week from week four, plus gradually stronger/more frequent localized weather; the first three weeks and the finale's attack schedule retain their previous weather.

A synthetic fixed-position study held the blower and activated available Whirlwind recovery automatically. At seed 77, Easy / Medium / Hard lost after approximately 245 / 110 / 66 seconds, with peak airborne populations of 73 / 65 / 70 and means of 18 / 22 / 26. None reached the ceiling. This demonstrates wave gaps and loss under that restricted policy; it is not a human survival target, an optimal strategy, or a physical-phone performance measurement.

At 200 initial leaves, the updated headless CPU benchmark measured:

| Workload | Mean physics | Mean leaf updates | Combined mean |
| --- | ---: | ---: | ---: |
| Juggling | 1.52 ms | 0.43 ms | 1.95 ms |
| Capturing | 2.15 ms | 1.53 ms | 3.68 ms |
| Storm and squall, juggling | 1.95 ms | 0.49 ms | 2.44 ms |
| Storm and squall, capturing | 2.40 ms | 1.49 ms | 3.89 ms |

These single-run desktop timings exclude GPU rendering and other scene work. Captures can free slots for bounded North Wind releases; every case stays within the 200-leaf ceiling. They do not establish phone FPS.

`tests/test_balance_pacing.gd` checks actual per-wave release totals and gaps, cap/loss compatibility, old-plateau escalation, full-power close/distant gust response, unchanged opening acceleration, later progression and smooth lead-in/force transitions. The earlier warning text, chevrons and weather streaks have been removed from the renderer. The blower's own streak geometry remains unchanged.

## Further tuning if the phone still slows down

First test the optimized APK on the phone and compare a release export under the same workload. Measure physics, rendering and spikes separately; a release build does not remove the underlying per-leaf work.

The 200-leaf cap and 30–50-leaf waves preserve the dense attached canopy while reducing the mobile workload. Extra difficulty comes from gradually increasing fall pressure and localized crosswinds/downdrafts. Any further ceiling reduction must account for grounded recovery reservations and remain above the largest loss allowance, so the winter loss condition stays reachable. These choices still need phone playtesting.

Fewer, larger leaves remain an option, but affect much more than performance: crown coverage, target spacing, capture radius, weekly quotas, miss allowances, score progression and save migration would all need review. They can also increase transparent overdraw despite reducing the CPU count. Foliage count and size are unchanged.
