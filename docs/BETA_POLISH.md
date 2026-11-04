# Beta polish stages

1. Results and checkpoints: compact, equal-size actions; Gold Leaf currency badge; focus pause only for live scenes; saved levels offer Continue from the beginning.
2. Leaf control: position-dependent outward airflow, independent turbulence, and frontmost canopy detachment.
3. Workshop: equipment tabs, branching icon nodes and prerequisites, two Gold Leaves per completed week, and a higher-cost Whirlwind ability. Preserve and migrate earlier campaigns.
4. Presentation: separated leg parts with joint animation; original synthesized retro music and effects for the scenes and actions.

Each stage is committed and pushed separately on `beta-polish` after its relevant checks. Browser and headless coverage validate the complete flow at the end.

Leaf control uses smooth per-leaf turbulence and an outward force proportional to distance across the cone. The screen-edge return breeze remains active. Shedding peels overlapping leaves in the same order as the renderer while using seasonal colour weights among visible candidates. This makes the seasonal mix slightly broader than an unrestricted weighted draw, in exchange for visible detachment.

## Branching progression (rules 6)

Boots, Blower and Battery each have ten nodes: a root, two paths, four specializations and three capstones. The middle capstone joins both inner paths. Select an icon to read its name, effect, prerequisites and Gold Leaf cost; only the current equipment tree is shown. Tabs animate their nodes; the internal reduced-effects mode disables that motion. Root and specialization nodes cost one Gold Leaf, capstones cost two, and Whirlwind costs three after Torque fan (four total). Each completed main week awards two Gold Leaves; the boss awards none. The reset icon opens a Reset all upgrades / Cancel confirmation and returns exact costs.

Save data stores explicit node IDs and verifies prerequisites, duplicates, node counts and budget. Earlier campaigns double earned currency, retain mapped equipment and Whirlwind access, and receive the remainder after the mapped node costs. All historical scores share one top ten per difficulty, with one best result per campaign. Earlier score scales normalize during import; no archive or rules selector appears in the game.

## Animation and audio

The lower body uses a separate 18-part illustrated atlas: thigh, shin and shoe per leg across three clothing sets. Hip/knee inverse kinematics preserves bone lengths, stance feet stay planted, and swing feet tilt slightly. Travel drives the 29-unit gait, so standing at a boundary cannot march in place. The original body/wardrobe remains above the independently drawn legs.

Eighteen original sixteen-bar scores cover each of the twelve weeks, North Wind, menu, workshop, results, victory and winter. Sunny weeks have bright, brisk hooks; rainy weeks use softer minor-key melodies; nights leave more space over a warm bass. Each arrangement has a contrasting bridge, a varied final refrain, seventh-chord pads, syncopated bass, arpeggios, answering melodies and small drum fills. Original MIDI sources ship beside rendered Ogg loops; no MIDI player or soundfont is required at runtime. Crossfades join scenes. A layered blower loop changes pitch with charge, while steps, menus, purchases, resets, Whirlwind, leaves, low battery and week completion have separate effects. Rescue cues are rate-limited; ground impacts are silent. Audio waits for user interaction; pause suspends music/stops effects; mute silences all layers. Music/effects sliders and mute persist locally. Short Web effects use Godot's default sample path. Long Web music streams compressed MP3 through two persistent browser media elements with a WebAudio output, avoiding long-buffer allocation failures in Godot's sample path. The bytes come from the game package, so this adds no network dependency. Both elements unlock on the same input gesture; crossfades, pause, mute and volume still use the shared audio director. Native music uses Godot players.

Regenerate audio with `python3 tools/generate_audio.py` (NumPy and ffmpeg). Rebuild limb metadata with `python3 tools/build_limb_regions.py` (Pillow, NumPy, SciPy). Both are authoring-only tools.

## Review images

The [compact results](images/beta-results.png) and [Whirlwind workshop](images/beta-workshop.png) are browser captures from validated saved-week studies, not claims of a human-played campaign. Native phones and subjective full-campaign balance still need playtesting.

## Validation status

