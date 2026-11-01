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
	check(is_equal_approx(game.x, 302.0), "one second of movement uses logical units")
	for i in range(60): game.step(1.0 / 60.0, 1.0, false)
	check(game.x == 331.0, "movement remains inside the shared playfield")
	game = Loop.new()
	for i in range(370): game.step(1.0 / 60.0, 0.0, true)
	check(game.energy_locked and game.charge == 0.0, "holding the blower drains and locks the battery")
	for i in range(60): game.step(1.0 / 60.0, 0.0, true)
	check(game.charge == 0.0 and not game.blowing, "empty battery cannot recharge while held")
	for i in range(240): game.step(1.0 / 60.0, 0.0, false)
	check(game.charge > 0.99 and not game.energy_locked, "release restores usable energy")
	game = Loop.new()
	game.spawn_leaf()
	var leaf: Dictionary = game.leaves[0]
	leaf.position = Vector2(180, 300)
	for i in range(180): game.step(1.0 / 60.0, 0.0, true)
	check(game.rescued >= 1 and game.score >= 100, "a real gust carries a falling leaf to the canopy")
	var before: int = game.score
	game.resolve_leaf(leaf, true)
	check(game.score == before, "a rescued leaf cannot score twice")
	game = Loop.new()
	game.spawn_leaf()
	leaf = game.leaves[0]
	leaf.position = Vector2(180, Loop.GROUND)
	game.step(1.0 / 60.0, 0, false)
	check(game.missed == 1 and game.pile_at(180) == 1, "misses populate the correct local pile")
	game.resolve_leaf(leaf, false)
	check(game.missed == 1, "ground outcomes are exactly once")
	game = Loop.new()
	game.day = 7
	game.spawned = game.day_leaf_count()
	game.missed = Loop.CAPACITY - 1
	game.leaves.append({"id": 99, "position": Vector2(180, Loop.GROUND), "velocity": Vector2.ZERO, "state": "air", "lifted": false, "age": 0.0, "angle": 0.0, "colour": Color.WHITE})
	game.step(1.0 / 60.0, 0, false)
	check(game.status == "lost", "loss takes precedence when the final leaf fills capacity")
	before = game.score
	game.step(1, 1, true)
	check(game.score == before and game.x == 180.0, "ending freezes score and gameplay")
	game = Loop.new()
	game.spawned = game.day_leaf_count()
	game.step(1.0 / 60.0, 0, false)
	check(game.status == "workshop" and game.points == 1, "day completion awards one upgrade point")
	for i in range(20): game.step(1.0 / 60.0, 0, false)
	check(game.points == 1, "workshop cannot repeatedly award a day's point")
	check(game.buy(1) and game.points == 0, "first blower tier costs one point")
	check(not game.buy(1), "cannot afford a two-point advanced upgrade")
	check(not game.buy(-1) and not game.buy(3), "invalid upgrade branches are rejected")
	check(game.stats().force > 410 and game.stats().speed < Loop.BASE_SPEED, "heavy blower trades movement speed for force")
	game.refund_build()
	check(game.points == 1 and game.tiers == [0, 0, 0], "reallocation returns the exact earned budget")
	check(game.buy(0), "refund can be spent on a different branch")
	check(game.next_day() and game.day == 2 and game.tiers[0] == 1, "next day preserves the build")
	check(game.charge == 1.0 and game.pile_at(180) == 0, "next day refills and clears local piles")
	check(not game.next_day() and not game.buy(2), "cannot skip days or buy during active play")
	for a in range(3):
		for b in range(3):
			for c in range(3):
				var s: Dictionary = game.stats([a, b, c])
				check(s.speed * (1.0 - s.pile_penalty) > 60.0, "all build combinations retain usable movement")
	var first = Loop.new(922)
	var second = Loop.new(922)
	for i in range(1200):
		var axis := sin(i / 70.0)
		first.step(1.0 / 60.0, axis, i % 360 < 200)
		second.step(1.0 / 60.0, axis, i % 360 < 200)
	check(first.leaves == second.leaves and first.score == second.score and first.x == second.x, "same seed and fixed-step inputs reproduce state")
	game = Loop.new()
	game.day = 7
	game.spawned = game.day_leaf_count()
	game.step(1.0 / 60.0, 0, false)
	check(game.status == "won" and game.score == 6900 and game.points == 0, "final-day success awards the win bonus and no unusable upgrade point")
	game = Loop.new()
	game.spawned = 150
	for i in range(150): game.spawn_leaf()
	for i in range(600): game.step(1.0 / 60.0, sin(i / 50.0), i % 300 < 180)
	check(game.leaves.size() <= 150 and is_finite(game.charge), "150-leaf stress scenario stays bounded")
	print("Simulation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
