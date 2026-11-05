extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Scores = preload("res://scripts/high_scores.gd")
const Campaign = preload("res://scripts/campaign.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func _initialize() -> void:
	var path := "user://scores-test-%d.json" % Time.get_ticks_usec()
	var scores = Scores.new(path)
	check(scores.tables == [[], [], []], "three independent empty local tables")
	check(Scores.clean_initials("éa1b!zq") == "ABZ" and Scores.clean_initials("") == "AAA", "initials allow only three uppercase ASCII letters")
	var game = Loop.new()
	game.score = 100
	check(not scores.qualifies(game), "unfinished games cannot submit scores")
	game.status = "lost"
	check(scores.submit(game, "abc"), "a terminal score saves")
	check(not scores.qualifies(game) and not scores.submit(game, "ZZZ"), "reopening a result cannot duplicate a campaign")
	game.score = 90
	check(not scores.submit(game, "BBB"), "a lower retry score never replaces the campaign best")
	game.score = 200
	game.week = 2
	check(scores.submit(game, "def") and scores.tables[1].size() == 1 and scores.tables[1][0].score == 200, "a better retry replaces the same campaign row")
	var tie = Loop.new()
	tie.status = "lost"
	tie.score = 200
	tie.week = 2
	scores.submit(tie, "GHI")
	check(scores.tables[1][0].initials == "DEF" and scores.tables[1][1].initials == "GHI", "exact ties preserve earlier insertion order")
	for i in range(12):
		var other = Loop.new()
		other.status = "lost"
		other.score = 300 + i * 100
		scores.submit(other, "AAA")
	check(scores.tables[1].size() == 10 and scores.tables[1][0].score == 1400 and scores.tables[1][-1].score == 500, "descending tables retain only the ten best scores")
	check(not scores.qualifies(game), "scores below the full table do not qualify")
	for difficulty in [0, 2]:
		var other = Loop.new(641023, difficulty)
		other.status = "lost"
		other.score = 100
		scores.submit(other, "NEW")
	check(scores.tables[0].size() == 1 and scores.tables[2].size() == 1, "each difficulty has its own qualifying threshold")
	var reopened = Scores.new(path)
	check(reopened.tables == scores.tables, "all score fields survive a native reopen")
	var data := {"version": 2, "tables": scores.tables.duplicate(true)}
	data.tables[0][0].initials = "<b>"
	check(not Scores.valid_document(data), "malformed stored initials are rejected")
	data = {"version": 2, "tables": scores.tables.duplicate(true)}
	data.tables[1].reverse()
	check(not Scores.valid_document(data), "unsorted stored tables are rejected")
	data = {"version": 2, "tables": scores.tables.duplicate(true)}
	data.tables[0][0].score = NAN
	check(not Scores.valid_document(data), "nonfinite stored scores are rejected")
	data = {"version": 2, "tables": scores.tables.duplicate(true)}
	data.tables[2][0].id = data.tables[0][0].id
	check(not Scores.valid_document(data), "duplicate campaign identities cannot load")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(Scores.new(path).tables[1].size() == 10 and Scores.new(path).error.contains("Recovered"), "a corrupt primary recovers the validated backup")
	var blocked = Scores.new("user://no-score-folder-%d/scores.json" % Time.get_ticks_usec())
	game.score = 9999
	check(not blocked.submit(game, "AAA") and blocked.error.contains("session"), "failed persistence is reported while retaining session scores")
	for difficulty in range(3):
		game = Loop.new(55, difficulty)
		var checkpoint: Dictionary = Campaign.snapshot(game)
		var restored = Campaign.restore(checkpoint)
		check(restored.difficulty == difficulty and restored.run_id == game.run_id, "difficulty and campaign identity survive checkpoint %d" % difficulty)
		game.missed = game.capacity() - 1
		game.week_missed = game.missed
		check(game.pressure() < 1.0, "pressure uses the selected capacity")
		game.spawn_leaf()
		game.resolve_leaf(game.leaves[0], false)
		check(game.status == "lost", "selected difficulty loses at its own capacity")
	var easy = Loop.new(55, 0)
	var hard = Loop.new(55, 2)
	check(easy.capacity() > hard.capacity() and easy.week_leaf_count() < hard.week_leaf_count(), "difficulty profiles change pressure and shedding")
	var legacy: Dictionary = Campaign.snapshot(Loop.new())
	legacy.erase("difficulty")
	legacy.erase("rules")
	legacy.erase("regrown")
	legacy.erase("week_regrown")
	legacy.leaf_ids.resize(48)
	legacy.order = legacy.order.filter(func(id): return id < 48)
	if legacy.order.is_empty(): legacy.order = [0]
	legacy.erase("run_id")
	check(Campaign.restore(legacy).difficulty == 1 and Campaign.restore(legacy).run_id == Campaign.restore(legacy).run_id, "legacy saves migrate to Medium with a stable campaign identity")
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with(path.get_file()): DirAccess.remove_absolute("user://" + name)
	print("High scores and difficulty: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
