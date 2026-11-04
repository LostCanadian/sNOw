extends SceneTree

const Loop = preload("res://scripts/loop.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	var game = Loop.new()
	for i in range(60): game.step(1.0 / 60.0, 1.0, false)
	check(is_equal_approx(game.x, 230.0), "one second of movement uses logical units")
	for i in range(180): game.step(1.0 / 60.0, 1.0, false)
	check(game.x == 331.0, "movement remains inside the shared playfield")
	game = Loop.new()
	for i in range(370): game.step(1.0 / 60.0, 0.0, true)
	check(game.energy_locked and game.low_power and game.blowing, "holding past depletion enters a running low-power draft")
	for i in range(60): game.step(1.0 / 60.0, 0.0, true)
	check(game.charge > 0.15 and game.low_power and game.blowing, "held low-power draft recharges the battery")
	for i in range(240): game.step(1.0 / 60.0, 0.0, false)
	check(game.charge > 0.99 and not game.energy_locked, "release restores usable energy")
	game = Loop.new()
	game.shedding_order.erase(16)
	game.shedding_order.push_front(16)
	game.spawn_leaf()
	var leaf: Dictionary = game.leaves[0]
	var home: Vector2 = game.slots[leaf.home_slot].position
	game.week_time = Loop.BRANCH_COOLDOWN+0.01
	game.spawn_timer = 999
	leaf.position = home + Vector2(0, 90)
	# Isolate swept capture from lateral flutter during the slower climb.
	leaf.flutter_strength = 0
	game.x = home.x - Loop.NOZZLE_OFFSET.x
	for i in range(180): game.step(1.0 / 60.0, 0.0, true)
	check(game.rescued >= 1 and game.score >= 10 and leaf.state == "rescued" and game.slots.any(func(slot): return slot.leaf_id == leaf.id), "a real gust reattaches a leaf to an actual empty branch position")
	var before: int = game.score
	game.resolve_leaf(leaf, true)
	check(game.score == before, "a rescued leaf cannot score twice")
	game = Loop.new()
	game.spawn_leaf()
	leaf = game.leaves[0]
	leaf.position = Vector2(185, Loop.GROUND)
	game.step(1.0 / 60.0, 0, false)
	check(game.missed == 1 and game.pile_at(185) == 1, "misses populate the correct local pile")
	game.resolve_leaf(leaf, false)
	check(game.missed == 1, "ground outcomes are exactly once")
	game = Loop.new()
	game.week = Loop.BOSS_STAGE
	game.week_handled = game.week_leaf_count() - 1
	game.week_missed = game.capacity() - 1
	game.missed = game.week_missed
	game.leaves.append({"id": 99, "position": Vector2(180, Loop.GROUND), "velocity": Vector2.ZERO, "state": "air", "lifted": false, "age": 0.0, "angle": 0.0, "colour": Color.WHITE})
	game.step(1.0 / 60.0, 0, false)
	check(game.status == "lost", "loss takes precedence when the final leaf fills capacity")
	before = game.score
	game.step(1, 1, true)
	check(game.score == before and game.x == 180.0, "ending freezes score and gameplay")
	game = Loop.new()
	game.week_handled = game.week_leaf_count()
	game.step(1.0 / 60.0, 0, false)
	check(game.status == "workshop" and game.points == 2, "week completion awards two Gold Leaves")
	for i in range(20): game.step(1.0 / 60.0, 0, false)
	check(game.points == 2, "workshop cannot repeatedly award a week's point")
	check(game.buy(1) and game.points == 1, "first blower tier costs one point")
	check(not game.buy(1, 2), "cannot buy Whirlwind without three Gold Leaves")
	check(not game.buy(-1) and not game.buy(3), "invalid upgrade branches are rejected")
	check(game.stats().force > 410 and game.stats().speed < Loop.BASE_SPEED, "heavy blower trades movement speed for force")
	game.refund_build()
	check(game.points == 2 and game.tiers == [0, 0, 0], "reallocation returns the exact earned budget")
	check(game.buy(0), "refund can be spent on a different branch")
	check(game.next_week() and game.week == 2 and game.tiers[0] == 1, "next week preserves the build")
	check(game.charge == 1.0 and game.pile_at(180) == 0, "next week refills and clears local piles")
	game.step(1.0/60,0,false)
	check(not game.next_week() and not game.buy(2), "cannot skip weeks or buy during active play")
	for a in range(7):
		for b in range(7):
			for c in range(7):
				var s: Dictionary = game.stats([a, b, c])
				check(s.speed * (1.0 - s.pile_penalty) > 25.0, "all build combinations retain usable movement")
	var first = Loop.new(922)
	var second = Loop.new(922)
	for i in range(1200):
		var axis := sin(i / 70.0)
		first.step(1.0 / 60.0, axis, i % 360 < 200)
		second.step(1.0 / 60.0, axis, i % 360 < 200)
	check(first.leaves == second.leaves and first.score == second.score and first.x == second.x, "same seed and fixed-step inputs reproduce state")
	game = Loop.new()
	game.week = Loop.BOSS_STAGE
	game.week_handled = game.week_leaf_count()
	game.step(1.0 / 60.0, 0, false)
	check(game.status == "won" and game.score == 550 + 5 * game.capacity() and game.points == 0, "final-week success awards the win bonus and no unusable upgrade point")
	game = Loop.new()
	game.shedding_order.clear()
	for slot in game.slots: game.shedding_order.append(slot.leaf_id)
	for i in range(game.slots.size()): game.spawn_leaf()
	check(game.leaves.size() == Loop.MAX_ACTIVE and game.attached_count() == Loop.Canopy.SLOT_COUNT - Loop.MAX_ACTIVE, "full-canopy shedding respects the active-leaf budget and conservation")
	for i in range(600): game.step(1.0 / 60.0, sin(i / 50.0), i % 300 < 180)
	check(game.leaves.size() <= Loop.MAX_ACTIVE and is_finite(game.charge), "full-canopy stress scenario stays bounded")
	test_canopy()
	test_weeks()
	print("Simulation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_canopy() -> void:
	var game = Loop.new()
	check(game.attached_count() == Loop.Canopy.SLOT_COUNT and game.leaves.is_empty(), "every initial canopy leaf occupies a visible branch slot")
	check(game.capture_slot(Vector2(180, 300), Vector2(180, 75)) == -1, "occupied branches cannot accept another leaf")
	game.spawn_leaf()
	var first: Dictionary = game.leaves[0]
	var empty: int = first.home_slot
	var p: Vector2 = game.slots[empty].position
	check(game.attached_count() == Loop.Canopy.SLOT_COUNT - 1 and game.slots[empty].leaf_id == -1, "shedding removes the attached leaf and exposes its exact gap")
	check(first.position.distance_to(p) <= 10.0, "falling leaves originate at their branch rather than an arbitrary sky band")
	game.week_time=Loop.BRANCH_COOLDOWN+0.01
	check(game.capture_slot(p + Vector2(0, 50), p - Vector2(0, 50)) == empty, "swept capture finds a gap even at upgraded velocity")
	check(game.capture_slot(Vector2(180, 310), Vector2(180, 300)) == -1, "a lifted leaf away from a real empty spot does not count as saved")
	var before: int = game.score
	game.resolve_leaf(first, true)
	check(game.score == before and first.state == "air", "the former blanket canopy scoring shortcut is rejected")
	game.spawn_leaf()
	var second: Dictionary = game.leaves[1]
	game.resolve_leaf(second, true, empty)
	check(game.slots[empty].leaf_id == second.id and game.slots[second.home_slot].leaf_id == -1, "a leaf can fill a different empty branch position")
	game.resolve_leaf(first, true, empty)
	check(first.state == "air" and game.rescued == 1, "an already-filled spot rejects a second leaf and score")
	game.resolve_leaf(first, false)
	game.leaves.clear()
	game.week_handled = game.week_leaf_count()
	game.step(1.0 / 60.0, 0, false)
	var remaining: int = game.attached_count()
	var gap: int = second.home_slot
	game.next_week()
	check(game.attached_count() <= remaining and game.slots[gap].leaf_id == -1, "missed-leaf gaps stay bare while the next week also thins healthy clusters")
	check(game.attached_count() + game.missed - game.regrown + game.seasonal_fallen == Loop.Canopy.SLOT_COUNT, "canopy conservation survives a miss, cross-slot rescue, and week transition")
	check(game.week_leaf_count() <= game.attached_count(), "later shedding schedules never invent leaves to refill a depleted canopy")
	var id: int = game.slots[empty].leaf_id
	game.week = Loop.MAIN_WEEKS
	check(game.leaf_colour(id) != Color("8fa65c"), "late-season attached leaves use the autumn palette")


func test_weeks() -> void:
	var game = Loop.new()
	var previous := 100
	for stage in range(1, Loop.MAIN_WEEKS + 1):
		check(game.week == stage and not game.is_boss(), "campaign includes main week %d" % stage)
		check(game.temperature() < previous, "temperature drops in week %d" % stage)
		previous = game.temperature()
		game.week_handled = game.week_leaf_count()
		game.step(1.0 / 60, 0, false)
		check(game.status == "workshop" and game.earned_points == stage * 2, "main week %d completes once and awards its workshop point" % stage)
		game.next_week()
	check(game.is_boss() and game.stage_title() == "FINAL ENCOUNTER", "twelve weeks lead to the separately named boss encounter")
	game.week_time = 0.5
	check(game.boss_phase() == "warning", "boss telegraphs its gust")
	game.week_time = 2.0
	check(game.boss_phase() == "blast", "boss has a distinct leaf-stripping snow gust")
	var normal = Loop.new()
	var boss = Loop.new()
	normal.spawn_leaf()
	boss.spawn_leaf()
	boss.week = Loop.BOSS_STAGE
	boss.week_time = 1.4
	boss.wind_cycle = 0
	boss.wind_lane = 220
	var wind_position:Vector2 = Loop.NorthWind.center(boss.week_time+1.0/60,220)
	for sample in [normal,boss]:
		sample.leaves[0].position = wind_position+Vector2(0,20)
		sample.leaves[0].velocity = Vector2.ZERO
	normal.step(1.0 / 60, 0, false)
	boss.step(1.0 / 60, 0, false)
	check(boss.leaves[0].velocity.y > normal.leaves[0].velocity.y, "the boss gust actually accelerates leaves downward")
	game.week_time = 3.5
	check(game.boss_phase() == "rest", "boss gives a predictable recovery window")
	game.week_handled = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	check(game.status == "won" and game.earned_points == 24, "only the boss completes the campaign without an extra unusable point")
