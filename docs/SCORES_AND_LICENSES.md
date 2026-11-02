# Scores and acknowledgements

The main menu now has **High Scores** and **License** buttons. Both fit the fixed portrait playfield, work with mouse/touch and keyboard, and retain their screen when paused and resumed.

## Local high scores

Each difficulty has its own top ten: **Breezy**, **Blustery**, and **Gale**. Empty tables show an invitation to play; no fabricated scores are installed. A qualifying completed week, loss or victory offers **Enter initials** on the result screen. Enter three A–Z characters with the keyboard or the large plus/minus letter controls; empty positions default to A. **Not now** returns to the result without recording it.

A record contains score, initials, highest week/final encounter, completion/loss/win outcome, equipment tiers, difficulty, campaign identity and scoring-rules version. Scores rank by descending score and then highest week; earlier exact ties retain their order. Each saved campaign contributes **one best result**. A better retry replaces that campaign's previous row; equal/worse retries and reopening a victory never create duplicates. Positive scores qualify at completed-week, loss and victory boundaries. Once initials have been recorded, later improvements update that campaign row automatically after the results tally. Exiting an unfinished level does not submit a score.

Campaign saves and high scores are separate. A level retry rolls gameplay back to its checkpoint while retaining the best result already earned. Starting a replacement campaign creates a new campaign identity. Local tables can be edited by the device owner; they are not authenticated competitive leaderboards. No account, network leaderboard or login is used.

Browser scores use localStorage `snow.highscores.v1` with `.backup` recovery; native scores use `user://highscores.json` and `.bak`. Version/field/order validation rejects malformed records. Writes preserve a good backup and damaged primary data. A storage failure displays a notice and keeps scores only for the current session. Browser data belongs to that hostname/port/origin; clearing site data removes it. Campaign slot storage remains `snow.campaigns.v1` / `user://campaigns.json`.

New-save difficulty is selected above the name field and stays fixed for that campaign. Existing checkpoints without these fields migrate to **Blustery** with a stable identity, retaining their difficulty and progress while migrating the new rules. The current profiles, weekly miss limits, 2,880-leaf persistent canopy, 960-leaf recovery floor and eighteen-node workshop are documented in [Campaign rules](CAMPAIGN.md). Rules version 4 separates dense-canopy/batched-shedding scores from previous balance rules. Previous scores remain stored under the same key and can be viewed using the **Previous scores** button; they are not overwritten or ranked against current results. Each rules version retains ten entries per difficulty.

## License screen

Four selectable, scrollable sections are bundled for offline reading:

- **About:** engine/version, font attribution, project/component distinction and upstream links.
- **Godot (MIT):** complete Godot copyright, permission and warranty text from `Engine.get_license_text()`.
- **Engine libraries:** all component names, copyright holders, source-file notices and license identifiers returned by `Engine.get_copyright_info()`, followed by the complete terms from `Engine.get_license_info()`. This follows the engine actually running the game, including its browser export template.
- **DejaVu fonts:** the Bitstream Vera copyright/trademark, permission, modification/renaming, distribution and warranty terms, plus the public-domain status of DejaVu changes. The font-specific notice is bundled as `assets/licenses/DEJAVU.txt`; the original font package notice is retained.

The export preset explicitly includes the font license text, which is otherwise a non-resource file. Third-party terms apply to their identified components; adding this screen does not assign an open-source license to the game's own code or artwork. See [asset provenance](../assets/ASSET_MANIFEST.md).

## Verification

`tests/test_scores.gd` covers sorting, table limits, ties, replacement/deduplication, malformed records, native reopen/backup/failure paths, all difficulty thresholds and legacy checkpoint migration. `tests/test_menus.gd` covers actual menu screens, full notice content, pause restoration and initials-form submission. `tests/browser_menus.py` checks exported notices offline and new-save difficulty selection; the main browser suite submits the actual lost-run score through the initials UI and reloads it from storage.

Scoring versions 1, 2 and 3 remain separately accessible through Previous Scores. Current recovery removes a miss while its leaf is back in play; it earns nothing until actual reattachment. No streak or achievement announcement appears during play.

## Running locally in a browser

Complete a week, wait for its tally, then choose **Enter initials** when the score qualifies. Type three letters or use the letter controls and press **Save score**. **Not now** leaves that first score unrecorded. Losing or winning also provides entry when eligible. Returning from the score table restores the result page. Later campaign improvements retain those initials automatically.

If the old flow is still showing, rerun `python3 tools/play_web.py --open` from the updated checkout; avoid `--serve-only` until it has rebuilt. Use the same origin each time: `localhost:8000`, `127.0.0.1:8000`, a different port and another browser profile all have separate storage. Clearing site data/private sessions can remove local scores. Loading a save selects its difficulty for subsequent score-menu visits in that session. Choose the difficulty tab matching the save; older rules remain under Previous Scores. Storage-denied/write errors display on the page and preserve session play.

See [HUD/results](HUD_AND_RESULTS.md) for the complete weekly flow and [browser results test](../tests/browser_results.py) for entry/reload coverage.
