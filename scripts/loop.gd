extends RefCounted
## Presentation-independent fixed-step arcade simulation. All coordinates are logical 360 x 640.

const BlowerPose = preload("res://scripts/blower_pose.gd")
const NOZZLE_OFFSET := BlowerPose.REST_NOZZLE
const Upgrades = preload("res://scripts/upgrades.gd")
const RULES := 10
const NorthWind = preload("res://scripts/north_wind.gd")
const CROWN_CEILINGS := [2160,2080,2000,1900,1800,1680,1560,1440,1320,1200,1080,960,960]
const SURGE_DURATION := 1.15
const RECOVERY_FLOOR := 720
const GRAVITY := 48.0
const GROUND := 502.0
const Canopy = preload("res://scripts/canopy.gd")
const CAPTURE_RADIUS := 15.0
const MAX_ACTIVE := 1500
const SHED_BATCH := 10
const BASE_SPEED := 50.0
const CAPACITY := 105 # Default weekly allowance. Cumulative loss remains in missed.
const DIFFICULTIES := [
	{"name": "Breezy", "capacity": 135, "leaves": 180, "increment": 15, "cadence": 1.15, "wind": 0.70, "fall": 0.88},
	{"name": "Blustery", "capacity": 105, "leaves": 225, "increment": 15, "cadence": 1.0, "wind": 1.0, "fall": 1.0},
	{"name": "Gale", "capacity": 75, "leaves": 270, "increment": 23, "cadence": 0.85, "wind": 1.30, "fall": 1.12},
]
const MAIN_WEEKS := 12
const BOSS_STAGE := MAIN_WEEKS + 1
const LEAF_RADIUS := Canopy.RADIUS
const ATTACH_DURATION := 0.34
const BRANCH_COOLDOWN := 5.0
const PileSurface=preload("res://scripts/leaf_piles.gd")
const KNEE_HEIGHT := 14.0
const PILE_HEIGHT := 10.0
const COLOUR_WEIGHTS := [0.15, 1.0, 3.0, 7.0] # Green, yellow, orange, red.
const SEASONS := [
	[0.84,0.16,0.00,0.00], [0.70,0.25,0.05,0.00], [0.48,0.32,0.17,0.03],
	[0.30,0.30,0.29,0.11], [0.20,0.26,0.32,0.22], [0.12,0.20,0.32,0.36],
	[0.08,0.16,0.29,0.47], [0.05,0.14,0.28,0.53], [0.04,0.13,0.27,0.56],
	[0.03,0.12,0.27,0.58], [0.03,0.11,0.26,0.60], [0.03,0.10,0.25,0.62],
	[0.02,0.09,0.23,0.66],
]
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
var low_power := false
var direction := 0.0
var facing := 1.0
var aim := 0.0
var score := 0
var week_start_score := 0 # -1 only for older completed checkpoints without this detail.
var combo := 0
var rescued := 0
var missed := 0
var regrown := 0
var week_regrown := 0
var seasonal_fallen := 0
var wind_cycle := -1
var wind_lane := 220.0
var wind_released := 0
var wind_next_packet:=0.0
var spawned := 0
var week_rescued := 0
var week_missed := 0
var week_time := 0.0
var spawn_timer := 0.5
var status := "playing"
var leaves: Array[Dictionary] = []
var ground_leaves: Array[Dictionary] = []
var pile_surface=PileSurface.new()
var surge_charge := 1.0
var surge_left := 0.0
var surge_held := false
var slots: Array[Dictionary] = []
var capture_grid := {}
var attached_lookup := PackedInt32Array()
var canopy_revision := 0
var attachment_motions := {}
var shedding_order: Array[int] = []
var piles: Array[int] = []
var points := 0
var earned_points := 0
var tiers := [0, 0, 0]
var owned: Array[int] = []
var events: Array[Dictionary] = []


func _init(seed_value: int = 641023, difficulty_value := 1) -> void:
	difficulty = clampi(difficulty_value, 0, 2)
	run_id = (str(Time.get_unix_time_from_system()) + ":" + str(Time.get_ticks_usec()) + ":" + str(randi())).sha256_text().substr(0, 32)
	rng.seed = seed_value
	piles.resize(12)
	piles.fill(0)
	slots = Canopy.slot_layout()
	index_canopy()
	prepare_shedding()


