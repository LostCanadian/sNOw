# Ground leaves, slow abilities and seasonal story

## One leaf stays one leaf

Landing retains the original leaf dictionary, identity, paper texture, colour and orientation. It moves from airborne to grounded state; it is no longer replaced by several decorative mini-leaves. Ground leaves settle into layers, slide, rotate and hop slightly when the caretaker walks through them. Their actual positions rebuild local pile density, which creates bounded movement drag. The existing Boots upgrades reduce that drag.

Ground leaves are separate from the active air pool. Ordinary footsteps disturb them without granting free canopy captures. The path clears at the next-week boundary, preserving the established saved-canopy/recovery-floor rule. Falling leaves beyond the viewport still return through edge airflow.

## Whirlwind

The Blower **Whirlwind** node costs three Gold Leaves and requires Torque fan. Press **E** or tap its tornado button. A short airborne tumble rotates the whole cutout in the screen plane; the nozzle and airflow follow that rotation, lifting nearby original ground leaves and stirring airborne ones. It works from a separate reserve, even when the ordinary blower battery is empty. Its cooldown advances only during active gameplay, never during pauses, story panels or menus.

| Upgrade | Effect |
| --- | --- |
| Blower Whirlwind | Unlock; 36-second base recharge |
| Blower Vortex core / Cyclone | Larger lifting radius; Cyclone also adds force |
| Battery Whirlwind cell | Recharge reduced by five seconds |
| Battery Storm reserve | Recharge reduced by seven more seconds (24 seconds with both) |

The normal battery recharge remains separate and quick. Holding E does not automatically spend another surge when it becomes ready; the action needs a new press. Quick press/release input is buffered so it works even between physics frames. If neither ground nor airborne leaves are in range, the charge is not wasted. The player moves at 65% speed during the 1.15-second airborne tumble. New weeks/retries start with ready reserves and the saved clean path.

**Recovery is real:** lifting a ground leaf removes it from the ground pile and its current-week frost penalty while it is back in play. It earns no points merely for being lifted. It must reach a real empty branch position to earn its one rescue. If it lands again, its miss returns. Existing duplicate-score/identity guards remain in place. The accounting invariant is `attached + airborne + unrecovered misses − regrown = 2160`; grounded leaves are already represented in unrecovered misses, so they are not counted twice.

All scores share one top ten per difficulty, with no archived versions. Current rules version 11 includes the branching progression, Gold Leaves, positional airflow, seasonal thinning, the North Wind schedule, decreasing active-anchor limits and a two-second detached-leaf cooldown. Existing campaign checkpoints migrate without losing their leaves, completed weeks or earned-week ledger and mapped equipment; the extra Gold Leaves for completed weeks are credited.

## Quiet gameplay UI

The fan uses a 256-pixel SVG source with mipmapped smooth filtering, replacing the three low-detail filled polygons. The action button has no HOLD caption. There are no “N leaves in a row” announcements. Combo bookkeeping remains part of the existing score calculation; no achievement unlock system or celebration UI ships in this version.

## Short story interludes

Each main week and the finale have unique opening and closing text. A stylized paper panel appears as the scene fades in, then fades out automatically. Each interlude lasts 3.1 seconds and can be skipped by tapping or pressing Space/Enter after a short minimum. Input clears at the transition so skipping cannot accidentally blow or buy an upgrade.

Physics, shedding, battery/ability clocks and scoring stay frozen while a card is readable. Pause/focus loss freezes the card's own fade/read timer too. Ordinary weekly completion autosaves before the closing panel, then opens the results tally. Upgrades are an optional visit that returns to results. Loading an already-completed ordinary week shows Results directly. The finale grows new leaves and flowers, then holds the completed scene before showing its final line in a separate story card. Continue appears after that card and opens Results; reloading a completed finale replays the visual sequence without awarding anything again.

The text suggests unusual warmth, old roots, shadows and sounds, leaving the explanation to the player. Neither the panels nor the menu announces the tree's role outright. Full chapter text follows below.

## Validation and capture boundaries

Native tests cover identity conservation, layering, foot disturbance, drag, surge transfer/refund, no duplicate score, long cooldown and upgrades, held/quick input, pause, interlude timing, autosave order, unique subtle text and unified high-score migration. Browser checks use real input over validated saved loadouts. The ability study begins at week 6 with earned equipment; the closing-panel study uses an explicitly shortened saved schedule to isolate the UI. Neither is a claim of a human-completed campaign.

The motion clip and selected stills come from that recorded browser session. Frame timestamps are reviewed because video encoding and browser-wall clocks need not align exactly. Captured candidate frames are kept in ignored test-results, not automatically treated as approved artwork. Physical Android/iOS performance and final gameplay balance still require device playtests.

## Chapter text

| Week | Chapter | Opening | Closing |
| --- | --- | --- | --- |
| 1 | The First Leaf | The last warm tree sheds a leaf.<br>You lift it back into the branches. | The leaves hold for another week.<br>A colder breeze finds the lane. |
| 2 | An Uneasy Rustle | A cold draft shakes the branches.<br>Keep their colour a little longer. | The tree still shelters the lane.<br>Tonight, the windows mist over. |
| 3 | Borrowed Warmth | Frost has reached the fields.<br>Grass stays warm beneath this tree. | You have kept a little warmth here.<br>Something under the roots stirs. |
| 4 | Knots in the Grain | Old marks show in the bare bark.<br>Someone stood here before you. | Another frost kept at bay.<br>Cold winds gather beyond the ridge. |
| 5 | A Longer Shadow | The rain carries a sharper chill.<br>The branches need your help again. | The tree keeps its autumn colours.<br>The evenings are getting shorter. |
| 6 | What the Roots Remember | The village sleeps in moonlight.<br>You keep watch by the old trunk. | The lane stays clear of frost.<br>The distant hills have turned white. |
| 7 | The Last Cricket | One cricket sings beneath the roots.<br>Keep a roof of leaves above it. | The cricket still sings.<br>Tonight, the branches answer. |
| 8 | Porch Lights | Storm clouds hide the moon.<br>You work by the village porch lights. | Another week of shelter won.<br>The cold is closer now. |
| 9 | A Quiet Bargain | You left a scarf beside the trunk.<br>In the morning, it was warm. | The tree holds back another frost.<br>The wind whispers your name. |
| 10 | The Narrowing Sky | Fewer leaves catch the light.<br>Each leaf keeps winter waiting. | Another week stolen from the cold.<br>The path to the village stays open. |
| 11 | Before the Hush | Rain freezes on the distant fences.<br>Here, the last branches still bend. | The village windows still glow.<br>Beyond the ridge, the wind rises. |
| 12 | One Last Week | One last week of autumn colour.<br>Keep the cold from these branches. | Twelve weeks of warmth kept.<br>Now the North Wind wants the tree. |
| Final encounter | The North Wind | The North Wind has found the tree.<br>Hold its last leaves against the cold. | A flower opens in the frozen grass.<br>For now, the valley can breathe. |

The panels now fade away without a continuation caption. Tap or Space/Enter can still skip after the short minimum; this does not start the blower.

Latest movement, airborne Surge, knee-height scuffs and the leaf-first winter ending are specified in [MOTION_AND_SEASONS.md](MOTION_AND_SEASONS.md). The action button has only its icon/recharge ring, without a name or numeric cooldown.
