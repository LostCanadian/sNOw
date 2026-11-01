# Paper & Lanterns — technical art prototype

## What is implemented

- Godot **4.6.3 stable**, GDScript, Compatibility rendering, no third-party engine plugins.
- Modern rural paper-textured scenery with ordinary houses and a solar roof, plus independently drawn bare trees, textured paper-leaf sprites, a transparent electric-blower character, directional wind streaks, local leaf piles, gentle light/fog overlays, and soft shadows.
- Fixed-camera, fixed **360 × 640** logical playfield, uniformly fitted inside browser safe-area padding. Screen shape changes decorative margins, not gameplay geometry.
- Keyboard and independent multi-touch movement/blowing, input release on touch cancellation, pause on application focus loss, and explicit pause/resume.
- Upward leaf force with mild flutter, once-only rescue/miss outcomes, pile slowdown, battery depletion/release-to-recharge, score/combo, seven short day profiles, and cumulative winter pressure.
- A conserved canopy of 48 individually occupied branch positions. Shedding opens a gap; an upward-blown leaf reattaches only near a real empty position, including one other than its original spot. Missed leaves leave the trees barer across days, rather than resetting the foliage overnight. Daily schedules only use the remaining attached leaves. Late-day colours turn orange/red independently of canopy occupancy.
- Between-day workshop with boots, blower and battery branches; prerequisites, one point per completed day 1–6, weight/energy tradeoffs, reallocation, and carryover within a run.
- Small warning flakes near defeat; clouds, cut-paper snowflakes and ground snow on loss; flowers on victory. Main-menu season previews allow immediate art review.
- Soft-effects and mute options; a quiet synthesized electric whirr after starting a run. No microphone input or external audio service.

The title screen offers **Keep winter waiting** to play and **Explore the seasons** to review the visual states. The prototype has one tuning profile; seven days are deliberately short and not the finished difficulty curve. Nothing is purchased with score or real money.

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

Leaving the blower held at zero charge will not refill it: release first. Upgrades reset on a fresh run. Workshop reallocation refunds the earned budget and removes all nodes before rebuilding. Settings and scores are session-only in this prototype.

## Reproducible validation

Current-instance headless results: **66 simulation checks and 19 scene/input checks passed**. The additional canopy checks cover occupied-slot rejection, swept capture, cross-slot reattachment, leaf conservation, persistent gaps and a complete 48-leaf shed scenario. The browser pass completed all seven scenarios without runtime errors, including touch-driven movement/blowing, real branch reattachment, a workshop purchase, persistent foliage gaps and winter loss, plus five aspect ratios and simulated safe-area padding. These observations are from Linux/headless Chromium, not physical phones; see the latest generated browser report for its run outcome.

Actual screenshots of [gameplay](images/prototype-gameplay.png), the [sparse late-autumn warning preview](images/prototype-warning.png), and the [bare-tree winter preview](images/prototype-winter.png) are included in the repository. The generated release is under ignored `build/web/`; a portable browser bundle is `build/snow-web-prototype.zip`. The bundle must still be served over HTTP/HTTPS, not opened directly from disk.

The simulation and scene/input suites have no extra dependencies:

```sh
bash tools/godot.sh --headless --script tests/test_loop.gd
bash tools/godot.sh --headless --script tests/test_ui.gd
```

Browser integration uses **Python Playwright 1.62.0** and an installed Chromium. Those are test tools, not game/runtime dependencies. To reproduce in a machine that lacks them, install that Playwright version in a development virtual environment and install its Chromium browser or supply your system Chromium path. Build a separate debug export, leave the server above running, then:

```sh
mkdir -p build/web/test
bash tools/godot.sh --headless --export-debug Web build/web/test/index.html
python3 tests/browser_smoke.py --chromium /usr/bin/chromium
```

The debug browser check enables a read-only `window.snowSnapshot` only in debug builds with the explicit `?test=1` flag. Release builds do not expose it. The test drives actual keyboard and browser multi-touch input; it does not use a cheat API to advance days or award upgrades. It writes screenshots and a JSON report to ignored `test-results/`. Do not publish the nested debug export as part of a release.

### Validation boundaries

The headless suites cover leaf rescue/miss accounting, branch occupancy, persistent canopy gaps, battery recovery, movement bounds, upgrade economics, minimum mobility for all builds, final-leaf loss precedence, seeded repeatability, a full-canopy 48-leaf scenario, focus loss, touch release/cancellation, workshop transitions and run reset. The browser suite checks rendering/runtime errors, touch and keyboard, a real reattachment, five screen ratios, simulated safe-area padding, day completion/purchase/carryover, foliage conservation across days, actual winter defeat, and ending previews.

Headless Chromium uses software WebGL in this environment. It can establish functionality and geometry, not phone frame rate, thermal behaviour, perceived sound quality, native touch comfort, Safari compatibility, or cross-platform deterministic scoring. Real Android/iOS and mobile-browser tests remain required. No signed native builds or store submissions are included.

## Deliberate prototype limits

- Distant scenery remains a composited background plate with baked lighting. Gameplay trees, their foliage and atmospheric overlays are separate runtime layers; the bare branch paths and leaf anchors share `scripts/canopy.gd`. This is not a final rigged 2.5D or fully dynamic lighting pipeline.
- The character is a single transparent pose with a walk bob. Dedicated walking, looking-up, celebration and blower-idle animations remain production work.
- Branch capture has a forgiving 15-logical-pixel radius and sweeps each motion segment to avoid missing slots at higher speeds. The radius, branch layout, foliage density and marker visibility need phone-scale playtesting. Arriving at an arbitrary sky height never counts as a rescue.
- Weather/endings demonstrate the visual states rather than finished cinematic direction. Warning flakes do not collide with leaves or change movement.
- Workshop purchases immediately change the visible build readout; production needs a fuller before/after preview and confirmation flow.
- No saved high scores, initials entry, difficulty selector, persistent settings, resume checkpoints, global leaderboard, production music, or temporary pickups. These remain in the staged design plan.
- Art readability, battery cadence, day difficulty, scoring and all upgrade numbers need human playtesting. Fixed-step logic and equal viewports do not solve every future ranked-play fairness issue.

Next gate: play this on physical Android and iPhone browsers, review empty-branch aiming and the paper effect at phone scale, then refine branch art, scenery depth and animated character assets.