func stats(build: Array = []) -> Dictionary:
	var nodes: Array = owned if build.is_empty() else Upgrades.legacy_nodes(build)
	var effects := Upgrades.effects(nodes)
	var ranks := Upgrades.counts(nodes)
	var load_factor: float = 1.0 + (0.025 * ranks[1] + 0.005 * ranks[2]) * (1.0 - effects.weight_relief)
	return {
		"speed": BASE_SPEED * (1.0 + effects.speed) / load_factor,
		"force": 410.0 * (1.0 + effects.force),
		"width": 48.0 + effects.width,
		"reach": 335.0 + effects.reach,
		"steering": 1.0 + effects.steering,
		"burst": 6.0 * (1.0 + effects.burst) / (1.0 + 0.035 * ranks[1]),
		"recharge": 3.0 * (1.0 - effects.recharge),
		"pile_penalty": maxf(0.04, 0.32 - effects.grip),
		"surge_cooldown": 36.0 - effects.cooldown,
		"surge_radius": 88.0 + effects.radius,
		"surge_force": 1.0 + effects.surge_force,
	}


func capacity() -> int:
	return DIFFICULTIES[difficulty].capacity


func pressure() -> float:
	return clampf(float(week_missed) / capacity(), 0.0, 1.0)


func week_leaf_count() -> int:
	return shedding_order.size()


func attached_count() -> int:
	var count := 0
	for slot in slots:
		if slot.leaf_id >= 0: count += 1
	return count


func leaf_category(id: int, season_week := 0) -> int:
	var profile: Array = SEASONS[clampi((week if season_week <= 0 else season_week) - 1, 0, SEASONS.size() - 1)]
	var value := fposmod(id * 0.61803398875 + 0.137, 1.0)
	var boundary := 0.0
	for category in range(4):
		boundary += profile[category]
		if value < boundary: return category
	return 3


func leaf_colour(id: int, season_week: int = 0) -> Color:
	var category := leaf_category(id, season_week)
	if category == 0: return Color("8fa65c") if id % 2 == 0 else Color("bbc16b")
	return LEAF_COLOURS[category - 1]


func seasonal_risk() -> float:
	var profile: Array = SEASONS[clampi(week - 1, 0, SEASONS.size() - 1)]
	var risk := 0.0
	var peak := 0.0
	var first := 0.0
	for category in range(4):
		risk += profile[category] * COLOUR_WEIGHTS[category]
		peak += SEASONS[11][category] * COLOUR_WEIGHTS[category]
		first += SEASONS[0][category] * COLOUR_WEIGHTS[category]
	return clampf((risk - first) / (peak - first), 0, 1)


func shed_batch_size() -> int:
	return 4 + roundi(6 * sqrt(seasonal_risk()))


func shedding_interval() -> float:
	return maxf(0.65, 1.30 - week * 0.045) * DIFFICULTIES[difficulty].cadence * lerpf(1.15, 1.0, seasonal_risk())


func prepare_shedding() -> void:
	# A weighted permutation without replacement: each scheduled identity is real.
	var candidates: Array = []
	var remaining := {}
	var coverers := Canopy.foreground_coverers(slots)
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		slot.attached_at = -10.0
		slot.capture_after = 0.0
		if slot.leaf_id >= 0:
			var weight: float = COLOUR_WEIGHTS[leaf_category(slot.leaf_id)]
			candidates.append([index, -log(maxf(0.000001, rng.randf())) / weight])
			remaining[index] = true
	candidates.sort_custom(func(a, b): return a[1] < b[1])
	shedding_order.clear()
	var count := mini(candidates.size(), int(DIFFICULTIES[difficulty].leaves) + int(DIFFICULTIES[difficulty].increment) * (week - 1) + (90 if is_boss() else 0))
	for i in range(count):
		# Peel visible leaves off each spray before releasing the leaves behind them.
		for j in range(candidates.size()):
			var index: int = candidates[j][0]
			var blocked := false
			for front in coverers[index]:
				if remaining.has(front):
					blocked = true
					break
			if blocked: continue
			shedding_order.append(int(slots[index].leaf_id))
			remaining.erase(index)
			candidates.remove_at(j)
			break


func temperature() -> int:
	return 22 - 2 * (mini(week, MAIN_WEEKS) - 1) - (2 if is_boss() else 0)


func is_boss() -> bool:
	return week == BOSS_STAGE


func stage_title() -> String:
	return "FINAL ENCOUNTER" if is_boss() else "WEEK %d / %d" % [week, MAIN_WEEKS]


