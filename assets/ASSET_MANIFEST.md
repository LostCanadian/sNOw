# Prototype asset provenance

| File | Source / creator | Status and use |
| --- | --- | --- |
| `art/autumn_stage.png` | Generated with OpenAI image generation for this project; revised from the earlier paper-cut backdrop at the user's request | Recomposed for the central tree: small modern rural houses and solar roof at the far edges, forest/hills framing a quiet open central clearing and sky. No castle, bridge or baked-in gameplay trees/foliage. Background lighting and paper grain remain baked into the plate. |
| `art/paper_leaf.png` | Generated with OpenAI image generation for this project | Transparent ivory cut-paper maple leaf, tinted per season. One shared material for attached, airborne and grounded foliage. |
| `art/caretaker.png` | Generated with OpenAI image generation for this project | Retained original character reference; superseded at runtime by the wardrobe and ending atlases. |
| `art/season_tree.png` | Generated with OpenAI image generation **using the user-attached tree as the editing reference**, `exec-7bdc1abc-d1d0-43d7-9c61-a704c12bb537.png` | Authoritative runtime tree: gnarled, asymmetric ancient tree with layered bark texture and exposed roots. A transparent adaptation of the supplied reference, rather than an exact-byte copy. Whole illustration with separately attached leaves. |
| `art/bare_tree.png` | Earlier generated tree | Retired reference; the previous identification as the user’s preferred illustration was incorrect. Excluded from browser exports; never selected by the runtime. |
| `art/wardrobe.png` | Generated with OpenAI image generation for this project, using the original character as reference | 4 × 3 transparent atlas: twelve progressively warmer weekly outfits. Runtime crops each equal cell to its visible silhouette, then applies a small two-bone-per-leg cutout mesh rig and a weighted blower vibration control. |
| `art/endings.png` | Generated with OpenAI image generation for this project, referencing the wardrobe sheet | 2 × 1 transparent atlas: happy T-shirt/shorts victory and sad heavily bundled defeat. |
| `art/snowflake.svg` | Original vector artwork authored in this repository | Sixfold cut-paper snowflake with transparent punched-out details; no external source asset. |
| `icon.svg` | Original vector artwork authored in this repository | Temporary project icon; not final branding. |
| `fonts/DejaVuSans.ttf`, `fonts/DejaVuSerif.ttf` | DejaVu Fonts project, copied from the environment's installed fonts | Redistributed under the bundled [font license](fonts/LICENSE.txt); retain that license with distributions. |
| Anchor markers, wind streaks, fog, shadows, clouds and flowers | Original procedural drawing in `scripts/main.gd`; artist-authored twig positions/orientations in `scripts/canopy.gd` | Separate runtime layers. Leaves use the textured paper sprite above; no purchased assets. |
| Music and sound effects | Original offline synthesis in `tools/generate_audio.py`, played by `scripts/audio_director.gd` | Nine MIDI/Ogg scores, eleven effects; no recorded samples. |

Generated image originals are retained outside the checkout under `/workspace/generated_images` in this task. Runtime copies are included here so the project does not depend on those paths. The earlier comparison/progression sheets are creative references, not included in the runtime build. Review final production assets, consistency, and distribution rights before shipping; the attached tree supplied by the user is the reference for the current Season Tree adaptation.

Large paper sprites generate mipmaps and use smooth linear filtering at runtime. They are not pixel-art assets.

The in-game License screen reads Godot’s full MIT text and bundled-library copyright/license terms from the running engine. `licenses/DEJAVU.txt` includes the font-specific Bitstream Vera terms and DejaVu public-domain notice; exports explicitly include this text and the original font package notice. These third-party terms do not assign a license to the project’s own code or artwork.

`art/upgrade_icons.png` was generated with OpenAI image generation for this project (`exec-fc2d4fb0-083c-4bb5-ac97-8f63de8eb65f.png`): textured boots, electric fan and battery icons. Atlas regions in `scripts/main.gd` preserve each full silhouette; icons use fixed header bounds with smooth mipmapped filtering.

`art/fan.svg` and `art/surge.svg` are original vector UI assets authored in this repository. Smooth curved fan blades and the current tornado symbol use vector sources with mipmaps; no external artwork or new runtime libraries were introduced.

`art/hud_frost.svg` and `art/battery_frame.svg` are original vector status assets authored in this repository. The sixfold punched-paper flake has a 256px source; the rounded battery frame is 256 × 144. Both use mipmaps and runtime tint/fill, without new dependencies.

`scripts/canopy_sprays.gd` contains 2,592 baked branch attachment coordinates derived from the existing Season Tree alpha mask, extending the original 288 positions to 2,880 leaves. `tools/build_canopy_sprays.py` regenerates that geometry with Pillow, NumPy and SciPy (authoring dependencies only). It reads the image and writes coordinates; it does not modify the tree artwork. All added stems meet painted bark, and leaf pairs follow their twig directions.

`art/play.svg`, `art/pause.svg` and `art/twinkle.svg` are original vector interface assets authored here, with mipmaps. The upper-body mesh uses the wardrobe atlas; independently illustrated lower-body pieces use the dedicated limb atlas. No new runtime library was introduced.

`art/gold_leaf.svg` and `art/upgrades/*.svg` are original vector UI artwork authored in this repository. The currency and node line drawings are retired reference assets. Runtime upgrades use the paper illustrations described below; only the small lock UI marker remains in use. No additional library or external asset license is required.

`art/caretaker_limbs.png` is a new OpenAI-generated transparent atlas derived from the existing wardrobe reference (current cleaned revision: `/workspace/generated_images/exec-95f93f98-8d21-43fa-8dec-56692a1c4872.png`). Eighteen isolated thigh/shin/shoe illustrations cover shorts, green trousers and brown trousers/boots. `tools/build_limb_regions.py` bakes the solid component bounds into `scripts/limb_regions.gd` without altering source pixels. The runtime uses these separate pieces for the lower-body rig.

`audio/*.ogg` and `audio/midi/*.mid` are original compositions and synthesized effects authored by `tools/generate_audio.py`. Nine eight-bar MIDI scores are rendered with original sine/soft-pulse/triangle voices and procedural noise; no recordings, soundfonts, downloaded samples, external songs or audio libraries are redistributed. NumPy and ffmpeg are authoring tools only. Ogg files play offline through Godot; MIDI source files preserve the notes, tempo and instrumentation.

`audio/streams/*.mp3data` are MP3 renderings of the same nine scores, for browser codec compatibility. They are explicitly included as raw package files so browser media elements can stream them without asking Godot to allocate long WebAudio sample buffers. The audio generator renders both formats from the same synthesized samples.

`art/speaker.svg` is an original vector speaker icon for the main-menu audio settings entry. Mute and music/effects volume are inside the audio panel; the main menu has no effects or mute checkboxes.

`art/workshop_paper.png` (original `exec-9e236699-d6bb-4854-a879-3821cc5dd949.png`) is a generated transparent 6 × 5 atlas of thirty distinct textured paper upgrade objects. `art/workshop_tokens.png` (`exec-b146f0a7-d170-4524-81d9-827dfca66114.png`) contains the matching golden maple leaf currency and circular reset arrows. Both were generated with OpenAI image generation using existing project artwork as reference. `tools/build_workshop_regions.py` reads solid alpha component bounds and writes atlas coordinates; it never changes pixels. Runtime icons use mipmaps and smooth filtering.

`scripts/canopy_center.gd` adds 144 central attachments derived from earlier authored branch sprays. Seven original layers plus these attachments make the current 2,160-leaf crown. `tools/build_canopy_center.py` regenerates the added coordinates without editing the tree image.
