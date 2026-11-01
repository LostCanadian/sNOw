# Paper & Lanterns — technical art prototype

## What is implemented

- Godot **4.6.3 stable**, GDScript, Compatibility rendering, no third-party engine plugins.
- Modern rural paper-textured scenery with ordinary houses and a solar roof, plus independently drawn bare trees, textured paper-leaf sprites, a transparent electric-blower character, directional wind streaks, local leaf piles, gentle light/fog overlays, and soft shadows.
- Fixed-camera, fixed **360 × 640** logical playfield, uniformly fitted inside browser safe-area padding. Screen shape changes decorative margins, not gameplay geometry.
- Keyboard and independent multi-touch movement/blowing, input release on touch cancellation, pause on application focus loss, and explicit pause/resume.
- Upward leaf force with mild flutter, once-only rescue/miss outcomes, pile slowdown, battery depletion/release-to-recharge, score/combo, 12 main weeks and a final North Wind encounter, and cumulative winter pressure.
- A conserved canopy of 48 individually occupied branch positions. Shedding opens a gap; an upward-blown leaf reattaches only near a real empty position, including one other than its original spot. Missed leaves leave the trees barer across weeks, rather than resetting the foliage overnight. Weekly schedules only use the remaining attached leaves. Late-week colours turn orange/red independently of canopy occupancy.
- Between-week workshop with boots, blower and battery branches; prerequisites, one point per completed week 1–12, weight/energy tradeoffs, reallocation, and carryover within a run.
- Small warning flakes near defeat; clouds, cut-paper snowflakes and ground snow on loss; flowers on victory. Main-menu season previews allow immediate art review.
- Soft-effects and mute options; a quiet synthesized electric whirr after starting a run. No microphone input or external audio service.

The title screen offers **Continue / New garden** to choose one of three named local save slots and **Explore the seasons** to review the visual states. The prototype has one tuning profile; weeks are deliberately short and not the finished difficulty curve. Nothing is purchased with score or real money.

For the exact save/retry contract, clothing progression, final encounter and deferred scenery polish, see [Campaign design](CAMPAIGN.md). Native saves use `user://campaigns.json` with a recovery backup; browser saves use the localStorage key `snow.campaigns.v1` and a separate backup value. Browser close confirmation wording is controlled by the browser; completed checkpoints do not depend on that dialog.

## Run and export

Install Godot 4.6.3 stable and matching export templates using Godot's export-template manager. A plain `godot --path .` or opening `project.godot` works on a configured desktop. The Bash wrapper checks the pinned version and gives cloud tasks writable Godot data/cache/config locations under `/workspace/.snow-tools`; outside `/workspace`, it preserves normal platform locations. Set `SNOW_GODOT_BIN` to the executable path if it is not named `godot`.

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
| Pause/resume | Escape | Tap pause, then Resume |
| Workshop/menu | Tab, arrows where supported, Enter/Space | Tap/click buttons |

Leaving the blower held at zero charge will not refill it: release first. Upgrades reset on a new campaign, not on level retry. Workshop reallocation refunds the earned budget and removes all nodes before rebuilding. Campaign checkpoints, scores within the campaign, canopy state and upgrades persist locally. Settings and separate high-score tables are not yet persisted.

## Reproducible validation

Current-instance validation: **175 headless checks passed** (108 simulation, 36 scene/input, 31 campaign-save checks). All **nine browser integration scenarios passed without runtime errors**, plus separate browser denied-storage and corrupt-primary/backup recovery checks. The headless suites cover simulation, weekly/boss progression, artwork/pausing, and local campaign persistence. Browser checks include real multi-touch, reattachment, five aspect ratios, automatic pause/explicit resume, level completion, named-save reload, retry, exit confirmation and ending previews. The latest run outcome is recorded in ignored `test-results/browser-results.json`; native phone performance is not established by these checks.

