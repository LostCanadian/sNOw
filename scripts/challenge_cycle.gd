extends RefCounted
## One deterministic calendar drives atmosphere and real storm gusts. No RNG draws.
const Wind = preload("res://scripts/north_wind.gd")
const STAGE_SECONDS := 10.0
const FADE_SECONDS := 5.0
# name, time, weather, rain, fog, wind, cloud, night, dusk, sunlight
const STAGES := [
	["Sunlit clearing", "day", "sun", 0.0, 0.08, 0.25, 0.0, 0.0, 0.0, 1.0],
	["Passing clouds", "day", "partly", 0.0, 0.10, 0.32, 0.25, 0.0, 0.0, 0.8],
	["Silver skies", "day", "cloud", 0.0, 0.18, 0.45, 0.60, 0.0, 0.0, 0.25],
	["Wind in the valley", "day", "wind", 0.0, 0.20, 0.80, 0.75, 0.0, 0.15, 0.12],
	["Evening rain", "dusk", "rain", 0.55, 0.32, 0.70, 0.85, 0.0, 0.65, 0.0],
	["An evening storm", "dusk", "storm", 0.85, 0.38, 1.0, 1.0, 0.0, 0.85, 0.0],
	["The rain eases", "dusk", "rain", 0.40, 0.32, 0.65, 0.80, 0.10, 1.0, 0.0],
	["Clouds at twilight", "dusk", "cloud", 0.0, 0.24, 0.45, 0.60, 0.35, 0.8, 0.0],
	["A break in the clouds", "night", "partly", 0.0, 0.18, 0.30, 0.25, 0.85, 0.25, 0.0],
	["Moonlit hush", "night", "clear", 0.0, 0.15, 0.22, 0.0, 1.0, 0.0, 0.0],
	["Clouds across the moon", "night", "partly", 0.0, 0.18, 0.32, 0.25, 1.0, 0.0, 0.0],
	["A clouded night", "night", "cloud", 0.0, 0.24, 0.45, 0.60, 1.0, 0.0, 0.0],
	["Night winds", "night", "wind", 0.0, 0.28, 0.80, 0.75, 1.0, 0.0, 0.0],
	["Rain after dark", "night", "rain", 0.55, 0.34, 0.70, 0.85, 1.0, 0.0, 0.0],
	["Distant night storm", "night", "storm", 0.85, 0.38, 1.0, 1.0, 1.0, 0.0, 0.0],
	["Night rain eases", "night", "rain", 0.40, 0.32, 0.65, 0.85, 0.90, 0.10, 0.0],
	["A breeze before dawn", "dawn", "wind", 0.0, 0.28, 0.55, 0.70, 0.55, 0.55, 0.0],
	["Clouds at dawn", "dawn", "cloud", 0.0, 0.24, 0.40, 0.55, 0.15, 0.85, 0.05],
	["First morning light", "day", "partly", 0.0, 0.15, 0.32, 0.25, 0.0, 0.35, 0.60],
	["Morning sunlight", "day", "sun", 0.0, 0.08, 0.25, 0.0, 0.0, 0.0, 1.0],
]
const PERIOD := STAGE_SECONDS * 20
const STORM_STAGES := [5, 14]
const GUST_AT := 6.0 # After the storm has finished fading in.
const FIELDS := ["rain", "fog", "wind", "cloud", "night_amount", "dusk_amount", "sunlight"]

static func sample(time: float) -> Dictionary:
	var elapsed := maxf(0, time)
	var index := floori(elapsed / STAGE_SECONDS) % STAGES.size()
	var previous := maxi(0, floori(elapsed / STAGE_SECONDS) - 1) % STAGES.size()
	var blend := smoothstep(0, FADE_SECONDS, fposmod(elapsed, STAGE_SECONDS))
	var from: Array = STAGES[previous]
	var to: Array = STAGES[index]
	var lunar_cycle := floori(elapsed / PERIOD)
	# Begin at waxing gibbous, then full, waning, new and waxing again.
	var moon := (7 + lunar_cycle) % 8
	var result := {"week": 8, "stage": index, "cycle": lunar_cycle,
		"name": to[0], "time": to[1], "weather": to[2], "moon": moon,
		"moon_turn": -0.12, "moon_position": Vector2(282, 94), "sun": Vector2(78, 90),
		"seed": 72031, "rare": to[1] == "night" and moon == 0}
	for i in range(FIELDS.size()): result[FIELDS[i]] = lerpf(from[i + 3], to[i + 3], blend)
	result.storm = lerpf(1.0 if from[2] == "storm" else 0.0, 1.0 if to[2] == "storm" else 0.0, blend)
	return result

static func gust(time: float) -> Dictionary:
	var stage := floori(maxf(0, time) / STAGE_SECONDS)
	var index := stage % STAGES.size()
	var local := fposmod(maxf(0, time), STAGE_SECONDS) - GUST_AT
	if index not in STORM_STAGES or local < 0.0 or local >= Wind.WARNING + Wind.SWEEP: return {}
	var pass_id := floori(stage / STAGES.size()) * 2 + STORM_STAGES.find(index)
	# NorthWind's own period selects direction. Each storm gets exactly one pass.
	return {"id": pass_id, "time": (pass_id % 2) * Wind.PERIOD + local}
