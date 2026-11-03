extends SceneTree
const Main=preload("res://main.tscn")
const Campaign=preload("res://scripts/campaign.gd")
const TREE_ART=preload("res://assets/art/season_tree.png")
const Loop=preload("res://scripts/loop.gd")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	main.start_run();main.finish_story()
	main.sim.week=13;main.sim.earned_points=24;main.sim.points=24;main.sim.status="won"
	main._physics_process(1.0/60)
	main._physics_process(main.FLOWER_DURATION)
	check(main.mode=="won" and main.overlay==null,"flowers finish before any closing card or Results overlay appears")
	main._physics_process(main.VICTORY_HOLD-0.1)
	check(main.mode=="won" and main.overlay==null,"completed flowers remain visible for a few seconds")
	main._physics_process(0.2)
	check(main.mode=="victory_outro" and main.visual_mode()=="won" and main.overlay==null,"the victory sentence gets its own story card over the completed flower scene")
	var score:int=main.sim.score
	main.pause_for_focus();var frozen:float=main.story_time;main._physics_process(1)
	check(main.mode=="paused" and main.story_time==frozen,"focus loss freezes the victory closing card")
	main.resume_game();main._physics_process(0.7)
	main.finish_story()
	check(main.mode=="won" and main.overlay!=null and main.sim.score==score,"Results follow the closing card without awarding victory twice")
	check(main.overlay.find_children("*","Label",true,false).all(func(label):return not label.text.contains("first flower")),"the victory sentence is absent from Results button slots")
	var win_path:="user://finale-win-%d.json"%Time.get_ticks_usec()
	main.campaign=Campaign.new(win_path)
	main.campaign.store(0,"Winter kept",Campaign.snapshot(main.sim))
	main.load_slot(0)
	check(main.mode=="won" and main.ending_time==0 and main.overlay==null and main.sim.score==score,"loading a completed finale replays its flowers and closing card without awarding points again")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(win_path+suffix):DirAccess.remove_absolute(win_path+suffix)
	var branches:=true
	var moved:={}
	var image:Image=TREE_ART.get_image()
	for item:Vector4 in Loop.Canopy.BranchFill.REPLACEMENTS:
		branches=branches and image.get_pixel(int(item.y),int(item.z)).a>0.86 and not moved.has(int(item.x))
		moved[int(item.x)]=true
	check(branches and moved.size()==280,"middle-right sprays attach to actual painted bark with stable unique slot IDs")
	var baseline=Loop.new()
	var boots=Loop.new();boots.owned.assign([0,1]);boots.tiers=Loop.Upgrades.counts(boots.owned)
	check(baseline.stats().speed==50 and is_equal_approx(boots.stats().speed,61),"slower starting movement makes two early speed upgrades materially useful")
	for difficulty in range(3):
		var game=Loop.new(55,difficulty)
		var valid:=true
		for week in range(12):
			game.spawned=game.week_leaf_count();game.step(1.0/60,0,false)
			game.next_week()
			valid=valid and Campaign.valid_checkpoint(Campaign.snapshot(game)) and game.attached_count()+game.seasonal_fallen+game.missed-game.regrown==Loop.Canopy.SLOT_COUNT
		check(valid and game.attached_count()==960 and game.seasonal_fallen==1200 and game.missed==0 and game.regrown==0,"healthy difficulty %d visibly thins through the campaign without charging player misses or repeat rewards"%difficulty)
		check(Loop.RECOVERY_FLOOR>=game.week_leaf_count() and game.week_leaf_count()>game.capacity()*3,"difficulty %d keeps enough finale leaves for a meaningful miss allowance"%difficulty)
		var checkpoint:Dictionary=Campaign.snapshot(game)
		var restored=Campaign.restore(checkpoint)
		check(restored.seasonal_fallen==game.seasonal_fallen and restored.slots==game.slots and restored.points==game.points,"seasonal gaps and upgrade budgets survive a retry exactly")
		var rejected:=checkpoint.duplicate(true);rejected.seasonal_fallen+=1
		check(not Campaign.valid_checkpoint(rejected),"mismatched seasonal gap history is rejected")
		# A perfect-response study checks finite scheduling and duplicate protection,
		# not whether a human can rescue every gust on a device.
		var seen:={};var duplicate:=false
		for frame in range(9000):
			game.step(1.0/60,0,false)
			for leaf in game.leaves:
				duplicate=duplicate or seen.has(leaf.id);seen[leaf.id]=true
				game.resolve_leaf(leaf,true,leaf.home_slot)
			game.leaves.clear()
			if game.status!="playing":break
		check(game.status=="won" and not duplicate and seen.size()==game.week_leaf_count(),"all scheduled identities in difficulty %d can be stripped exactly once and the encounter finishes"%difficulty)
		var depleted=Campaign.restore(checkpoint)
		var missing:=0
		for slot in depleted.slots:
			if slot.leaf_id>=0 and missing<240:slot.leaf_id=-1;missing+=1
		depleted.missed=240;depleted.index_canopy();depleted.prepare_shedding()
		var minimum:Dictionary=Campaign.snapshot(depleted)
		check(depleted.attached_count()==720 and Campaign.valid_checkpoint(minimum),"the protected minimum remains a valid playable finale checkpoint")
		for frame in range(3000):
			depleted.step(1.0/60,0,false)
			if depleted.status!="playing":break
		check(depleted.status=="lost" and depleted.week_missed==depleted.capacity(),"a depleted difficulty %d finale still has enough real leaves to lose through missed gusts"%difficulty)
	var wind=Loop.new(77);wind.week=13;wind.prepare_shedding()
	wind.step(0.2,0,false)
	check(wind.spawned==0 and wind.boss_phase()=="warning","the North Wind telegraphs before detaching anything")
	wind.week_time=1.4;wind.wind_cycle=0;wind.wind_lane=220
	var path:Array[Vector2]=Loop.NorthWind.segment(wind.week_time,wind.week_time+1.0/60,220)
	var original_positions:={}
	for slot in wind.slots:original_positions[slot.leaf_id]=slot.position
	wind.step(1.0/60,0,false)
	var swept:bool=wind.spawned>0 and wind.spawned<=6
	for leaf in wind.leaves:
		var origin:Vector2=original_positions[leaf.id]
		swept=swept and origin.distance_to(Geometry2D.get_closest_point_to_segment(origin,path[0],path[1]))<=Loop.NorthWind.RADIUS
	check(swept,"a visible swept path strips only nearby real leaves in bounded packets")
	var count:int=wind.spawned
	wind.week_time=3.0;wind.step(1.0/60,0,false)
	check(wind.spawned==count and wind.boss_phase()=="rest","the recovery phase does not trigger an extra wind packet")
	wind.spawn_timer=0;wind.step(1.0/60,0,false)
	check(wind.spawned==count+3 and wind.boss_phase()=="rest","ordinary leaves keep falling between North Wind passes")
	var path_wind=Loop.NorthWind
	var first:Vector2=path_wind.center(path_wind.WARNING,220)
	var last:Vector2=path_wind.center(path_wind.WARNING+path_wind.SWEEP-0.001,220)
	var upper:Vector2=path_wind.point(0.25,220,1)
	var lower:Vector2=path_wind.point(0.75,220,1)
	check(first.x< -100 and last.x>460 and upper.y-lower.y>90,"a gust curves above and below its lane and exits fully offscreen")
	check(path_wind.center(path_wind.PERIOD+path_wind.WARNING,220).x>460,"the next approach enters from the opposite side")
	check(Loop.NorthWind.force(Vector2(1000,1000),1.4,220)==Vector2.ZERO and Loop.NorthWind.direction(5.8)<0,"the gust has a local force field and reverses its next approach")
	var old:Dictionary=Campaign.snapshot(Loop.new());old.rules=7;old.erase("seasonal_fallen");old.week=13;old.earned_points=24;old.points=24
	var migrated=Campaign.restore(old)
	check(migrated!=null and migrated.attached_count()==960 and migrated.seasonal_fallen==1200 and Campaign.valid_checkpoint(Campaign.snapshot(migrated)),"older full-canopy finale saves adopt the new season once without losing score or currency")
	main.queue_free();await process_frame
	print("Finale: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