Twenty-seven headless regression scripts pass 986 checks across simulation, leaf identity, positional airflow, detachment, progression prerequisites, save migration/storage, scores, UI, rigid animation, winter, scene continuity and audio routing. All 26 Python launcher/mobile-export/composition checks also pass. Godot 4.6.3 produces the release Web export successfully. Browser output measurements verify actual music, silence while paused/muted and recovery after unmuting; the browser suite also exercises the end-to-end game and workshop flow. These checks do not substitute for native phone frame-rate, subjective listening/mix review or full-campaign balance playtests.

The final release was also launched in Chromium after switching browser streams to MP3 for codec compatibility: its packaged music produced a nonzero WebAudio output and `?test=1` exposed no debug snapshot. The complete debug browser flow passed with no runtime errors before that codec-only change; the streamed music adapter and controls are shared.

The main menu now uses a speaker-only audio settings button. Mute is inside the audio panel alongside the two volume sliders, and the Soft effects toggle is removed from the menu.

## Leaf piles and rendering follow-up

The canopy now has 2,160 distinct leaves (25% fewer), at radius 7.8 (30% larger), including 144 extra central attachments. Weekly shedding and miss allowances scale to the lighter canopy; the recovery floor is 720. Previous save densities migrate proportionally while preserving score, campaign identity and upgrade purchases.

Leaf identities retain their depth ordering across detachment and flight in one instanced pass. Foreground occluders shed first, before seasonal colour preference. Two independent fine support surfaces stack landed leaves into growing piles; alternate identities draw before/after the player. The ending simulates only airborne leaves at 30 Hz and interpolates movement for rendering. Bulk instance buffers replace thousands of server calls and individual ground/air draw commands. Warning snow emits above the top edge, including when snowfall density increases.

A 600-frame headless CPU study measured about 0.82 seconds combined simulation/upload work versus 1.43 seconds previously (roughly 43% less); this is a renderer-update benchmark, not a mobile frame-rate claim. Physical device profiling remains necessary.

The walking atlas has been replaced with textured paper trouser, calf and shoe pieces without exposed connector tabs. The two-bone solver now bends toward the toes (including mirrored travel), using the same bend at rest so starting a stride does not flip the joint. Bone length, planted-foot and directional-knee checks cover complete strides.

## Paper workshop and checkpoint upgrades

All thirty nodes now use original textured paper object illustrations, with a matching Gold Leaf token and reset icon. Equipment tabs are image-only. The currency count sits beside a small leaf; Done returns to the originating screen. Hover popups/highlights and the Saved footer have been removed.

Upgrades are available from results (including a loss), saved Continue, and the live restart review. Continue and Retry purchases update the level checkpoint immediately. During a live restart review, choices stay in a draft: Cancel resumes the unchanged attempt, while Restart commits and saves the selected kit. Mid-attempt purchases remain disallowed.

High-score storage version 2 merges historical tables, normalizes pre-score-reduction values, keeps the best row per campaign, and saves one top ten per difficulty without rules metadata. Old browser/native keys and backups still load.

## Held blower recovery

After depletion, holding Space/touch continues a low-power draft while charging at 55% of the normal recharge rate. Its short reach and near-gravity lift can arrest a falling leaf and raise it slightly, without marking it for capture. Release/press restores full power using the partial charge; reaching full charge resumes full power automatically. The weak draft has shorter/fainter streaks, a slower fan, a charging bolt, and a quieter lower-pitched motor. Pause and non-playing scenes freeze recovery.

Reproduce the CPU loss-animation study with `bash tools/godot.sh --headless --script tools/bench_leaf_fall.gd`. Browser tests additionally cover every-leaf landing before snow, pause/focus behavior, paper tabs and reset cancellation, checkpoint upgrades, both low-power recovery exits, WebAudio output and persistent audio controls.

## Fluid reattachment and paper winter clouds

A caught leaf now follows a 0.34-second curve from its incoming position, rotation and paper tilt to the branch. The branch is reserved and the rescue scores once at capture; its existing instance keeps the same depth while settling. Pause freezes the motion. The last leaf continues settling during the closing interlude; winter and any new detachment preserve a leaf’s current visible pose. The motion is transient presentation data, so existing saves remain compatible.

