# sNOw — staged development plan

Status: an initial [technical art prototype](PROTOTYPE.md) now implements a subset of these stages in Godot 4.6.3, with a browser export, automated simulation/input checks, original prototype assets, and a small upgrade workshop. This is not a completed cross-platform gate or production vertical slice. Physical-device performance, native exports, full animation/layered-art production, difficulties and separate high-score/settings persistence remain outstanding. Complete each exit gate before expanding scope; the list below remains the broader delivery plan.

The revised prototype uses modern rural homes instead of the original medieval backdrop. Bare gameplay trees and all foliage now render independently: occupied positions shed real leaves, misses leave persistent gaps, and returning leaves reattach to vacant positions. A single textured ancient tree adapted from the user-attached reference and artist-authored twig metadata, textured leaf sprites and directional wind streaks replace the static painted canopy, blanket sky capture and spiral blower ribbons. The current finite canopy has 48 leaves; the earlier 150-leaf budget below remains a future scale target, not a claim about the current stress scenario.

The campaign prototype now includes 12 weekly outfit frames, two ending poses, falling temperature, all-screen pausing, and three named local boundary-save slots. Final boss mechanics are a first North Wind gust/snow study. A first procedural cutout leg rig now follows ground distance, with blower vibration, moving wind streaks and seeded gravity/flutter/drift for leaves. Artist-separated limbs, authored turn/ending performances, human difficulty tuning and native device validation remain open. The rural backdrop now leaves its center clear and frames the tree with houses at the sides.

## Technology recommendation and evaluation

The prototype pins **Godot 4.6.3 stable, GDScript, 2D scenes, and the Compatibility renderer**, with matching export templates and a single-threaded web export. This fits scene animation, UI, paper effects, and a potential native Android/iOS workflow while preserving a browser target. The headless Chromium functionality checks pass; native export and minimum-device compatibility remain open gates. Verify the chosen release's actual platform requirements before relying on any export feature.

The selected paper-cut style strengthens the case for 2D: layer textured sprites, animate cutout parts, use inexpensive offset shadows and authored light gradients, and add a small number of supported dynamic lights or shaders where measured benefit justifies them. Build fog from translucent layers rather than depend on volumetric 3D rendering. Paper snowflake sprites, cloud layers, snow-cover masks, and unfolding-flower animation fit the same pipeline. Verify shader, mask, and lighting support in the chosen Compatibility/web export; the concept art is a visual target, not proof that every effect is cheap or available.

Use custom lightweight leaf motion and canopy capture logic rather than a rigid-body object per leaf. Keep the gameplay simulation in logical coordinates with a fixed-step update and seeded schedules. Build presentation around that state so fog, particles, and quality settings cannot alter scoring. Save local state through the engine's persistent storage abstraction; test browser persistence rather than assuming it works.

Use a fixed 360 × 640 logical 9:16 playfield, uniformly fitted within safe-area insets, with scalable art and container-based UI. Unused screen space contains only noninteractive paper framing. Never expand or crop gameplay for a different aspect ratio. Validate default control positions and physical touch-target sizes on the smallest supported device. Test identical seeded scenarios and scripted inputs at 9:16, 9:19.5, 9:21, tablet ratios, and wide browser sizes, including low/high refresh rates. Record geometry equality separately from simulation consistency and human input fairness.

| Candidate | Why consider it | Main uncertainty / tradeoff |
| --- | --- | --- |
| Godot 4, 2D | Integrated editor, animation, native exports, 2D lighting | Mobile-browser performance, web audio/storage, export and hosting compatibility |
| Phaser + TypeScript + Capacitor | Browser-first iteration and broad web tooling; native wrapping | More custom lighting/animation tooling and wrapper/platform integration |
| Godot fixed-camera 3D | True model depth and lighting | Higher art, GPU, web-download, and mobile performance cost |

Godot 2D is a recommendation, not a completed technology decision. If its web spike misses the minimum target devices or required browser support, compare a small Phaser proof of concept before producing engine-specific final assets. Treat 3D as an optional art study; require demonstrated visual benefit and mobile headroom to adopt it.

Native iOS signing and device deployment require an appropriate macOS/Xcode workflow and signing credentials. Android release signing and store distribution also require later platform configuration. Never commit signing material. Browser hosting must serve the export with correct MIME types and any headers required by the selected export mode. Document those requirements when the engine version is pinned.

## Stage 0 — decisions and target matrix

1. Use the design document as the scope baseline. Resolve terminology and make clear which numbers remain provisional.
2. Define minimum supported phone/browser/OS targets and obtain access to representative devices. Include an older Android, an iPhone with a safe-area inset, desktop Chrome/Firefox/Safari where available, and mobile Safari/Chrome.
3. Agree a performance budget: target 60 fps, with a stable 30 fps reduced-effects mode as the provisional minimum. Start with a maximum 150 active gameplay leaves, pooled decorative particles, and a modest web-download budget (initial target under 20 MB compressed).
4. Sketch the portrait composition, touch zones, HUD, menus, and both endings. Record an initial asset inventory and sources.

