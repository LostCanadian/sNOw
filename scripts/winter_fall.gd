extends RefCounted
## A frozen-score ending: the actual remaining identities fall, then snow covers them.
const Loop = preload("res://scripts/loop.gd")
var records: Array[Dictionary] = []
var phase := "idle"
var time := 0.0
var cover_time := 0.0
var attached := 0
var airborne := 0
var grounded := 0

func begin(game) -> void:
	records.clear()
	phase = "falling"
	time = 0
	cover_time = 0
	attached = 0
	airborne = 0
	grounded = 0
	for index in range(game.slots.size()):
		var slot: Dictionary = game.slots[index]
		if slot.leaf_id < 0: continue
		add_leaf(slot.leaf_id, slot.position, Vector2.ZERO, slot.angle, game.leaf_colour(slot.leaf_id), 1, index)
	for i in range(game.ground_leaves.size()):
		var leaf: Dictionary = game.ground_leaves[i]
		add_leaf(leaf.id, leaf.position, Vector2.ZERO, leaf.angle, leaf.colour, 3, 10000 + i, leaf.get("roll",1.0))
	for i in range(game.leaves.size()):
		var leaf: Dictionary = game.leaves[i]
		if leaf.state == "air": add_leaf(leaf.id, leaf.position, leaf.velocity, leaf.angle, leaf.colour, 2, 20000 + i, leaf.get("roll",1.0))

func add_leaf(id: int, position: Vector2, velocity: Vector2, angle: float, colour: Color, state: int, order: int, roll := 1.0) -> void:
	var seed := fposmod(id * 0.754877666, 1.0)
	records.append({"id":id, "position":position, "velocity":velocity, "angle":angle, "colour":colour,
		"state":state, "release_at":0.45 + seed * 1.2, "flutter":seed * TAU, "roll":roll, "order":order,
		"render_dirty":true})
	if state == 1: attached += 1
	elif state == 2: airborne += 1
	else: grounded += 1

func cover() -> float:
	return smoothstep(0, 2.2, cover_time)

func finished() -> bool:
	return phase == "done"

func step(dt: float) -> void:
	if phase in ["idle", "done"]: return
	var delta := minf(dt, 0.05)
	time += delta
	if phase == "snow":
		cover_time += delta
		if cover_time >= 2.2: phase = "done"
		return
	var layers := {}
	for leaf in records:
		if leaf.state == 1 and time >= leaf.release_at:
			leaf.state = 2
			leaf.velocity = Vector2(sin(leaf.flutter) * 9, 3)
			attached -= 1
			airborne += 1
		if leaf.state == 2:
			var velocity: Vector2 = leaf.velocity
			velocity.x = lerpf(velocity.x, sin(time * 2.4 + leaf.flutter) * 27 - 9, delta * 2.0)
			velocity.y = minf(190, velocity.y + 105 * delta)
			leaf.position += velocity * delta
			leaf.position.x = clampf(leaf.position.x, 5, 355)
			if leaf.position.y < 75:
				leaf.position.y = 75
				velocity.y = maxf(5, velocity.y)
			leaf.velocity = velocity
			leaf.angle += (sin(time * 3 + leaf.flutter) * 1.1 + 0.4) * delta
			leaf.roll = move_toward(leaf.roll,0.72 + 0.28 * absf(cos(time * 2 + leaf.flutter)),delta * 0.8)
			leaf.render_dirty = true
			if leaf.position.y >= Loop.GROUND - 12:
				leaf.state = 3
				leaf.velocity = Vector2.ZERO
				airborne -= 1
				grounded += 1
		if leaf.state == 3:
			var cell := clampi(int(leaf.position.x / 30), 0, 11)
			var depth: int = layers.get(cell, 0)
			layers[cell] = depth + 1
			var floor_y := Loop.GROUND - 2 - minf(10, depth * 0.2)
			if leaf.position.y != floor_y:
				leaf.position.y = floor_y
				leaf.render_dirty = true
	if attached == 0 and airborne == 0: phase = "snow"

func finish_preview() -> void:
	for leaf in records:
		leaf.state = 3
		leaf.position.y = Loop.GROUND - 2 - fposmod(leaf.id * 0.618034, 1.0) * 10
		leaf.render_dirty = true
	attached = 0
	airborne = 0
	grounded = records.size()
	phase = "done"
	cover_time = 2.2
