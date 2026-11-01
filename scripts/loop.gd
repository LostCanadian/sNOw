extends RefCounted
## Presentation-independent fixed-step arcade simulation. All coordinates are logical 360 x 640.

const GROUND := 502.0
const CAPTURE_Y := 176.0
const MAX_ACTIVE := 150
const BASE_SPEED := 122.0
const CAPACITY := 28
const TOTAL_DAYS := 7
const LEAF_COLOURS := [Color("e6ae3d"), Color("d96a32"), Color("b54332"), Color("b5b352")]

var rng := RandomNumberGenerator.new()
var day := 1
var x := 180.0
var charge := 1.0
var idle_charge_time := 0.0
var energy_locked := false
var blowing := false
var direction := 0.0
var score := 0
var combo := 0
var rescued := 0
var missed := 0
var spawned := 0
var day_rescued := 0
var day_missed := 0
var day_time := 0.0
var spawn_timer := 0.5
var next_id := 0
var status := "playing"
var leaves: Array[Dictionary] = []
var piles: Array[int] = []
var points := 0
var earned_points := 0
var tiers := [0, 0, 0]
var events: Array[Dictionary] = []


func _init(seed_value: int = 641023) -> void:
	rng.seed = seed_value
	piles.resize(12)
	piles.fill(0)


func stats(build: Array = tiers) -> Dictionary:
	var load_factor: float = 1.0 + 0.075 * build[1] + (0.04 if build[2] == 2 else 0.0)
	return {
		"speed": BASE_SPEED * (1.10 if build[0] >= 1 else 1.0) / load_factor,
		"force": 410.0 * (1.0 + 0.25 * build[1]),
		"width": 48.0 + (12.0 if build[1] == 2 else 0.0),
		"burst": 6.0 * (1.30 if build[2] == 2 else 1.0) / ((1.0 + 0.15 * build[1]) * (0.78 if build[2] >= 1 else 1.0)),
		"recharge": 3.0 * (1.30 if build[2] == 2 else 1.0),
		"pile_penalty": 0.30 if build[0] == 2 else 0.40,
	}


func pressure() -> float:
	return clampf(float(missed) / CAPACITY, 0.0, 1.0)


func day_leaf_count() -> int:
	return 16 + (day - 1) * 2


func pile_at(at_x: float) -> int:
	return piles[clampi(int(at_x / 30.0), 0, 11)]


func nozzle() -> Vector2:
	return Vector2(x + 13.0, GROUND - 53.0)


func step(dt: float, move_axis: float, wants_blow: bool) -> void:
	events.clear()
	if status != "playing":
		blowing = false
		return
	var s := stats()
	direction = clampf(move_axis, -1.0, 1.0)
	var drag: float = minf(float(pile_at(x)) / 5.0, 1.0) * s.pile_penalty
	x = clampf(x + direction * s.speed * (1.0 - drag) * dt, 29.0, 331.0)
	if not wants_blow:
		energy_locked = false
		idle_charge_time += dt
		if idle_charge_time > 0.5:
			charge = minf(1.0, charge + dt / s.recharge)
	else:
		idle_charge_time = 0.0
	blowing = wants_blow and not energy_locked and charge > 0.0
	if blowing:
		charge = maxf(0.0, charge - dt / s.burst)
		if charge <= 0.0:
			energy_locked = true
			blowing = false
	day_time += dt
	spawn_timer -= dt
	if spawn_timer <= 0.0 and spawned < day_leaf_count() and leaves.size() < MAX_ACTIVE:
		spawn_leaf()
		spawn_timer += maxf(0.60, 1.30 - day * 0.075)
	var origin := nozzle()
	for leaf in leaves:
		if leaf.state != "air":
			continue
		leaf.age += dt
		var p: Vector2 = leaf.position
		var v: Vector2 = leaf.velocity
		var height := origin.y - p.y
		var center_x := origin.x + direction * height * 0.15
		var in_gust: bool = blowing and height > -8.0 and height < 335.0 and absf(p.x - center_x) < s.width * (0.7 + height / 340.0)
		var wind := sin(day_time * 0.9 + day) * (5.0 + day * 1.6)
		v.x += (wind + sin(leaf.age * 4.0 + leaf.id) * 12.0 - v.x * 0.60) * dt
		v.y += (38.0 - v.y * 0.16) * dt
		if in_gust:
			leaf.lifted = true
			v.y -= s.force * dt
			v.x += ((center_x - p.x) * 2.0 + sin(leaf.age * 10.0 + leaf.id) * 95.0) * dt
		v.y = clampf(v.y, -158.0, 45.0 + day * 1.5)
		v.x = clampf(v.x, -85.0, 85.0)
		p += v * dt
		if p.x < 24.0 or p.x > 336.0:
			p.x = clampf(p.x, 24.0, 336.0)
			v.x = -v.x * 0.6
		leaf.position = p
		leaf.velocity = v
		leaf.angle += dt * (1.8 if in_gust else 0.7)
		# A broad canopy band guarantees upgrades cannot shoot through a tiny target.
		if leaf.lifted and p.y <= CAPTURE_Y:
			resolve_leaf(leaf, true)
		elif p.y >= GROUND - minf(14.0, pile_at(p.x) * 2.0):
			resolve_leaf(leaf, false)
		if status == "lost":
			break
	leaves = leaves.filter(func(leaf: Dictionary) -> bool: return leaf.state == "air")
	if status == "playing" and spawned >= day_leaf_count() and leaves.is_empty():
		score += 500 + 50 * (CAPACITY - missed)
		blowing = false
		if day == TOTAL_DAYS:
			score += 5000
			status = "won"
		else:
			points += 1
			earned_points += 1
			status = "workshop"


func spawn_leaf() -> void:
	var start_x := rng.randf_range(48.0, 312.0)
	leaves.append({
		"id": next_id, "position": Vector2(start_x, 166.0 + rng.randf_range(0, 18)),
		"velocity": Vector2(rng.randf_range(-10, 10), 8.0),
		"state": "air", "lifted": false, "age": 0.0,
		"angle": rng.randf_range(-PI, PI), "colour": LEAF_COLOURS[next_id % LEAF_COLOURS.size()],
	})
	next_id += 1
	spawned += 1


func resolve_leaf(leaf: Dictionary, saved: bool) -> void:
	if leaf.state != "air":
		return
	leaf.state = "rescued" if saved else "grounded"
	if saved:
		combo += 1
		rescued += 1
		day_rescued += 1
		var multiplier := 1 if combo < 5 else (2 if combo < 10 else (3 if combo < 15 else 4))
		score += 100 * multiplier
	else:
		missed += 1
		day_missed += 1
		combo = 0
		var segment := clampi(int(leaf.position.x / 30.0), 0, 11)
		piles[segment] += 1
		if missed >= CAPACITY:
			status = "lost"
			blowing = false
	events.append({"position": leaf.position, "saved": saved})


func buy(branch: int) -> bool:
	if status != "workshop" or branch < 0 or branch > 2 or tiers[branch] >= 2:
		return false
	var cost: int = 1 if tiers[branch] == 0 else 2
	if points < cost:
		return false
	points -= cost
	tiers[branch] += 1
	return true


func refund_build() -> void:
	if status != "workshop":
		return
	tiers = [0, 0, 0]
	points = earned_points


func next_day() -> bool:
	if status != "workshop":
		return false
	day += 1
	charge = 1.0
	energy_locked = false
	idle_charge_time = 0.0
	spawned = 0
	day_rescued = 0
	day_missed = 0
	day_time = 0.0
	spawn_timer = 0.5
	piles.fill(0)
	leaves.clear()
	status = "playing"
	return true
