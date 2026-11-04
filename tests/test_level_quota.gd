extends SceneTree
const Loop=preload("res://scripts/loop.gd")
const Campaign=preload("res://scripts/campaign.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func study(target:int=2) -> RefCounted:
	var game=Loop.new(55)
	game.shedding_order.resize(target);game.spawn_timer=999
	return game
func _initialize() -> void:
	var game=study(3)
	for i in range(3):game.spawn_leaf()
	game.spawn_timer=0;game.step(1.0/60,0,false)
	check(game.spawned>3 and game.status=="playing" and game.week_handled==0,"ordinary leaves keep falling past the quota-sized initial schedule while earlier leaves are still airborne")
	check(game.week_leaf_count()==3 and game.attached_count()+game.leaves.size()==2160,"extending the stream cannot extend the goal or invent leaves")
	var seen:Dictionary={};var unique:=true
	for leaf in game.leaves:
		unique=unique and not seen.has(leaf.id);seen[leaf.id]=true
	check(unique,"the stream cannot detach an identity that is already airborne")
	game=study()
	for i in range(3):game.spawn_leaf()
	var first:Dictionary=game.leaves[0];var landed:Dictionary=game.leaves[1];var pending:Dictionary=game.leaves[2]
	game.resolve_leaf(first,true,pending.home_slot)
	landed.position.y=Loop.GROUND;landed.velocity=Vector2.ZERO
	game.step(1.0/60,0,false)
	check(game.status=="workshop" and game.week_handled==2 and game.leaves.size()==1,"the exact quota ends the level immediately with another leaf still airborne")
	check(game.week_rescued==1 and game.week_missed==1 and game.points==2 and game.earned_points==2,"only resolved leaves contribute score, frost and the once-only level reward")
	var score:int=game.score;var missed:int=game.missed;var random_state:int=game.rng.state
	var live_ids:Array=game.slots.map(func(slot):return slot.leaf_id)
	var checkpoint:Dictionary=Campaign.snapshot(game)
	check(Campaign.valid_checkpoint(checkpoint),"a quota completion with unfinished falls produces a valid boundary checkpoint")
	check(checkpoint.leaf_ids.count(-1)==missed and checkpoint.leaf_ids.has(pending.id) and checkpoint.leaf_ids.has(first.id),"checkpoint reconciliation preserves both identities even when another rescue filled the unfinished leaf's home")
	check(game.slots.map(func(slot):return slot.leaf_id)==live_ids and game.leaves[0].position==pending.position,"saving cannot pop unfinished leaves back onto the live closing scene")
	var restored=Campaign.restore(checkpoint)
	check(restored!=null and restored.week_handled==2 and restored.week_rescued==1 and restored.week_missed==1 and restored.score==score,"completed quota and weekly results survive save and reload without extra awards")
	for frame in range(900):game.advance_completed_leaves(1.0/60)
	check(game.closing_settled and pending.get("closing_grounded",false),"unfinished leaves keep falling decoratively after the level ends")
	check(game.score==score and game.missed==missed and game.week_handled==2 and game.rng.state==random_state,"decorative landings cannot change score, danger, progress or gameplay randomness")
	check(Campaign.snapshot(game)==checkpoint,"watching the completed scene cannot change its saved boundary")
	game.step(10,1,true)
	check(game.score==score and game.points==2,"holding controls after completion cannot repeat the level reward")
	check(game.next_week() and game.week_handled==0 and game.week_missed==0 and game.missed==missed and game.regrown==0,"the next week resets the quota without charging unfinished falls as misses or regrowth")
	check(Campaign.valid_checkpoint(Campaign.snapshot(game)),"the next week's neutral canopy reconciliation still conserves every identity")
	game=study(4);game.owned.assign([10,12]);game.tiers=Loop.Upgrades.counts(game.owned)
	game.spawn_leaf();var leaf:Dictionary=game.leaves[0]
	leaf.position=Vector2(game.x,Loop.GROUND);game.resolve_leaf(leaf,false);game.leaves.clear()
	check(game.week_handled==1 and game.activate_surge() and game.week_handled==1,"recovering a ground leaf cannot rewind quota progress")
	game.resolve_leaf(leaf,true,leaf.home_slot)
	check(game.week_handled==1 and game.week_rescued==1 and game.week_missed==0,"a recovered leaf cannot count its first fall twice toward the quota")
	game.resolve_leaf(leaf,true,leaf.home_slot)
	check(game.week_handled==1,"duplicate resolutions cannot advance the quota")
	game=study()
	# Fill a real miss ledger up to the danger limit, with the last landing
	# reaching both the quota and the losing condition in the same physics step.
	game.prepare_shedding();game.shedding_order.resize(game.capacity())
	for i in range(game.capacity()):
		game.spawn_leaf();leaf=game.leaves[-1]
		if i<game.capacity()-1:game.resolve_leaf(leaf,false)
		else:leaf.position=Vector2(180,Loop.GROUND);leaf.velocity=Vector2.ZERO
	game.step(1.0/60,0,false)
	check(game.status=="lost" and game.points==0 and game.week_handled==game.capacity(),"the danger limit takes precedence when the same landing also reaches the quota")
	var older:=checkpoint.duplicate(true);older.rules=11;older.erase("week_handled")
	restored=Campaign.restore(older)
	check(restored!=null and restored.status=="workshop" and restored.score==score,"older completed checkpoints remain compatible")
	var invalid:=checkpoint.duplicate(true);invalid.week_handled=-1
	check(not Campaign.valid_checkpoint(invalid),"invalid quota counters cannot enter saved campaigns")
	game=Loop.new(55);game.week=13;game.retire_seasonal_foliage();game.prepare_shedding();game.shedding_order.resize(3)
	for i in range(960):game.spawn_leaf()
	check(game.leaves.size()==960 and game.attached_count()==0 and not game.spawn_leaf(),"continuous shedding remains bounded by real canopy supply without fabricating leaves")
	print("Level quota: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
