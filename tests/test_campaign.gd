extends SceneTree

const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	var path := "user://campaign-test-%d.json" % Time.get_ticks_usec()
	var store = Campaign.new(path)
	check(store.slots == [null, null, null], "three fresh slots start empty")
	var game = Loop.new(922)
	var start: Dictionary = Campaign.snapshot(game)
	check(Campaign.valid_checkpoint(start), "new level boundary is a valid checkpoint")
	check(not Campaign.valid_document({"version": true, "slots": [null, null, null]}), "wrong JSON version types fail safely")
	check(store.store(0, "My Autumn", start), "a named first slot saves")
	check(store.store(1, "Other garden", start) and store.store(2, "Third garden", start), "all three slots are independent")
	check(not store.store(3, "Extra", start), "a fourth slot is rejected")
	store = Campaign.new(path)
	check(store.slots[0].name == "My Autumn" and store.slots[1].name == "Other garden", "names and checkpoints survive reopening storage")
	check(store.rename_slot(1, "  Renamed garden  "), "rename persists without replacing progress")
	check(Campaign.new(path).slots[1].name == "Renamed garden", "renamed slot survives reload")
	var loaded = Campaign.restore(store.slots[0].checkpoint)
	check(loaded != null and loaded.week == 1 and loaded.score == 0, "level restart restores the start, not a failed attempt")
	for i in range(60): game.step(1.0 / 60, 1, true)
	check(Campaign.snapshot(game).is_empty(), "mid-level progress cannot masquerade as a boundary save")
	var retried = Campaign.restore(start)
	var baseline = Campaign.restore(start)
	for i in range(120):
		retried.step(1.0 / 60, 0, i < 80)
		baseline.step(1.0 / 60, 0, i < 80)
	check(retried.leaves == baseline.leaves and retried.rng.state == baseline.rng.state, "checkpoint retains the precise schedule and random state")
	game = Loop.new()
	game.spawn_leaf()
	game.resolve_leaf(game.leaves[0], false)
	game.leaves.clear()
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	check(store.store(0, "My Autumn", Campaign.snapshot(game)), "completed level autosaves its workshop boundary")
	game.buy(1)
	check(store.store(0, "My Autumn", Campaign.snapshot(game)), "workshop upgrade purchases are saved")
	loaded = Campaign.restore(Campaign.new(path).slots[0].checkpoint)
	check(loaded.status == "workshop" and loaded.earned_points == 2 and loaded.points == 1 and loaded.tiers[1] == 1, "workshop reload does not duplicate score or upgrade rewards")
	check(loaded.missed == 1 and loaded.attached_count() == Loop.Canopy.SLOT_COUNT - 1, "persistent canopy gaps survive a local save")
	loaded.next_week()
	var week_two: Dictionary = Campaign.snapshot(loaded)
	check(store.store(0, "My Autumn", week_two), "starting the next week saves its retry checkpoint")
	for field in ["week", "score", "missed", "points", "earned_points"]:
		var bad := week_two.duplicate(true)
		bad[field] = -999
		check(not Campaign.valid_checkpoint(bad), "malformed " + field + " is rejected")
	var bad := week_two.duplicate(true)
	bad.leaf_ids[2] = bad.leaf_ids[3]
	check(not Campaign.valid_checkpoint(bad), "duplicate occupied leaf identities cannot load")
	bad = week_two.duplicate(true)
	bad.tiers = [100, 0, 0]
	check(not Campaign.valid_checkpoint(bad), "invalid upgrade builds are rejected")
	bad = week_two.duplicate(true)
	bad.rng_state = "not an integer"
	check(not Campaign.valid_checkpoint(bad), "invalid random state is rejected")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{interrupted-write")
	file.close()
	var recovered = Campaign.new(path)
	check(recovered.slots[0] != null and recovered.slots[1].name == "Renamed garden", "backup recovery preserves other gardens after a damaged primary file")
	var blocked = Campaign.new("user://missing-parent-%d/save.json" % Time.get_ticks_usec())
	check(not blocked.store(0, "No disk", start) and blocked.error != "", "unavailable storage produces a clear failure instead of claiming persistence")
	game = Loop.new()
	for stage in range(1, 13):
		game.spawned = game.week_leaf_count()
		game.step(1.0 / 60, 0, false)
		var branch := (stage - 1) / 4
		game.buy(branch)
		game.next_week()
	check(game.tiers == [4, 4, 4] and game.points == 10 and game.earned_points == 24, "twenty-four Gold Leaves retain a balanced kit plus unspent currency")
	check(store.store(2, "Finale", Campaign.snapshot(game)) and Campaign.restore(store.slots[2].checkpoint).is_boss(), "final encounter checkpoints retain the full campaign build")
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	check(store.store(2, "Victory", Campaign.snapshot(game)) and Campaign.restore(store.slots[2].checkpoint).status == "won", "campaign victory persists without replaying rewards")
	game = Loop.new()
	for i in range(6):
		game.spawn_leaf()
		var leaf: Dictionary = game.leaves[-1]
		game.resolve_leaf(leaf, true, leaf.home_slot)
	game.leaves.clear()
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	loaded = Campaign.restore(Campaign.snapshot(game))
	check(loaded.combo == 6 and loaded.week_rescued == 6, "workshop checkpoint preserves combo and the completed-level summary")
	for extension in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + extension): DirAccess.remove_absolute(path + extension)
	print("Campaign saves: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
