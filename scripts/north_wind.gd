extends RefCounted
## One shared path for the visible wind ribbons, branch stripping and airborne force.
const PERIOD := 4.8
const WARNING := 0.8
const SWEEP := 1.5
const RADIUS := 52.0

static func cycle(time: float) -> int: return floori(time / PERIOD)
static func direction(time: float) -> float: return 1.0 if cycle(time) % 2 == 0 else -1.0
static func phase(time: float) -> String:
	var local := fposmod(time, PERIOD)
	return "warning" if local < WARNING else ("blast" if local < WARNING + SWEEP else "rest")
static func progress(time: float) -> float:
	return clampf((fposmod(time, PERIOD) - WARNING) / SWEEP, 0, 1)
static func center(time: float, lane: float) -> Vector2:
	var t := progress(time)
	var x := lerpf(-90, 450, t)
	if direction(time) < 0: x = 360 - x
	return Vector2(x, lane + sin(t * TAU) * 18)
static func segment(previous: float, time: float, lane: float) -> Array[Vector2]:
	var beginning := cycle(time) * PERIOD + WARNING
	return [center(maxf(previous, beginning), lane), center(time, lane)]
static func force(position: Vector2, time: float, lane: float) -> Vector2:
	if phase(time) != "blast": return Vector2.ZERO
	var radial := position - center(time, lane)
	var strength := clampf(1.0 - radial.length() / 82.0, 0, 1)
	return (Vector2(direction(time) * 165, 55) + radial.orthogonal().normalized() * direction(time) * 110) * strength
