extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Actor = preload("res://scripts/paper_actor.gd")
const StoragePaths = preload("res://scripts/storage_paths.gd")
const Scores = preload("res://scripts/high_scores.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func _initialize() -> void:
	var game = Loop.new(55)
	check(game.attached_count() == Loop.Canopy.SLOT_COUNT, "new campaigns begin with thousands of separately occupied leaves")
	for i in range(12): game.step(1.0 / 60, -1, false)
	check(game.facing == -1 and game.aim < -0.5, "running left turns the character and aims the blower left")
	var actor = Actor.new()
	actor.advance(-2, 1.0 / 60, false, false, game.facing, game.aim)
	check((actor.nozzle() - (game.nozzle() - Vector2(game.x, Loop.GROUND))).length() < 0.01, "rendered tip and physics nozzle share the same pose")
	for i in range(12): game.step(1.0 / 60, 0, true)
	check(game.facing == -1 and is_zero_approx(game.aim) and game.air_axis() == Vector2.UP, "stopping retains facing and returns to vertical airflow")
	var velocities := []
	for axis in [-1, 0, 1]:
		var sample = Loop.new(77)
		for frame in range(12): sample.step(1.0 / 60, axis, false)
		sample.spawn_leaf()
		sample.spawn_timer = 999
		sample.leaves[0].position = sample.nozzle() + sample.air_axis() * 100
		sample.leaves[0].velocity = Vector2.ZERO
		sample.step(1.0 / 60, axis, true)
		velocities.append(sample.leaves[0].velocity.x)
	check(velocities[0] < velocities[1] - 0.3 and velocities[2] > velocities[1] + 0.3, "moving airflow imparts real signed horizontal force")
	for edge in [-10, 370]:
		game = Loop.new(77)
		game.spawn_leaf()
		game.spawn_timer = 999
		var leaf: Dictionary = game.leaves[0]
		leaf.position = Vector2(edge, 230)
		leaf.velocity = Vector2(-100 if edge < 0 else 100, 0)
		for frame in range(120): game.step(1.0 / 60, 0, false)
		check(leaf.position.x > 0 and leaf.position.x < 360, "an off-screen leaf naturally returns to the playable area")
	game = Loop.new()
	var initial_count: int = game.week_leaf_count()
	for i in range(initial_count):
		game.spawn_leaf()
		var leaf: Dictionary = game.leaves[-1]
		game.resolve_leaf(leaf, true, leaf.home_slot)
	game.leaves.clear()
	game.step(1.0 / 60, 0, false)
	check(game.status == "workshop" and game.attached_count() == Loop.Canopy.SLOT_COUNT, "a perfect week retains the entire canopy")
	game.next_week()
	check(game.attached_count() == game.crown_ceiling() and game.week_leaf_count() > initial_count and game.regrown == 0 and game.seasonal_fallen == 80, "the next week thins healthy twig clusters without counting seasonal loss as player misses")
	# A plausible sparse end-of-campaign checkpoint: 1,500 losses over twelve Breezy weeks.
	game = Loop.new(55, 0)
	game.week = 12
	game.status = "workshop"
	game.earned_points = 24
	game.points = 24
	for i in range(1500): game.slots[i].leaf_id = -1
	game.missed = 1500
	game.week_missed = 160
	game.x = 29
	game.piles.fill(4)
	var score: int = game.score
	game.next_week()
	check(game.attached_count() == Loop.RECOVERY_FLOOR and game.week_regrown == 60 and game.regrown == 60, "overnight recovery adds only the leaves needed for the safety floor")
	check(game.week_missed == 0 and game.pressure() == 0 and game.missed == 1500, "weekly danger resets while lifetime history remains accurate")
	check(game.score == score and game.earned_points == 24, "regrowth never awards points, rescues or extra upgrades")
	check(game.charge == 1 and game.pile_at(180) == 0 and game.x == 180, "the next week starts with a clean path, full battery and repeatable position")
	var checkpoint: Dictionary = Campaign.snapshot(game)
	check(Campaign.valid_checkpoint(checkpoint), "sparse recovered canopies are valid saved checkpoints")
	var depleted := checkpoint.duplicate(true)
	for i in range(depleted.leaf_ids.size()):
		if depleted.leaf_ids[i] >= 0 and not depleted.order.has(depleted.leaf_ids[i]):
			depleted.leaf_ids[i] = -1
			depleted.missed += 1
			break
	check(not Campaign.valid_checkpoint(depleted), "a checkpoint cannot restart below the guaranteed playable supply")
	var loaded = Campaign.restore(checkpoint)
	check(loaded.attached_count() == Loop.RECOVERY_FLOOR and loaded.regrown == 60 and loaded.slots == game.slots, "saved leaf identities and regrowth survive retry exactly")
	check(not loaded.next_week() and loaded.regrown == 60, "retry cannot repeat regrowth or skip a level")
	var builds := 0
	for a in range(7):
		for b in range(7):
			for c in range(7):
				if a + b + c == 12:
					builds += 1
					var stats: Dictionary = game.stats([a,b,c])
					check(stats.speed * (1-stats.pile_penalty) > 50 and stats.burst > 3, "each full-budget build retains mobility and usable battery time")
	check(builds == 28 and Loop.Upgrades.MAX_RANK * 3 == 30, "thirty nodes support the prior kit comparisons alongside branching builds")
	var legacy: Dictionary = Campaign.snapshot(Loop.new())
	legacy.erase("rules")
	legacy.erase("regrown")
	legacy.erase("week_regrown")
	legacy.leaf_ids.resize(48)
	legacy.order = [1, 5, 8]
	legacy.week = 13
	legacy.earned_points = 12
	legacy.points = 0
	legacy.tiers = [2,2,2]
	loaded = Campaign.restore(legacy)
	check(loaded != null and loaded.tiers == [4,4,4] and loaded.attached_count() == loaded.crown_ceiling(), "old slots keep their budget and progress when migrating to the larger canopy and tree")
	check(Campaign.valid_checkpoint(Campaign.snapshot(loaded)), "a migrated slot can immediately save under the new rules")
	var path := "user://archive-score-test-%d.json" % Time.get_ticks_usec()
	var scores = Scores.new(path)
	loaded.score = 2000
	loaded.status = "won"
	scores.submit(loaded, "NEW")
	var previous:Dictionary=scores.entries(1)[0].duplicate(true)
	previous.rules=1;previous.initials="OLD";previous.tiers=[2,2,2];previous.score=30000
	var recent:Dictionary=scores.entries(1)[0].duplicate(true);recent.rules=6
	var other:Dictionary=previous.duplicate(true);other.id="another-legacy-campaign";other.score=15000;other.initials="XYZ"
	var old_scores:={"version":1,"tables":[[],[recent,previous,other],[]]}
	check(Scores.valid_document(old_scores),"a real historical multi-version document remains readable")
	var scores_file:=FileAccess.open(path,FileAccess.WRITE)
	scores_file.store_string(JSON.stringify(old_scores));scores_file.close()
	scores=Scores.new(path)
	check(scores.entries(1).size()==2 and scores.entries(1)[0].score==3000 and scores.entries(1)[0].initials=="OLD" and scores.entries(1)[1].score==1500,"all historical scores merge into one table, with the best result per campaign on the current score scale")
	check(scores.flush() and Campaign.read_document(FileAccess.get_file_as_string(path)).version==2 and scores.entries(1).all(func(row):return not row.has("rules")),"unified scores save without rules labels or archives")
	loaded.score=4000
	check(scores.submit(loaded,"NEW") and scores.entries(1).size()==2 and scores.entries(1)[0].score==4000,"later campaign improvements update the same unified row")
	for extension in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + extension): DirAccess.remove_absolute(path + extension)
	var migration_name := "migration-probe-%d.json" % Time.get_ticks_usec()
	var old_directory := OS.get_user_data_dir().get_base_dir().path_join("sNOw — Paper & Lanterns")
	DirAccess.make_dir_recursive_absolute(old_directory)
	var old_file := FileAccess.open(old_directory.path_join(migration_name), FileAccess.WRITE)
	old_file.store_string("legacy-checkpoint")
	old_file.close()
	check(StoragePaths.legacy_raw(migration_name, false) == "legacy-checkpoint", "renamed application can still read its former native data directory")
	check(StoragePaths.legacy_raw(migration_name, true) == "legacy-checkpoint", "legacy recovery falls back to its preserved primary when no backup exists")
	DirAccess.remove_absolute(old_directory.path_join(migration_name))
	print("Airflow and campaign recovery: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
