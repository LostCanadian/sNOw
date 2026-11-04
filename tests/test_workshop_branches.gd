extends SceneTree
const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var game = Loop.new()
	game.week_handled = game.week_leaf_count()
	game.step(1.0/60,0,false)
	check(game.points == 2 and game.earned_points == 2, "one completed week awards exactly two Gold Leaves")
	check(not game.buy(1,2) and not game.surge_unlocked(), "Whirlwind cannot skip its prerequisite")
	check(game.buy(1,0) and not game.buy(1,2), "Whirlwind requires three additional Gold Leaves")
	game.next_week()
	game.week_handled = game.week_leaf_count()
	game.step(1.0/60,0,false)
	check(game.buy(1,2) and game.surge_unlocked() and game.points == 0, "Whirlwind unlocks for a total investment of four Gold Leaves")
	var restored = Campaign.restore(Campaign.snapshot(game))
	check(restored != null and restored.owned == game.owned and restored.surge_unlocked(), "branch choices and ability survive a JSON save round trip")
	game.refund_build()
	check(game.points == 4 and game.owned.is_empty() and not game.surge_unlocked(), "reset refunds exact node costs and removes the ability")
	check(game.buy(0,0) and game.buy(0,1) and game.buy(0,4), "the left inner path can be upgraded independently")
	check(not game.buy(0,8), "a crossover capstone requires both paths")
	game.points = 24
	check(game.buy(0,2) and game.buy(0,5) and game.buy(0,8), "joining both inner paths enables the crossover capstone")
	var speed: float = game.stats().speed
	var baseline = Loop.new()
	baseline.owned.assign([0,2,5])
	baseline.tiers = Loop.Upgrades.counts(baseline.owned)
	check(speed > baseline.stats().speed and game.stats().pile_penalty < baseline.stats().pile_penalty, "different boots branches produce different actual movement stats")
	var old: Dictionary = Campaign.snapshot(Loop.new())
	old.rules = 5
	for id in range(2160,2880):old.leaf_ids.append(id)
	old.week = 7
	old.earned_points = 6
	old.points = 1
	old.tiers = [1,2,2]
	old.erase("owned")
	restored = Campaign.restore(old)
	check(restored != null and restored.earned_points == 12 and restored.surge_unlocked() and restored.tiers == [1,2,2], "old campaigns receive the extra weekly currency and keep their former ability")
	check(Campaign.valid_checkpoint(Campaign.snapshot(restored)), "migrated branching builds can immediately save under rules six")
	var bad: Dictionary = Campaign.snapshot(restored)
	bad.owned.append(19)
	check(not Campaign.valid_checkpoint(bad), "missing parents, wrong counts and overspending cannot load as a valid kit")
	bad = Campaign.snapshot(restored)
	bad.owned.append(bad.owned[0])
	check(not Campaign.valid_checkpoint(bad), "duplicate nodes are rejected")
	print("Branching workshop: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