Ground impacts are silent, including batches of fallen leaves. Rescue cues remain rate-limited independently. The Upgrades results button has no hover tooltip.

The [winter preview](images/paper-cloud-winter.png) uses an original textured paper cloud bank with rounded alpha edges, smooth mipmapped filtering and restrained drift, replacing the polygon silhouettes. The sprite extends beyond both sides and the top throughout its entrance. `tests/browser_leaf_settle.py` exercises a real blower capture from a validated one-leaf study, then reviews the Upgrades hover state and warning/winter cloud scenes.

## Finale timing and attachment cues

Victory now lets the 3.5-second flower animation finish and holds the finished scene for another 5.5 seconds. Its closing sentence then uses a separate story card before Results, with pause/skip behavior matching the other interludes. The sentence is removed from the Results action grid. Attachment suggestions now cycle through at most five fully fading glints.

## North Wind and seasonal balance

The North Wind is now a fast ribbon of curls drawn over the tree, with its visible path shared by branch stripping and local airborne forces. Each 4.8-second pass has a telegraphed approach, a 1.5-second sweep, and a recovery window. Only real pending identities in the swept capsule detach; packets are bounded and each identity is scheduled once. Later passes target remaining foliage so the encounter finishes.

Seasonal twig clusters thin a healthy crown from 2,160 to 960 leaves, with a separate saved seasonal-loss counter. The 720-leaf recovery floor remains above the largest 636-leaf finale schedule, preventing a nearly empty tree from making the boss trivial. Initial middle-right coverage improves through 280 relocated sprays on verified painted bark in the middle-right and central fork, without increasing total density. Starting speed is now 50; two early speed upgrades raise it to 61. All these values still need human balance playtesting.

The browser finale study covers the completed flower hold, the separate closing card with pause/resume, clean Results, visible gusts in both directions, and a fresh first-week crown. Completed-save loading also replays the victory scene without awarding points again. Perfect-response scheduling studies finish all three finite boss profiles; idle depleted-crown studies still lose at their normal miss limits. These are simulation/flow checks, not claims of a human full-campaign win.

Browser review stills: [North Wind sweep](images/north-wind-sweep.png), [victory closing card](images/finale-closing-card.png), and [initial branch coverage](images/filled-middle-right-crown.png). The first two use validated study checkpoints; the crown capture starts a fresh campaign.

## Weather and defeat continuity

Every level intro clears the snow pool, including Next Week. Snow is also cleared and hidden below 55% weekly frost pressure, so particles cannot persist into safe gameplay or reappear halfway down the screen after recovery. Both finished endings now linger: victory holds 5.5 seconds after its flowers finish before the closing card, and defeat holds three seconds after snow finishes accumulating before Continue appears. Pause freezes these holds.

Starting speed is 50 logical units/second. Existing percentage boot effects apply to that baseline. An additional 120 placements now point into the central fork, west of the prior middle-right pass, using actual inner branches while retaining all 2,160 identities.

Defeat uses twelve matched sad outfit illustrations instead of one bundled winter pose. The current costume index and facing are retained, with a short transition from the live pose. Victory retains its existing celebration.

Explore the seasons uses the same current-week outfit selection. Its weather settings no longer change the clothing to a winter costume; the winter preview keeps that outfit in its matching sad pose.

`tests/browser_scene_continuity.py` loads validated study checkpoints and uses real buttons and keyboard input to check warning snow through Next Week, a clean next-level opening, and early/mid-season defeats with the correct clothing and the extra ending hold. It completes without browser runtime errors. Review stills: [early outfit defeat](images/defeat-early-outfit.png) and [hoodie outfit defeat](images/defeat-hoodie-outfit.png).


## Living valley and expanded soundtrack

[Ambient world](AMBIENT_WORLD.md) now ships: paper wildlife, stable weekly time/weather choices, separate painted overcast/dusk/night valleys, fog, rain, soft sky glow, feathered sun rays and cosmetic leaf rustling. Explore the seasons has week arrows and plays the corresponding score, so each atmosphere can be reviewed directly. Background wildlife, wind and weather freeze with pause and never change the gameplay RNG.