func boss_phase() -> String:
	return NorthWind.phase(week_time) if is_boss() else ""


func step_north_wind(previous_time: float) -> void:
	if spawned >= week_leaf_count() or leaves.size() >= MAX_ACTIVE: return
	var cycle := NorthWind.cycle(week_time)
	if cycle != wind_cycle:
		wind_cycle = cycle
		wind_released = 0
		wind_next_packet=week_time
		wind_lane = choose_wind_lane()
	if boss_phase() != "blast" or week_time<wind_next_packet: return
	var quota: int = [48,56,64][difficulty]
	if wind_released >= quota: return
	var path := NorthWind.segment(previous_time, week_time, wind_lane)
	var candidates: Array[int] = []
	for pending in range(spawned, shedding_order.size()):
		var id := shedding_order[pending]
		var index := find_attached_leaf(id)
		if index < 0: continue
		var point: Vector2 = slots[index].position
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,path[0],path[1])) <= NorthWind.RADIUS:
			candidates.append(id)
	candidates.sort_custom(func(a,b):return Canopy.depth(a)>Canopy.depth(b))
	for id in candidates.slice(0,mini(4,quota-wind_released)):
		var pending := shedding_order.find(id,spawned)
		shedding_order[pending] = shedding_order[spawned]
		shedding_order[spawned] = id
		if not spawn_leaf(): break
		var radial:Vector2=leaves[-1].position-NorthWind.center(week_time,wind_lane)
		leaves[-1].velocity+=NorthWind.tangent(week_time,wind_lane)*135+radial.orthogonal().normalized()*NorthWind.direction(week_time)*90
		leaves[-1].spin+=NorthWind.direction(week_time)*0.7
		wind_released += 1
	if not candidates.is_empty():wind_next_packet=week_time+0.05


func choose_wind_lane() -> float:
	# Score candidate lanes against the whole curved sweep, once per pass. A bit
	# mask counts each pending leaf once even if several samples pass nearby.
	const LANES:=16
	const FIRST:=110.0
	const STEP:=15.0
	var counts:=PackedInt32Array();counts.resize(LANES);counts.fill(0)
	var path:=PackedVector2Array()
	for sample in range(25):path.append(NorthWind.point(sample/24.0,0,NorthWind.direction(week_time)))
	for pending in range(spawned,shedding_order.size()):
		var index:=find_attached_leaf(shedding_order[pending])
		if index<0:continue
		var point:Vector2=slots[index].position
		var lanes:=0
		for p in path:
			var dx:=point.x-p.x
			if absf(dx)>NorthWind.RADIUS:continue
			var reach:=sqrt(NorthWind.RADIUS*NorthWind.RADIUS-dx*dx)
			var low:=maxi(0,ceili((point.y-p.y-reach-FIRST)/STEP))
			var high:=mini(LANES-1,floori((point.y-p.y+reach-FIRST)/STEP))
			for lane in range(low,high+1):lanes|=1<<lane
		for lane in range(LANES):
			if lanes & (1<<lane):counts[lane]+=1
	var best:=(maxi(0,wind_cycle)*5)%LANES
	# Rotate equal-density choices without consuming the gameplay RNG.
	for lane in range(LANES):
		var candidate:=(lane+maxi(0,wind_cycle)*5)%LANES
		if counts[candidate]>counts[best]:best=candidate
	return FIRST+best*STEP


func crown_ceiling() -> int:
	return CROWN_CEILINGS[clampi(week-1,0,CROWN_CEILINGS.size()-1)]


func retire_seasonal_foliage() -> int:
	var count := maxi(0,attached_count()-crown_ceiling())
	if count == 0: return 0
	# Whole twig clusters thin out, leaving readable bare patches rather than
	# removing a uniform dusting from a still-solid-looking crown.
	var occupied: Array[int] = []
	for index in range(slots.size()):
		if slots[index].leaf_id >= 0: occupied.append(index)
	occupied.sort_custom(func(a,b):
		var ca := Vector2i(slots[a].stem/28.0)
		var cb := Vector2i(slots[b].stem/28.0)
		var pa := fposmod(ca.x*0.438579+ca.y*0.754877,1.0)
		var pb := fposmod(cb.x*0.438579+cb.y*0.754877,1.0)
		return a<b if is_equal_approx(pa,pb) else pa<pb)
	for index in occupied.slice(0,count):slots[index].leaf_id=-1
	seasonal_fallen += count
	index_canopy()
	return count


