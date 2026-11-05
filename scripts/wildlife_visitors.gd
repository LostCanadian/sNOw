extends RefCounted
## One resident per lane. Replacements wait until outgoing animals are offscreen.
const Motion = preload("res://scripts/wildlife_motion.gd")
const DWELL := {"squirrel": 20.0, "owl": 25.0, "rabbit": 26.0, "wolf": 28.0, "bat": 20.0}
var lanes := {}
var squirrel_visits := 0
var cooldown := {"tree": 0.0, "ground": 0.0, "air": 0.0}

func reset() -> void:
	lanes.clear()
	squirrel_visits = 0
	cooldown = {"tree": 0.0, "ground": 0.0, "air": 0.0}

func wants(profile: Dictionary) -> Dictionary:
	var night: bool = profile.night_amount > 0.55
	var shelter: bool = profile.storm > 0.65
	return {"tree": "" if shelter else ("owl" if night else "squirrel"),
		"ground": "" if shelter else ("wolf" if night and profile.rare else "rabbit"),
		"air": "bat" if night and profile.rare and not shelter else ""}

func advance(dt: float, profile: Dictionary, motion, clock: float) -> void:
	var desired := wants(profile)
	for lane in ["tree", "ground", "air"]:
		cooldown[lane] = maxf(0, cooldown[lane] - dt)
		var target: String = desired[lane]
		# The rabbit must have left before either full-moon visitor enters.
		if lane == "air" and (not lanes.has("ground") or lanes.ground.kind != "wolf" or lanes.ground.phase == "exit"): target = ""
		if not lanes.has(lane):
			if target != "" and cooldown[lane] <= 0:
				lanes[lane] = {"kind": target, "phase": "enter", "age": 0.0, "route_time": 0.0,
					"exit_from": Vector2.ZERO, "exit_to": Vector2.ZERO, "duration": 0.0, "climbs": true}
				if target == "squirrel":
					lanes[lane].climbs = motion.squirrel_climbs(squirrel_visits)
					squirrel_visits += 1
			continue
		var animal: Dictionary = lanes[lane]
		if animal.phase != "exit" and animal.kind != target:
			leave(animal, motion, clock)
		animal.age += dt
		if animal.phase == "enter":
			animal.route_time = minf(animal.age, enter_duration(animal.kind, animal.climbs))
			if animal.age >= enter_duration(animal.kind, animal.climbs): animal.phase = "stay"; animal.age = 0.0
		elif animal.phase == "stay" and animal.age >= DWELL[animal.kind]:
			leave(animal, motion, clock)
		elif animal.phase == "exit" and animal.age >= animal.duration:
			lanes.erase(lane)
			cooldown[lane] = 3.0 if animal.kind == target else 0.0

func leave(animal: Dictionary, motion, clock: float) -> void:
	var current: Dictionary = pose(animal, motion, clock, 1.0)[0]
	animal.exit_from = current.position
	animal.phase = "exit"; animal.age = 0.0
	if animal.kind == "squirrel" and animal.climbs:
		animal.duration = maxf(0.01, animal.route_time)
	else:
		var flying: bool = animal.kind in ["owl", "bat"]
		var side := -65.0 if current.position.x < 180 else 425.0
		animal.exit_to = Vector2(side, 60 if animal.kind == "owl" else (90 if flying else 443))
		animal.duration = 3.0 if flying else maxf(0.1, absf(side-current.position.x)/(45.0 if animal.kind == "wolf" else 38.0))

static func enter_duration(kind: String, climbs := true) -> float:
	if kind == "squirrel": return 10.9 if climbs else 4.0
	return 5.0 if kind == "rabbit" else 3.0

static func travel_pose(kind: String, frame: int, position: Vector2, height: float, action: String) -> Dictionary:
	return {"kind": kind, "sheet": "travel", "frame": frame, "position": position,
		"height": height, "direction": 1, "alpha": 1.0, "plane": "tree", "action": action}

func pose(animal: Dictionary, motion, clock: float, coat: float) -> Array[Dictionary]:
	var kind: String = animal.kind
	var exiting: bool = animal.phase == "exit"
	var entering: bool = animal.phase == "enter"
	var age: float = animal.age
	if kind == "squirrel":
		if not animal.climbs:
			var ground: Dictionary = motion.squirrel_ground(animal.route_time if entering else 4.0+age,false)
			if exiting:
				ground.position = animal.exit_from.lerp(animal.exit_to,clampf(age/animal.duration,0,1))
				ground.direction = 1 if animal.exit_to.x >= animal.exit_from.x else -1
				ground.frame = int(clock*9)%4;ground.action = "leave"
			return [ground]
		var t: float = maxf(0, animal.route_time-age) if exiting else (animal.route_time if entering else 11.0+age)
		return [motion.squirrel_depart(t,clock) if exiting else motion.squirrel_arrival(t)]
	if kind == "owl":
		if not entering and not exiting: return [motion.owl(clock, false)]
		var t := clampf(age/3.0, 0, 1)
		var origin: Vector2 = animal.exit_from if exiting else Vector2(-65, 110)
		var target: Vector2 = animal.exit_to if exiting else motion.owl_perch
		var position := origin.bezier_interpolate(origin+Vector2(75,-25), target+Vector2(-65,-35), target, smoothstep(0,1,t))
		var frame := int(clock*9)%4
		var action := "fly_out" if exiting else "fly_in"
		if entering and t > 0.75: frame = 4+mini(3,int((t-0.75)*16)); action = "land"
		var p := travel_pose(kind, frame, position, 25.0, action)
		if exiting and target.x < origin.x: p.direction = -1
		return [p]
	var poses: Array[Dictionary] = []
	if kind == "rabbit": poses = motion.rabbit(0 if entering or exiting else age, coat, false)
	elif kind == "wolf": poses = [motion.wolf(0 if entering or exiting else age, false)]
	else: poses = [motion.bat(0 if entering or exiting else age, false)]
	if not entering and not exiting: return poses
	var target: Vector2 = animal.exit_to if exiting else poses[0].position
	var origin: Vector2 = animal.exit_from if exiting else Vector2(425 if kind == "bat" else -65, target.y)
	var duration: float = animal.duration if exiting else enter_duration(kind)
	var t := clampf(age/duration, 0, 1)
	for p in poses:
		p.position = origin.lerp(target, t)
		p.direction = 1 if target.x >= origin.x else -1
		p.action = "leave" if exiting else "arrive"
		if kind == "rabbit":
			p.frame = int(p.coat)*8+int(clock*8)%4
			p.position.y -= absf(sin(clock*PI*3))*3.2*sin(t*PI)
		elif kind == "wolf": p.frame = int(clock*8)%6
		else: p.frame = 8+int(clock*10)%8
	return poses

func poses(motion, clock: float, coat: float, soft := false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for animal in lanes.values():
		var frames:=pose(animal,motion,clock,coat)
		if soft:
			for frame in frames:
				if frame.sheet=="travel":frame.frame=1 if frame.kind=="owl" else (8 if frame.action=="descend" else 12)
				elif frame.kind=="owl":frame.frame=2
				elif frame.kind=="squirrel":frame.frame=12 if animal.phase=="stay" else frame.frame
				elif frame.kind=="rabbit":frame.frame=int(frame.coat)*8+4
				elif frame.kind=="wolf":frame.frame=6
				else:frame.frame=8
		result.append_array(frames)
	return result
