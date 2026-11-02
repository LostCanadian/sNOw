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
| Electric whirr | Original synthesized tone in `scripts/main.gd` | Temporary, quiet motor cue. No recorded audio samples. |

Generated image originals are retained outside the checkout under `/workspace/generated_images` in this task. Runtime copies are included here so the project does not depend on those paths. The earlier comparison/progression sheets are creative references, not included in the runtime build. Review final production assets, consistency, and distribution rights before shipping; the attached tree supplied by the user is the reference for the current Season Tree adaptation.

Large paper sprites generate mipmaps and use smooth linear filtering at runtime. They are not pixel-art assets.

The in-game License screen reads Godot’s full MIT text and bundled-library copyright/license terms from the running engine. `licenses/DEJAVU.txt` includes the font-specific Bitstream Vera terms and DejaVu public-domain notice; exports explicitly include this text and the original font package notice. These third-party terms do not assign a license to the project’s own code or artwork.

`art/upgrade_icons.png` was generated with OpenAI image generation for this project (`exec-fc2d4fb0-083c-4bb5-ac97-8f63de8eb65f.png`): textured boots, electric fan and battery icons. Atlas regions in `scripts/main.gd` preserve each full silhouette; icons use fixed header bounds with smooth mipmapped filtering.

`art/fan.svg` and `art/surge.svg` are original vector UI assets authored in this repository. Smooth curved fan blades and upward leaf jets use 256px sources with mipmaps; no external artwork or new runtime libraries were introduced.

`art/hud_frost.svg` and `art/battery_frame.svg` are original vector status assets authored in this repository. The sixfold punched-paper flake has a 256px source; the rounded battery frame is 256 × 144. Both use mipmaps and runtime tint/fill, without new dependencies.

`scripts/canopy_sprays.gd` contains 2,592 baked branch attachment coordinates derived from the existing Season Tree alpha mask, extending the original 288 positions to 2,880 leaves. `tools/build_canopy_sprays.py` regenerates that geometry with Pillow, NumPy and SciPy (authoring dependencies only). It reads the image and writes coordinates; it does not modify the tree artwork. All added stems meet painted bark, and leaf pairs follow their twig directions.

`art/play.svg`, `art/pause.svg` and `art/twinkle.svg` are original vector interface assets authored here, with mipmaps. The walking rig now samples rigid thigh/shin/shoe cutouts from the existing wardrobe atlas using UV regions; the artwork itself is unchanged. No new runtime library was introduced.

`art/gold_leaf.svg` and `art/upgrades/*.svg` are original vector UI artwork authored in this repository. Each upgrade has a thematic line icon; the tornado icon replaces the previous Leaflift Surge symbol. No additional library or external asset license is required.