func capture_slot(from: Vector2, to: Vector2) -> int:
	var best := -1
	var nearest := CAPTURE_RADIUS * CAPTURE_RADIUS
	var start := Vector2i((from.min(to) - Vector2.ONE * CAPTURE_RADIUS) / 24.0)
	var end := Vector2i((from.max(to) + Vector2.ONE * CAPTURE_RADIUS) / 24.0)
	for cx in range(start.x, end.x + 1):
		for cy in range(start.y, end.y + 1):
			for i in capture_grid.get(Vector2i(cx, cy), []):
				if slots[i].leaf_id >= 0 or week_time < float(slots[i].get("capture_after",0)): continue
				var point := Geometry2D.get_closest_point_to_segment(slots[i].position, from, to)
				var distance := point.distance_squared_to(slots[i].position)
				if distance < nearest or (distance == nearest and best >= 0 and i < best):
					nearest = distance
					best = i
	return best


func index_canopy() -> void:
	canopy_revision += 1
	capture_grid.clear()
	attached_lookup.resize(Canopy.SLOT_COUNT)
	attached_lookup.fill(-1)
	for i in range(slots.size()):
		var cell := Vector2i(slots[i].position / 24.0)
		if not capture_grid.has(cell): capture_grid[cell] = []
		capture_grid[cell].append(i)
		if slots[i].leaf_id >= 0: attached_lookup[slots[i].leaf_id] = i


func find_attached_leaf(id: int) -> int:
	var index := attached_lookup[id]
	if index >= 0 and slots[index].leaf_id == id: return index
	# Restores and editor/test fixtures may replace occupancy directly.
	if index >= 0:
		attached_lookup[id] = -1
		for i in range(slots.size()):
			if slots[i].leaf_id == id:
				attached_lookup[id] = i
				return i
	return -1


func pile_at(at_x: float) -> int:
	return piles[clampi(int(at_x / 30.0), 0, 11)]


func surge_progress() -> float:
	return 1.0 - surge_left / SURGE_DURATION if surge_left > 0 else 0.0


func surge_spin() -> float:
	var t := surge_progress()
	return facing * (TAU * 2 * (1 - pow(1 - t, 2)) + sin(t * TAU * 3) * 0.18 * sin(t * PI))


func surge_offset() -> Vector2:
	var t := surge_progress()
	return Vector2(sin(t * TAU * 1.7) * 10, -64) * sin(t * PI)


func surge_transform() -> Transform2D:
	var rotation := Transform2D(surge_spin(), Vector2.ZERO)
	var pivot := Vector2(0, -36)
	rotation.origin = pivot + surge_offset() - rotation * pivot
	return rotation


func nozzle() -> Vector2:
	return Vector2(x, GROUND) + surge_transform() * BlowerPose.nozzle_offset(facing, aim)


func air_axis() -> Vector2:
	return BlowerPose.axis(aim + surge_spin())


