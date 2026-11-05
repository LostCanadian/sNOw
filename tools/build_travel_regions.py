#!/usr/bin/env python3
"""Bake complete sprite bounds/anchors; leave the generated RGBA pixels unchanged."""
from pathlib import Path
from PIL import Image
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
image = Image.open(ROOT / 'assets/art/wildlife_travel.png')
alpha = np.asarray(image)[:, :, 3]
rects, anchors = [], []
# Body/talon anchors and head-to-talon heights, independent of spread wings/tails.
feet = [(0.64,.79),(.65,.79),(.67,.79),(.68,.79),(.62,.88),(.62,.89),(.63,.90),(.63,.90)]
heights = [155,145,150,150,175,170,168,166] + [210]*8
for index in range(16):
    col, row = index % 4, index // 4
    x, right = col*image.width//4, (col+1)*image.width//4
    y, bottom = row*image.height//4, (row+1)*image.height//4
    yy, xx = np.where(alpha[y:bottom, x:right] > 180)
    assert len(xx) and xx.max()-xx.min()>40 and yy.max()-yy.min()>40
    left, top = max(x, x+xx.min()-2), max(y, y+yy.min()-2)
    endx, endy = min(right, x+xx.max()+3), min(bottom, y+yy.max()+3)
    rects.append((left, top, endx-left, endy-top))
    if index < 8:
        ax, ay = feet[index]
        anchors.append((x+ax*(right-x),y+ay*(bottom-y)))
    elif index < 12:
        anchors.append((x+(right-x)*.45,y+(bottom-y)*.65))
    else:
        anchors.append(((left+endx)/2, endy-2))
lines = ['extends RefCounted', '## Baked by tools/build_travel_regions.py; source art is untouched.', 'const RECTS := [']
lines += ['\tRect2(%d,%d,%d,%d),' % r for r in rects] + [']', 'const ANCHORS := [']
lines += ['\tVector2(%.2f,%.2f),' % a for a in anchors] + [']', 'const BODY_HEIGHTS := '+str(heights)]
(ROOT/'scripts/travel_regions.gd').write_text('\n'.join(lines)+'\n')
print('Baked 16 travel/landing/descent frames.')
