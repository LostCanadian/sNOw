# sNOw — technical art prototype

## What is implemented

- Godot **4.6.3 stable**, GDScript, Compatibility rendering, no third-party engine plugins.
- Modern rural paper-textured scenery with ordinary houses and a solar roof, plus a single central magical tree adapted from the user’s attached textured, asymmetric ancient-tree reference, textured paper-leaf sprites, a transparent electric-blower character, directional wind streaks, local leaf piles, gentle light/fog overlays, and soft shadows.
- Fixed-camera, fixed **360 × 640** logical playfield, uniformly fitted inside browser safe-area padding. Screen shape changes decorative margins, not gameplay geometry.
- Keyboard and independent multi-touch movement/blowing, input release on touch cancellation, pause on application focus loss, and explicit pause/resume.
- A basic procedural cutout rig with hip/knee/ankle chains, distance-driven forward/backward strides, subtle torso motion and weighted electric-blower vibration. Feet stop cycling against boundaries and follow actual slowed/upgraded movement. Wind streaks travel away from the visual nozzle; physics uses its shared rest position.
- Seeded per-leaf flutter phase/frequency, aerodynamic drag, gravity, lateral wind, tumble and foreshortening, with upward blower force, once-only scoring, intact scuffable ground leaves, layered pile slowdown, battery depletion/release-to-recharge, score/combo, 12 main weeks and a final North Wind encounter, and weekly winter pressure.
- A conserved canopy of 288 individually occupied branch positions, with a 96-leaf between-week recovery floor. Shedding opens a gap; an upward-blown leaf reattaches only near a real empty position, including one other than its original spot. Missed leaves leave the tree barer across weeks; overnight regrowth occurs only below the recovery floor and awards no points. Weekly schedules only use the remaining attached leaves. Late-week colours turn orange/red independently of canopy occupancy.
- Between-week workshop with boots, blower and battery branches; prerequisites, one point per completed week 1–12, weight/energy tradeoffs, reallocation, and carryover within a run.
- Blower rank 2 unlocks Leaflift Surge: a brief downward spin lifts nearby original ground leaves, with a 36-second recharge reduced to 31/26 seconds by Battery ranks 3/5. Tap the leaf-lifting button or press E.
- Unique short opening/closing paper panels frame all twelve weeks and the finale. Physics and recharge clocks wait for the panel to fade; tap or Space/Enter can skip it. Achievements are deferred; rescue-streak announcements are removed.
- Small warning flakes near defeat; clouds, cut-paper snowflakes and ground snow on loss; flowers on victory. Main-menu season previews allow immediate art review.
- Soft-effects and mute options; a quiet synthesized electric whirr after starting a run. No microphone input or external audio service.

The title screen offers **Continue / New game** to choose one of three named Save Slots and **Explore the seasons** to review the visual states. New saves choose Breezy, Blustery or Gale; weeks are deliberately short and not the finished difficulty curve. The main menu also opens local **High Scores** and offline **License** notices. See [scores and licenses](SCORES_AND_LICENSES.md) for the storage/deduplication contract and current difficulty tuning. Nothing is purchased with score or real money.

For the exact save/retry contract, clothing progression, final encounter and deferred scenery polish, see [Campaign design](CAMPAIGN.md). Native saves use `user://campaigns.json` with a recovery backup; browser saves use the localStorage key `snow.campaigns.v1` and a separate backup value. Browser close confirmation wording is controlled by the browser; completed checkpoints do not depend on that dialog.

## Run and export

For a fully command-line browser setup, install Python **3.9+**, then run from the checkout:

```sh
# macOS / Linux:
python3 tools/play_web.py --open
# Windows:
py -3 tools/play_web.py --open
```

The launcher downloads the pinned Standard Godot editor and official template archive over HTTPS, checks their SHA-512 hashes against the matching release manifest, imports/exports without opening the editor, then serves only `build/web` on loopback at **http://localhost:8000**. It uses Python’s standard library: no pip dependencies, Bash, system Godot installation or administrator privileges are required. It supports x86-64/ARM64 Windows and Linux, plus the universal macOS build. Linux is tested here; native Windows/macOS execution still needs verification.

