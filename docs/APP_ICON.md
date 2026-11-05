# Paper maple leaf app icon

`assets/icon.png` is the project icon and classic Android launcher icon. `assets/icon-adaptive.png` has extra space around the complete leaf and stem for Android adaptive masks. Both square images retain their full ivory paper field; the launcher chooses the outer shape. `assets/icon-background.svg` supplies an ivory adaptive background. Android paths are explicit in `export_presets.cfg` so exports do not fall back to the retired temporary SVG.

The centred maple silhouette uses the existing `assets/art/paper_leaf.png` as its shape and paper-texture reference. Colour flows horizontally from green through yellow and orange to red. The adaptive image places the complete silhouette inside the central safe circle; the main image uses a larger leaf while retaining enough margin for a full-image circular crop. See [Godot's Android launcher icon guidance](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html#providing-launcher-icons).

Generated with the built-in `image_gen` tool. Main original: `exec-cd8fd954-9b0f-4860-b3c9-64e3a56d7d05.png`. Padded adaptive original: `exec-b9031867-28ce-4018-bad1-405d52f9bf0e.png`. PNGs are copied unchanged into the project. No new image-processing runtime dependency is needed.

## Main generation prompt

```text
Use case: logo-brand
Asset type: square production mobile launcher icon for the paper-art game sNOw.
Input image 1 is a STYLE and maple-leaf SHAPE REFERENCE only, not an edit target: match its handmade cut-paper fibres, fine crease veins, irregular pointed maple lobes, and softly shaded paper relief.
Primary request: one upright paper maple leaf, completely visible including its short downward stem, centered horizontally and vertically. Colour must flow in one smooth LEFT-TO-RIGHT horizontal gradient across the leaf: rich fresh green at the far left, golden yellow at left-middle, warm orange at right-middle, deep autumn red at the far right. Retain this order clearly; do not use separate leaves or quadrants. Subtle warm brown vein detail and slightly darker paper edges, readable as a small phone app icon. The silhouette should resemble the reference leaf, with the top point upright, the stem downward, all tips intact.
Composition: square canvas, flat front view. CRITICAL mobile adaptive/circular icon safety: the complete leaf INCLUDING stem and every tip must fit within an invisible centered circle whose diameter is 59% of the canvas width. Keep at least 20% empty margin on all four sides. Place the visual centre at the exact centre of the square. No objects near the edges. Leaf should be substantial within that safe area, not tiny.
Background: an unbroken full-bleed pale warm ivory paper field with very subtle paper fibre, no scenery, no frame, no border, no baked rounded square or circle. A restrained soft contact shadow directly behind the cut-paper leaf is fine. No typography, no letters, no app name, no watermarks, no extra symbols. Produce a polished square bitmap icon, single icon only, no mockup or layout sheet.
```

## Adaptive padding edit prompt

```text
Use case: precise-object-edit
Edit target: the supplied square paper maple leaf app icon.
Change ONLY the amount of empty paper margin around the existing leaf: shrink the complete leaf and its tiny shadow to 72% of their current dimensions, keeping the leaf precisely centered horizontally and vertically. Extend the same pale ivory paper background seamlessly into the added space. Keep the existing square canvas.
Preserve the exact existing maple leaf shape, complete stem, cut-paper fibres, crease veins, and smooth green-left to yellow to orange to red-right gradient. Do not redraw or redesign the leaf. The full leaf including stem should now occupy approximately 54% of the canvas width and height, leaving approximately 23% empty paper margin on every side. All parts of the leaf must lie inside an invisible centered circle of diameter 59% of the image width. This is intentionally generous padding required for an Android adaptive icon mask. No visible circle, no border, no text, no new objects.
```

