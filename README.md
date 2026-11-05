# sNOw

A portrait, single-screen arcade game about holding back winter with an electric leaf blower. Catch falling paper leaves in the wind and blow them into empty branch positions before the ground becomes impassable. One magical tree governs the seasons of a modern rural valley; keeping its leaves attached holds winter at bay. Its crown grows visibly barer as leaves are missed.

The working title is **sNOw**, with **NO** emphasized. The selected paper-cut visual style is not a subtitle. See [naming ideas](docs/NAMING.md).

## Project documents

- [Beta polish and validation](docs/BETA_POLISH.md): Gold Leaves, branching equipment, checkpoint flow, limb animation and original audio.
- [Challenge performance](docs/CHALLENGE_PERFORMANCE.md): leaf simulation/rendering measurements, optimizations and options for phone tuning.
- [Game design](docs/GAME_DESIGN.md): concept, controls, rules, progression, scoring, UX, visual direction, and first-version scope.
- [Development plan](docs/DEVELOPMENT_PLAN.md): staged implementation, technology evaluation, assets, validation, and release criteria.
- [Campaign, saves, and art direction](docs/CAMPAIGN.md): 12 weeks plus the boss, clothing, pause, local checkpoints, and future environment polish.
- [Ground leaves, surge and story](docs/ABILITIES_AND_STORY.md): persistent ground objects, slow recovery abilities, seasonal opening/closing lines.
- [Future achievements](docs/ACHIEVEMENTS.md): deliberately deferred past the initial release.
- [Motion and seasonal shedding](docs/MOTION_AND_SEASONS.md): rigid leg animation, colour-weighted leaves, airborne Surge and the leaf-first winter ending.
- [Future consumables](docs/CONSUMABLES.md): proposed one-time upgrades such as coffee; not implemented.
- [HUD and weekly results](docs/HUD_AND_RESULTS.md): compact status icons, saved summaries, optional upgrades and weekly initials entry.
- [Ambient world](docs/AMBIENT_WORLD.md): paper wildlife, weekly light/weather and quiet reactions.
- [High scores and licenses](docs/SCORES_AND_LICENSES.md): local per-difficulty tables, initials entry, storage, and offline third-party notices.
- [Decisions and open questions](docs/DECISIONS.md): recommendations, unresolved choices, and how to test them.

## Export Android or iOS from the command line

```sh
python3 tools/export_mobile.py android
python3 tools/export_mobile.py ios --team-id ABCDE12345
```

Android produces a test APK; iOS produces an Xcode project on a Mac. No Godot UI is needed. Add `--check` to check prerequisites without downloading or exporting. Android requires a JDK and Android SDK; iOS requires macOS/Xcode. The script installs matching Godot/templates automatically. Signed APKs, Play AABs, IPA packaging and existing-Godot options are covered in the [mobile export guide](docs/MOBILE_EXPORT.md). On Windows use `py -3` in place of `python3`.

## Play the technical art prototype

From the repository folder, use **Python 3.9 or newer** to download Godot and its matching export templates, export the game headlessly, and start a local server. No Godot UI, package installation or admin access is needed.

**macOS / Linux:**

```sh
python3 tools/play_web.py --open
```

**Windows (PowerShell or Command Prompt):**

```powershell
py -3 tools/play_web.py --open
```

The browser opens at **http://localhost:8000** once the export finishes. Leave the terminal running; press **Ctrl+C** to stop. The first run downloads the portable Godot **4.6.3** executable and roughly **1.2 GB** of official export templates, verifies the archives against the release’s SHA-512 checksums, and installs only browser templates. Later runs reuse the installation and rebuild the game. Downloads/tooling stay in ignored `.snow-tools/`; macOS puts matching templates in its standard Godot Application Support directory.