The first download includes the approximately **1.2 GB** template archive; only its four browser templates and version metadata are installed. Executables and cached downloads live in ignored `.snow-tools/` in this checkout. Linux/Windows Godot data are isolated there too; macOS templates use `~/Library/Application Support/Godot/export_templates/4.6.3.stable/`. After successful installation, `.snow-tools/downloads/` may be deleted to recover archive space. Existing browser saves remain in the browser’s localStorage.

Subsequent launches reuse installed files and export current source again. `--serve-only` skips installation/export, `--build-only` exits after export, `--port 8080` selects another local port, and `--open` opens the browser after the server starts. Keep the terminal open and stop with Ctrl+C. Use the same hostname/port between sessions to keep the same browser save origin. When port 8000 is already occupied, stop that server or select a different port.

For an existing Godot installation, install Godot 4.6.3 stable and matching export templates using Godot's export-template manager. A plain `godot --path .` or opening `project.godot` works on a configured desktop. The Bash wrapper checks the pinned version and gives cloud tasks writable Godot data/cache/config locations under `/workspace/.snow-tools`; outside `/workspace`, it preserves normal platform locations. Set `SNOW_GODOT_BIN` to the executable path if it is not named `godot`.

```sh
# From the repository root:
bash tools/godot.sh --editor

# Browser release; generated files are deliberately ignored by Git:
bash tools/export_web.sh
python3 -m http.server 8000 --directory build/web
```

Use the locally served page rather than a `file:` URL. The single-threaded export needs WebAssembly and WebGL 2, but does not require threaded-export cross-origin isolation headers. Serve `.wasm` as `application/wasm`. Production hosting should use HTTPS and gzip/Brotli for the engine files; do not infer compressed download size from the raw WASM file. There is no PWA/offline cache yet.

The shell fits a constant portrait rectangle within the viewport's safe-area padding, caps rendering resolution at device pixel ratio 2, and displays readable loading/failure messages. Browser side margins expose no incoming leaves. Native platform safe-area handling remains to be implemented and tested before an Android/iOS release.

### Controls

| Action | Keyboard | Touch / pointer |
| --- | --- | --- |
| Move | A/D or Left/Right | Hold a direction button; slide between directions |
| Blow | Hold Space | Hold the fan button alongside a direction touch |
| Recharge | Release Space | Release the fan; wait briefly |
| Leaflift Surge (Blower rank 2) | Press E | Tap the leaf-lifting button |
| Skip story panel | Space / Enter | Tap after the short minimum |
| Pause/resume | Escape | Tap pause, then Resume |
| Workshop/menu | Tab, arrows where supported, Enter/Space | Tap/click buttons |

Leaving the blower held at zero charge will not refill it: release first. Upgrades reset on a new campaign, not on level retry. Workshop reallocation refunds the earned budget and removes all nodes before rebuilding. Campaign checkpoints, scores within the campaign, canopy state and upgrades persist locally. Separate per-difficulty high-score tables persist locally; settings are not yet persisted.

## Reproducible validation

Current-instance validation: **634 headless checks passed** (424 simulation/build mobility, 38 scene/input, 31 campaign-save, 14 cutout-animation/flutter, 29 score/difficulty, 16 menu/layout/license, 52 airflow/recovery/migration and 30 ground-leaf/ability/story/archive checks). All **ten browser integration scenarios passed without runtime errors**, alongside three ground-leaf/ability/story browser scenarios and exported offline-notice and difficulty-selection checks, with denied-storage and corrupt-primary/backup recovery separately verified in the preceding save-system pass. The headless suites cover simulation, weekly/boss progression, artwork/pausing, and local campaign persistence. Browser checks include real multi-touch, reattachment, five aspect ratios, automatic pause/explicit resume, validated workshop-fixture upgrades, named-save reload, retry, exit confirmation and ending previews. The latest run outcome is recorded in ignored `test-results/browser-results.json`; native phone performance is not established by these checks.

