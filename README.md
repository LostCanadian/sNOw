# sNOw

A portrait, single-screen arcade game about holding back winter with an electric leaf blower. Catch falling paper leaves in the wind and blow them into empty branch positions before the ground becomes impassable. One magical tree governs the seasons of a modern rural valley; keeping its leaves attached holds winter at bay. Its crown grows visibly barer as leaves are missed.

The title is **sNOw**, with **NO** treated as a playful, emphatic visual element in the eventual logo.

## Project documents

- [Game design](docs/GAME_DESIGN.md): concept, controls, rules, progression, scoring, UX, visual direction, and first-version scope.
- [Development plan](docs/DEVELOPMENT_PLAN.md): staged implementation, technology evaluation, assets, validation, and release criteria.
- [Campaign, saves, and art direction](docs/CAMPAIGN.md): 12 weeks plus the boss, clothing, pause, local checkpoints, and future environment polish.
- [Decisions and open questions](docs/DECISIONS.md): recommendations, unresolved choices, and how to test them.

## Play the technical art prototype

Use **Godot 4.6.3 stable**. Open `project.godot` in the editor and run the main scene, or:

```sh
bash tools/godot.sh --editor
```

Move with **A/D** or **Left/Right**. Hold **Space** to blow and release to recharge. **Escape** or the pause button pauses any screen. Switching away pauses automatically; returning requires Resume. Completed levels and workshop choices autosave locally in three named slots; a failed or exited level restarts from its checkpoint. Phones use the on-screen direction and fan buttons simultaneously. Choose **Explore the seasons** from the menu to preview warning snow, winter defeat, and flowering victory.

To build the browser version, install the matching Godot web export templates, then:

```sh
bash tools/export_web.sh
python3 -m http.server 8000 --directory build/web
```

Open the locally served `index.html` in a WebGL 2-capable browser; opening the file directly does not work. See [prototype instructions and validation](docs/PROTOTYPE.md) for setup, tests, and limitations, and the [asset manifest](assets/ASSET_MANIFEST.md) for artwork provenance.

This is an early playable art/interaction study, not a release candidate. The campaign now has 12 weeks and a final North Wind encounter, weekly clothing/temperature progression, three named local checkpoint slots, and an upgrade workshop. The central tree now follows the supplied ancient-tree reference, with a rural clearing around it. A basic cutout rig animates distance-driven steps and blower vibration; leaves drift and tumble under gravity. See the [gameplay screenshot](docs/images/prototype-gameplay.png) and [motion clip](docs/images/prototype-motion.mp4). Difficulty selection, high-score tables, artist-separated character animation and native-device validation remain planned. Design numbers are provisional.
