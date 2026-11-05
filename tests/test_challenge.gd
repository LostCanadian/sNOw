extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Scores = preload("res://scripts/high_scores.gd")
const Main = preload("res://main.tscn")
var checks := 0
var failures := 0
var paths: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func temp_path(suffix: String) -> String:
	var path := "user://challenge-test-%d-%s.json" % [Time.get_ticks_usec(), suffix]
	paths.append(path)
	return path

func action(main, text: String) -> Button:
	for b in main.overlay.find_children("*", "Button", true, false):
		if b.text == text: return b
	return null

func layout_ok(main) -> bool:
	var buttons = main.overlay.find_children("*", "Button", true, false)
	for i in range(buttons.size()):
		if not Rect2(0, 0, 360, 640).encloses(buttons[i].get_global_rect()): return false
		for j in range(i + 1, buttons.size()):
			if buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()): return false
	return true

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for difficulty in range(3):
		var game = Loop.new(55, difficulty, true)
		check(game.challenge and game.tiers == [10,10,10] and game.owned.size() == 30 and game.surge_unlocked(), "Challenge starts fully upgraded on difficulty %d" % difficulty)
		check(not game.can_upgrade() and not game.buy(0) and Campaign.snapshot(game).is_empty(), "Challenge cannot edit equipment or become a campaign checkpoint")
		var first: float = game.shedding_interval()
		game.week_time = 120
		var later: float = game.shedding_interval()
		game.week_time = 600
		check(first > later and later > game.shedding_interval(), "leaf arrival rate keeps accelerating")
		game.week_time = 0
		# A perfect-response study resolves real falling identities, across repeated
		# refills. It checks endless rules, not human ability to reach this score.
		var unique := true
		for frame in range(12000):
			game.step(1.0 / 60, 0, false)
			var ids := {}
			for leaf in game.leaves:
				unique = unique and not ids.has(leaf.id)
				ids[leaf.id] = true
				game.resolve_leaf(leaf, true, leaf.home_slot)
			game.leaves.clear()
			if game.rescued > game.week_leaf_count() * 3: break
		check(game.status == "playing" and game.rescued > game.week_leaf_count() * 3 and game.score > 0 and game.earned_points == 0 and unique, "rescues continue through three quotas without victory, rewards or duplicate identities")
		game.complete_level()
		check(game.status == "playing", "Challenge cannot complete a campaign level")
		# Ordinary play must still be able to lose through actual ground impacts.
		var idle = Loop.new(55, difficulty, true)
		for frame in range(12000):
			idle.step(1.0 / 60, 0, false)
			if idle.status != "playing": break
		check(idle.status == "lost" and idle.week_missed == idle.capacity(), "Challenge ends at the normal winter loss allowance")

	var path := temp_path("campaign")
	var saves = Campaign.new(path)
	var won = Loop.new()
	won.week = 13; won.points = 24; won.earned_points = 24; won.status = "won"
	var win: Dictionary = Campaign.snapshot(won)
	check(saves.store(0, "Winner", win) and saves.challenge_unlocked, "campaign victory unlocks Challenge")
	var legacy := {"version": 1, "slots": [{"name": "Old victory", "checkpoint": win}, null, null]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	saves = Campaign.new(path)
	check(saves.challenge_unlocked, "existing victory saves unlock without replaying the boss")
	saves.store(0, "Fresh", Campaign.snapshot(Loop.new()))
	saves = Campaign.new(path)
	check(saves.challenge_unlocked and saves.slots[0].checkpoint.phase == "playing", "unlock survives replacing the winning slot and reopening")

	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.campaign = Campaign.new(temp_path("ui"))
	main.high_scores = Scores.new(temp_path("scores"))
	main.challenge_scores = Scores.new(temp_path("challenge-scores"), "snow.challenge_scores.v1")
	main.show_title()
	await process_frame
	check(action(main, "Continue").disabled and action(main, "New Game") != null and action(main, "Challenge · locked").disabled, "new players have separate menu actions and a locked Challenge")
	check(layout_ok(main), "portrait menu controls do not overlap")
	main.start_challenge()
	check(main.mode == "title", "locked Challenge cannot start")
	action(main, "New Game").pressed.emit()
	action(main, "Slot 1 · Empty").pressed.emit()
	action(main, "Start week 1").pressed.emit()
	main.finish_story()
	var original: Dictionary = main.campaign.slots[0].duplicate(true)
	main.show_title()
	action(main, "Continue").pressed.emit()
	check(action(main, "Slot 2 · Empty").disabled, "Continue cannot create a new campaign")
	for b in main.overlay.find_children("*", "Button", true, false):
		if b.text.begins_with("Save 1\n"): b.pressed.emit(); break
	check(main.mode == "continue" and main.sim.run_id == original.checkpoint.run_id, "Continue restores the selected saved campaign")
	main.show_slots("new")
	for b in main.overlay.find_children("*", "Button", true, false):
		if b.text.begins_with("Save 1\n"): b.pressed.emit(); break
	check(main.mode == "name" and main.campaign.slots[0] == original, "New Game on an occupied slot opens setup without loading or replacing it")
	action(main, "Review fresh start").pressed.emit()
	check(action(main, "Keep my save") != null and main.campaign.slots[0] == original, "replacement requires a separate confirmation")
	action(main, "Keep my save").pressed.emit()
	check(main.campaign.slots[0] == original and main.slots_intent == "new", "cancelling replacement preserves the save and returns to New Game")
	main.show_slot_name(0, false, true)
	action(main, "Review fresh start").pressed.emit()
	action(main, "Start fresh · Blustery").pressed.emit()
	check(main.campaign.slots[0].checkpoint.run_id != original.checkpoint.run_id and main.sim.week == 1, "explicit confirmation replaces only the chosen campaign")
	main.finish_story()
	main.sim.week = 13; main.sim.earned_points = 24; main.sim.points = 24; main.sim.status = "won"
	main._physics_process(1.0 / 60)
	main.campaign = Campaign.new(main.campaign.path)
	check(main.campaign.challenge_unlocked, "the live victory transition persists the unlock")
	main.show_title()
	check(action(main, "Challenge") != null and not action(main, "Challenge").disabled, "winning enables the main-menu Challenge button")
	action(main, "Challenge").pressed.emit()
	await process_frame
	check(layout_ok(main), "Challenge setup has distinct portrait hit areas")
	var before: Array = main.campaign.slots.duplicate(true)
	action(main, "Gale").pressed.emit()
	check(main.mode == "play" and main.sim.challenge and main.sim.difficulty == 2 and main.active_slot == -1 and main.level_checkpoint.is_empty(), "Challenge difficulty starts an independent live run")
	main.pause_for_focus()
	var time: float = main.sim.week_time
	main._physics_process(1)
	check(main.mode == "paused" and main.sim.week_time == time, "Challenge pauses on focus loss")
	main.confirm_restart()
	check(action(main, "Upgrades") == null, "Challenge restart never offers editable upgrades")
	action(main, "Cancel").pressed.emit()
	check(main.mode == "play", "cancelling restart resumes the Challenge")
	main.sim.score = 5000; main.sim.status = "lost"
	main.show_result(); main.finish_tally()
	check(action(main, "Play again") != null and action(main, "Retry this level") == null, "Challenge results offer a fresh attempt")
	main.show_initials()
	main.overlay.find_children("*", "LineEdit", true, false)[0].text = "xyz"
	action(main, "Save score").pressed.emit()
	await process_frame
	check(main.challenge_scores.entries(2).size() == 1 and main.challenge_scores.entries(2)[0].initials == "XYZ" and main.high_scores.entries(2).is_empty(), "initials submit to Challenge scores without polluting campaign tables")
	check(layout_ok(main), "score screen tabs do not overlap")
	var reopened = Scores.new(main.challenge_scores.path, "snow.challenge_scores.v1")
	check(reopened.entries(2).size() == 1 and reopened.entries(2)[0].score == 5000, "Challenge high scores survive reopening")
	main.return_from_scores()
	check(main.mode == "lost" and not main.challenge_scores.qualifies(main.sim), "returning from scores retains the result without duplicate rows")
	var run_id: String = main.sim.run_id
	action(main, "Play again").pressed.emit()
	check(main.sim.run_id != run_id and main.sim.score == 0 and main.sim.tiers == [10,10,10], "Play again resets score and identity with all upgrades")
	main.save_boundary()
	check(main.campaign.slots == before, "Challenge start, loss, scores and retry leave campaign saves unchanged")
	main.queue_free()
	await process_frame
	for saved in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(saved + suffix): DirAccess.remove_absolute(saved + suffix)
	await create_timer(0.5).timeout
	print("Challenge and new game: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
