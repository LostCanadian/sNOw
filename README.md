# sNOw

A portrait, single-screen arcade game about holding back winter with an electric leaf blower. Catch falling paper leaves in the wind and blow them into empty branch positions before the ground becomes impassable. One magical tree governs the seasons of a modern rural valley; keeping its leaves attached holds winter at bay. Its crown grows visibly barer as leaves are missed.

The working title is **sNOw**, with **NO** emphasized. The selected paper-cut visual style is not a subtitle. See [naming ideas](docs/NAMING.md).

## Project documents

- [Game design](docs/GAME_DESIGN.md): concept, controls, rules, progression, scoring, UX, visual direction, and first-version scope.
- [Development plan](docs/DEVELOPMENT_PLAN.md): staged implementation, technology evaluation, assets, validation, and release criteria.
- [Campaign, saves, and art direction](docs/CAMPAIGN.md): 12 weeks plus the boss, clothing, pause, local checkpoints, and future environment polish.
- [Ground leaves, surge and story](docs/ABILITIES_AND_STORY.md): persistent ground objects, slow recovery abilities, seasonal opening/closing lines.
- [Future achievements](docs/ACHIEVEMENTS.md): deliberately deferred past the initial release.
- [Motion and seasonal shedding](docs/MOTION_AND_SEASONS.md): rigid leg animation, colour-weighted leaves, airborne Surge and the leaf-first winter ending.
- [Future consumables](docs/CONSUMABLES.md): proposed one-time upgrades such as coffee; not implemented.
- [HUD and weekly results](docs/HUD_AND_RESULTS.md): compact status icons, saved summaries, optional upgrades and weekly initials entry.
- [Future ambient world](docs/AMBIENT_WORLD.md): seasonal wildlife, varied skies and quiet reactions.
- [High scores and licenses](docs/SCORES_AND_LICENSES.md): local per-difficulty tables, initials entry, storage, and offline third-party notices.
- [Decisions and open questions](docs/DECISIONS.md): recommendations, unresolved choices, and how to test them.

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

This is an early playable art/interaction study, not a release candidate. The campaign now has 12 weeks and a final North Wind encounter, weekly clothing/temperature progression, three named Save Slots, and a branching, icon-led 30-node workshop. Each completed week awards two Gold Leaves; 24 Gold Leaves cannot buy every path. Its 2,880-leaf canopy carries forward; weekly danger resets, with limited regrowth to a 960-leaf recovery floor. The central tree now follows the supplied ancient-tree reference, with a rural clearing around it. Cutout legs animate distance-driven steps; the blower vibrates while running, and leaves drift and tumble under gravity. See the [gameplay screenshot](docs/images/prototype-gameplay.png) and [motion clip](docs/images/prototype-motion.mp4). New saves select Breezy, Blustery or Gale, each with a local top ten and initials entry. The menu’s License screen includes offline engine/library/font terms. Native-device validation remains planned. Design numbers are provisional.

Completed weeks open results with the week, temperature and animated totals. Enter initials there when a score qualifies; later improvements retain them. Open Upgrades, then close back to results before choosing Next Week or Main Menu. Gameplay keeps only the score, growing winter snowflake, battery icon and pause at the top.
