extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Main = preload("res://main.tscn")
const Scores = preload("res://scripts/high_scores.gd")
const Story = preload("res://scripts/stage_story.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func land(game, count: int) -> void:
	game.spawn_timer = 999
	for i in range(count):
		game.spawn_leaf()
		var leaf: Dictionary = game.leaves[-1]
		leaf.position = Vector2(180 + i % 2 * 2, Loop.GROUND)
		game.resolve_leaf(leaf, false)
	game.leaves = game.leaves.filter(func(leaf): return leaf.state == "air")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = Loop.new()
	game.spawn_leaf()
	var original: Dictionary = game.leaves[0]
	var colour: Color = original.colour
	var angle: float = original.angle
	original.position = Vector2(180, Loop.GROUND)
	game.resolve_leaf(original, false)
	original.identity_probe = true
	check(game.ground_leaves.size() == 1 and game.ground_leaves[0].get("identity_probe", false), "landing keeps one original leaf object rather than generating substitutes")
	check(game.ground_leaves[0].colour == colour and game.ground_leaves[0].angle == angle, "landed leaves preserve their paper colour and orientation")
	check(game.piles.reduce(func(total, count): return total + count, 0) == 1, "pile density counts a single leaf once")
	game.leaves.clear()
	game.spawn_timer = 999
	game.x = 155
	for frame in range(45): game.step(1.0 / 60, 1, false)
	check(original.position.x > 180 and original.state == "grounded", "walking stirs and hops the original ground leaf without giving a free aerial rescue")
	game = Loop.new()
	land(game, 8)
	var before: float = game.x
	game.step(1.0 / 60, 1, false)
	var pile_speed: float = game.x - before
	var clear = Loop.new()
	clear.step(1.0 / 60, 1, false)
	check(pile_speed < clear.x - 180 and pile_speed > 1, "dense ground leaves create a bounded local slowdown")
	var heights: Array = game.ground_leaves.map(func(leaf): return leaf.position.y)
	check(heights.max() - heights.min() > 2, "individual leaves form layers rather than one floating row")
	check(not game.activate_surge(), "surge must first be unlocked in the upgrade tree")
	game.owned.assign([10,12])
	game.tiers = [0,2,0]
	check(game.activate_surge(), "the unlocked charged ability lifts a nearby pile")
	check(game.ground_leaves.is_empty() and game.leaves.size() == 8 and game.piles.max() == 0, "surge transfers each actual ground leaf into the air exactly once")
	check(game.week_missed == 0 and game.missed == 0 and game.score == 0, "lifting restores its frost budget but awards no unearned points")
	check(not game.activate_surge() and game.surge_charge == 0, "the ability cannot fire again during its long recharge")
	var leaf: Dictionary = game.leaves[0]
	game.resolve_leaf(leaf, true, leaf.home_slot)
	var score: int = game.score
	game.resolve_leaf(leaf, true, leaf.home_slot)
	check(score == 10 and game.score == score and game.rescued == 1, "a recovered leaf scores once only after actual reattachment")
	game.leaves = game.leaves.filter(func(item): return item.state == "air")
	check(game.attached_count() + game.leaves.size() + game.missed - game.regrown == Loop.Canopy.SLOT_COUNT, "surge and reattachment conserve leaf identities and the loss ledger")
	game = Loop.new()
	game.owned.assign([10,12])
	game.tiers = [0,2,0]
	land(game, 3)
	game.step(1.0 / 60, 0, false, true)
	for frame in range(180): game.step(1.0 / 60, 0, false, true)
	check(game.surge_charge > 0.07 and game.surge_charge < 0.10, "three seconds restores only a small part of the thirty-six-second cooldown")
	for frame in range(2020): game.step(1.0 / 60, 0, false, true)
	check(game.surge_charge > 0.999 and game.surge_left == 0, "holding the ability key never automatically fires a recharged surge")
	game.owned.assign([10,12,20,22,26])
	check(game.stats().surge_cooldown == 31, "two Battery recovery nodes shorten the special ability cooldown")
	game.status = "workshop"
	var charge: float = game.surge_charge
	game.step(20, 0, false)
	check(game.surge_charge == charge, "menu time cannot advance an ability's gameplay clock")
	game.next_week()
	check(game.ground_leaves.is_empty() and game.surge_charge == 1 and game.surge_left == 0, "next week starts with the saved clean path and charged ability")
	var introductions := {}
	var conclusions := {}
	var subtle := true
	for chapter in Story.CHAPTERS:
		introductions[chapter[1]] = true
		conclusions[chapter[2]] = true
		for text in chapter:
			subtle = subtle and str(text).findn("magic") == -1 and str(text).findn("controls the seasons") == -1
	check(introductions.size() == 13 and conclusions.size() == 13 and subtle, "all twelve weeks and the finale have unique suggestive opening and closing lines")
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.start_run()
	var random_state: int = main.sim.rng.state
	main.sim.surge_charge = 0.25
	main._physics_process(0.4)
	check(main.mode == "intro" and main.sim.week_time == 0 and main.sim.rng.state == random_state and main.sim.surge_charge == 0.25, "the scene-opening panel freezes simulation, shedding and ability recharge")
	main.pause_game()
	var story_time: float = main.story_time
	main._physics_process(1)
	check(main.story_time == story_time and main.mode == "paused", "pause freezes the interlude fade and reading time")
	main.resume_game()
	main._physics_process(0.3)
	var skip := InputEventKey.new()
	skip.physical_keycode = KEY_SPACE
	skip.pressed = true
	main._input(skip)
	check(main.mode == "play" and main.keys.is_empty() and main.sim.week_time == 0, "Space dismisses the panel without accidentally starting the blower")
	main.sim.spawned = main.sim.week_leaf_count()
	main._physics_process(1.0 / 60)
	check(main.mode == "outro" and main.sim.points == 2, "a completed week presents its congratulations before the workshop")
	var saved_time: float = main.sim.week_time
	main._physics_process(1)
	check(main.sim.week_time == saved_time and main.sim.points == 2, "closing narration cannot advance gameplay or repeat rewards")
	main._physics_process(Story.DURATION)
	check(main.mode == "results", "closing text fades into weekly results before the workshop")
	check(main.FAN_ICON.get_image().get_used_rect().size.x > 150 and main.FAN_ICON.get_image().get_mipmap_count() > 0, "the rotating fan uses a high-resolution mipmapped vector-source icon")
	main.start_run()
	main.finish_story()
	main.sim.owned.assign([10,12])
	main.sim.tiers = [0,2,0]
	land(main.sim, 4)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	main._input(press)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_E
	release.pressed = false
	main._input(release)
	main._physics_process(1.0 / 60)
	check(main.sim.surge_left > 0 and main.sim.ground_leaves.is_empty(), "a quick key press/release is buffered into one surge action")
	main.pause_game()
	var remaining: float = main.sim.surge_left
	var ability_charge: float = main.sim.surge_charge
	main._physics_process(5)
	check(main.sim.surge_left == remaining and main.sim.surge_charge == ability_charge, "pause freezes both the spin animation and slow recovery")
	var path := "user://multi-rules-test-%d.json" % Time.get_ticks_usec()
	var scores = Scores.new(path)
	game = Loop.new()
	game.score = 100
	game.status = "lost"
	scores.submit(game, "NEW")
	for version in [5,4,3,2,1]:
		var old: Dictionary = scores.entries(1)[0].duplicate(true)
		old.rules = version
		old.initials = "OLD"
		scores.tables[1].append(old)
	check(scores.flush(), "both older scoring versions remain preserved alongside the new ability rules")
	scores = Scores.new(path)
	check(scores.available_rules(1) == [6,5,4,3,2,1] and scores.entries(1,2).size() == 1 and scores.entries(1,1).size() == 1, "score archives can cycle through each prior rules version separately")
	for extension in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + extension): DirAccess.remove_absolute(path + extension)
	main.queue_free()
	await process_frame
	await process_frame
	print("Ground leaves, surge and story: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