To serve an existing build quickly, add `--serve-only`; to export without starting a server, use `--build-only`. Change the local port with `--port 8080`. Omit `--open` to open the printed address yourself. See [setup details](docs/PROTOTYPE.md#run-and-export) for the existing-Godot workflow.

Move with **A/D** or **Left/Right**. Hold **Space** to blow and release to recharge. **E** activates Whirlwind after buying the tornado node in the Blower tree. **Escape** or the pause button pauses active play. Switching away pauses a live level; returning requires Resume. Results and menus stay open. Loading a saved level shows **Continue**, which begins that level again. Completed levels and workshop choices autosave locally in three named Save Slots; a failed or exited level restarts from its checkpoint. Phones use the on-screen direction and fan buttons simultaneously. Brief opening/closing panels tell the story; tap or Space skips them. Fallen leaves stay intact, scuff underfoot and can be lifted again with Whirlwind. The character turns with movement; the blower aims upright at rest and leans into movement, steering the airflow. Choose **Explore the seasons** from the menu to preview warning snow, winter defeat, and flowering victory.

To build the browser version, install the matching Godot web export templates, then:

```sh
bash tools/export_web.sh
python3 -m http.server 8000 --directory build/web
```

Open the locally served `index.html` in a WebGL 2-capable browser; opening the file directly does not work. See [prototype instructions and validation](docs/PROTOTYPE.md) for setup, tests, and limitations, and the [asset manifest](assets/ASSET_MANIFEST.md) for artwork provenance.

This build includes the beta polish pass; balance and native-device performance still need playtesting. The campaign now has 12 weeks and a final North Wind encounter, weekly clothing/temperature progression, three named Save Slots, and a branching, icon-led 30-node workshop. Each completed week awards two Gold Leaves; 24 Gold Leaves cannot buy every path. Its 2,160-leaf canopy carries forward and thins with the seasons; weekly danger resets, with limited regrowth to a 720-leaf recovery floor. The central tree now follows the supplied ancient-tree reference, with a rural clearing around it. Separate illustrated thigh, shin and shoe layers animate a shorter, distance-driven gait; the blower vibrates while running, and leaves drift and tumble under gravity. See the [gameplay screenshot](docs/images/prototype-gameplay.png) and [motion clip](docs/images/prototype-motion.mp4). The main menu separates **Continue** from **New Game**. Continue selects an existing campaign; New Game chooses an empty slot or reviews an occupied save before replacing it. New saves select Easy, Medium or Hard, each with a local top ten and initials entry. The menu’s License screen includes offline engine/library/font terms. Eighteen original sixteen-bar MIDI-style scores (one per level plus scene music) and layered action sounds are included, with independent music/effects volume and a persistent mute option. Native-device validation remains planned. Design numbers are provisional.

**Challenge** unlocks permanently after beating the North Wind: Easy wins unlock Easy, Medium wins unlock Easy/Medium, and Hard wins unlock all three. Harder choices stay disabled. The highest completed difficulty persists independently of save slots, including after overwriting every campaign; existing completed saves migrate using their recorded difficulty. Start with all 30 upgrades and chase a high score through 30–50-leaf waves, recovery gaps and progressively stronger localized gusts, with no completion quota. Challenge shares a 200-airborne-leaf cap across shedding, North Wind and Whirlwind; blocked releases do not build up a catch-up burst. Each attempt starts fresh, uses the selected difficulty’s normal miss limit, and has its own local top ten with initials. Challenge never replaces campaign saves. Its landscape stays aligned while day, dusk, night, dawn and weather fade in logical order. Moon phases advance each night; stormy weather occasionally brings one North Wind pass. Wildlife arrives, rests and departs naturally, with new owl flight/landing and squirrel descent frames.

Completed weeks open results with the week, temperature and animated totals. Enter initials there when a score qualifies; later improvements retain them. Open Upgrades, then close back to results before choosing Next Week or Main Menu. Gameplay keeps only the score, growing winter snowflake, battery icon and pause at the top.

The valley now has textured paper squirrels, seasonally changing rabbits, nocturnal owls and rare full-moon visitors. Weeks vary between sunny days, rain, dusk, moonlight, mist and a night storm. Gentle background rays, fog and attached-leaf rustling add motion without changing difficulty. In Explore the seasons, use the week arrows to review each atmosphere and its music.

Wildlife now has seventy-two paper animation poses, main-tree perches and grazing/nibbling routines. Nighttime scene previews include **Full moon** to review the rare wolf and bat. Run the native regression suite with `python3 tools/check_godot_tests.py`; this also checks for engine errors.
