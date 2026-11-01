# Prototype asset provenance

| File | Source / creator | Status and use |
| --- | --- | --- |
| `art/autumn_stage.png` | Generated with OpenAI image generation for this project, based on the user-selected Paper & Lanterns concept progression | Prototype environment plate. Lighting, trees and paper grain are baked into one image, not separately rigged production layers. |
| `art/caretaker.png` | Generated with OpenAI image generation for this project | Transparent single-pose electric-blower character. Runtime uses the nontransparent region and a small walk bob; no finished animation rig. |
| `art/snowflake.svg` | Original vector artwork authored in this repository | Sixfold cut-paper snowflake with transparent punched-out details; no external source asset. |
| `icon.svg` | Original vector artwork authored in this repository | Temporary project icon; not final branding. |
| `fonts/DejaVuSans.ttf`, `fonts/DejaVuSerif.ttf` | DejaVu Fonts project, copied from the environment's installed fonts | Redistributed under the bundled [font license](fonts/LICENSE.txt); retain that license with distributions. |
| Runtime leaves, gusts, fog, shadows, clouds, flowers and fan icon | Original procedural drawing in `scripts/main.gd` | Prototype vector effects; no purchased or externally sourced textures. |
| Electric whirr | Original synthesized tone in `scripts/main.gd` | Temporary, quiet motor cue. No recorded audio samples. |

Generated image originals are retained outside the checkout under `/workspace/generated_images` in this task. Runtime copies are included here so the project does not depend on those paths. The earlier comparison/progression sheets are creative references, not included in the runtime build. Review final production assets, consistency, and distribution rights before shipping; no third-party reference art was downloaded for this prototype.
