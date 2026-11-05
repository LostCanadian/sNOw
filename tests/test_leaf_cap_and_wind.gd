extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Pose = preload("res://scripts/blower_pose.gd")
const Wind = preload("res://scripts/challenge_wind.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func fixture(count: int, challenge := true):
	var game = Loop.new(77, 1, challenge)
	game.falling_order.assign(range(Loop.Canopy.SLOT_COUNT))
	game.spawn_timer = 999
	for i in range(count):
		if not game.spawn_leaf():break
		var leaf: Dictionary = game.leaves[-1]
		leaf.position = Vector2(160 + i % 40, 130 + i % 30)
		leaf.velocity = Vector2.ZERO
		leaf.attach_after = 999
	return game

func _initialize() -> void:
	var game = fixture(550)
	check(game.leaves.size() == 200 and not game.spawn_leaf(), "Challenge detachment is capped at exactly 200 airborne identities")
	check(game.attached_count() + game.leaves.size() == Loop.Canopy.SLOT_COUNT, "leaves blocked by the cap stay on their original branches")
	game.spawn_timer = 0
	for frame in range(120):game.step(1.0/60, 0, false)
	check(game.leaves.size() == 200 and game.spawn_timer == 0, "a full cap cannot accumulate overdue shedding")
	var first: Dictionary = game.leaves.pop_back()
	game.resolve_leaf(first, true, first.home_slot)
	game.step(1.0/60, 0, false)
	check(game.leaves.size() == 200 and game.spawn_timer > 0, "one released budget slot admits one leaf and starts a fresh interval")
	first = game.leaves.pop_back();game.resolve_leaf(first, true, first.home_slot)
	game.step(1.0/60, 0, false)
	check(game.leaves.size() == 199, "a freed slot cannot trigger a second catch-up packet on the next tick")
	game = fixture(199)
	game.spawn_timer = 0
	game.step(1.0/60, 0, false)
	check(game.leaves.size() == 200, "ordinary multi-leaf packets stop at the last available slot")
	game.week_time = 56.79
	var spawned: int = game.spawned
	game.step(0.03, 0, false)
	check(game.leaves.size() == 200 and game.spawned == spawned and game.wind_released == 0, "North Wind cannot detach beyond the shared cap")
	check(game.wind_cycle >= 0 and game.boss_phase() == "blast", "the North Wind still visits and warns when the airborne cap is full")
	game = fixture(0)
	for i in range(3):
		game.spawn_leaf()
		var leaf: Dictionary = game.leaves[-1]
		leaf.position = Vector2(180, Loop.GROUND)
		game.resolve_leaf(leaf, false)
	game.leaves.clear()
	for i in range(199):game.spawn_leaf()
	var recoveries:Array=game.ground_leaves.duplicate()
	check(game.leaves.size()==197 and not game.spawn_leaf(), "branch shedding reserves slots for all three original ground leaves")
	game.week_time=56.79;game.spawn_timer=0;game.step(0.03,0,false)
	check(game.leaves.size()==197 and game.wind_released==0 and game.spawn_timer==0,"ordinary and storm shedding preserve recovery space without building a spawn backlog")
	check(game.activate_surge() and game.leaves.size() == 200 and game.ground_leaves.is_empty(), "Whirlwind lifts every nearby ground identity even at the shedding budget limit")
	check(game.missed == 0 and game.week_missed == 0 and game.attached_count() + game.leaves.size() == Loop.Canopy.SLOT_COUNT, "reserved recovery keeps frost counters and identity conservation correct")
	for leaf in recoveries:leaf.attach_after=999
	for frame in range(40):game.step(1.0/60,0,false)
	check(recoveries.all(func(leaf):return leaf.state=="air" and leaf.position.y<Loop.GROUND-55) and game.leaves.size()<=200,"recovered leaves visibly clear the ground throughout the spin without exceeding 200 airborne leaves")
	var campaign = fixture(550, false)
	check(campaign.leaves.size() == 550 and campaign.active_leaf_limit() == Loop.MAX_ACTIVE, "the new Challenge budget does not alter campaign shedding capacity")
	campaign=fixture(0,false);campaign.owned.assign(range(30));campaign.tiers=campaign.Upgrades.counts(campaign.owned)
	for i in range(3):
		campaign.spawn_leaf();var leaf:Dictionary=campaign.leaves[-1]
		leaf.position=Vector2(180,Loop.GROUND);campaign.resolve_leaf(leaf,false)
	campaign.leaves.clear()
	for i in range(Loop.MAX_ACTIVE):campaign.spawn_leaf()
	check(campaign.leaves.size()==Loop.MAX_ACTIVE-3 and campaign.activate_surge() and campaign.ground_leaves.is_empty() and campaign.leaves.size()==Loop.MAX_ACTIVE,"campaign shedding also preserves recovery slots at its unchanged 1500-leaf cap")
	var changes := true
	var down := false
	var quiet := false
	var left := false
	var right := false
	for tick in range(18000):
		var time := tick * 0.01
		var sample := Wind.sample(time, 1, 77)
		changes = changes and sample.distance_to(Wind.sample(time + 0.01, 1, 77)) < 2.0
		down = down or sample.y > 15
		quiet = quiet or (time > 20 and sample.y == 0)
		left = left or sample.x < -8
		right = right or sample.x > 8
	check(changes and left and right, "seeded wind changes direction smoothly instead of jittering frame to frame")
	check(down and quiet and Wind.sample(3, 1, 77) == Vector2.ZERO, "downdrafts have calm recovery windows and the opening starts calm")
	check(Wind.sample(80, 1, 77) == Wind.sample(80, 1, 77) and Wind.sample(80, 1, 77) != Wind.sample(80, 1, 79), "wind sampling is repeatable for a seed and varies with other seeds")
	check(Wind.sample(80, 0, 77).length() < Wind.sample(80, 2, 77).length(), "Easy receives gentler gusts than Hard")
	check(Loop.NorthWind.downburst(0.5) == 0 and Loop.NorthWind.downburst(1.85) > 0.99 and Loop.NorthWind.downburst(3.5) == 0, "North Wind fall surges ramp inside the warned blast and stop during recovery")
	var clear := Wind.sample(58, 1, 77)
	var storm := Wind.sample(58, 1, 77, 1.85)
	check(storm.y > clear.y + 10 and storm.x == clear.x, "a North Wind pass adds a temporary downward surge")
	var original: Vector2 = Loop.NorthWind.force(Vector2(180,220),1.6,220)
	var shared: Vector2 = Loop.NorthWind.force_at(Vector2(180,220),Loop.NorthWind.center(1.6,220),Loop.NorthWind.tangent(1.6,220)*150,Loop.NorthWind.direction(1.6)*165)
	check(original.is_equal_approx(shared), "sharing the wind path once per tick preserves its local eddy force")
	check(Pose.reflect_draft(12,Vector2(-100,-200)).x > 70 and Pose.reflect_draft(348,Vector2(100,-200)).x < -70, "outward blower flow reflects inward near both screen sides")
	check(Pose.reflect_draft(180,Vector2(50,-200)) == Vector2(50,-200) and Pose.reflect_draft(12,Vector2(50,-200)) == Vector2(50,-200), "centre airflow and already-inward flow keep their original force")
	for side in [-1,1]:
		game = fixture(1, false)
		var leaf: Dictionary = game.leaves[0]
		leaf.position = Vector2(8 if side < 0 else 352, 230)
		leaf.velocity = Vector2(side * 100,0)
		game.step(1.0/60, 0, false)
		check(leaf.velocity.x * side < 0 and leaf.position.x >= Loop.LEAF_RADIUS and leaf.position.x <= 360-Loop.LEAF_RADIUS, "wall overshoot reflects momentum inward on side %d" % side)
		game = fixture(1, false)
		game.x = 140 if side < 0 else 220; game.facing = side
		game.owned.assign(range(30)); game.tiers = game.Upgrades.counts(game.owned)
		leaf = game.leaves[0]
		leaf.position = Vector2(12 if side < 0 else 348, 240)
		leaf.flutter_rate = 0; leaf.flutter_phase = 0; leaf.flutter_strength = 0; leaf.lift_response = 1; leaf.drag = 0.65
		for frame in range(180):game.charge = 1; game.step(1.0/60, 0, true)
		check(leaf.position.x > 95 if side < 0 else leaf.position.x < 270, "reflected blower flow carries side %d leaves beyond the old edge-hover band" % side)
	print("Leaf budget and wind: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
