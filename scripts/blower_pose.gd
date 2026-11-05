extends RefCounted
## Shared pose/airflow geometry. Both cutout mesh and fixed-step physics use this.
const SIZE := Vector2(78, 76)
const ANCHOR := Vector2(0.40, 1.0)
const NOZZLE_UV := Vector2(0.95, 0.06)
const GRIP_UV := Vector2(0.55, 0.48)
const GRIP := (GRIP_UV - ANCHOR) * SIZE
const ORIGINAL_TIP := (NOZZLE_UV - ANCHOR) * SIZE
const ORIGINAL_ANGLE := 0.7739918139903581
const MOVING_TILT := PI * 32.0 / 180.0
const TURN_SPEED := 7.0
const REST_NOZZLE := Vector2(11.7, -84.15548364250128)

static func local_tip(tilt: float) -> Vector2:
	return GRIP + (ORIGINAL_TIP - GRIP).rotated(tilt - ORIGINAL_ANGLE)

static func nozzle_offset(facing: float, aim: float) -> Vector2:
	var tip := local_tip(aim * facing)
	return Vector2(tip.x * facing, tip.y)

static func axis(aim: float) -> Vector2:
	return Vector2.UP.rotated(aim)

static func attenuation(distance: float, reach: float) -> float:
	# Keep the nozzle strong, then soften smoothly along the expanding cone.
	return lerpf(1.0, 0.28, smoothstep(0.0, maxf(reach, 1.0), maxf(distance, 0.0)))

static func edge_force(x: float) -> float:
	if x < 48.0: return (48.0 - x) * 5.0 + (120.0 if x < 0 else 0.0)
	if x > 312.0: return -(x - 312.0) * 5.0 - (120.0 if x > 360 else 0.0)
	return 0.0

static func reflect_draft(x: float, force: Vector2, return_side := 0) -> Vector2:
	# Turn outward airflow inward across a soft wall band. Past the nozzle the
	# normal fan-out can then carry a returned leaf farther into the clearing.
	if return_side > 0 and x < 144.0:
		force.x = absf(force.x)
		return force
	if return_side < 0 and x > 216.0:
		force.x = -absf(force.x)
		return force
	if force.x < 0 and x < 96.0:
		force.x *= lerpf(-1.0, 1.0, smoothstep(0.0, 96.0, x))
	elif force.x > 0 and x > 264.0:
		force.x *= lerpf(-1.0, 1.0, smoothstep(0.0, 96.0, 360.0 - x))
	return force

static func reflect_point(point: Vector2, margin := 7.8) -> Vector2:
	# Mirror overshoot instead of pinning a leaf at a wall.
	if point.x < margin: point.x = 2.0 * margin - point.x
	elif point.x > 360.0 - margin: point.x = 720.0 - 2.0 * margin - point.x
	point.x = clampf(point.x, margin, 360.0 - margin)
	return point
