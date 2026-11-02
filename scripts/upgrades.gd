extends RefCounted
## Thirty explicit nodes. IDs are stable save data; prerequisites refer to local node IDs.
const MAX_RANK := 10
const TITLES := ["BOOTS", "BLOWER", "BATTERY"]
const POSITIONS := [Vector2(168, 0), Vector2(88, 57), Vector2(248, 57), Vector2(48, 114), Vector2(128, 114), Vector2(208, 114), Vector2(288, 114), Vector2(48, 171), Vector2(168, 171), Vector2(288, 171)]
const PARENTS := [[], [0], [0], [1], [1], [2], [2], [3], [4,5], [6]]
const NAMES := [
	["Trail soles", "Quick stride", "Sure footing", "Light steps", "Balanced kit", "Deep grip", "Leaf skimmer", "Fleet feet", "All terrain", "Feather tread"],
	["Torque fan", "Wide nozzle", "Whirlwind", "Air shaper", "Long reach", "Vortex core", "Updraft", "Meadow fan", "Storm weave", "Cyclone"],
	["Smart cell", "Larger pack", "Quick recovery", "Cell bank", "Efficient motor", "Rapid charge", "Whirlwind cell", "Long haul", "Hybrid pack", "Storm reserve"],
]
const ICONS := [
	["boot", "stride", "grip", "feather", "balance", "roots", "skimmer", "wings", "terrain", "feather"],
	["fan", "wide", "tornado", "steer", "reach", "vortex", "updraft", "wide", "weave", "tornado"],
	["cell", "pack", "charge", "pack", "efficient", "charge", "tornado_cell", "cell", "hybrid", "tornado_cell"],
]
const DETAILS := [
	["Lighter soles increase walking speed by 6%.", "Stride speed +9%.", "Pile slowdown reduced by 5 percentage points.", "Stride speed +10%.", "Carry blower and battery weight 20% more easily.", "Pile slowdown reduced by 7 percentage points.", "Stride speed +5%; pile slowdown reduced by 3 percentage points.", "Stride speed +14%.", "Stride speed +8%; pile slowdown reduced by 5 percentage points. Requires both inner paths.", "Pile slowdown reduced by 8 percentage points."],
	["Lift force +12%.", "Wind cone width +10.", "E: leap into a Whirlwind, lifting nearby ground and airborne leaves. Recharges in 36 seconds.", "Outward steering +25%.", "Wind reach +35.", "Whirlwind radius +22.", "Lift force +15%.", "Wind cone width +16.", "Lift force +12%; steering +15%. Requires both inner paths.", "Whirlwind lift +25%; radius +20."],
	["Burst duration +10%.", "Burst duration +16%.", "Battery recharge 12% faster.", "Burst duration +22%.", "Burst duration +12%; carry weight reduced.", "Battery recharge 15% faster.", "Whirlwind recharges 5 seconds sooner.", "Burst duration +25%.", "Burst duration +14%; recharge 10% faster. Requires both inner paths.", "Whirlwind recharges 7 seconds sooner."],
]
const EFFECTS := [
	[{"speed":0.06},{"speed":0.09},{"grip":0.05},{"speed":0.10},{"weight_relief":0.2},{"grip":0.07},{"speed":0.05,"grip":0.03},{"speed":0.14},{"speed":0.08,"grip":0.05},{"grip":0.08}],
	[{"force":0.12},{"width":10.0},{"whirlwind":1.0},{"steering":0.25},{"reach":35.0},{"radius":22.0},{"force":0.15},{"width":16.0},{"force":0.12,"steering":0.15},{"surge_force":0.25,"radius":20.0}],
	[{"burst":0.10},{"burst":0.16},{"recharge":0.12},{"burst":0.22},{"burst":0.12,"weight_relief":0.1},{"recharge":0.15},{"cooldown":5.0},{"burst":0.25},{"burst":0.14,"recharge":0.1},{"cooldown":7.0}],
]

static func cost(branch: int, node: int) -> int:
	return 3 if branch == 1 and node == 2 else (2 if node >= 7 else 1)

static func available(owned: Array, branch: int, node: int) -> bool:
	if branch < 0 or branch > 2 or node < 0 or node >= MAX_RANK or owned.has(branch * MAX_RANK + node): return false
	for parent in PARENTS[node]:
		if not owned.has(branch * MAX_RANK + parent): return false
	return true

static func spent(owned: Array) -> int:
	var total := 0
	for id in owned: total += cost(int(id) / MAX_RANK, int(id) % MAX_RANK)
	return total

static func counts(owned: Array) -> Array:
	var result := [0,0,0]
	for id in owned: result[int(id) / MAX_RANK] += 1
	return result

static func valid(owned, tiers) -> bool:
	if not owned is Array or owned.size() > 30: return false
	var seen := []
	for id in owned:
		if not (id is int or id is float) or not is_finite(float(id)) or id != floor(id) or id < 0 or id >= 30 or seen.has(int(id)): return false
		seen.append(int(id))
	for id in seen:
		for parent in PARENTS[id % MAX_RANK]:
			if not seen.has(id / MAX_RANK * MAX_RANK + parent): return false
	var actual := counts(seen)
	for branch in range(3):
		if actual[branch] != tiers[branch]: return false
	return true

static func legacy_nodes(tiers: Array) -> Array[int]:
	var result: Array[int] = []
	for branch in range(3):
		var order := [0,2,6,1,3,4] if branch == 1 else [0,1,2,3,4,5]
		for i in range(mini(int(tiers[branch]), 6)): result.append(branch * MAX_RANK + order[i])
	return result

static func effects(owned: Array) -> Dictionary:
	var result := {"speed":0.0,"grip":0.0,"weight_relief":0.0,"force":0.0,"width":0.0,"whirlwind":0.0,"steering":0.0,"reach":0.0,"radius":0.0,"surge_force":0.0,"burst":0.0,"recharge":0.0,"cooldown":0.0}
	for id in owned:
		for key in EFFECTS[int(id) / MAX_RANK][int(id) % MAX_RANK]:
			result[key] += EFFECTS[int(id) / MAX_RANK][int(id) % MAX_RANK][key]
	return result

static func description(branch: int, node: int) -> String:
	return DETAILS[branch][node]