func step(dt: float, move_axis: float, wants_blow: bool, wants_surge := false) -> void:
	events.clear()
	if status != "playing":
		blowing = false
		low_power=false
		return
	advance_attachments(dt)
	var s := stats()
	surge_left = maxf(0, surge_left - dt)
	surge_charge = minf(1.0, surge_charge + dt / float(s.surge_cooldown))
	if wants_surge and not surge_held: activate_surge()
	surge_held = wants_surge
	direction = clampf(move_axis, -1.0, 1.0)
	var drag: float = minf(float(pile_at(x)) / 50.0, 1.0) * s.pile_penalty
	var previous_x := x
	x = clampf(x + direction * s.speed * (1.0 - drag) * (0.65 if surge_left > 0 else 1.0) * dt, 29.0, 331.0)
	if absf(direction) > 0.01: facing = signf(direction)
	var target_aim := facing * BlowerPose.MOVING_TILT if absf(x - previous_x) > 0.001 else 0.0
	if surge_left > 0: target_aim = 0.0
	aim = move_toward(aim, target_aim, dt * BlowerPose.TURN_SPEED)
	if not wants_blow:
		energy_locked=false
		idle_charge_time+=dt
		if idle_charge_time>0.5:charge=minf(1.0,charge+dt/s.recharge)
	else:
		idle_charge_time=0
		if charge<=0:energy_locked=true
		if energy_locked:
			# A quiet holding draft keeps running while the battery recovers.
			charge=minf(1.0,charge+dt/s.recharge*0.55)
			if charge>=1.0:energy_locked=false
	blowing=wants_blow and surge_left<=0 and absf(aim)<=BlowerPose.MOVING_TILT+0.01
	low_power=blowing and energy_locked
	if blowing and not low_power:
		charge=maxf(0,charge-dt/s.burst)
		if charge<=0:
			energy_locked=true
			low_power=true
	step_ground(dt, x - previous_x)
	var previous_time := week_time
	week_time += dt
	# Ordinary shedding continues in the finale, sharing the same finite schedule.
	spawn_timer -= dt
	if spawn_timer<=0 and spawned<week_leaf_count() and leaves.size()<MAX_ACTIVE:
		for i in range(3 if is_boss() else shed_batch_size()):
			if not spawn_leaf():break
		spawn_timer+=shedding_interval()*(2.4 if is_boss() else 1.0)
	if is_boss():step_north_wind(previous_time)
	var origin := nozzle()
	var airflow := air_axis()
	var lateral := airflow.orthogonal()
	for leaf in leaves:
		if leaf.state != "air":
			continue
		leaf.age += dt
		var p: Vector2 = leaf.position
		var previous := p
		var v: Vector2 = leaf.velocity
		var offset := p - origin
		var height := offset.dot(airflow)
		var across := offset.dot(lateral)
		var in_gust: bool = blowing and height > -8.0 and height < (minf(s.reach,145.0) if low_power else s.reach) and absf(across) < s.width * (0.7 + height / 340.0)
		var wind := sin(week_time * 0.9 + week) * (5.0 + week * 1.6) * float(DIFFICULTIES[difficulty].wind)
		# Smooth, seeded aerodynamic variation: broad drifting arcs, never frame noise.
		var flutter: float = leaf.age * leaf.get("flutter_rate", 2.8) + leaf.get("flutter_phase", float(leaf.id))
		var flutter_x: float = sin(flutter) * leaf.get("flutter_strength", 26.0)
		v.x += (wind + flutter_x - v.x) * 1.8 * dt
		var drag_coefficient: float = leaf.get("drag", 0.65) * (0.75 + 0.25 * cos(flutter * 2))
		v.y += (GRAVITY * float(DIFFICULTIES[difficulty].fall) - v.y * drag_coefficient + sin(flutter * 2) * 8.0) * dt
		if is_boss(): v += NorthWind.force(p,week_time,wind_lane)*dt
		if in_gust:
			if not low_power:leaf.lifted=true
			var spread: float = s.width * (0.7 + height / 340.0)
			var normalized_across := clampf(across / spread, -1, 1)
			# Fan out from the nozzle: standing to one side now steers a leaf that way.
			# Each leaf carries independent, smooth turbulence rather than sharing lanes.
			var turbulence: float = sin(flutter * 1.31 + leaf.id * 2.399) * 23.0 + sin(flutter * 2.17) * 9.0
			var lift:float=(GRAVITY*float(DIFFICULTIES[difficulty].fall)+7.0)/maxf(0.7,-airflow.y) if low_power else float(s.force)*float(leaf.get("lift_response",1.0))
			var force:Vector2=airflow*lift+lateral*(normalized_across*155.0*float(s.steering)+turbulence)*(0.25 if low_power else 1.0)
			# At the borders a return breeze wins over outward-directed blower force.
			if force.x < 0: force.x *= smoothstep(-8, 48, p.x)
			if force.x > 0: force.x *= (1.0 - smoothstep(312, 368, p.x))
			v+=force*dt
			if low_power and v.y < -12.0:v.y=move_toward(v.y,-12.0,dt*180)
		if surge_left > 0:
			var center := Vector2(x, GROUND - 35) + surge_offset()
			var radial: Vector2 = p - center
			var reach: float = 175.0 + float(s.surge_radius) - 88.0
			if radial.length() < reach:
				var strength: float = 1.0 - radial.length() / reach
				var cone: float = 1.0 if height > -18 and height < 225 and absf(across) < 45 + maxf(0, height) * 0.48 else 0.0
				v += (airflow * float(s.force) * cone * 1.25 * float(s.surge_force) + radial.orthogonal().normalized() * facing * 95 * strength + Vector2(0, -110) * strength) * dt
				leaf.lifted = true
				leaf.surge_lift = 0.8
		v.x += BlowerPose.edge_force(p.x) * dt
		leaf.surge_lift = maxf(0, float(leaf.get("surge_lift", 0)) - dt)
		v.y = clampf(v.y, -238.0 if leaf.surge_lift > 0 else -158.0*float(leaf.get("lift_response",1.0)), (45.0 + week * 1.5) * float(DIFFICULTIES[difficulty].fall))
		v.x = clampf(v.x, -125.0, 125.0)
		p += v * dt
		# A short overshoot is allowed; the spring continuously draws leaves back in.
		if p.x < -22.0:
			p.x = -22.0
			v.x = maxf(24, absf(v.x) * 0.35)
		elif p.x > 382.0:
			p.x = 382.0
			v.x = -maxf(24, absf(v.x) * 0.35)
		leaf.position = p
		leaf.velocity = v
		var detach_blend := smoothstep(0, 0.8, leaf.age)
		leaf.angle = leaf.get("rest_angle", 0.0) + (sin(flutter) * 0.65 + leaf.age * leaf.get("spin", 0.2)) * detach_blend
		leaf.roll = lerpf(float(leaf.get("detach_roll", 1.0)), 0.62 + 0.38 * absf(cos(flutter * 0.7)), detach_blend)
		var target := capture_slot(previous, p) if leaf.lifted and v.y < 0.0 else -1
		if target >= 0:
			resolve_leaf(leaf, true, target)
		elif p.y >= pile_surface.surface(p.x, leaf.id):
			resolve_leaf(leaf, false)
		elif p.y < 75.0:
			# Missing a real gap never scores. Let the leaf fall back into reach.
			leaf.position.y = 75.0
			leaf.velocity.y = maxf(8.0, -leaf.velocity.y * 0.25)
		if status == "lost":
			break
	leaves = leaves.filter(func(leaf: Dictionary) -> bool: return leaf.state == "air")
	if status == "playing" and spawned >= week_leaf_count() and leaves.is_empty():
		score += 50 + 5 * (capacity() - week_missed)
		blowing = false
		low_power=false
		surge_left = 0
		if is_boss():
			score += 500
			status = "won"
		else:
			points += 2
			earned_points += 2
			status = "workshop"