Exit gate: a target matrix, scoped first release, layout sketches, and explicit decisions/tests for rendering, controls, and persistence. Device targets and numerical budgets are proposals until measured.

## Stage 1 — cross-platform and visual feasibility spike

1. Create a minimal Godot project in a separate coding task; pin engine/export templates and add documented local run commands. Use the existing checkout, not a new worktree unless explicitly requested.
2. Render a placeholder tree, character, and 150 pooled moving leaves. Exercise one light, one fog layer, safe-area-aware controls, and multi-touch movement/blowing.
3. Export browser and Android prototypes. Validate iOS export/build/device execution through a macOS workflow when available; record export-only and real-device results separately.
4. Test web startup, user-gesture audio unlock, focus loss, resize/orientation changes, local persistence, touch scrolling prevention inside the game, and keyboard navigation. If hosting needs extra headers, verify them on the intended host.
5. Profile frame time, memory, thermal behaviour, startup time, and input responsiveness on the minimum devices. Compare effects on/off.
6. Recreate the selected paper-cut style with a few textured layers, shadows, a gust, and warning snowflakes. Measure readability and cost on mobile web. Produce a tiny fixed-camera-3D comparison only if the selected mood cannot be achieved in 2D; do not commission full asset sets for both.

Exit gate: a recorded engine/rendering decision with playable touch/browser builds and export evidence for both native platforms. If native tooling is unavailable, keep that platform gate explicitly open and continue platform-independent work. Cross-platform readiness remains unproven until actual device checks pass.

## Stage 2 — greybox core loop

Implement fixed-screen movement, the upward blower cone, wind/gravity/swirl, canopy capture, and the finite leaf lifecycle. Add rechargeable blower energy, ground segments, visible pile depth, capped slowdown, cumulative danger, and exact week/loss transitions. Prototype one mobility upgrade and one heavy blower upgrade to measure movement/force tradeoffs before expanding the tree. Use simple shapes and temporary audio.

Prototype at least two cone widths and wind strengths. Check whether automatic upward aiming is satisfying before investing in an aim stick. Add a developer overlay for leaf states, capture bounds, current forces, and frame time, kept out of release UI.

Exit gate: a first-time player can catch leaves intentionally, understand a miss and slowdown, finish a week, and lose for a visible reason. No leaf can score twice, vanish without resolution, remain permanently airborne, or trap the player in an immovable pile. The loop should be enjoyable before final art or power-ups.

## Stage 3 — representative vertical slice

Polish one representative mid-autumn week with a final-quality character, tree, leaf style, gust trails, layered background, restrained lighting/fog, audio cues, and touch controls. Implement the main menu, difficulty selection, HUD, pause, first-play prompts, and week summary.

Create short versions of both ending sequences now to test the game's promise. Implement score/combo rules and a minimal local per-difficulty score table so a complete run flow can be tested.

Exit gate: a new player can go from menu to gameplay to an ending and replay without explanation. Leaves remain readable on a small screen with effects enabled. The slice meets the minimum-device frame-time budget. Review the style before creating all seasonal variants.

## Stage 4 — full progression and arcade systems

Author twelve week profiles and a final encounter and all three difficulty variants as data. Add the colour progression, telegraphed crosswinds, heavy-leaf introduction, week transitions, and persistent run danger. Implement the three-branch, two-tier upgrade tree, once-per-week point awards, prerequisites, between-week reallocation, weight effects, and workshop stat previews. Finish all score bonuses, initials entry, top-ten tables with build records, settings, and versioned persistence.

Test mobility, power, endurance, and mixed builds against the same week profiles. Check that no heavy build becomes immobile, no high-power build loses capture reliability, and no refund/transition grants extra points. Tune the difficulty curve from observed rescue rates, run duration, recharge downtime, and reasons for loss; avoid adjusting every variable at once. Temporary pickups are deferred.

Exit gate: each difficulty supports a complete twelve-week win and an understandable loss; score rules cannot be farmed; upgrades support viable alternative builds. Verify scores and settings survive restart, including all three independent tables. Confirm storage failure does not block play.

## Stage 5 — art, animation, audio, and accessibility polish

Later environment pass: slow clouds, occasional noncolliding squirrels, and a possible night/storm week with restrained background lightning. Keep these behind readable gameplay, pause them with the game, provide reduced-motion/flash alternatives, and profile on minimum phones. These specific ambient features remain planned. See [campaign direction](CAMPAIGN.md).

Finish the seasonal scene, sNOw logo, pressure-driven warning snowfall, winter cloud/snow-cover animation with intricate paper snowflakes, sunshine/unfolding-paper-flower victory, transitions, UI states, and audio mix. Replace the mockup flame icon with a labelled blower/fan charge gauge and battery symbol; use a separate snowflake winter-pressure indicator. Add reduced-effects settings, reduced-motion endings, optional haptics, and blower toggle. Make HUD and menu navigation usable with touch, mouse, and keyboard.

