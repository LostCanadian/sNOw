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
		if i % 2 == 0 and game.slots[i].leaf_id>=0 and removed < 180:
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
	# One normal falling identity isolates the branch-settle animation for browser review.
	var returning=Loop.new()
	var nearest:=0
	for index in range(returning.slots.size()):
		if returning.slots[index].position.distance_squared_to(Vector2(192,320))<returning.slots[nearest].position.distance_squared_to(Vector2(192,320)):nearest=index
	returning.shedding_order.assign([returning.slots[nearest].leaf_id])
	var attachment_study:={"version":1,"slots":[{"name":"Attachment study","checkpoint":Campaign.snapshot(returning)},null,null]}
	if not Campaign.valid_document(attachment_study):
		push_error("Invalid attachment study")
		quit(1)
		return
	file=FileAccess.open("res://test-results/attachment-fixture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"saves":attachment_study,"target":[returning.slots[nearest].position.x,returning.slots[nearest].position.y]}))
	file.close()
	var north=Loop.new(55,1)
	for completed in range(12):
		north.spawned=north.week_leaf_count();north.step(1.0/60,0,false);north.next_week()
	north.owned.assign([0,1,10,11,12,20,21]);north.tiers=Loop.Upgrades.counts(north.owned)
	north.points=north.earned_points-Loop.Upgrades.spent(north.owned)
	var normal_north:Dictionary=Campaign.snapshot(north)
	var one_target:=-1
	for index in range(north.slots.size()):
		if north.slots[index].leaf_id<0:continue
		if one_target<0 or north.slots[index].position.distance_squared_to(Vector2(192,280))<north.slots[one_target].position.distance_squared_to(Vector2(192,280)):one_target=index
	north.shedding_order.assign([north.slots[one_target].leaf_id])
	var finale_studies:={"version":1,"slots":[{"name":"Victory study","checkpoint":Campaign.snapshot(north)}, {"name":"North Wind study","checkpoint":normal_north},null]}
	if not Campaign.valid_document(finale_studies):
		push_error("Invalid finale studies");quit(1);return
	file=FileAccess.open("res://test-results/finale-fixture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(finale_studies));file.close()
	var early_outfit=Loop.new(641023,2)
	var mid_outfit=Loop.new(641023,2)
	for completed in range(6):
		mid_outfit.spawned=mid_outfit.week_leaf_count();mid_outfit.step(1.0/60,0,false);mid_outfit.next_week()
	var transition=Loop.new(641023,2)
	for missed_leaf in range(60):
		transition.spawn_leaf();transition.resolve_leaf(transition.leaves[-1],false)
	transition.leaves.clear();transition.spawned=transition.week_leaf_count();transition.step(1.0/60,0,false)
	var continuity_studies:={"version":1,"slots":[{"name":"Early outfit study","checkpoint":Campaign.snapshot(early_outfit)}, {"name":"Mid outfit study","checkpoint":Campaign.snapshot(mid_outfit)}, {"name":"Next level study","checkpoint":Campaign.snapshot(transition)}]}
	if not Campaign.valid_document(continuity_studies):push_error("Invalid continuity studies");quit(1);return
	file=FileAccess.open("res://test-results/continuity-fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify(continuity_studies));file.close()
	var night_wildlife=Loop.new(641023,0)
	night_wildlife.run_id="wildlife-night-study-2026-11-03"
	for completed in range(5):
		night_wildlife.spawned=night_wildlife.week_leaf_count();night_wildlife.step(1.0/60,0,false);night_wildlife.next_week()
	var animal_studies:={"version":1,"slots":[{"name":"Night wildlife","checkpoint":Campaign.snapshot(night_wildlife)},null,null]}
	if not Campaign.valid_document(animal_studies):push_error("Invalid wildlife study");quit(1);return
	file=FileAccess.open("res://test-results/wildlife-fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify(animal_studies));file.close()
	print("Created validated late-week, boss and workshop UI fixtures.")
	quit()
