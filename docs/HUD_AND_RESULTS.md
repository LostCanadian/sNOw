# Compact HUD and weekly results

## Gameplay

The score has its own bar at the top left. Independent badges sit along the top: the winter snowflake, battery and pause button. They share a 40-logical-pixel height, top edge 14 and bottom edge 54, leaving more sky visible than the previous 65-pixel dashboard. Gameplay shows no week fraction, temperature, frost count or battery percentage. Clothes, canopy colour and weather carry the seasonal progression.

The original sixfold cut-paper frost icon grows with current weekly danger. Its slow pulse, blue tint, halo and encroaching warm-edged ring become more pronounced near failure. Recovery can reduce it again. Soft effects disables the pulse while preserving size and contrast cues. Warning snowfall still uses the same real weekly danger as the loss condition.

The battery silhouette encloses a shrinking fill: green above half, yellow down to one fifth, red below that. Remaining fill provides a cue independent of colour. A small lightning mark appears during normal recharge. The status icons and rounded play/pause symbols are original SVG assets with smooth mipmapped filtering. The fan action remains separate from this status icon.

## After a week

Flow: **closing story → results → optional upgrades → results → next week's opening**. The results page can also return directly to the main menu. Completed checkpoints reopen this results page on load.

Results show the completed week, actual temperature and difficulty. Three staggered bars/counts tally **leaves saved**, **leaves fallen** and **points earned this week**, plus the cumulative score. Leaf bars share the week's scheduled-leaf maximum; the points bar fills during the tally. Fallen means leaves still unrecovered at the end, consistent with surge recovery and weekly frost. Animation lasts 2.1 seconds, freezes when paused, and never changes the awarded score or upgrade budget. Soft effects shows settled counts without count-up motion.

After tallying, a qualifying result shows **New high score!** and an **Enter initials** button. Other results offer High Scores. Upgrades show how many points remain available. Closing the workshop always returns to the summary, refreshing that preview; Next Week is a results-page action. Loss and final victory use the same tally format after their ending animation, with Retry or Save Slots instead of upgrades/Next.

Completion autosaves before the closing text and tally. The saved `week_start_score` makes the points-earned breakdown survive reload and upgrade visits; the existing weekly rescue/miss counters supply the leaf counts. Older completed saves still load, showing a dash for unknown weekly points and their correct cumulative score. Their next week establishes a new exact baseline. No second award happens when returning from menus or upgrades.

## Initials and score persistence

Before this change, only loss or full-campaign victory could enter the score tables; successful intermediate weeks had no initials action. Qualifying positive completed-week scores can now be saved immediately, as well as loss/victory results. Type three A–Z letters or use the touch-friendly plus/minus controls; Not Now returns to results. Once this campaign has an entry, later improvements update it automatically after tallying and retain its initials. Each campaign still occupies one best row per rules version and difficulty.

Completed-week rows say CLEARED, distinct from LOSS and final WIN. Earlier records without this metadata remain readable. The High Scores page omits the requested explanatory footer lines; real storage errors remain visible. See [scores and licenses](SCORES_AND_LICENSES.md) for storage troubleshooting and archive compatibility.

## Validation

`tests/test_results.gd` covers tally timing, no repeated rewards, pause, actual weekly totals, explicit workshop return, checkpoint reload, initials, automatic score improvements, legacy records and badge geometry. `tests/browser_results.py` uses real input over a validated week-nine summary fixture to check results, entry, letter buttons, score storage, upgrade return, reload and the next-week boundary. It also drives real battery discharge and accumulating frost for visual review. These fixtures test UI and persistence, not human full-campaign pacing or phone performance.

The later density increment raises the canopy to 2,880 leaves, weekly shedding/danger by ten, and the recovery floor to 960. The HUD still derives its icon state from relative pressure and charge, so it needs no additional numeric labels. Occupied-slot difficulty replacement is available through Edit → Start fresh; see [campaign rules](CAMPAIGN.md).
