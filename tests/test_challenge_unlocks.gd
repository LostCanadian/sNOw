extends SceneTree
const Campaign = preload("res://scripts/campaign.gd")
const Loop = preload("res://scripts/loop.gd")
const Main = preload("res://main.tscn")
var checks := 0
var failures := 0
var paths: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func temp_path() -> String:
	var path := "user://challenge-unlocks-%d-%d.json" % [Time.get_ticks_usec(), paths.size()]
	paths.append(path)
	return path

func win(difficulty: int) -> Dictionary:
	var game = Loop.new(55, difficulty)
	game.week = 13; game.earned_points = 24; game.points = 24; game.status = "won"
	return Campaign.snapshot(game)

func write_document(path: String, document: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()

func buttons(main) -> Array[Node]:
	return main.overlay.find_children("*", "Button", true, false).filter(func(node):return node.text in ["Easy", "Medium", "Hard"])

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var fresh = Campaign.new(temp_path())
	check(fresh.highest_completed_difficulty == -1 and not fresh.challenge_unlocked, "fresh progress has no completed difficulty")
	for difficulty in range(3):check(not fresh.can_play_challenge(difficulty), "fresh progress locks Challenge difficulty %d" % difficulty)
	check(not fresh.unlock_challenge(-1) and not fresh.unlock_challenge(3) and fresh.highest_completed_difficulty == -1, "invalid unlock levels cannot grant Challenge access")
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	for completed in range(3):
		var path := temp_path()
		var progress = Campaign.new(path)
		check(progress.store(0, "Winner", win(completed)), "a difficulty %d campaign win persists" % completed)
		progress = Campaign.new(path)
		check(progress.highest_completed_difficulty == completed, "winning difficulty %d reloads independently of the selected game" % completed)
		main.campaign = progress
		main.show_title()
		main.show_challenge()
		var choices := buttons(main)
		for difficulty in range(3):
			check(progress.can_play_challenge(difficulty) == (difficulty <= completed), "win %d grants exactly the eligible Challenge level %d" % [completed, difficulty])
			check(choices[difficulty].disabled == (difficulty > completed), "win %d disables exactly the harder Challenge button %d" % [completed, difficulty])
		main.selected_difficulty = mini(completed + 1, 2)
		if completed < 2:
			main.start_challenge()
			check(main.mode == "challenge_setup", "stale harder selection cannot start Challenge after a lower win")
			main.start_run(-1, "", completed + 1, true)
			check(main.mode == "challenge_setup", "direct Challenge start also enforces the completed difficulty")
		# Overwrite all three slots and reopen storage before checking access again.
		for slot in range(3):check(progress.store(slot, "New save", Campaign.snapshot(Loop.new(55, 0))), "replacing slot %d after win %d succeeds" % [slot, completed])
		progress = Campaign.new(path)
		check(progress.highest_completed_difficulty == completed and progress.slots.all(func(slot):return slot.checkpoint.phase == "playing"), "replacing every winning save preserves the independent unlock for difficulty %d" % completed)
		check(progress.unlock_challenge(0) and progress.highest_completed_difficulty == completed, "a later Easy win cannot reduce earned access")
		main.campaign = progress
		main.selected_difficulty = completed
		main.start_challenge()
		check(main.mode == "play" and main.sim.challenge and main.sim.difficulty == completed, "earned difficulty %d remains playable after overwriting every slot" % completed)
		main.sim.difficulty = 2; main.sim.status = "won"; main.save_boundary()
		check(Campaign.new(path).highest_completed_difficulty == completed, "Challenge itself cannot increase campaign completion progress")
	# A higher win raises existing account progress; lower wins never lower it.
	var path := temp_path()
	var progress = Campaign.new(path)
	for completed in range(3):
		progress.store(0, "Winner", win(completed))
		check(Campaign.new(path).highest_completed_difficulty == completed, "new higher campaign victory expands the permanent unlock")
	progress.store(0, "Easy winner", win(0))
	check(Campaign.new(path).can_play_challenge(2), "saving a lower victory cannot revoke Hard Challenge")
	# Migrate completed saves from before difficulty-specific unlock metadata.
	for completed in range(3):
		path = temp_path()
		write_document(path, {"version":1,"slots":[{"name":"Old winner","checkpoint":win(completed)},null,null]})
		progress = Campaign.new(path)
		check(progress.highest_completed_difficulty == completed, "legacy completed save recovers its actual difficulty %d" % completed)
		progress.store(0, "Replacement", Campaign.snapshot(Loop.new()))
		check(Campaign.new(path).highest_completed_difficulty == completed, "migrated win %d survives replacement and reopening" % completed)
	path = temp_path()
	write_document(path, {"version":1,"slots":[null,null,null],"challenge_unlocked":true})
	progress = Campaign.new(path)
	check(progress.can_play_challenge(0) and not progress.can_play_challenge(1), "an old boolean-only unlock retains Easy access without inventing a harder win")
	progress.store(0, "New save", Campaign.snapshot(Loop.new()))
	check(Campaign.new(path).highest_completed_difficulty == 0, "a boolean-only unlock migrates to permanent difficulty metadata")
	for invalid in [true, -2, 3, 1.5, "2"]:
		check(not Campaign.valid_document({"version":1,"slots":[null,null,null],"highest_completed_difficulty":invalid}), "malformed completion metadata is rejected: %s" % str(invalid))
	path = temp_path(); progress = Campaign.new(path)
	progress.unlock_challenge(2)
	progress.store(0, "New save", Campaign.snapshot(Loop.new()))
	write_document(path, {"version":1,"slots":[null,null,null],"highest_completed_difficulty":"broken"})
	check(Campaign.new(path).highest_completed_difficulty == 2, "backup recovery retains an independent Hard unlock after metadata damage")
	path = temp_path(); progress = Campaign.new(path)
	var other_session = Campaign.new(path)
	progress.store(0, "Hard winner", win(2))
	other_session.store(0, "Fresh save", Campaign.snapshot(Loop.new()))
	check(Campaign.new(path).highest_completed_difficulty == 2, "a save from an older open session cannot revoke a newly earned Hard unlock")
	main.queue_free()
	await process_frame
	for saved in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(saved + suffix):DirAccess.remove_absolute(saved + suffix)
	await create_timer(0.3).timeout
	print("Challenge difficulty unlocks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