`tools/score_composition.py` holds the eighteen original sixteen-bar arrangements. `tools/generate_audio.py` renders their MIDI sources to native Ogg and packaged Web MP3 streams. `assets/audio/score_catalog.json` records tempo, mood, duration, note-event count, peak and RMS; tests verify unique weekly note sequences, contrasting sections, quieter/lower night melodies, headroom and both encoded formats. Existing short effects are retained unchanged. The old three seasonal music files are replaced by twelve individual weekly pieces.

Browser checks cover all thirteen atmosphere/score pairs, textured canopy colors, moving paper animals, actual WebAudio output and silence while paused. The native suite adds persistence, isolated cosmetic randomness, rare full-moon wildlife, coat blending and scene pause checks. These are functional/rendering checks; native phone frame rate and subjective listening still need playtesting.

Release Web validation also uses `tests/browser_release_atmospheres.py`, since the optimized Compatibility template exposed a packed instance-colour problem absent from some debug captures. Leaf passes now use an explicit 128×34 RGBA lookup by stable depth index (17 rows of colours plus 17 rows of branch-motion flags), retaining four bulk uploads, the existing identity ordering and independent front/rear piles. The renderer samples that small palette instead of relying on the packed instance tint. Scene layers keep rear foliage, caretaker, foreground piles, snow cover and UI in order.


## Planted tree base and smooth moon

A separate textured paper meadow bank covers the bottom root fan, behind the player and leaf piles. Its grass, clover and low plants overlap the unchanged tree painting. The moon now has a feathered circular edge and phase terminator; its dark side lets the actual sky show through instead of painting a second hard-edged circle over it. The original paper-leaf texture provides faint grain. [Tree-base review](images/planted-roots.png).


## Wildlife animation and branch placement

Four paper motion atlases replace the sixteen-pose reference sheet with seventy-two poses. The owl sits on verified main-tree bark in a less crowded leaf area, tracks the player's horizontal position through front-view head poses, and occasionally plays an eight-frame wingbeat. The squirrel draws over the trunk, climbs once, jumps onto a branch and remains there to nibble. Grass, leaves and the player draw in front of tree residents. Rabbits hop and graze, disappear offscreen and return facing the other way; wolves trot and sniff; bats use a full eight-frame wingbeat. Pausing freezes all clocks.

The nighttime **Full moon** preview action makes rare visitors easy to inspect and cannot change campaign weather or saves. Review captures: [squirrel climbing](images/squirrel-climbing.png), [branch resident](images/squirrel-perched.png), [owl gaze](images/owl-gaze.png), [full-moon visitors](images/full-moon-visitors.png). Motion and asset checks live in `tests/test_wildlife_polish.gd`; `tests/browser_wildlife_polish.py` uses real buttons/keys and read-only frame observations.

Run native regressions with `python3 tools/check_godot_tests.py`. It rejects engine/script errors even when Godot returns a successful exit code, in addition to checking each script's reported failures. Test teardown gives the mixer time to release its last sample before quitting.

### November 2026: planted ground and spring transition

The root bank is now completely vegetated paper artwork, with a feathered lower edge and lighting/colour treatments for autumn, rain, dusk, night and winter. Victory sends a short warm light pulse through the tree. Missing leaves grow from their stems in a staggered branch wave; the existing crown changes colour, the meadow greens over 5.5 seconds, and the current winter outfit dissolves into the summer celebration pose. The landscape crossfades into sunlight. These are presentation effects and do not change saved leaf identities, rewards or RNG. Settled snow has a smooth highlighted rim and shaded banks.

Validation: seven growth/render-buffer checks, the existing finale timing tests, and the browser finale flow. Ambient rustle now reaches independently timed leaves throughout the crown; the attachment regression allows its small cosmetic motion after a leaf has settled.


### North Wind and snow polish

The finale uses a sixteen-frame paper wind atlas with interpolated poses, rolling motion and a curved, side-to-side route that travels completely offscreen. Its physical stripping capsule and local swirling force follow the same route. Gusts impart a rolling impulse to real leaves; regular three-leaf falls continue between gusts, sharing the existing finite schedule. Fine chaff and orbiting debris add motion without creating scoring leaves. Rules 10 retains earlier saves and the single high-score table.

