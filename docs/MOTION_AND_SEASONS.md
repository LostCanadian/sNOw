# Articulated motion and seasonal shedding

## Beta motion update

The walking renderer now uses a separate 18-piece thigh/shin/shoe atlas with three clothing sets. Each segment has its own rigid hip, knee or ankle transform; complete hidden hinge ends overlap at the joints. The body uses the existing wardrobe artwork. Source sprite bounds are baked by alpha-component analysis without modifying the artwork. A 29-unit stride, 62% planted stance, lower foot lift and small swing-phase shoe pitch replace the broader gait. Feet stop cycling when movement stops or reaches a boundary.

## Character

The old leg skinning stretched painted regions between bones of mismatched lengths. The replacement uses separate illustrated thigh, shin and shoe sprites from the dedicated limb atlas. Hip/knee joints rotate those pieces with fixed lengths and unit scale; shoes stay level in stance and tilt slightly in swing. A short crouch gives the legs enough reach for a distance-driven run cycle. Long coats cover the hip hinges. Turning retains gait progress; standing still stops the cycle. Blower/upper-body aiming and restrained motor vibration remain separate from the legs.

This is an articulated cutout animation using the existing twelve costumes. Additional arm/face poses and a hand-authored animation pass remain future polish. The runtime does not warp the leg textures to reach an impossible foot position.

## Colour and falling rate

Week one is approximately **94% green / 6% yellow**, with no orange or red. Week two introduces some orange; red begins in week three. Colours advance monotonically for each stable leaf identity. By week twelve, the canopy is approximately 3% green, 10% yellow, 25% orange and 62% red. The finale shifts a little further toward red. Full profiles are in `Loop.SEASONS`. Victory gradually changes every leaf to the green palette, including newly grown leaves; it does not reuse week one’s remaining yellow mix.

Selection uses a seeded weighted permutation without replacement: green weight **0.15**, yellow **1**, orange **3**, red **7**. Later falling foliage is therefore mostly red, with orange/yellow mixed in and rare green leaves. The same identity cannot be pending or airborne twice at once. Once reattached, it may be selected again when the fall queue refills. Its colour stays attached to it when it falls or returns to another branch.

The seasonal colour mix also determines shedding intensity. Week one releases **four** leaves per event, with a slightly longer interval. Late weeks reach ten per event at the former interval. Fixed weekly quotas and miss limits still support substantial ground piles; a gentler first week takes longer to finish. Difficulty modifies the interval as before. Numbers remain subject to human playtesting.

## Detachment and targets

Detachment removes an occupied tree identity and creates its airborne state at the **same position, angle, colour and 7.8-unit radius**. There is no downward spawn offset or size change. Flutter/tumble blends in over the first 0.8 seconds. Canopy draw order uses an independent hash, preventing red/yellow leaves from always drawing over all the green ones.

Vacant branches show small, warm twinkling dots at real capture positions, with a restrained halo and a maximum of 64 simultaneous markers. Soft effects makes them steady. These are aiming cues, not arbitrary points in the sky; reattachment still requires an actual empty branch position.

## Foot scuffs

Walking starts a short, individually phased swirl: lateral drift, rotation and a shallow rise. A scuff must finish before another can start, and its height is calculated from the pile surface rather than added to its previous velocity. Scuffs rise four units above the current pile surface. Overlapping leaves build growing piles in independent front/rear depth lanes and slow movement according to actual local density. Footsteps do not create free airborne rescues or alter leaf identity.

## Surge: airborne tumble

The latest direction replaces both the earlier faux vertical-axis spin and the intermediate downward-aim proposal. The caretaker tumbles around the **screen-plane Z axis** for 1.15 seconds, with a small erratic lateral wobble and a bounded hop. The cutout retains its full width and bone lengths. Position and orientation return to the normal pose on landing.

The nozzle and force cone follow the whole-character rotation. Moving wind streaks continue in that direction; there are no rays bouncing off the ground. Nearby ground leaves transfer into the air once, restoring their miss budget. Leaves already airborne receive the rotating cone and a local circulating/upward draft too. The ability can start when only airborne leaves are in range. Lifting alone earns no score; points require actual reattachment.

The touch action shows only its icon and a recharge ring. E still activates it. The Whirlwind node unlocks it, and Battery Whirlwind cell/Storm reserve reduce the 36-second cooldown to 31/24 seconds. Pause freezes the tumble, forces and recharge.

## Winter ending

At defeat, a separate presentation simulation takes the actual attached, airborne and grounded identities, preserving their poses and colours. Attached leaves release in a staggered wave, drift under a stronger cinematic gravity and settle on the ground. No leaves are removed by a visibility cutoff. Every identity remains in one of those three states throughout the sequence.

Ground snow starts accumulating **only after all leaves have landed**. It then covers the pile over 2.2 seconds before results appear. Clouds and small warning flakes can arrive earlier. The ending takes longer than the old four-second reveal; pause/focus loss freezes it. Results, score, gameplay RNG and campaign checkpoints stay frozen at the moment of defeat, so cinematic landings do not add misses or change retry state.

Ending foliage uses instanced paper-leaf batches; transforms upload once per rendered frame rather than every fixed physics step. Settled leaves keep their cached transforms. Snow caps are placed on branch anchors, independent of foliage density. The season preview can jump to the fully snow-covered state for art review.

## Scoring and migration

Rules **5** reduce every gameplay score award by ten: rescue 10 × combo multiplier, weekly bonus 50 + 5 × unused miss allowance, finale bonus 500. Rules 6 then replace upgrade points with two Gold Leaves per completed week and explicit branch nodes.

Earlier campaign totals and known week-start score baselines divide by ten on migration. A newly saved current checkpoint is never converted again. Existing canopy, weeks, upgrades and identity remain. Earlier playing checkpoints regenerate a repeatable colour-weighted schedule from their saved RNG state; completed summaries keep their historical counts. Historical high scores normalize onto the current score scale and join one top ten per difficulty, retaining each campaign’s best result.

## Verification

`tests/test_animation_seasons.gd` checks colour progression/selection, detachment continuity, rigid bone lengths, planted-foot reach, bounded repeated scuffs, ground/air Surge, frozen-score winter identity conservation, snow ordering and score migration. `tests/browser_motion_seasons.py` drives real walking and a validated full-canopy ending study; it checks branch origin/colour, every-leaf landing before snow, pause and unchanged scores. Recorded studies are UI/art validation, not a claim of human campaign completion or phone frame rate.

Recorded browser studies: [walking](images/prototype-motion.mp4), [airborne Surge](images/prototype-surge.mp4), [all-leaf winter fall](images/prototype-winter-fall.mp4), and stills of the [moving rig](images/prototype-walk.png), [falling canopy](images/prototype-winter-fall.png) and [settled pile](images/prototype-winter-ground.png). The ending clip is an uninterrupted art capture; pause is checked separately. Videos use software WebGL in the cloud and do not establish device frame rate.