Actual screenshots of [gameplay](images/prototype-gameplay.png), [save slots](images/prototype-save-slots.png), [week 12](images/prototype-week-12.png), [the boss study](images/prototype-boss.png), [victory](images/prototype-victory.png), the [sparse late-autumn warning preview](images/prototype-warning.png), and the [bare-tree winter preview](images/prototype-winter.png) are included in the repository. The generated release is under ignored `build/web/`; a portable browser bundle is `build/snow-web-prototype.zip`. The bundle must still be served over HTTP/HTTPS, not opened directly from disk.

The simulation and scene/input suites have no extra dependencies:

```sh
bash tools/godot.sh --headless --script tests/test_loop.gd
bash tools/godot.sh --headless --script tests/test_ui.gd
bash tools/godot.sh --headless --script tests/test_campaign.gd
bash tools/godot.sh --headless --script tests/test_actor.gd
bash tools/godot.sh --headless --script tests/test_scores.gd
bash tools/godot.sh --headless --script tests/test_menus.gd
bash tools/godot.sh --headless --script tests/test_progression.gd
bash tools/godot.sh --headless --script tests/test_ground_story.gd
```

Browser integration uses **Python Playwright 1.62.0** and an installed Chromium. Those are test tools, not game/runtime dependencies. The ground/story check records video using Playwright’s ffmpeg and requires system ffmpeg for candidate-frame extraction. To reproduce in a machine that lacks them, install that Playwright version in a development virtual environment and install its Chromium browser or supply your system Chromium path. Build a separate debug export, leave the server above running, then:

```sh
mkdir -p build/web/test
bash tools/godot.sh --headless --export-debug Web build/web/test/index.html
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
python3 tests/browser_menus.py
# Generate validated study checkpoints, then exercise the new ability/story flow:
bash tools/godot.sh --headless --script tests/visual_fixture.gd
python3 tests/browser_ground_story.py
```

The debug browser check enables a read-only `window.snowSnapshot` only in debug builds with the explicit `?test=1` flag. Release builds do not expose it. The test drives actual keyboard and browser multi-touch input; it does not use a cheat API to advance weeks or award upgrades. It writes screenshots and a JSON report to ignored `test-results/`. Do not publish the nested debug export as part of a release.

### Validation boundaries

The headless suites cover leaf rescue/miss accounting, branch occupancy, persistent canopy gaps, battery recovery, movement bounds, upgrade economics, minimum mobility for all builds, final-leaf loss precedence, seeded repeatability, a 288-leaf canopy with a bounded 150-leaf active scenario, focus loss, touch release/cancellation, workshop transitions and run reset. The browser suite additionally checks real reload persistence of workshop choices, automatic blur pause, explicit resume, checkpoint retry and confirmed exit. The native save suite covers all three named slots, malformed files, backup recovery, precise random-state round trips, and the final saved victory.

Headless Chromium uses software WebGL in this environment. It can establish functionality and geometry, not phone frame rate, thermal behaviour, perceived sound quality, native touch comfort, Safari compatibility, or cross-platform deterministic scoring. Real Android/iOS and mobile-browser tests remain required. No signed native builds or store submissions are included.

## Deliberate prototype limits