static func leaf_lift_response(id:int) -> float:
	# Mix identity bits independently of the sequences used for colour and depth.
	# Thus the frontmost leaves in a falling clump do not all have the same mass.
	var bits:=id^0x9e3779b9
	bits=(((bits>>16)^bits)*0x45d9f3b)&0xffffffff
	bits=(((bits>>16)^bits)*0x45d9f3b)&0xffffffff
	bits=(bits>>16)^bits
	return 0.80+float(bits&0xffff)/65535.0*0.36


func spawn_leaf() -> bool:
	if spawned >= shedding_order.size() or leaves.size() >= MAX_ACTIVE: return false
	var id := shedding_order[spawned]
	var slot_index := find_attached_leaf(id)
	if slot_index < 0: return false
	var slot: Dictionary = slots[slot_index]
	var pose := attachment_pose(slot_index)
	attachment_motions.erase(slot_index)
	slot.leaf_id = -1
	slot.capture_after = week_time+BRANCH_COOLDOWN
	canopy_revision += 1
	attached_lookup[id] = -1
	leaves.append({
		"id": id, "position": pose.position, "home_slot": slot_index,
		"velocity": Vector2(rng.randf_range(-6, 6), 3.0),
		"state": "air", "lifted": false, "age": 0.0,
		"lift_response": leaf_lift_response(id),
		"angle": pose.angle, "rest_angle": pose.angle, "colour": leaf_colour(id), "category": leaf_category(id),
		"flutter_phase": rng.randf_range(0, TAU), "flutter_rate": rng.randf_range(2.1, 3.8),
		"flutter_strength": rng.randf_range(23, 37), "drag": rng.randf_range(0.48, 0.85),
		"spin": rng.randf_range(-0.35, 0.35), "roll": pose.roll, "detach_roll": pose.roll,
	})
	spawned += 1
	return true


func advance_attachments(dt: float) -> void:
	var finished := false
	for index in attachment_motions.keys():
		var motion: Dictionary = attachment_motions[index]
		motion.age += dt
		if motion.age >= ATTACH_DURATION or slots[index].leaf_id != motion.id:
			attachment_motions.erase(index)
			finished = true
	# Refresh the cached canopy once the final moving instance becomes stationary.
	if finished: canopy_revision += 1


