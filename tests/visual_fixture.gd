extends SceneTree
## Art-review fixtures, not evidence that a human played a complete campaign.
## Creates valid late-week/boss checkpoints without changing production gameplay.

const Loop = preload("res://scripts/loop.gd")
const Campaign = preload("res://scripts/campaign.gd")


func _initialize() -> void:
	var game = Loop.new()
	for stage in range(11):
		game.spawned = game.week_leaf_count()
		game.step(1.0 / 60, 0, false)
		game.next_week()
	game.tiers = [2, 2, 1]
	game.points = 2
	var removed := 0
	for i in range(game.slots.size()):
		if i % 2 == 0 and removed < 22:
			game.slots[i].leaf_id = -1
			removed += 1
	game.missed = removed
	game.prepare_shedding()
	var late := Campaign.snapshot(game)
	game.spawned = game.week_leaf_count()
	game.step(1.0 / 60, 0, false)
	game.buy(2)
	game.next_week()
	var boss := Campaign.snapshot(game)
	var document := {"version": 1, "slots": [
		{"name": "Late autumn study", "checkpoint": late},
		{"name": "North Wind study", "checkpoint": boss}, null]}
	if not Campaign.valid_document(document):
		push_error("Invalid art review fixture")
		quit(1)
		return
	var file := FileAccess.open("res://test-results/visual-fixture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()
	print("Created valid art-review fixtures for week 12 and the finale.")
	quit()