Actual screenshots of [gameplay](images/prototype-gameplay.png), [save slots](images/prototype-save-slots.png), [week 12](images/prototype-week-12.png), [the boss study](images/prototype-boss.png), [victory](images/prototype-victory.png), the [sparse late-autumn warning preview](images/prototype-warning.png), and the [bare-tree winter preview](images/prototype-winter.png) are included in the repository. The generated release is under ignored `build/web/`; a portable browser bundle is `build/snow-web-prototype.zip`. The bundle must still be served over HTTP/HTTPS, not opened directly from disk.

The simulation and scene/input suites have no extra dependencies:

```sh
bash tools/godot.sh --headless --script tests/test_loop.gd
bash tools/godot.sh --headless --script tests/test_ui.gd
bash tools/godot.sh --headless --script tests/test_campaign.gd
```

Browser integration uses **Python Playwright 1.62.0** and an installed Chromium. Those are test tools, not game/runtime dependencies. To reproduce in a machine that lacks them, install that Playwright version in a development virtual environment and install its Chromium browser or supply your system Chromium path. Build a separate debug export, leave the server above running, then:

```sh
mkdir -p build/web/test
bash tools/godot.sh --headless --export-debug Web build/web/test/index.html
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
```

The debug browser check enables a read-only `window.snowSnapshot` only in debug builds with the explicit `?test=1` flag. Release builds do not expose it. The test drives actual keyboard and browser multi-touch input; it does not use a cheat API to advance weeks or award upgrades. It writes screenshots and a JSON report to ignored `test-results/`. Do not publish the nested debug export as part of a release.

### Validation boundaries

The headless suites cover leaf rescue/miss accounting, branch occupancy, persistent canopy gaps, battery recovery, movement bounds, upgrade economics, minimum mobility for all builds, final-leaf loss precedence, seeded repeatability, a full-canopy 48-leaf scenario, focus loss, touch release/cancellation, workshop transitions and run reset. The browser suite additionally checks real reload persistence of workshop choices, automatic blur pause, explicit resume, checkpoint retry and confirmed exit. The native save suite covers all three named slots, malformed files, backup recovery, precise random-state round trips, and the final saved victory.

Headless Chromium uses software WebGL in this environment. It can establish functionality and geometry, not phone frame rate, thermal behaviour, perceived sound quality, native touch comfort, Safari compatibility, or cross-platform deterministic scoring. Real Android/iOS and mobile-browser tests remain required. No signed native builds or store submissions are included.

## Deliberate prototype limits

- Distant scenery remains a composited background plate with baked lighting. Gameplay trees, their foliage and atmospheric overlays are separate runtime layers; the whole illustrated tree sprite is paired with twig-coordinate/orientation metadata in `scripts/canopy.gd`. This is not a final rigged 2.5D or fully dynamic lighting pipeline.
- The character uses 12 wardrobe atlas frames plus separate warm victory and bundled sad-defeat poses, with smooth mipmapped filtering. Full walking, looking-up, celebration and blower-idle animation rigs remain production work.
- Branch capture has a forgiving 15-logical-pixel radius and sweeps each motion segment to avoid missing slots at higher speeds. The radius, branch layout, foliage density and marker visibility need phone-scale playtesting. Arriving at an arbitrary sky height never counts as a rescue.
- Weather/endings demonstrate the visual states rather than finished cinematic direction. Warning flakes do not collide with leaves or change movement.
- Workshop purchases immediately change the visible build readout; production needs a fuller before/after preview and confirmation flow.
- No saved high scores, initials entry, difficulty selector, persistent settings, exact mid-attempt resume after process termination, global leaderboard, production music, or temporary pickups. These remain in the staged design plan.
- Art readability, battery cadence, week difficulty, scoring and all upgrade numbers need human playtesting. Fixed-step logic and equal viewports do not solve every future ranked-play fairness issue.

Next gate: play this on physical Android and iPhone browsers, review empty-branch aiming and the paper effect at phone scale, then refine branch art, scenery depth and animated character assets.

Week-12 and boss screenshots use validated art-review checkpoint fixtures generated by `tests/visual_fixture.gd`, not a claim that a human completed the full campaign. Main browser integration plays real early levels, saves/reloads the workshop, loses and retries a level. Human full-campaign pacing and physical-device playtests remain outstanding.