func attachment_pose(index: int) -> Dictionary:
	var slot: Dictionary = slots[index]
	var pose := {"position": slot.position, "angle": slot.angle, "roll": 1.0}
	if not attachment_motions.has(index): return pose
	var motion: Dictionary = attachment_motions[index]
	if slot.leaf_id != motion.id: return pose
	var t := clampf(float(motion.age) / ATTACH_DURATION, 0, 1)
	var eased := smoothstep(0, 1, t)
	# Retain the incoming direction, then arrive with zero speed. A bounded
	# tangent prevents fast captures from looping past the branch.
	var start: Vector2 = motion.from
	var tangent: Vector2 = motion.velocity * (ATTACH_DURATION / 3.0)
	tangent = tangent.limit_length(start.distance_to(slot.position) * 0.85 + 2.0)
	pose.position = start.bezier_interpolate(start + tangent, slot.position, slot.position, t)
	pose.angle = lerp_angle(motion.angle, slot.angle, eased)
	pose.roll = lerpf(motion.roll, 1.0, eased)
	return pose


func resolve_leaf(leaf: Dictionary, saved: bool, slot_index: int = -1) -> void:
	if leaf.state != "air":
		return
	if saved:
		if slot_index < 0 or slot_index >= slots.size() or slots[slot_index].leaf_id >= 0: return
		if leaf.id < 0 or leaf.id >= slots.size(): return
		if find_attached_leaf(leaf.id) >= 0: return
		# Reserve the branch and award the rescue once, while the same rendered
		# identity eases from its actual capture pose onto the attachment.
		attachment_motions[slot_index] = {"id": leaf.id, "from": leaf.position,
			"velocity": leaf.velocity, "angle": leaf.angle, "roll": leaf.get("roll", 1.0), "age": 0.0}
		slots[slot_index].leaf_id = leaf.id
		canopy_revision += 1
		attached_lookup[leaf.id] = slot_index
		slots[slot_index].attached_at = week_time
		leaf.position = slots[slot_index].position
	leaf.state = "rescued" if saved else "grounded"
	if not saved:
		leaf.position.y = pile_surface.deposit(leaf.position.x, leaf.id)
		leaf.rest_y = leaf.position.y
		leaf.velocity = Vector2(leaf.velocity.x * 0.25, 0)
		leaf.scuff_cooldown = 0.0
		leaf.scuff_left = 0.0
		ground_leaves.append(leaf)
	if saved:
		combo += 1
		rescued += 1
		week_rescued += 1
		var multiplier := 1 if combo < 5 else (2 if combo < 10 else (3 if combo < 15 else 4))
		score += 10 * multiplier
	else:
		missed += 1
		week_missed += 1
		combo = 0
		rebuild_piles()
		if week_missed >= capacity():
			status = "lost"
			blowing = false
			low_power=false
			surge_left = 0
	events.append({"position": leaf.position, "saved": saved})


func can_upgrade() -> bool:
	return status=="workshop" or (status=="playing" and week_time==0)


func buy(branch: int, node := -1) -> bool:
	if not can_upgrade() or branch < 0 or branch > 2: return false
	if node < 0:
		for candidate in range(Upgrades.MAX_RANK):
			if Upgrades.available(owned, branch, candidate):
				node = candidate
				break
	if not Upgrades.available(owned, branch, node): return false
	var cost := Upgrades.cost(branch, node)
	if points < cost: return false
	points -= cost
	owned.append(branch * Upgrades.MAX_RANK + node)
	tiers = Upgrades.counts(owned)
	return true


func refund_build() -> void:
	if not can_upgrade():return
	owned.clear()
	tiers = [0,0,0]
	points = earned_points


func next_week() -> bool:
	if status != "workshop":
		return false
	week += 1
	week_start_score = score
	x = 180.0
	direction = 0
	facing = 1
	aim = 0
	blowing = false
	retire_seasonal_foliage()
	week_regrown = restore_playable_canopy()
	charge = 1.0
	energy_locked = false
	low_power=false
	idle_charge_time = 0.0
	spawned = 0
	week_rescued = 0
	week_missed = 0
	week_time = 0.0
	spawn_timer = 0.5
	piles.fill(0)
	leaves.clear()
	ground_leaves.clear()
	attachment_motions.clear()
	pile_surface.clear()
	surge_charge = 1.0
	surge_left = 0
	surge_held = false
	wind_cycle = -1
	wind_released = 0
	prepare_shedding()
	status = "playing"
	return true


