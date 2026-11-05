extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Scores = preload("res://scripts/high_scores.gd")
const Main = preload("res://main.tscn")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func press(main, text: String) -> void:
	for node in main.overlay.find_children("*", "Button", true, false):
		if node.text == text:
			node.pressed.emit()
			return
	check(false, "missing action: " + text)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = Loop.new()
	check(game.attached_count() == 2160 and game.week_leaf_count() == 225 and game.capacity() == 105, "the new Medium tree, weekly shedding and danger budget scale with the lighter canopy")
	var identity := {}
	for slot in game.slots: identity[slot.leaf_id] = true
	check(identity.size() == 2160, "dense foliage consists of distinct recoverable leaves")
	for i in range(31): game.step(1.0 / 60, 0, false)
	check(game.spawned == 4 and game.leaves.size() == 4, "the opening week releases four real leaves per event rather than the late ten")
	for frame in range(6000):
		game.step(1.0 / 60, 0, false)
		if game.status == "lost": break
	check(game.status == "lost" and game.ground_leaves.size() == 105, "a real idle loss leaves a substantial pile rather than a dozen leaves")
	check(game.week_time < 90, "increased foliage retains a short arcade week")
	check(game.attached_count() + game.leaves.size() + game.missed - game.regrown == 2160, "large batches preserve the leaf identity invariant at loss")
	# Compare spatial queries against the original exhaustive geometric definition.
	var correct := true
	for i in range(40):
		var from := Vector2(24 + i * 7.7, 90 + fmod(i * 29.3, 300))
		var to := from + Vector2(sin(i) * 30, -40)
		var expected := -1
		var best := Loop.CAPTURE_RADIUS * Loop.CAPTURE_RADIUS
		for j in range(game.slots.size()):
			if game.slots[j].leaf_id >= 0 or not game.anchors.active.has(j) or game.week_time<float(game.slots[j].get("capture_after",0)): continue
			var point := Geometry2D.get_closest_point_to_segment(game.slots[j].position, from, to)
			var distance := point.distance_squared_to(game.slots[j].position)
			if distance < best:
				best = distance
				expected = j
		correct = correct and game.capture_slot(from, to) == expected
	check(correct, "nearby-branch indexing matches exhaustive swept capture over eligible branches")
	# Construct an actual previous-format boundary, including relocated identities/gaps.
	var old: Dictionary = Campaign.snapshot(Loop.new())
	old.rules = 3
	old.leaf_ids.resize(288)
	old.leaf_ids[0] = 1
	old.leaf_ids[1] = 0
	old.leaf_ids[5] = -1
	old.leaf_ids[9] = -1
	old.missed = 3
	old.regrown = 1
	old.score = 9000
	old.week = 4
	old.earned_points = 3
	old.points = 3
	old.order = [0, 1, 8, 12]
	old.erase("week_start_score")
	check(Campaign.valid_checkpoint(old), "previous 288-leaf saves remain valid input")
	var restored = Campaign.restore(old)
	check(restored != null and restored.attached_count() == 1900 and restored.seasonal_fallen == 245 and restored.missed == 23 and restored.regrown == 8, "migration preserves the visible proportion of canopy gaps and recovery history")
	check(restored.attached_count()+restored.missed-restored.regrown+restored.seasonal_fallen==2160, "migration reconciles rounded gaps without duplicated identities")
	check(restored.score == 900 and restored.week == 4 and restored.points == 6 and restored.shedding_order.size() == 270, "migration rescales score, retains week/budget and schedules the new colour-weighted week")
	check(Campaign.valid_checkpoint(Campaign.snapshot(restored)), "a migrated campaign can immediately save under the new rules")
	check(restored.rng.state == Campaign.restore(old).rng.state and restored.shedding_order == Campaign.restore(old).shedding_order, "migrated schedules and random state are repeatable from the saved boundary")
	old.phase = "workshop"
	old.earned_points = 4
	old.points = 4
	old.week_rescued = 3
	old.week_missed = 2
	restored = Campaign.restore(old)
	check(restored.week_rescued == 23 and restored.week_missed == 15 and restored.week_start_score == -1, "older completed summaries migrate counts while keeping unknown weekly points explicit")
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	var prefix := "user://fresh-slot-test-%d" % Time.get_ticks_usec()
	main.campaign = Campaign.new(prefix + "-campaign.json")
	main.high_scores = Scores.new(prefix + "-scores.json")
	for index in range(3): main.start_run(index, "Occupied %d" % index, index)
	var original: Array = main.campaign.slots.duplicate(true)
	main.show_slot_name(0, true)
	press(main, "Start fresh…")
	press(main, "Hard")
	press(main, "Review fresh start")
	check(main.campaign.slots == original, "choosing a replacement difficulty does not alter any existing slot before confirmation")
	press(main, "Keep my save")
	check(main.campaign.slots == original, "cancelling a fresh start preserves all three occupied saves")
	main.show_slot_name(0, true)
	press(main, "Start fresh…")
	press(main, "Hard")
	press(main, "Review fresh start")
	press(main, "Start fresh · Hard")
	check(main.mode == "intro" and main.sim.difficulty == 2 and main.sim.week == 1 and main.sim.score == 0, "confirmed fresh start uses the new difficulty and resets campaign progress")
	check(main.sim.run_id != original[0].checkpoint.run_id and main.campaign.slots[0].name == "Occupied 0", "replacement gets a new campaign identity and retains the chosen slot name")
	check(main.campaign.slots[1] == original[1] and main.campaign.slots[2] == original[2], "replacing one occupied slot leaves the other two intact")
	check(Campaign.new(prefix + "-campaign.json").slots[0].checkpoint.difficulty == 2, "replacement difficulty survives storage reload")
	check(main.canopy_batch.instance_count == 2160 and main.canopy_shadows.instance_count == 2160, "dense foliage uses full-count instanced paper-art batches")
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with(prefix.get_file()): DirAccess.remove_absolute("user://" + name)
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("Dense canopy and fresh save slots: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