Exit gate: safe areas and text remain legible across the target matrix; essential information does not depend on colour/audio alone; full and reduced-motion endings yield the same results. Run a sustained worst-case effects session on minimum hardware and check heat, battery impact, and memory growth.

## Stage 6 — release candidates and distribution

Create reproducible browser, Android, and iOS build instructions and a versioned release checklist. Set up CI for simulation tests and available export smoke checks; reserve signed/device checks for correctly provisioned platform runners. Keep signing credentials in secure CI/platform settings.

Test fresh install, update, offline native play, reload, background/resume, incoming interruptions, browser storage denial/corruption, orientation changes, and score migration. Configure app icons, launch screens, package IDs, store metadata, and required privacy disclosures after inspecting the actual dependencies and distribution requirements.

Exit gate: all required platform checks have evidence, no known progress/scoring/persistence blockers remain, and build instructions reproduce release candidates. Publish a browser build and native test builds before store submission. Store approval and distribution are separate milestones from a successful export.

## Asset creation plan

| Asset group | First pass | Production delivery |
| --- | --- | --- |
| Character + blower | Block silhouette and cone | Idle, walk, blow, recharge, slowed, look-up, shiver, celebrate; consistent pivot points |
| Trees and leaves | Geometric canopy regions | Layered trunk/canopy, seasonal palettes, leaf silhouettes, heavy-leaf variant, anchor metadata |
| Ground and piles | Depth bars per segment | Smooth pile layers tied to actual depth, ground snow masks, flowers and bloom frames |
| Environment | Flat colour backdrop | Sky, clouds, distant trees, foreground accents, warm/cold lighting presets, subtle fog |
| UI and branding | Text buttons and bars | Stylized sNOw logo, icons, readable font, button states, charge/danger indicators, workshop tree and equipment upgrade variants |
| Effects | Debug lines and dots | Gust ribbons, leaf trails, attachment puff, restrained snow, sunshine accents |
| Audio | Temporary cues | Blower loop with clean transitions, rustles, catch/miss/low-charge sounds, wind cues, music and endings |

Create one art style sheet before production: palette, outline thickness, lighting direction, character proportions, scale guide, and small-screen contrast examples. Use modular layers so autumn/winter/win states reuse the scene. Keep source assets editable and export through a documented pipeline with consistent pivots, naming, atlas padding, and import/filter settings.

Track each asset's creator, source URL where applicable, license, attribution, editable source, and exported files in an asset manifest. Temporary/generated/purchased art must receive the same rights and style review before release. Never assume a reference image is licensed for shipping. Choose specific tools and asset dimensions after the visual spike rather than impose a pixel-art pipeline prematurely.

## Validation strategy

Automate gameplay invariants once the implementation exists: exactly-once leaf outcomes, capture eligibility, bounded force/charge/slowdown, combo reset, capacity threshold, final-leaf win/loss precedence, deterministic schedule generation, and upgrade cost/prerequisite/refund rules. Test exactly-once point awards, run resets, build-stat calculation, viable minimum speed, and upgrade-independent score formulas. Test persistence round trips, malformed files, rules-version changes, and stable leaderboard ordering independently of rendering.

Add integration checks for menu → week → summary → next week, full win/loss → score entry → replay, and pause/background behaviour. Include simultaneous touches, touch cancellation, held inputs during pause, score submission once, and cinematic skip/interruption. A simulation-only pass cannot establish mobile input or graphical readiness.

Maintain a small manual device matrix covering minimum hardware, browser/native builds, safe areas, low-effect settings, sound unlock, offline/reload expectations, and local score retention. Use short playtests to discover confusion and sustained runs to measure performance. Record the build, device, scenario, result, and outstanding issue; do not label skipped platform checks as passed.

## Risks and controlled scope reductions

- If atmospheric effects hide leaves or harm frame time, reduce fog/particles/light count before reducing gameplay responsiveness.
- If pile slowdown creates an unrecoverable spiral, reduce its cap and improve pile warnings before adding rescue powers.
- If browser export compatibility fails, resolve it in the engine spike before art production; evaluate the Phaser fallback.
- If twelve weeks plus the finale make sessions long, rely on completed-level checkpoints and keep individual attempts short. Test retry score rollback, backup recovery and browser persistence; do not silently switch to arbitrary mid-level saving.
- If production capacity is limited, defer temporary pickups and extra leaf types first; keep the requested upgrade tree small rather than remove it. Preserve the three difficulties, local high scores, both endings, and readable core loop.

Next: review the playable art prototype on physical Android/iPhone browsers, record minimum-device assumptions and performance, and complete the remaining Stage 1 native/export gates before treating the engine choice as validated across platforms. See PROTOTYPE.md for the implemented subset and exact checks.
