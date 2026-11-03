extends SceneTree
const Loop=preload("res://scripts/loop.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Piles=preload("res://scripts/leaf_piles.gd")
const Main=preload("res://main.tscn")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func press(main,caption: String) -> void:
	for action in main.overlay.find_children("*","Button",true,false):
		if action.text==caption:action.pressed.emit();return
	check(false,"missing button: "+caption)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	check(Loop.Canopy.SLOT_COUNT==2160 and is_equal_approx(Loop.LEAF_RADIUS,7.8),"25 percent fewer leaves, 30 percent larger")
	var piles=Piles.new()
	var first:=piles.deposit(180,0)
	var last:=first
	for i in range(40):last=piles.deposit(180,i*2)
	check(last<first-40,"overlapping leaves create a growing pile, without a shallow height cap")
	check(piles.surface(180,1)>last+35,"front and rear piles have independent support surfaces")
	var game=Loop.new(77)
	var old:Dictionary=Campaign.snapshot(game)
	old.rules=6
	for id in range(2160,2880):old.leaf_ids.append(id)
	for i in range(80):old.leaf_ids[i]=-1
	old.missed=80;old.order=old.order.filter(func(id):return id>=80)
	var loaded=Campaign.restore(old)
	check(loaded!=null and loaded.missed==60 and loaded.attached_count()==2100,"dense previous saves migrate gaps proportionally")
	check(Campaign.valid_checkpoint(Campaign.snapshot(loaded)),"migrated saves remain valid and conserve unique identities")
	var weak=Loop.new(77)
	weak.spawn_leaf();weak.spawn_timer=9999
	weak.energy_locked=true;weak.charge=0
	var floating:Dictionary=weak.leaves[0]
	floating.position=weak.nozzle()+Vector2(0,-65);floating.velocity=Vector2(0,12)
	var initial_y:float=floating.position.y
	for frame in range(180):weak.step(1.0/60,0,true)
	check(weak.low_power and weak.blowing and weak.charge>0.5,"exhausted held blower keeps a draft and recharges")
	check(floating.position.y<initial_y+8 and floating.velocity.y<0 and not floating.lifted and weak.rescued==0,"low power arrests a falling leaf and raises it gently without granting tree capture")
	var partial:float=weak.charge
	weak.step(1.0/60,0,false);weak.step(1.0/60,0,true)
	check(weak.blowing and not weak.low_power and not weak.energy_locked and weak.charge<partial,"release and press restores full power at partial charge")
	weak.energy_locked=true;weak.charge=0.9999
	weak.step(1.0/60,0,true)
	check(weak.blowing and not weak.low_power and not weak.energy_locked,"full charge resumes full power without releasing the control")
	var frozen_charge:float=weak.charge
	weak.status="workshop";weak.step(1,0,true)
	check(weak.charge==frozen_charge and not weak.blowing and not weak.low_power,"non-playing scenes cannot run or recharge the blower")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	main.leaf_renderer.clear()
	var id:int=game.shedding_order[0]
	var slot:Dictionary=game.slots[game.find_attached_leaf(id)]
	main.leaf_renderer.leaf(id,slot.position,slot.angle,game.leaf_colour(id))
	main.leaf_renderer.upload()
	var rank:int=main.leaf_renderer.rank[id]
	var palette:Image=main.leaf_renderer.palette_image()
	check(palette.get_pixel(rank%128,rank/128).is_equal_approx(game.leaf_colour(id)),"the GPU palette retains the exact identity tint before detachment")
	var pose:PackedFloat32Array=main.leaf_renderer.buffers[0].slice(rank*12,rank*12+12)
	game.spawn_leaf()
	var leaf:Dictionary=game.leaves[0]
	main.leaf_renderer.leaf(leaf.id,leaf.position,leaf.angle,leaf.colour)
	main.leaf_renderer.upload()
	check(main.leaf_renderer.buffers[0].slice(rank*12,rank*12+12)==pose,"detachment preserves the same instance, depth, scale and pose")
	main.leaf_renderer.leaf(0,Vector2(180,495),0,Color.WHITE,1,true)
	main.leaf_renderer.leaf(1,Vector2(180,495),0,Color.WHITE,1,true)
	main.leaf_renderer.upload()
	check(main.leaf_renderer.buffers[2][main.leaf_renderer.rank[0]*12]>0 and main.leaf_renderer.buffers[0][main.leaf_renderer.rank[0]*12]==0,"front ground leaves transfer to the pass after the player")
	check(main.leaf_renderer.buffers[0][main.leaf_renderer.rank[1]*12]>0 and main.leaf_renderer.buffers[2][main.leaf_renderer.rank[1]*12]==0,"rear ground leaves remain in the pass before the player")
	palette=main.leaf_renderer.palette_image()
	var front_rank:int=main.leaf_renderer.rank[0]
	check(palette.get_pixel(front_rank%128,front_rank/128)==Color.WHITE,"front/rear transfer retains the identity's tint in the shared GPU palette")
	main.preview_mode=true;main.preview_weather=1
	for flake in main.snow:flake.active=false
	main.snow_clock=1;main.advance_snow(0.01)
	check(main.snow.filter(func(f):return f.active).all(func(f):return f.y<0),"first warning snow starts above the screen")
	for i in range(80):main.advance_snow(0.1)
	var existing:Array=main.snow.filter(func(f):return f.active)
	main.snow_clock=1;main.advance_snow(0.01)
	check(main.snow.filter(func(f):return f.active and not existing.has(f)).all(func(f):return f.y<0),"increasing snow density never spawns a flake mid-screen")
	var path:="user://polish-campaign-%d.json"%Time.get_ticks_usec()
	main.campaign=Campaign.new(path)
	main.start_run(0,"Polish study")
	main.sim.week=3;main.sim.earned_points=4;main.sim.points=4
	main.save_boundary();main.show_continue()
	check(main.overlay.find_children("*","Button",true,false).any(func(b):return b.text=="Upgrades"),"Continue offers upgrades before starting the level")
	main.open_workshop("continue")
	check(main.overlay.find_children("*","Button",true,false).all(func(b):return b.tooltip_text.is_empty() and b.get_theme_stylebox("hover")==b.get_theme_stylebox("normal")),"workshop has no hover overlays or tooltip popups")
	check(main.overlay.find_children("*","Button",true,false).filter(func(b):return str(b.name).begins_with("Equipment")).all(func(b):return b.text.is_empty() and b.icon is AtlasTexture),"equipment tabs use paper images without captions")
	check(main.overlay.find_children("*","Label",true,false).all(func(label):return label.text!="Saved"),"workshop has no Saved footer")
	main.purchase(1,0);main.close_workshop()
	check(main.mode=="continue" and Campaign.restore(Campaign.new(path).slots[0].checkpoint).owned==[10] and main.level_checkpoint.points==3,"Continue purchases persist once in the starting checkpoint")
	main.begin_intro();main.finish_story();main.sim.step(0.1,0,false)
	check(not main.sim.buy(0,0),"mid-attempt upgrades cannot alter the live loadout")
	main.pause_game();main.confirm_restart();main.open_workshop("restart")
	main.purchase(0,0);main.close_workshop()
	check(main.sim.points==3 and main.sim.owned==[10] and Campaign.new(path).slots[0].checkpoint.points==3,"restart purchases stay pending while the attempt is paused")
	press(main,"Cancel")
	check(main.mode=="play" and main.restart_draft.is_empty() and main.sim.points==3 and main.sim.week_time>0,"cancelling restart discards pending upgrades and resumes the untouched attempt")
	main.pause_game();main.confirm_restart();main.open_workshop("restart");main.purchase(0,0);main.close_workshop()
	press(main,"Restart level")
	check(main.mode=="intro" and main.sim.week_time==0 and main.sim.owned==[10,0] and Campaign.new(path).slots[0].checkpoint.points==2,"confirmed restart commits the selected kit and persists its exact currency")
	main.show_continue();main.open_workshop("continue");main.confirm_reset_upgrades();press(main,"Cancel")
	check(main.workshop_game.owned==[10,0],"reset cancellation preserves all upgrades")
	main.confirm_reset_upgrades();press(main,"Reset all upgrades")
	check(main.workshop_game.owned.is_empty() and main.workshop_game.points==4 and Campaign.new(path).slots[0].checkpoint.points==4,"confirmed reset refunds all Gold Leaves and updates the checkpoint")
	main.close_workshop();main.sim.status="lost";main.sim.score=900;main.show_result();main.finish_tally()
	main.open_workshop("retry");main.purchase(2,0);main.close_workshop()
	check(main.sim.status=="lost" and main.sim.score==900 and main.sim.owned.is_empty() and main.level_checkpoint.owned==[20],"retry upgrades update the checkpoint without changing the failed result")
	main.restart_level()
	check(main.sim.owned==[20] and main.sim.points==3 and main.sim.score==0,"retry uses the upgraded level-start kit and its original score")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	main.queue_free();await process_frame
	print("Beta polish: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
