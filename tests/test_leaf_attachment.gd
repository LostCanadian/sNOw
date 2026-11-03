extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Winter = preload("res://scripts/winter_fall.gd")
const Main = preload("res://main.tscn")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func capture(game) -> Dictionary:
	game.spawn_leaf()
	game.spawn_timer = 999
	var leaf: Dictionary = game.leaves[-1]
	var index: int = leaf.home_slot
	leaf.position = game.slots[index].position + Vector2(-11, 10)
	leaf.velocity = Vector2(35, -115)
	leaf.angle = game.slots[index].angle + 1.3
	leaf.roll = 0.7
	var original: Dictionary = leaf.duplicate()
	game.resolve_leaf(leaf, true, index)
	return original

func rendered_position(main, id: int) -> Vector2:
	var offset: int = main.leaf_renderer.rank[id] * 12
	var data: PackedFloat32Array = main.leaf_renderer.buffers[0]
	return Vector2(data[offset + 3], data[offset + 7])

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var game = Loop.new(77)
	var incoming := capture(game)
	var index: int = incoming.home_slot
	var target: Vector2 = game.slots[index].position
	var pose: Dictionary = game.attachment_pose(index)
	check(pose.position == incoming.position and pose.angle == incoming.angle and pose.roll == incoming.roll,
		"capture starts at the exact incoming position, rotation and tilt")
	check(game.slots[index].leaf_id == incoming.id and game.capture_slot(target, target) == -1,
		"the destination is reserved immediately so two leaves cannot claim it")
	game.resolve_leaf(game.leaves[0], true, index)
	check(game.rescued == 1 and game.score == 10 and game.attached_count() == Loop.Canopy.SLOT_COUNT,
		"visual settling conserves identities and cannot award a rescue twice")
	var previous: Vector2 = incoming.position
	var maximum_step := 0.0
	var moving_frames := 0
	for frame in range(20):
		game.advance_attachments(1.0 / 60)
		pose = game.attachment_pose(index)
		maximum_step = maxf(maximum_step, previous.distance_to(pose.position))
		if previous.distance_to(pose.position) > 0.01: moving_frames += 1
		if frame == 9:
			check(pose.position.distance_to(target) > 0.5 and pose.position.distance_to(incoming.position) > 2,
				"a capture remains visibly in transit across multiple rendered frames")
			check(pose.roll > incoming.roll and pose.roll < 1 and not is_equal_approx(pose.angle, incoming.angle),
				"rotation and paper tilt ease toward the attached pose along with position")
		previous = pose.position
	check(moving_frames > 12 and maximum_step < 3, "capture follows a gradual curve instead of a one-frame snap")
	game.advance_attachments(0.1)
	pose = game.attachment_pose(index)
	check(game.attachment_motions.is_empty() and pose.position == target and pose.angle == game.slots[index].angle and pose.roll == 1,
		"the curve finishes exactly on the ordinary attached-leaf pose")
	check(game.score == 10 and game.rescued == 1, "settling itself cannot add extra score")

	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.start_run()
	main.finish_story()
	incoming = capture(main.sim)
	index = incoming.home_slot
	target = main.sim.slots[index].position
	main.sim.leaves.clear()
	main.update_canopy_batches()
	check(rendered_position(main, incoming.id).is_equal_approx(incoming.position),
		"the captured identity overrides its cached target instead of drawing a second leaf there")
	main.sim.spawned = main.sim.week_leaf_count()
	main._physics_process(1.0 / 60)
	check(main.mode == "outro" and not main.sim.attachment_motions.is_empty(),
		"the final capture can continue settling during the closing interlude")
	main.pause_game()
	var frozen_pose: Dictionary = main.sim.attachment_pose(index)
	main._physics_process(0.2)
	check(main.sim.attachment_pose(index) == frozen_pose, "pause freezes an in-progress branch attachment")
	main.resume_game()
	for frame in range(25): main._physics_process(1.0 / 60)
	main.update_canopy_batches()
	check(main.sim.attachment_motions.is_empty() and rendered_position(main, incoming.id).distance_to(target)<2.0,
		"the last moving instance reaches its branch and may rustle after airborne and ground leaves are gone")

	game = Loop.new(77)
	incoming = capture(game)
	index = incoming.home_slot
	game.advance_attachments(0.12)
	pose = game.attachment_pose(index)
	var ending = Winter.new()
	ending.begin(game)
	var winter_leaf: Dictionary = ending.records.filter(func(leaf): return leaf.id == incoming.id)[0]
	check(winter_leaf.position == pose.position and winter_leaf.angle == pose.angle and winter_leaf.roll == pose.roll,
		"losing during attachment preserves the visible pose when winter begins")
	game.shedding_order.assign([incoming.id])
	game.spawned = 0
	game.leaves.clear()
	game.spawn_leaf()
	check(game.leaves[0].position == pose.position and game.leaves[0].angle == pose.angle and game.leaves[0].roll == pose.roll and game.attachment_motions.is_empty(),
		"a settling leaf that detaches again continues from its actual visible pose")
	main.queue_free()
	await process_frame
	print("Fluid leaf attachment: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