Validation: 38 finale checks include finite unique schedules on all difficulties, playable minimum foliage, ordinary falling during recovery, curved exit/reentry and swept-path stripping. The browser finale study shows textured gusts on both approaches and verifies pause and ending flow. Small falling snow crystals now use smooth shaded silhouettes; the settled snowbank has an antialiased highlighted rim and soft folds. [Wind return review](images/north-wind-sweep.png).


### Original score and story revision

All thirteen chapters now describe the caretaker's effort to preserve the valley's last warm tree, retaining hints of an older watch, warm roots and a winter flower. Each line fits the existing story card at its actual font size.

The eighteen original sixteen-bar scores retain their hooks and contrasting sections, with lower lead registers (no lead above MIDI 81), at most four melody attacks per bar, held notes and rests. Close chord inversions and sparse replies replace overlapping high arpeggios. Band-limited quarter/half-duty pulses, triangle bass, reed, flute, mallet, bell and soft string voices provide different palettes; the bridge changes the foreground voice. Rain/mist/night pieces slow to 74–90 BPM; the finale uses a deliberate 116 BPM pulse. These are original melodies, using broad NES instrumentation cues without reproducing any existing game's music.

Regenerate just the music with `python3 tools/generate_audio.py --music-only`; this preserves every existing sound effect. The catalog records each instrumentation palette and measured output levels. Five composition tests cover form, register, breathing room, instrument contrast, encoding and headroom. Debug finale and release atmosphere checks cover actual packaged playback; native-device listening and final mix remain playtest work.


The snow samples both actual leaf-pile lanes. A fine coating follows their surfaces before accumulating into at most two rounded banks fitted to the piles. Bank slopes, the valley between them and paper grain define the shading; no independent marks are scattered over the snow. Geometry checks verify coverage, curvature, determinism, unchanged pile supports and accumulation from the leaves rather than from below. Victory also preserves the final leaf's unfinished attachment and the caretaker's facing through the outfit dissolve; the growth suite covers that terminal capture.


### Canopy performance regression fix

The November rustle change accidentally rewrote all 2,160 leaf transforms and colours on every active frame, rather than only updating the small moving population. The victory cache key also kept changing after all growth had finished. Rustle now runs in the vertex shader, with a separate attached-leaf mask in the lower half of the colour texture. Airborne/ground leaves keep their physical transforms, front ground passes skip breeze work, and completed victory/preview canopies stop rebuilding. The explicit Compatibility colour lookup and front/rear ordering are preserved.

`bash tools/godot.sh --headless --script tools/profile_canopy.gd` measures CPU presentation work, excluding GPU rendering. On this executor, 50 airborne leaves fell from 6.66 to 0.10 ms per update, 100 grounded leaves from 6.75 to 0.19 ms, and completed victory from 3.82 to 0.002 ms. These are component timings, not whole-game FPS. `tools/benchmark_browser.py` uses real menu/game input and CDP thread CPU timing: Chromium gameplay main-thread work fell from 120.88 to 20.38 ms per sampled frame. SwiftShader remained GPU-bound near 5 FPS in both versions, so this does not establish physical-device frame rates. The same 360×640 viewport, release template and input sequence were used.

Six native regressions cover stationary-canopy uploads, attached/detached breeze masks, unchanged palette colours and completed victory/preview caching. Browser release checks retain the thirteen-scene colour regression and ending previews.


### Snow accumulation and flake sizes

Snow begins with a thin white coating on the settled leaf silhouettes. Coverage builds gradually while the contour joins into broad banks, preserving the relationship to the piles instead of lifting a sheet from below. Empty ground receives a shallow coat. Shading follows the banks' slopes and shared valley, computed per vertex on narrow contour strips; the settled canvas commands stay cached once accumulation ends. The old sixteen scattered shading streaks are removed.

All flakes now share a continuous 0.65–6 logical-pixel radius distribution, weighted toward smaller flakes. Crystal detail fades in through the middle sizes, and larger flakes move faster to suggest depth. This replaces the old split between tiny dots and every ninth flake rendered up to roughly 29 pixels across. Mipmaps and soft shadows preserve smooth edges. Emission still starts above the screen and waits until the existing danger threshold.

