extends RefCounted
## One continuous depth/size distribution, with fewer large foreground crystals.
const MIN_RADIUS:=0.65
const MAX_RADIUS:=6.0
static func radius(sample:float) -> float:
	return lerpf(MIN_RADIUS,MAX_RADIUS,pow(clampf(sample,0,1),1.45))
static func detail(radius_px:float) -> float:
	return smoothstep(1.6,3.8,radius_px)
