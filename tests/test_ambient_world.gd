extends SceneTree
const World=preload("res://scripts/ambient_world.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Loop=preload("res://scripts/loop.gd")
const Main=preload("res://main.tscn")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world=World.new();root.add_child(world)
	var moods:={};var nights:=0;var rain:=false;var mist:=false
	for week in range(1,14):
		var p:Dictionary=World.Profile.choose("persisted-campaign",week)
		moods[p.name]=true;nights+=int(p.time=="night");rain=rain or p.rain>0;mist=mist or p.fog>=0.6
	check(moods.size()==13 and nights==2 and rain and mist,"the campaign has thirteen distinct cosmetic moods with rain, fog and two nights")
	check([1,2,12,13].all(func(w):return World.Profile.choose("same",w).time=="day"),"opening weeks, week twelve and North Wind retain daylight")
	var game=Loop.new();var before:Dictionary=Campaign.snapshot(game)
	var restored=Campaign.restore(before)
	check(World.Profile.choose(game.run_id,6)==World.Profile.choose(restored.run_id,6),"cosmetic selection survives save/restore without adding a save field")
	world.configure(game.run_id,6);var profile:Dictionary=world.profile.duplicate(true)
	world.advance(4,false,false,false,false,0,true,55)
	check(Campaign.snapshot(game)==before,"ambient animation and owl reactions never consume the simulation RNG or change a checkpoint")
	world.configure(game.run_id,6)
	check(world.clock==4 and world.profile==profile,"repeated configuration does not reset ambient movement")
	var clock:float=world.clock;var reaction:float=world.reaction_until
	world.advance(5,true,false,false,false,0,true,55)
	check(world.clock==clock and world.reaction_until==reaction,"pause freezes movement, weather and reaction timers")
	world.advance(0.1,false,false,false,false,0,true,55)
	check(world.reaction_until==reaction,"holding the blower cannot retrigger the owl during its cooldown")
	var rare_id:=""
	for i in range(100):
		if World.Profile.choose("moon-study-%d"%i,6).rare:rare_id="moon-study-%d"%i;break
	check(not rare_id.is_empty(),"a full moon is genuinely selectable")
	world.configure(rare_id,6)
	var kinds:=world.animal_poses().map(func(a):return a.kind)
	check(world.profile.moon==0 and kinds.has("wolf") and kinds.has("bat") and kinds.has("owl") and not kinds.has("rabbit"),"rare moonlight selects wolf and bat alongside the owl")
	var bounded:=true
	for week in range(1,14):
		world.configure("animal-study",week)
		for frame in range(40):
			world.advance(0.5,false,false,false,false,0)
			var species:={}
			for a in world.animal_poses():
				species[a.kind]=true;bounded=bounded and a.frame>=0 and a.frame<16 and a.position.y<480
			bounded=bounded and species.size()<=3
	check(bounded,"at most three species remain behind the playable path and use bounded atlas frames")
	world.configure("coat-study",5);world.advance(0,false,false,false,false,0)
	var coats:=world.animal_poses().filter(func(a):return a.kind=="rabbit")
	check(coats.size()==2 and coats.all(func(a):return a.alpha>0 and a.alpha<0.9),"the rabbit gradually blends painted coats rather than switching colors abruptly")
	world.advance(0,false,false,false,true,1)
	check(world.animal_poses().any(func(a):return a.kind=="rabbit" and a.frame in [8,9]),"loss uses the white rabbit coat")
	world.advance(0,false,false,true,false,0)
	check(world.animal_poses().any(func(a):return a.kind=="rabbit" and a.frame in [4,5]),"victory restores the summer coat")
	world.advance(1,false,true,false,false,0)
	check(world.rustle(7,Vector2(200,200))==Vector3.ZERO,"reduced effects stops leaf rustling")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false);main.start_run();main.finish_story()
	main._physics_process(0.5);var frozen:float=main.world.clock;main.pause_game();main._physics_process(1)
	check(main.world.clock==frozen,"the actual pause flow freezes the ambient world")
	main.resume_game();main._physics_process(0.5)
	check(main.world.clock>frozen,"resuming continues the same ambient clock")
	main.show_season_lab();main.world_preview_week=6;main._physics_process(0.1)
	check(main.world.profile.time=="night","the scene browser can review a real nighttime profile")
	main.queue_free();world.queue_free();await process_frame
	print("Ambient world: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
