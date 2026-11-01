extends RefCounted
## Presentation-independent fixed-step arcade simulation. All coordinates are logical 360 x 640.

const PaperActor = preload("res://scripts/paper_actor.gd")
const NOZZLE_OFFSET := PaperActor.NOZZLE_OFFSET
const GRAVITY := 48.0
const GROUND := 502.0
const Canopy = preload("res://scripts/canopy.gd")
const CAPTURE_RADIUS := 15.0
const MAX_ACTIVE := 150
const BASE_SPEED := 122.0
const CAPACITY := 28 # Existing Blustery saves retain their tuning.
const DIFFICULTIES := [
	{"name": "Breezy", "capacity": 34, "leaves": 14, "cadence": 1.15, "wind": 0.70, "fall": 0.88},
	{"name": "Blustery", "capacity": 28, "leaves": 16, "cadence": 1.0, "wind": 1.0, "fall": 1.0},
	{"name": "Gale", "capacity": 22, "leaves": 18, "cadence": 0.85, "wind": 1.30, "fall": 1.12},
]
const MAIN_WEEKS := 12
const BOSS_STAGE := MAIN_WEEKS + 1
const LEAF_COLOURS := [Color("e6ae3d"), Color("d96a32"), Color("b54332"), Color("b5b352")]

var difficulty := 1
var run_id := ""
var rng := RandomNumberGenerator.new()
var week := 1
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
var week_rescued := 0
var week_missed := 0
var week_time := 0.0
var spawn_timer := 0.5
var status := "playing"
var leaves: Array[Dictionary] = []
var slots: Array[Dictionary] = []
var shedding_order: Array[int] = []
var piles: Array[int] = []
var points := 0
var earned_points := 0
var tiers := [0, 0, 0]
var events: Array[Dictionary] = []


func _init(seed_value: int = 641023, difficulty_value := 1) -> void:
	difficulty = clampi(difficulty_value, 0, 2)
	run_id = (str(Time.get_unix_time_from_system()) + ":" + str(Time.get_ticks_usec()) + ":" + str(randi())).sha256_text().substr(0, 32)
	rng.seed = seed_value
	piles.resize(12)
	piles.fill(0)
	slots = Canopy.slot_layout()
	prepare_shedding()


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


func capacity() -> int:
	return DIFFICULTIES[difficulty].capacity


func pressure() -> float:
	return clampf(float(missed) / capacity(), 0.0, 1.0)


func week_leaf_count() -> int:
	return shedding_order.size()


func attached_count() -> int:
	var count := 0
	for slot in slots:
		if slot.leaf_id >= 0: count += 1
	return count


func leaf_colour(id: int, season_week: int = 0) -> Color:
	var colour_week := week if season_week <= 0 else season_week
	var autumn_fraction := clampf(float(colour_week) / MAIN_WEEKS, 0, 1)
	if fmod(id * 0.61803398875, 1.0) > autumn_fraction:
		return Color("8fa65c") if id % 2 == 0 else Color("bbc16b")
	return LEAF_COLOURS[id % 3]


