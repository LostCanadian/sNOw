#!/usr/bin/env python3
"""Measure the canonical painting's mountain ridge. Never modify source pixels."""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, gaussian_filter1d
ROOT=Path(__file__).resolve().parents[1]
im=np.asarray(Image.open(ROOT/'assets/art/weather_stages.png').convert('RGB'),dtype=float)/255
width=im.shape[1]//3
sm=gaussian_filter(im[:,:width],(2.5,2.5,0))
# This band contains the continuous sky/mountain edge, above houses and trees.
start,stop=450,540
cost=np.linalg.norm(sm[start+3:stop+3]-sm[start:stop],axis=2)
score=cost[:,0].copy();links=[]
for x in range(1,width):
 candidates=np.stack([np.roll(score,d)-abs(d)*0.012 for d in range(-3,4)])
 for i,d in enumerate(range(-3,4)):
  if d>0:candidates[i,:d]=-1e6
  elif d<0:candidates[i,d:]=-1e6
 best=candidates.argmax(axis=0)
 links.append(np.arange(len(score))-np.asarray(range(-3,4))[best])
 score=cost[:,x]+candidates.max(axis=0)
y=int(score.argmax());ridge=[y]
for link in reversed(links):y=int(link[y]);ridge.append(y)
ridge=np.asarray(list(reversed(ridge)),dtype=float)+start+1.5
ridge=gaussian_filter1d(ridge,.65)/im.shape[0]
lines=['extends RefCounted','## Measured by tools/build_skyline.py; original painting pixels stay intact.','const HEIGHTS := [']
for x in range(0,width,12):lines.append('\t'+','.join('%.7f'%v for v in ridge[x:x+12])+',')
lines+= [']']
(ROOT/'scripts/skyline.gd').write_text('\n'.join(lines)+'\n')
print('Measured %d fixed sky/mountain boundary samples.'%width)
