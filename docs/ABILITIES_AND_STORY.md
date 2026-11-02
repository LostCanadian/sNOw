# Ground leaves, slow abilities and seasonal story

## One leaf stays one leaf

Landing retains the original leaf dictionary, identity, paper texture, colour and orientation. It moves from airborne to grounded state; it is no longer replaced by several decorative mini-leaves. Ground leaves settle into layers, slide, rotate and hop slightly when the caretaker walks through them. Their actual positions rebuild local pile density, which creates bounded movement drag. The existing Boots upgrades reduce that drag.

Ground leaves are separate from the active air pool. Ordinary footsteps disturb them without granting free canopy captures. The path clears at the next-week boundary, preserving the established saved-canopy/recovery-floor rule. Falling leaves beyond the viewport still return through edge airflow.

## Leaflift Surge

Blower rank 2 unlocks **Leaflift Surge**. Press **E** or tap its leaf-lifting button. A short airborne tumble rotates the whole cutout in the screen plane; the nozzle and airflow follow that rotation, lifting nearby original ground leaves and stirring airborne ones. It works from a separate reserve, even when the ordinary blower battery is empty. Its cooldown advances only during active gameplay, never during pauses, story panels or menus.

| Upgrade | Effect |
| --- | --- |
| Blower rank 2 — Leaflift Surge | Unlock; 36-second base recharge |
| Higher Blower ranks | Larger lifting radius, alongside their normal lift/width changes |
| Battery rank 3 — Quick Recovery | Surge cooldown becomes 31 seconds |
| Battery rank 5 — Surge Cell | Surge cooldown becomes 26 seconds |

The normal battery recharge remains separate and quick. Holding E does not automatically spend another surge when it becomes ready; the action needs a new press. Quick press/release input is buffered so it works even between physics frames. If neither ground nor airborne leaves are in range, the charge is not wasted. The player moves at 65% speed during the 1.15-second airborne tumble. New weeks/retries start with ready reserves and the saved clean path.

**Recovery is real:** lifting a ground leaf removes it from the ground pile and its current-week frost penalty while it is back in play. It earns no points merely for being lifted. It must reach a real empty branch position to earn its one rescue. If it lands again, its miss returns. Existing duplicate-score/identity guards remain in place. The accounting invariant is `attached + airborne + unrecovered misses − regrown = 2880`; grounded leaves are already represented in unrecovered misses, so they are not counted twice.

Older scoring versions 1–4 remain separately viewable under Previous Scores. Current rules version 5 covers colour-weighted shedding and smaller score awards alongside ground recovery and the special ability; no earlier table is overwritten or compared against the new scores. Existing campaign checkpoints migrate without losing their leaves, completed weeks or point budget.

## Quiet gameplay UI

The fan uses a 256-pixel SVG source with mipmapped smooth filtering, replacing the three low-detail filled polygons. The action button has no HOLD caption. There are no “N leaves in a row” announcements. Combo bookkeeping remains part of the existing score calculation; no achievement unlock system or celebration UI ships in this version.

## Short story interludes

Each main week and the finale have unique opening and closing text. A stylized paper panel appears as the scene fades in, then fades out automatically. Each interlude lasts 3.1 seconds and can be skipped by tapping or pressing Space/Enter after a short minimum. Input clears at the transition so skipping cannot accidentally blow or buy an upgrade.

Physics, shedding, battery/ability clocks and scoring stay frozen while a card is readable. Pause/focus loss freezes the card's own fade/read timer too. Completion autosaves before the closing panel; it then opens the results tally. Upgrades are an optional visit that returns to results. Loading an already-completed checkpoint shows results without replaying the congratulations. The finale's last line appears in the winning result panel after the flowers.

The text suggests unusual warmth, old roots, shadows and sounds, leaving the explanation to the player. Neither the panels nor the menu announces the tree's role outright. Full chapter text follows below.

## Validation and capture boundaries

Native tests cover identity conservation, layering, foot disturbance, drag, surge transfer/refund, no duplicate score, long cooldown and upgrades, held/quick input, pause, interlude timing, autosave order, unique subtle text and multi-version score archives. Browser checks use real input over validated saved loadouts. The ability study begins at week 6 with earned equipment; the closing-panel study uses an explicitly shortened saved schedule to isolate the UI. Neither is a claim of a human-completed campaign.

The motion clip and selected stills come from that recorded browser session. Frame timestamps are reviewed because video encoding and browser-wall clocks need not align exactly. Captured candidate frames are kept in ignored test-results, not automatically treated as approved artwork. Physical Android/iOS performance and final gameplay balance still require device playtests.

## Chapter text

| Week | Chapter | Opening | Closing |
| --- | --- | --- | --- |
| 1 | The First Leaf | One leaf lets go.<br>You have other plans. | Autumn holds.<br>A colder breeze finds the lane. |
| 2 | An Uneasy Rustle | The branches rustle.<br>There is no wind. | The valley stays awake.<br>Tonight, the windows mist over. |
| 3 | Borrowed Warmth | The valley wears a frost.<br>This patch of grass does not. | A little warmth remains.<br>It will need watching. |
| 4 | Knots in the Grain | Old marks show in the bark.<br>Nobody remembers carving them. | Another frost kept at bay.<br>Something stirs beyond the ridge. |
| 5 | A Longer Shadow | The houses fall into shade.<br>One shadow points the other way. | The light lingers.<br>The evenings are getting shorter. |
| 6 | What the Roots Remember | The roots reach beneath the road.<br>The road is much younger. | The lane stays clear.<br>The hills have turned white. |
| 7 | The Last Cricket | A cricket sings under the roots.<br>Just one. | The cricket still sings.<br>The branches answer after dark. |
| 8 | Porch Lights | Porch lights blink on early.<br>You keep working. | Another week of amber.<br>The clouds stop moving east. |
| 9 | A Quiet Bargain | You leave a scarf by the trunk.<br>By morning, it is warm. | Winter waits outside.<br>The wind begins to whisper. |
| 10 | The Narrowing Sky | Clouds gather over the ridge.<br>Not a leaf moves. | Another week stolen from the cold.<br>Keep the path open. |
| 11 | Before the Hush | The village is quiet.<br>Something is listening. | The windows still glow.<br>Beyond them, a pale shape waits. |
| 12 | One Last Week | The last warm colours hold.<br>So do you. | Twelve weeks kept.<br>The North Wind wants an answer. |
| Final encounter | The North Wind | It followed the falling leaves.<br>Now it is here. | The first flower opens.<br>Nobody asks why. |

The panels now fade away without a continuation caption. Tap or Space/Enter can still skip after the short minimum; this does not start the blower.

Latest movement, airborne Surge, knee-height scuffs and the leaf-first winter ending are specified in [MOTION_AND_SEASONS.md](MOTION_AND_SEASONS.md). The action button has only its icon/recharge ring, without a name or numeric cooldown.