func restore_playable_canopy() -> int:
	var count := maxi(0, RECOVERY_FLOOR - attached_count())
	if count == 0: return 0
	var present := {}
	for slot in slots:
		if slot.leaf_id >= 0: present[slot.leaf_id] = true
	var identities: Array[int] = []
	for id in range(Canopy.SLOT_COUNT):
		if not present.has(id): identities.append(id)
	var filled := 0
	for slot in slots:
		if slot.leaf_id >= 0: continue
		slot.leaf_id = identities[filled]
		slot.attached_at = -10.0
		filled += 1
		if filled >= count: break
	regrown += filled
	index_canopy()
	return filled


func surge_unlocked() -> bool:
	return owned.has(12)


func activate_surge() -> bool:
	if status != "playing" or not surge_unlocked() or surge_charge < 1.0 or surge_left > 0: return false
	var radius: float = stats().surge_radius
	var center := Vector2(x, GROUND - 35)
	var nearby := leaves.any(func(leaf): return leaf.state == "air" and leaf.position.distance_to(center) < 175 + stats().surge_radius - 88)
	var lifted: Array[Dictionary] = []
	for leaf in ground_leaves:
		if absf(leaf.position.x - x) > radius or leaves.size() >= MAX_ACTIVE: continue
		var delta: float = leaf.position.x - x
		leaf.state = "air"
		leaf.lifted = true
		leaf.velocity = Vector2(signf(delta) * 25 + facing * 15, -95.0 - int(leaf.id) % 5 * 4)
		leaf.rest_angle = leaf.angle
		leaf.detach_roll = leaf.get("roll", 1.0)
		leaf.age = 0.0
		leaf.surge_lift = 1.0
		if not leaves.has(leaf): leaves.append(leaf)
		lifted.append(leaf)
	if lifted.is_empty() and not nearby: return false
	ground_leaves = ground_leaves.filter(func(leaf): return leaf.state == "grounded")
	missed -= lifted.size()
	week_missed -= lifted.size()
	surge_charge = 0
	surge_left = SURGE_DURATION
	rebuild_piles()
	return true


func rebuild_piles() -> void:
	piles.fill(0)
	pile_surface.clear()
	for leaf in ground_leaves:
		leaf.rest_y=pile_surface.deposit(leaf.position.x,leaf.id)
		piles[clampi(int(leaf.position.x / 30.0), 0, 11)] += 1


func step_ground(dt: float, displacement: float) -> void:
	rebuild_piles()
	for leaf in ground_leaves:
		var p: Vector2 = leaf.position
		var v: Vector2 = leaf.velocity
		var floor_y: float=leaf.get("rest_y",p.y)
		leaf.scuff_cooldown = maxf(0, float(leaf.get("scuff_cooldown", 0)) - dt)
		var remaining := maxf(0, float(leaf.get("scuff_left", 0)) - dt)
		if absf(displacement) > 0.001 and absf(p.x - x) < 24 and remaining <= 0 and leaf.scuff_cooldown <= 0:
			leaf.scuff_duration = 0.65 + fposmod(leaf.id * 0.754877, 1.0) * 0.3
			remaining = leaf.scuff_duration
			leaf.scuff_direction = signf(displacement)
			leaf.scuff_cooldown = leaf.scuff_duration + 0.35
		leaf.scuff_left = remaining
		if remaining > 0:
			var t := 1.0 - remaining / float(leaf.scuff_duration)
			var phase: float = fposmod(leaf.id * 0.618034, 1.0) * TAU
			var envelope := sin(t * PI)
			v.x = float(leaf.scuff_direction) * 18 * (1 - t) + sin(t * TAU * 1.25 + phase) * 22 * envelope
			p.y = floor_y - 4.0 * envelope * (0.75 + 0.25 * sin(t * TAU + phase))
			leaf.angle += (v.x * 0.05 + sin(t * TAU + phase) * 3) * dt
			leaf.roll = 0.68 + 0.32 * absf(cos(t * TAU + phase))
		else:
			v.x *= exp(-5 * dt)
			p.y = move_toward(p.y, floor_y, dt * 55)
			leaf.angle += v.x * dt * 0.035
			leaf.roll = 1.0
		v.x += BlowerPose.edge_force(p.x) * dt * 0.35
		p.x = clampf(p.x + v.x * dt, 5, 355)
		leaf.position = p
		leaf.velocity = Vector2(v.x, 0)
	rebuild_piles()