- Distant scenery remains a composited background plate with baked lighting. The Season Tree, its foliage and atmospheric overlays are separate runtime layers; the whole illustrated tree sprite is paired with twig-coordinate/orientation metadata in `scripts/canopy.gd`. This is not a final rigged 2.5D or fully dynamic lighting pipeline.
- The character uses 12 wardrobe atlas frames plus separate warm victory and bundled sad-defeat poses, with smooth mipmapped filtering. A lightweight CPU-skinned cutout mesh provides the first distance-synchronized stride, torso motion and blower vibration; it reuses the costume artwork rather than separately painted limb layers. It turns with movement and aims upright at rest; pose, cone and force share the same geometry. Production needs artist-separated limbs, richer arm/face poses, turn transitions and bespoke looking-up/celebration animation.
- Branch capture has a forgiving 15-logical-pixel radius and sweeps each motion segment to avoid missing slots at higher speeds. The radius, branch layout, foliage density and marker visibility need phone-scale playtesting. Arriving at an arbitrary sky height never counts as a rescue.
- Weather/endings demonstrate the visual states rather than finished cinematic direction. Warning flakes do not collide with leaves or change movement.
- Workshop purchases immediately change the visible build readout; production needs a fuller before/after preview and confirmation flow.
- No persistent settings, exact mid-attempt resume after process termination, global leaderboard, production music, or temporary pickups. These remain in the staged design plan.
- Art readability, battery cadence, week difficulty, scoring and all upgrade numbers need human playtesting. Fixed-step logic and equal viewports do not solve every future ranked-play fairness issue.

Next gate: play this on physical Android and iPhone browsers, review empty-branch aiming and the paper effect at phone scale, then refine branch art, scenery depth and animated character assets.

Week-12 and boss screenshots use validated art-review checkpoint fixtures generated by `tests/visual_fixture.gd`, not a claim that a human completed the full campaign. Main browser integration plays an early level through rescue/loss/retry; workshop/save tests use a validated fixture. Human full-campaign pacing and physical-device playtests remain outstanding.

## Motion and art review

The selected runtime tree is explicitly `assets/art/season_tree.png`; the previously misidentified `bare_tree.png` is retired. The rural backdrop has houses at the far edges and a quiet central clearing. Branch positions were remapped while retaining the first 48 save-compatible identities and adding 240 new positions.

The cutout mesh updates at 30 Hz while fixed-step movement/leaf forces and wind animation run at 60 Hz; settled idle poses reuse their mesh. Joint transforms are cached before skinning. Reduced effects lowers torso/motor motion and wind streak count. Animation clocks and physics freeze together when paused. Seeded leaf variation is generated on shedding, never from per-frame noise, preserving repeatable retries. These are prototype motion systems, not a finished hand-authored walk cycle.

To regenerate the gameplay/season/workshop screenshots from a release export, run `tests/visual_fixture.gd`, serve `build/web`, then `python3 tests/capture_art.py`. The optional `--video` uses Playwright’s ffmpeg to capture real input and system ffmpeg to encode the trimmed MP4. The resulting [motion clip](images/prototype-motion.mp4) demonstrates the running browser build; software rendering in the cloud does not establish device frame rate.

Launcher verification: `python3 tests/test_launcher.py` checks platform selection, cached-download reuse, checksum/incomplete-download failures and archive path containment without network access. The fresh Linux download/import/export and loopback HTTP serve are also exercised separately.

Current menu captures: [main menu](images/prototype-menu.png), [High Scores](images/prototype-high-scores.png), and [License](images/prototype-license.png). Score screenshots use an actual browser-played terminal result.

Updated campaign rules are in [CAMPAIGN.md](CAMPAIGN.md). The illustrated [workshop](images/prototype-workshop.png) has eighteen inspectable nodes and separate descriptions; [detail view](images/prototype-workshop-detail.png). Native layout tests check non-overlapping hit areas and bounded images/text. Title, Save Slots labels and browser branding now use sNOw only; native legacy save paths and archived old scores remain supported. All winning-build and pacing claims still require human full-campaign testing.

The [opening panel](images/prototype-story-intro.png), [closing panel](images/prototype-story-outro.png), [intact ground leaves](images/prototype-ground-leaves.png), and [Leaflift Surge study](images/prototype-surge.png) are actual browser frames. The [surge motion clip](images/prototype-surge.mp4) shows the first cutout spin and leaf fountain. See [abilities and chapter text](ABILITIES_AND_STORY.md) for cooldowns, recovery accounting, score-version migration and capture-fixture boundaries. The spin is a procedural cutout turn, still awaiting artist-authored poses.
