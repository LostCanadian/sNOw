extends SceneTree
const Cycle = preload("res://scripts/challenge_cycle.gd")
const World = preload("res://scripts/ambient_world.gd")
const Loop = preload("res://scripts/loop.gd")
const Main = preload("res://main.tscn")
const Campaign = preload("res://scripts/campaign.gd")
const Visitors = preload("res://scripts/wildlife_visitors.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)
func _initialize() -> void:
	run.call_deferred()
func on_screen(point: Vector2) -> bool:
	return point.x > -30 and point.x < 390 and point.y > -30
func run() -> void:
	var sequence: Array = []
	for index in range(6): sequence.append(Cycle.sample(index*10+6).weather)
	check(sequence == ["sun","partly","cloud","wind","rain","storm"], "weather builds logically from sunlight to a storm")
	var continuous := true
	for step in range(20000):
		var before := Cycle.sample(step*0.01)
		var after := Cycle.sample(step*0.01+0.01)
		for field in Cycle.FIELDS+["storm"]:
			continuous = continuous and absf(before[field]-after[field]) < 0.005
	check(continuous, "lighting, cloud, rain, fog and wind stay continuous across every stage and calendar wrap")
	var ordered := true
	for night in range(16):
		var profile := Cycle.sample(night*Cycle.PERIOD+95)
		ordered = ordered and profile.moon == (7+night)%8 and profile.rare == (profile.moon==0)
	check(ordered, "each successive night advances one ordered lunar phase, with full-moon visitors only at full moon")
	check(Cycle.sample(95).moon_position == Cycle.sample(295).moon_position, "moon position stays fixed while its phase advances between nights")
	var wind_windows := 0
	var was_gust := false
	var storm_only := true
	for step in range(4000):
		var time := step*0.1
		var gust := Cycle.gust(time)
		if not gust.is_empty() and not was_gust: wind_windows += 1
		was_gust = not gust.is_empty()
		storm_only = storm_only and (gust.is_empty() or Cycle.sample(time).storm > 0.99)
	check(wind_windows == 4 and storm_only, "two calendars produce four isolated one-pass storm encounters, with no fair-weather wind")
	for pass_time in [56.0,146.0]:
		var game = Loop.new(55,1,true)
		game.week_time=pass_time;game.spawn_timer=999
		var rng_state: int = game.rng.state
		game.step(0.2,0,false)
		check(game.spawned==0 and game.boss_phase()=="warning", "a storm visit warns before releasing leaves")
		var struck := {}
		for frame in range(180):
			game.step(1.0/60,0,false)
			for leaf in game.leaves: struck[leaf.id]=true
		check(game.wind_released>0 and game.wind_released<=20 and struck.size()==game.wind_released and game.rng.state!=rng_state, "one bounded swept pass strips real, unique branch identities")
		var count: int = game.spawned
		game.step(0.2,0,false)
		check(game.spawned==count and not game.has_north_wind(), "the gust leaves completely and cannot repeat immediately")
		check(not game.is_boss() and game.status=="playing" and game.earned_points==0, "storm visits never become campaign bosses or award completion rewards")
	var world=World.new();root.add_child(world)
	var canonical:Rect2=World.backdrop_region()
	var region_stable:=true
	for time in [0.0,15.0,45.0,55.0,95.0,145.0,175.0,205.0]:
		world.configure("challenge",8,false,true,time);world.advance(0,false,false,false,false,0)
		region_stable=region_stable and World.backdrop_region()==canonical and world.landscape.material.shader.resource_path=="res://scripts/landscape.gdshader"
	check(region_stable, "every atmosphere uses identical mountain, house and horizon geometry from one painting")
	var sample_game=Loop.new(55,1,true)
	var before_rng: int = sample_game.rng.state
	world.configure(sample_game.run_id,8,false,true,95)
	world.advance(1,false,false,false,false,0)
	check(sample_game.rng.state==before_rng and sample_game.score==0, "calendar, lighting and visitor logic never consume gameplay RNG or award points")
	var frozen_clock:float=world.clock
	var frozen:Dictionary=world.visitors.lanes.duplicate(true)
	world.advance(3,true,false,false,false,0)
	check(world.clock==frozen_clock and world.visitors.lanes==frozen, "pause freezes entry, landing, departure and resident timers")
	var motion=World.Motion.new();motion.reset(0)
	var visitors=Visitors.new()
	var actions:={};var frames:={};var bounded:=true;var smooth:=true;var swap_safe:=true
	var previous:={}
	# Cover waxing->full->waning nights and all day/night/storm replacements.
	for frame in range(6500):
		var time:=frame/10.0
		visitors.advance(0.1,Cycle.sample(time),motion,time)
		var poses:Array=visitors.poses(motion,time,1.0)
		var kinds:={};var current:={}
		for pose in poses:
			kinds[pose.kind]=true;actions[pose.action]=true
			bounded=bounded and pose.frame>=0 and pose.frame<World.Wildlife.Sprites.RECTS[pose.sheet].size() and is_equal_approx(pose.alpha,0.90 if pose.kind=="wolf" else (0.85 if pose.kind=="bat" else 1.0))
			if pose.sheet=="travel":frames[pose.frame]=true
			current[pose.kind]=pose.position
			if previous.has(pose.kind): smooth=smooth and previous[pose.kind].distance_to(pose.position)<24
			else: swap_safe=swap_safe and not on_screen(pose.position)
		for kind in previous:
			if not current.has(kind):swap_safe=swap_safe and not on_screen(previous[kind])
		previous=current
		bounded=bounded and kinds.size()<=3
	check(bounded, "cycling actors remain bounded to three species and valid opaque atlas frames")
	check(smooth and swap_safe, "arrivals, exits and full-moon replacements never teleport or remove an on-screen animal")
	check(["fly_in","land","fly_out","descend","leave","perch","nibble"].all(func(a):return actions.has(a)), "owls fly in, land, watch and depart; squirrels perch, descend and run away")
	check(frames.size()==16, "all sixteen new flight, landing, descent and run frames are exercised")
	var roaming=Visitors.new();var choices:={};var visits:=0;var held:=true;var ground_only:=true;var ground_runs:=false
	var daylight:=Cycle.sample(0)
	for frame in range(3200):
		var clock:=frame/4.0
		roaming.advance(0.25,daylight,motion,clock)
		if roaming.squirrel_visits>visits:
			visits=roaming.squirrel_visits;choices[visits]=roaming.lanes.tree.climbs
		if roaming.lanes.has("tree") and roaming.lanes.tree.kind=="squirrel":
			held=held and roaming.lanes.tree.climbs==choices[visits]
			var pose:Dictionary=roaming.pose(roaming.lanes.tree,motion,clock,1.0)[0]
			if not roaming.lanes.tree.climbs:
				ground_only=ground_only and pose.plane=="ground" and pose.position.y==443 and pose.action not in ["climb","jump","descend"]
				ground_runs=ground_runs or pose.action=="run"
	var tree_visits:=choices.values().count(true)
	check(held and visits>15 and tree_visits>0 and tree_visits<visits,"each Challenge squirrel visit chooses once and retains its route through entry, residence and exit")
	check(ground_only and ground_runs,"Challenge ground-only visits stay on the ground even when departing")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	main.campaign=Campaign.new("user://cycle-test-no-save.json")
	main.campaign.challenge_unlocked=true;main.start_challenge()
	main.sim.week_time=95;main.sim.spawn_timer=999;main._physics_process(0.1)
	check(main.world.challenge and main.world.profile.time=="night" and main.sim.week==8, "actual Challenge play cycles atmosphere without advancing the campaign week")
	main.pause_game();var profile:Dictionary=main.world.profile.duplicate(true)
	main._physics_process(5)
	check(main.world.profile==profile and main.world.clock>0, "the real pause overlay keeps the same cycle and lunar phase")
	main.queue_free();world.queue_free();await process_frame
	await create_timer(0.5).timeout
	print("Challenge cycle: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