Validation adds ten snow geometry/accumulation checks, four size/distribution checks, and `tests/browser_snowfall.py`, which follows an actual saved level through loss, first coating, growing banks, the final hold and Results. These are real input/render checks over a validated checkpoint, not a complete human campaign playtest.

Review captures: [coating on the real leaf piles](images/snow-first-coating.png), [release preview bank shading](images/snow-banks.png). Final verification: 26 native scripts / 956 checks, 26 Python tests, real-input snowfall accumulation, and release rendering across all thirteen atmospheres and both ending previews.


### Wind pacing, quiet glints and player-controlled endings

The old approach arcs are removed; the North Wind uses only the paper gust artwork when it enters. Lane selection scores the whole curved path against pending leaves once per pass. Four-leaf packets spaced by at least 50 ms spread releases along the sweep. The finite weekly schedule, nearby-leaf stripping and ordinary falling leaves remain intact. Gameplay rules 10 retain existing saves and the unified score tables.

Vacated spots cool for five seconds; older active spots remain usable by leaves whose own cooldown has elapsed. Full-power blower acceleration and upward speed vary per leaf, using an integer identity mix independent of canopy depth and colour. The recharge draft keeps its existing holding power. The wind/clump study covers four seeds and real capture eligibility.

Attachment suggestions now use at most five glints, with a shuffled cycle and complete fade-in/fade-out. The scheduler never changes capture eligibility, and unlit ready active spots still accept leaves. It works on the cached candidate areas and a bounded active list, preserving the earlier canopy performance fix.

After losing, the snow finishes and the existing short hold completes before a bottom-right Continue action appears. Victory still finishes its regrowth/flower sequence and closing card, then offers Continue. Both scenes keep their wildlife, weather and music running until the player opens Results. Loaded completed campaigns replay that sequence without awarding anything again. Ordinary weekly interludes still lead directly to Results. The main-menu speaker icon is centered.

Validation includes the cooldown and clump study, seven glint scheduling checks, manual victory/loss continuation, unchanged score on long ending holds, save compatibility and real-input browser captures. The one-leaf attachment study now starts in week two and uses a naturally old empty spot. [Watching the victory scene](images/ending-continue.png) · [Clean wind approach](images/wind-approach.png).


### Progressively fewer anchors and detached-leaf cooldown

Rules 11 limits the active empty attachment pool to 64 / 60 / 56 / 52 / 48 / 44 / 40 / 36 / 32 / 28 / 24 / 20 / 16 over the thirteen stages, without removing any foliage. Targets stay fixed until filled; replacements spread across bare branches, with a short history discouraging immediate reuse of the same area. Cooling targets count toward the cap. A newly emptied position need not become active while the pool is full. Only ready active positions appear in the existing five-glint cycle; unlit active positions still work.

Every detached leaf waits two seconds before it can attach anywhere, independently of the five-second cooldown on its former spot. Blower lift and steering still work immediately. The timer follows the original detachment rather than animation age, so a later ground recovery does not restart it. Intro cards display the current limit and delay. Existing saves derive the pool on restore; unified score tables and all leaf identities remain intact.

Twenty-nine new checks cover decreasing limits, unchanged foliage and simulation randomness, spatial spread, inactive gaps, stable targets and replacement, independent spot/leaf timing, real blower captures, a twenty-leaf gust and old-save/retry compatibility. Density-index and glint checks use the same eligibility rules. The complete suite passes 27 scripts / 986 checks and 26 Python tests. A native headless sample of 150 finale rescues averaged 0.265 ms for settlement and target replenishment (95th percentile 0.297 ms); this is not a device frame-rate measurement. Full-campaign balance still requires human playtesting.

Browser input checks confirm a delayed capture still interpolates through multiple poses, the finale exposes exactly sixteen targets, North Wind passes work in both directions, and victory remains behind the manual Continue flow. These use validated study saves, not a human campaign completion.

The release Web build also passes the thirteen-atmosphere and two-ending render smoke check, with packaged music playing, no browser errors and no exposed debug hooks.