func prepare_shedding() -> void:
	shedding_order.clear()
	for slot in slots:
		slot.attached_at = -10.0
		if slot.leaf_id >= 0: shedding_order.append(slot.leaf_id)
	for i in range(shedding_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value := shedding_order[i]
		shedding_order[i] = shedding_order[j]
		shedding_order[j] = value
	shedding_order.resize(mini(shedding_order.size(), int(DIFFICULTIES[difficulty].leaves) + (week - 1)))


func temperature() -> int:
	return 22 - 2 * (mini(week, MAIN_WEEKS) - 1) - (2 if is_boss() else 0)


func is_boss() -> bool:
	return week == BOSS_STAGE


func stage_title() -> String:
	return "FINAL ENCOUNTER" if is_boss() else "WEEK %d / %d" % [week, MAIN_WEEKS]


func boss_phase() -> String:
	if not is_boss(): return ""
	var t := fmod(week_time, 7.5)
	return "warning" if t < 1.5 else ("blast" if t < 4.0 else "rest")


func capture_slot(from: Vector2, to: Vector2) -> int:
	var best := -1
	var nearest := CAPTURE_RADIUS * CAPTURE_RADIUS
	for i in range(slots.size()):
		if slots[i].leaf_id >= 0: continue
		var point := Geometry2D.get_closest_point_to_segment(slots[i].position, from, to)
		var distance := point.distance_squared_to(slots[i].position)
		if distance < nearest:
			nearest = distance
			best = i
	return best


func pile_at(at_x: float) -> int:
	return piles[clampi(int(at_x / 30.0), 0, 11)]


func nozzle() -> Vector2:
	return Vector2(x, GROUND) + NOZZLE_OFFSET


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
	week_time += dt
	spawn_timer -= dt
	if spawn_timer <= 0.0 and spawned < week_leaf_count() and leaves.size() < MAX_ACTIVE:
		spawn_leaf()
		spawn_timer += (0.38 if boss_phase() == "blast" else maxf(0.65, 1.30 - week * 0.045)) * DIFFICULTIES[difficulty].cadence
	var origin := nozzle()
	for leaf in leaves:
		if leaf.state != "air":
			continue
		leaf.age += dt
		var p: Vector2 = leaf.position
		var previous := p
		var v: Vector2 = leaf.velocity
		var height := origin.y - p.y
		var center_x := origin.x + direction * height * 0.15
		var in_gust: bool = blowing and height > -8.0 and height < 335.0 and absf(p.x - center_x) < s.width * (0.7 + height / 340.0)
		var wind := sin(week_time * 0.9 + week) * (5.0 + week * 1.6) * float(DIFFICULTIES[difficulty].wind)
		# Smooth, seeded aerodynamic variation: broad drifting arcs, never frame noise.
		var flutter: float = leaf.age * leaf.get("flutter_rate", 2.8) + leaf.get("flutter_phase", float(leaf.id))
		var flutter_x: float = sin(flutter) * leaf.get("flutter_strength", 26.0)
		v.x += (wind + flutter_x - v.x) * 1.8 * dt
		var drag_coefficient: float = leaf.get("drag", 0.65) * (0.75 + 0.25 * cos(flutter * 2))
		v.y += (GRAVITY * float(DIFFICULTIES[difficulty].fall) - v.y * drag_coefficient + sin(flutter * 2) * 8.0) * dt
		if boss_phase() == "blast": v.y += 32.0 * dt
		if in_gust:
			leaf.lifted = true
			v.y -= s.force * dt
			# Directional airflow with mild flutter, rather than a corkscrew vortex.
			v.x += ((center_x - p.x) * 0.55 + sin(flutter) * 12.0) * dt
		v.y = clampf(v.y, -158.0, (45.0 + week * 1.5) * float(DIFFICULTIES[difficulty].fall))
		v.x = clampf(v.x, -85.0, 85.0)
		p += v * dt
		if p.x < 24.0 or p.x > 336.0:
			p.x = clampf(p.x, 24.0, 336.0)
			v.x = -v.x * 0.6
		leaf.position = p
		leaf.velocity = v
		leaf.angle = leaf.get("rest_angle", 0.0) + sin(flutter) * 0.65 + leaf.age * leaf.get("spin", 0.2)
		leaf.roll = 0.62 + 0.38 * absf(cos(flutter * 0.7))
		var target := capture_slot(previous, p) if leaf.lifted and v.y < 0.0 else -1
		if target >= 0:
			resolve_leaf(leaf, true, target)
		elif p.y >= GROUND - minf(14.0, pile_at(p.x) * 2.0):
			resolve_leaf(leaf, false)
		elif p.y < 75.0:
			# Missing a real gap never scores. Let the leaf fall back into reach.
			leaf.position.y = 75.0
			leaf.velocity.y = maxf(8.0, -leaf.velocity.y * 0.25)
		if status == "lost":
			break
	leaves = leaves.filter(func(leaf: Dictionary) -> bool: return leaf.state == "air")
	if status == "playing" and spawned >= week_leaf_count() and leaves.is_empty():
		score += 500 + 50 * (capacity() - missed)
		blowing = false
		if is_boss():
			score += 5000
			status = "won"
		else:
			points += 1
			earned_points += 1
			status = "workshop"


func spawn_leaf() -> bool:
	if spawned >= shedding_order.size() or leaves.size() >= MAX_ACTIVE: return false
	var id := shedding_order[spawned]
	var slot_index := -1
	for i in range(slots.size()):
		if slots[i].leaf_id == id:
			slot_index = i
			break
	if slot_index < 0: return false
	var slot: Dictionary = slots[slot_index]
	slot.leaf_id = -1
	leaves.append({
		"id": id, "position": slot.position + Vector2(0, 9), "home_slot": slot_index,
		"velocity": Vector2(rng.randf_range(-10, 10), 8.0),
		"state": "air", "lifted": false, "age": 0.0,
		"angle": slot.angle, "rest_angle": slot.angle, "colour": leaf_colour(id),
		"flutter_phase": rng.randf_range(0, TAU), "flutter_rate": rng.randf_range(2.1, 3.8),
		"flutter_strength": rng.randf_range(23, 37), "drag": rng.randf_range(0.48, 0.85),
		"spin": rng.randf_range(-0.35, 0.35), "roll": 1.0,
	})
	spawned += 1
	return true


func resolve_leaf(leaf: Dictionary, saved: bool, slot_index: int = -1) -> void:
	if leaf.state != "air":
		return
	if saved:
		if slot_index < 0 or slot_index >= slots.size() or slots[slot_index].leaf_id >= 0: return
		if leaf.id < 0 or leaf.id >= slots.size(): return
		for slot in slots:
			if slot.leaf_id == leaf.id: return
		slots[slot_index].leaf_id = leaf.id
		slots[slot_index].attached_at = week_time
		leaf.position = slots[slot_index].position
	leaf.state = "rescued" if saved else "grounded"
	if saved:
		combo += 1
		rescued += 1
		week_rescued += 1
		var multiplier := 1 if combo < 5 else (2 if combo < 10 else (3 if combo < 15 else 4))
		score += 100 * multiplier
	else:
		missed += 1
		week_missed += 1
		combo = 0
		var segment := clampi(int(leaf.position.x / 30.0), 0, 11)
		piles[segment] += 1
		if missed >= capacity():
			status = "lost"
			blowing = false
	events.append({"position": leaf.position, "saved": saved})


func buy(branch: int) -> bool:
	if status != "workshop" or branch < 0 or branch > 2 or tiers[branch] >= 2:
		return false
	var cost: int = 1 if tiers[branch] == 0 else 3
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


func next_week() -> bool:
	if status != "workshop":
		return false
	week += 1
	charge = 1.0
	energy_locked = false
	idle_charge_time = 0.0
	spawned = 0
	week_rescued = 0
	week_missed = 0
	week_time = 0.0
	spawn_timer = 0.5
	piles.fill(0)
	leaves.clear()
	prepare_shedding()
	status = "playing"
	return true
