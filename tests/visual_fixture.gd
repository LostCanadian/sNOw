extends SceneTree
## Valid art/UX review checkpoints, not claims of a human-played campaign.
const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")
func _initialize() -> void:
	var game = Loop.new()
	var initial_canopy := {}
	for slot in game.slots: initial_canopy[str(slot.leaf_id)] = [slot.position.x,slot.position.y,slot.angle,game.leaf_colour(slot.leaf_id).to_html(false)]
	var geometry := FileAccess.open("res://test-results/canopy-fixture.json",FileAccess.WRITE)
	geometry.store_string(JSON.stringify(initial_canopy))
	geometry.close()
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	var workshop := Campaign.snapshot(game)
	for stage in range(10):
		game.next_week()
		game.spawned = game.week_leaf_count()
		game.step(1.0 / 60, 0, false)
	game.next_week()
	game.tiers = [4, 4, 3]
	game.owned = Loop.Upgrades.legacy_nodes(game.tiers)
	game.points = game.earned_points - Loop.Upgrades.spent(game.owned)
	var removed := 0
	for i in range(game.slots.size()):
		if i % 2 == 0 and removed < 1320:
			game.slots[i].leaf_id = -1
			removed += 1
	game.missed = removed
	game.prepare_shedding()
	var late := Campaign.snapshot(game)
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	game.buy(2)
	game.next_week()
	var document := {"version": 1, "slots": [
		{"name": "Week 12 study", "checkpoint": late},
		{"name": "North Wind study", "checkpoint": Campaign.snapshot(game)},
		{"name": "Workshop study", "checkpoint": workshop}]}
	if not Campaign.valid_document(document):
		push_error("Invalid art review fixture")
		quit(1)
		return
	var file := FileAccess.open("res://test-results/visual-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	var ability = Loop.new(641023, 0)
	for stage in range(5):
		ability.spawned = ability.week_leaf_count()
		ability.step(1.0 / 60, 0, false)
		ability.next_week()
	ability.tiers = [0,2,3]
	ability.owned = Loop.Upgrades.legacy_nodes(ability.tiers)
	ability.points = ability.earned_points - Loop.Upgrades.spent(ability.owned)
	var story = Loop.new()
	story.week = 7
	story.earned_points = 12
	story.points = 12
	story.prepare_shedding()
	# A short saved schedule isolates the closing interlude for a UI review.
	story.shedding_order.resize(1)
	var studies := {"version": 1, "slots": [
		{"name": "Surge loadout study", "checkpoint": Campaign.snapshot(ability)},
		{"name": "Short story study", "checkpoint": Campaign.snapshot(story)}, null]}
	if not Campaign.valid_document(studies):
		push_error("Invalid ability/story review fixture")
		quit(1)
		return
	file = FileAccess.open("res://test-results/ability-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(studies))
	file.close()
	var results = Loop.new(641023, 0)
	for stage in range(8):
		results.spawned = results.week_leaf_count()
		results.step(1.0 / 60, 0, false)
		results.next_week()
	results.tiers = [3,3,2]
	results.owned = Loop.Upgrades.legacy_nodes(results.tiers)
	results.points = results.earned_points - Loop.Upgrades.spent(results.owned)
	for i in range(120):
		results.spawn_leaf()
		var leaf: Dictionary = results.leaves[-1]
		results.resolve_leaf(leaf, i < 90, leaf.home_slot)
	results.leaves.clear()
	results.spawned = results.week_leaf_count()
	results.step(1.0 / 60, 0, false)
	var summaries := {"version": 1, "slots": [{"name": "Week 9 result study", "checkpoint": Campaign.snapshot(results)}, null, null]}
	if not Campaign.valid_document(summaries):
		push_error("Invalid results review fixture")
		quit(1)
		return
	file = FileAccess.open("res://test-results/results-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summaries))
	file.close()
	var finale = Loop.new(641023, 2)
	for stage in range(11):
		finale.spawned = finale.week_leaf_count()
		finale.step(1.0 / 60,0,false)
		finale.next_week()
	finale.tiers = [4,4,3]
	finale.owned = Loop.Upgrades.legacy_nodes(finale.tiers)
	finale.points = finale.earned_points - Loop.Upgrades.spent(finale.owned)
	var endings := {"version":1,"slots":[{"name":"Full canopy ending","checkpoint":Campaign.snapshot(finale)},null,null]}
	if not Campaign.valid_document(endings):
		push_error("Invalid ending fixture")
		quit(1)
		return
	file = FileAccess.open("res://test-results/ending-fixture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(endings))
	file.close()
	print("Created validated late-week, boss and workshop UI fixtures.")
	quit()
