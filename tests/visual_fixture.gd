extends SceneTree
## Valid art/UX review checkpoints, not claims of a human-played campaign.
const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")
func _initialize() -> void:
	var game = Loop.new()
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	var workshop := Campaign.snapshot(game)
	for stage in range(10):
		game.next_week()
		game.spawned = game.week_leaf_count()
		game.step(1.0 / 60, 0, false)
	game.next_week()
	game.tiers = [4, 4, 3]
	game.points = 0
	var removed := 0
	for i in range(game.slots.size()):
		if i % 2 == 0 and removed < 132:
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
	print("Created validated late-week, boss and workshop UI fixtures.")
	quit()
