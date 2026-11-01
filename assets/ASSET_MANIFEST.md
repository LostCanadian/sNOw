# Prototype asset provenance

| File | Source / creator | Status and use |
| --- | --- | --- |
| `art/autumn_stage.png` | Generated with OpenAI image generation for this project; revised from the earlier Paper & Lanterns backdrop at the user's request | Modern rural houses, solar roof, distant forest/hills and open sky. No castle, bridge or baked-in gameplay trees/foliage. Background lighting and paper grain remain baked into the plate. |
| `art/paper_leaf.png` | Generated with OpenAI image generation for this project | Transparent ivory cut-paper maple leaf, tinted per season. One shared material for attached, airborne and grounded foliage. |
| `art/caretaker.png` | Generated with OpenAI image generation for this project | Retained original character reference; superseded at runtime by the wardrobe and ending atlases. |
| `art/bare_tree.png` | Generated with OpenAI image generation for this project | One complete smooth illustrated paper tree, mirrored for the right side. No procedural branch assembly. |
| `art/wardrobe.png` | Generated with OpenAI image generation for this project, using the original character as reference | 4 × 3 transparent atlas: twelve progressively warmer weekly outfits. Runtime crops each equal cell to its visible silhouette. |
| `art/endings.png` | Generated with OpenAI image generation for this project, referencing the wardrobe sheet | 2 × 1 transparent atlas: happy T-shirt/shorts victory and sad heavily bundled defeat. |
| `art/snowflake.svg` | Original vector artwork authored in this repository | Sixfold cut-paper snowflake with transparent punched-out details; no external source asset. |
| `icon.svg` | Original vector artwork authored in this repository | Temporary project icon; not final branding. |
| `fonts/DejaVuSans.ttf`, `fonts/DejaVuSerif.ttf` | DejaVu Fonts project, copied from the environment's installed fonts | Redistributed under the bundled [font license](fonts/LICENSE.txt); retain that license with distributions. |
| Anchor markers, wind streaks, fog, shadows, clouds, flowers and fan icon | Original procedural drawing in `scripts/main.gd`; artist-authored twig positions/orientations in `scripts/canopy.gd` | Separate runtime layers. Leaves use the textured paper sprite above; no purchased assets. |
| Electric whirr | Original synthesized tone in `scripts/main.gd` | Temporary, quiet motor cue. No recorded audio samples. |

Generated image originals are retained outside the checkout under `/workspace/generated_images` in this task. Runtime copies are included here so the project does not depend on those paths. The earlier comparison/progression sheets are creative references, not included in the runtime build. Review final production assets, consistency, and distribution rights before shipping; no third-party reference art was downloaded for this prototype.

Large paper sprites generate mipmaps and use smooth linear filtering at runtime. They are not pixel-art assets.
