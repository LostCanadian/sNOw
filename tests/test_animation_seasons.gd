extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Actor = preload("res://scripts/paper_actor.gd")
const Winter = preload("res://scripts/winter_fall.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Main = preload("res://main.tscn")
var checks := 0
var failures := 0

func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func land(game,count: int) -> void:
	game.spawn_timer = 999
	for i in range(count):
		game.spawn_leaf()
		var leaf: Dictionary = game.leaves[-1]
		leaf.position = Vector2(178 + i % 3,Loop.GROUND)
		game.resolve_leaf(leaf,false)
	game.leaves = game.leaves.filter(func(leaf): return leaf.state == "air")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = Loop.new(55)
	var colours := [0,0,0,0]
	var monotonic := true
	for id in range(Loop.Canopy.SLOT_COUNT):
		colours[game.leaf_category(id)] += 1
		for week in range(1,12): monotonic = monotonic and game.leaf_category(id,week + 1) >= game.leaf_category(id,week)
	check(colours[2] == 0 and colours[3] == 0 and colours[0] > 2200 and colours[1] > 400,"week one is predominantly green with yellow and no orange/red")
	check(monotonic,"each identity progresses through seasonal colours without turning green again")
	var initial_yellow: int = game.shedding_order.filter(func(id): return game.leaf_category(id) == 1).size()
	check(float(initial_yellow) / game.week_leaf_count() > float(colours[1]) / 2880 * 1.4,"yellow foliage is more likely to shed than the much larger green population")
	var first_rate: float = game.shed_batch_size() / game.shedding_interval()
	check(game.shed_batch_size() == 4,"the opening event is a small four-leaf group")
	game.week = 12
	game.prepare_shedding()
	var shedding := [0,0,0,0]
	for id in game.shedding_order: shedding[game.leaf_category(id)] += 1
	check(float(shedding[3]) / game.week_leaf_count() > 0.65 and shedding[2] > 20 and shedding[1] > 0 and shedding[0] < 10,"late shedding is mostly red, mixed with orange/yellow and occasional green")
	check(game.shed_batch_size() == 10 and first_rate < game.shed_batch_size() / game.shedding_interval() * 0.4,"the gentle opening rate advances to the previous late-game intensity")
	var again = Loop.new(55)
	check(again.shedding_order == Loop.new(55).shedding_order,"weighted selection is repeatable from a seed")
	var id: int = again.shedding_order[0]
	var slot: Dictionary = again.slots[again.find_attached_leaf(id)].duplicate()
	again.spawn_leaf()
	var original: Dictionary = again.leaves[0]
	check(original.position == slot.position and original.angle == slot.angle and original.colour == again.leaf_colour(id) and original.roll == 1,"detachment starts at the actual branch pose, colour and scale without an offset")
	check(again.slots[original.home_slot].leaf_id == -1 and again.attached_count() == 2879,"the original canopy identity is removed exactly when its falling object appears")
	again.spawn_timer = 999
	for frame in range(10): again.step(1.0 / 60,0,false)
	check(absf(original.angle - slot.angle) < 0.2,"flutter blends in rather than snapping to a new orientation")
	var actor = Actor.new()
	var rigid := true
	var reached := true
	for frame in range(360):
		actor.advance(1.5,1.0 / 60,true,false,-1 if frame > 180 else 1)
		for leg in range(2):
			var joint: Dictionary = actor.joints[leg]
			rigid = rigid and absf(joint.hip.distance_to(joint.knee) - Actor.rest(Actor.HIPS[leg]).distance_to(Actor.rest(Actor.KNEES[leg]))) < 0.001
			rigid = rigid and absf(joint.knee.distance_to(joint.ankle) - Actor.rest(Actor.KNEES[leg]).distance_to(Actor.rest(Actor.ANKLES[leg]))) < 0.001
			reached = reached and joint.ankle.distance_to(actor.foot_target(leg)) < 0.001
		for bone in actor.bones: rigid = rigid and absf(bone.determinant() - 1.0) < 0.0001
	check(rigid,"thighs/shins keep their painted length and unit scale through turns and complete strides")
	check(reached,"the gait stays within the fixed-length rig's reach, preserving planted feet")
	var frozen: float = actor.phase()
	actor.advance(0,1,false)
	check(actor.phase() == frozen and actor.movement == 0,"stopping settles the pose without cycling feet")
	game = Loop.new()
	land(game,40)
	var same_ids: Array = game.ground_leaves.map(func(leaf): return leaf.id)
	var bounded := true
	var drifted := false
	var rotated := false
	for frame in range(1200):
		game.step_ground(1.0 / 60,0.9 if frame % 60 < 30 else -0.9)
		for leaf in game.ground_leaves:
			bounded = bounded and leaf.position.y >= Loop.GROUND - Loop.KNEE_HEIGHT
			drifted = drifted or absf(leaf.position.x - 180) > 12
			rotated = rotated or absf(leaf.angle - leaf.rest_angle) > 0.8
	check(bounded,"repeated footsteps cannot stack ground leaves above knee height")
	check(drifted and rotated,"foot scuffs create varied lateral swirls and rotation")
	check(game.ground_leaves.map(func(leaf): return leaf.id) == same_ids and game.score == 0,"foot movement preserves the original leaves and awards no free rescues")
	game = Loop.new(88)
	var baseline = Loop.new(88)
	for sample in [game,baseline]:
		sample.owned.assign([10,12])
		sample.tiers = [0,2,0]
		sample.spawn_leaf()
		sample.spawn_timer = 999
		sample.leaves[0].position = Vector2(180,390)
		sample.leaves[0].velocity = Vector2.ZERO
	var boosted: Dictionary = game.leaves[0]
	var unboosted: Dictionary = baseline.leaves[0]
	check(game.ground_leaves.is_empty() and game.activate_surge(),"Surge can start with only airborne leaves in range")
	check(game.score == 0 and game.week_missed == 0,"activating in midair cannot manufacture score or refund an unmissed leaf")
	var highest := 0.0
	var rotation := 0.0
	var unit := true
	for frame in range(80):
		game.step(1.0 / 60,0,false)
		baseline.step(1.0 / 60,0,false)
		highest = minf(highest,game.surge_offset().y)
		rotation = maxf(rotation,absf(game.surge_spin()))
		unit = unit and absf(game.surge_transform().determinant() - 1.0) < 0.0001
	check(highest < -50 and rotation > TAU and unit,"the airborne tumble rotates in the screen plane without shrinking/flipping the cutout")
	check(boosted.lifted and boosted.position.distance_to(unboosted.position) > 15,"rotating airflow changes the actual airborne leaf trajectory")
	check(game.surge_left == 0 and game.surge_offset() == Vector2.ZERO and game.surge_transform().is_equal_approx(Transform2D.IDENTITY),"the tumble lands back in the normal pose without a retained offset")
	game = Loop.new()
	game.owned.assign([10,12])
	game.tiers = [0,2,0]
	land(game,25)
	var lifted_leaf: Dictionary = game.ground_leaves[0]
	lifted_leaf.angle += 1.4
	lifted_leaf.roll = 0.77
	var ground_angle: float = lifted_leaf.angle
	check(game.activate_surge() and game.missed == 0 and game.ground_leaves.is_empty() and game.leaves.size() == 25,"the same ability also transfers actual ground leaves and restores their miss budget")
	game.step(1.0 / 60,0,false)
	check(absf(lifted_leaf.angle - ground_angle) < 0.03 and absf(lifted_leaf.roll - 0.77) < 0.03,"ground-to-air pickup preserves the scuffed leaf pose as flutter blends back in")
	check(game.attached_count() + game.leaves.size() + game.missed - game.regrown == 2880,"mixed Surge physics keeps the canopy conservation rule")
	game = Loop.new()
	game.spawn_leaf()
	game.resolve_leaf(game.leaves[0],true,game.leaves[0].home_slot)
	check(game.score == 10,"one rescued leaf now earns ten points")
	game.leaves.clear()
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60,0,false)
	check(game.score == 10 + 50 + 5 * game.capacity(),"completion bonuses use the same tenfold score reduction")
	var old: Dictionary = Campaign.snapshot(game)
	old.rules = 4
	old.earned_points = 1
	old.points = 1
	old.score = 12340
	old.week_start_score = 9000
	var migrated = Campaign.restore(old)
	check(migrated.score == 1234 and migrated.week_start_score == 900,"old campaign totals and weekly baselines migrate together to the smaller score scale")
	check(Campaign.restore(Campaign.snapshot(migrated)).score == 1234,"saving and reopening cannot apply score conversion twice")
	game = Loop.new()
	land(game,3)
	for i in range(5): game.spawn_leaf()
	var score: int = game.score
	var random_state: int = game.rng.state
	var ending = Winter.new()
	ending.begin(game)
	check(ending.records.size() == 2880 and ending.attached == 2872 and ending.airborne == 5 and ending.grounded == 3,"winter begins with the actual attached, airborne and grounded identities")
	var conserved := true
	var snow_after_landing := true
	for frame in range(900):
		ending.step(1.0 / 60)
		conserved = conserved and ending.attached + ending.airborne + ending.grounded == 2880 and ending.records.size() == 2880
		if ending.cover() > 0: snow_after_landing = snow_after_landing and ending.attached == 0 and ending.airborne == 0
		if ending.finished(): break
	check(conserved,"the ending moves leaves between states rather than winking them out")
	check(snow_after_landing and ending.finished() and ending.grounded == 2880,"every leaf lands before snow builds over the pile")
	check(game.score == score and game.rng.state == random_state and game.missed == 3,"ending weather cannot alter gameplay results or consume gameplay randomness")
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.start_run()
	main.finish_story()
	main.sim.status = "lost"
	main._physics_process(1.0 / 60)
	main.pause_game()
	var before: float = main.winter_fall.time
	main._physics_process(10)
	check(main.winter_fall.time == before,"pause freezes the falling-leaf ending and its snow clock")
	check([main.SCORE_BADGE,main.FROST_BADGE,main.BATTERY_BADGE,main.PAUSE].all(func(rect): return rect.position.y == 14 and rect.size.y == 40),"all four HUD elements share the same top and height")
	check(main.PLAY_ICON.get_image().get_mipmap_count() > 0 and main.PAUSE_ICON.get_image().get_mipmap_count() > 0,"play/pause symbols use smooth mipmapped vector artwork")
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("Articulated motion, seasons and winter: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
