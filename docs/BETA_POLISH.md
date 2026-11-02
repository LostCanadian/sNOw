# Beta polish stages

1. Results and checkpoints: compact, equal-size actions; Gold Leaf currency badge; focus pause only for live scenes; saved levels offer Continue from the beginning.
2. Leaf control: position-dependent outward airflow, independent turbulence, and frontmost canopy detachment.
3. Workshop: equipment tabs, branching icon nodes and prerequisites, two Gold Leaves per completed week, and a higher-cost Whirlwind ability. Preserve and migrate earlier campaigns.
4. Presentation: separated leg parts with joint animation; original synthesized retro music and effects for the scenes and actions.

Each stage is committed and pushed separately on `beta-polish` after its relevant checks. Browser and headless coverage validate the complete flow at the end.

Leaf control uses smooth per-leaf turbulence and an outward force proportional to distance across the cone. The screen-edge return breeze remains active. Shedding peels overlapping leaves in the same order as the renderer while using seasonal colour weights among visible candidates. This makes the seasonal mix slightly broader than an unrestricted weighted draw, in exchange for visible detachment.

## Branching progression (rules 6)

Boots, Blower and Battery each have ten nodes: a root, two paths, four specializations and three capstones. The middle capstone joins both inner paths. Select an icon to read its name, effect, prerequisites and Gold Leaf cost; only the current equipment tree is shown. Tabs animate their nodes; the internal reduced-effects mode disables that motion. Root and specialization nodes cost one Gold Leaf, capstones cost two, and Whirlwind costs three after Torque fan (four total). Each completed main week awards two Gold Leaves; the boss awards none. The reset icon opens a Reset all upgrades / Cancel confirmation and returns exact costs.

Save data stores explicit node IDs and verifies prerequisites, duplicates, node counts and budget. Earlier campaigns double earned currency, retain mapped equipment and Whirlwind access, and receive the remainder after the mapped node costs. All historical scores share one top ten per difficulty, with one best result per campaign. Earlier score scales normalize during import; no archive or rules selector appears in the game.

## Animation and audio

The lower body uses a separate 18-part illustrated atlas: thigh, shin and shoe per leg across three clothing sets. Hip/knee inverse kinematics preserves bone lengths, stance feet stay planted, and swing feet tilt slightly. Travel drives the 29-unit gait, so standing at a boundary cannot march in place. The original body/wardrobe remains above the independently drawn legs.

Nine original eight-bar scores cover menu, workshop, early weeks (1–4), autumn (5–8), frost (9–12), North Wind, results, victory and winter. Original MIDI sources ship beside rendered Ogg loops; no MIDI player or soundfont is required at runtime. Crossfades join scenes. A layered blower loop changes pitch with charge, while steps, menus, purchases, resets, Whirlwind, leaves, low battery and week completion have separate effects. Leaf sounds are rate-limited to avoid ten simultaneous batch hits. Audio waits for user interaction; pause suspends music/stops effects; mute silences all layers. Music/effects sliders and mute persist locally. Short Web effects use Godot's default sample path. Long Web music streams compressed MP3 through two persistent browser media elements with a WebAudio output, avoiding long-buffer allocation failures in Godot's sample path. The bytes come from the game package, so this adds no network dependency. Both elements unlock on the same input gesture; crossfades, pause, mute and volume still use the shared audio director. Native music uses Godot players.

Regenerate audio with `python3 tools/generate_audio.py` (NumPy and ffmpeg). Rebuild limb metadata with `python3 tools/build_limb_regions.py` (Pillow, NumPy, SciPy). Both are authoring-only tools.

## Review images

The [compact results](images/beta-results.png) and [Whirlwind workshop](images/beta-workshop.png) are browser captures from validated saved-week studies, not claims of a human-played campaign. Native phones and subjective full-campaign balance still need playtesting.

## Validation status

Fourteen headless regression scripts pass 754 checks across simulation, leaf identity, positional airflow, detachment, progression prerequisites, save migration/storage, scores, UI, rigid animation, winter and audio routing. The five Python launcher tests also pass. Godot 4.6.3 produces the release Web export successfully. Browser output measurements verify actual music, silence while paused/muted and recovery after unmuting; the browser suite also exercises the end-to-end game and workshop flow. These checks do not substitute for native phone frame-rate, subjective listening/mix review or full-campaign balance playtests.

The final release was also launched in Chromium after switching browser streams to MP3 for codec compatibility: its packaged music produced a nonzero WebAudio output and `?test=1` exposed no debug snapshot. The complete debug browser flow passed with no runtime errors before that codec-only change; the streamed music adapter and controls are shared.

The main menu now uses a speaker-only audio settings button. Mute is inside the audio panel alongside the two volume sliders, and the Soft effects toggle is removed from the menu.

## Leaf piles and rendering follow-up

The canopy now has 2,160 distinct leaves (25% fewer), at radius 7.8 (30% larger), including 144 extra central attachments. Weekly shedding and miss allowances scale to the lighter canopy; the recovery floor is 720. Previous save densities migrate proportionally while preserving score, campaign identity and upgrade purchases.

Leaf identities retain their depth ordering across detachment and flight in one instanced pass. Foreground occluders shed first, before seasonal colour preference. Two independent fine support surfaces stack landed leaves into growing piles; alternate identities draw before/after the player. The ending simulates only airborne leaves at 30 Hz and interpolates movement for rendering. Bulk instance buffers replace thousands of server calls and individual ground/air draw commands. Warning snow emits above the top edge, including when snowfall density increases.

A 600-frame headless CPU study measured about 0.96 seconds combined simulation/upload work versus 1.43 seconds previously; this is a renderer-update benchmark, not a mobile frame-rate claim. Physical device profiling remains necessary.

The walking atlas has been replaced with textured paper trouser, calf and shoe pieces without exposed connector tabs. The two-bone solver now bends toward the toes (including mirrored travel), using the same bend at rest so starting a stride does not flip the joint. Bone length, planted-foot and directional-knee checks cover complete strides.

## Paper workshop and checkpoint upgrades

All thirty nodes now use original textured paper object illustrations, with a matching Gold Leaf token and reset icon. Equipment tabs are image-only. The currency count sits beside a small leaf; Done returns to the originating screen. Hover popups/highlights and the Saved footer have been removed.

Upgrades are available from results (including a loss), saved Continue, and the live restart review. Continue and Retry purchases update the level checkpoint immediately. During a live restart review, choices stay in a draft: Cancel resumes the unchanged attempt, while Restart commits and saves the selected kit. Mid-attempt purchases remain disallowed.

High-score storage version 2 merges historical tables, normalizes pre-score-reduction values, keeps the best row per campaign, and saves one top ten per difficulty without rules metadata. Old browser/native keys and backups still load.
