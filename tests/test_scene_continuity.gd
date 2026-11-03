extends SceneTree
const Main=preload("res://main.tscn")
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
	main.sim.week_missed=int(main.sim.capacity()*0.8);main.advance_snow(0.2)
	check(main.snow.any(func(f):return f.active),"warning pressure enables snowfall")
	main.snow[0].active=true;main.snow[0].y=220
	main.sim.status="workshop";main.sim.earned_points=2;main.sim.points=2
	main.continue_week()
	check(main.mode=="intro" and main.sim.week==2 and main.snow.all(func(f):return not f.active),"starting the next level clears all surviving warning flakes")
	main.finish_story();main.advance_snow(2)
	check(main.snow.all(func(f):return not f.active),"safe opening gameplay cannot display snow")
	main.sim.week_missed=int(main.sim.capacity()*0.8);main.advance_snow(0.2)
	check(main.snow.filter(func(f):return f.active).all(func(f):return f.y<0),"new warning snow still enters from the top")
	for frame in range(25):main.advance_snow(0.1)
	main.sim.week_missed=0;main.advance_snow(0.01)
	check(main.snow.all(func(f):return not f.active),"recovering below the danger threshold clears existing snow too")
	main.sim.week_missed=int(main.sim.capacity()*0.8);main.advance_snow(0.2)
	check(main.snow.filter(func(f):return f.active).all(func(f):return f.y<0),"warning snowfall cannot reappear halfway down the screen after recovery")
	main.begin_intro()
	check(main.snow.all(func(f):return not f.active),"every intro route resets the weather pool")
	main.sim.status="lost";main.mode="lost";main.clear_overlay();main.begin_winter_fall()
	main.winter_fall.finish_preview()
	main._physics_process(main.DEFEAT_HOLD-0.1)
	check(main.overlay==null,"the finished loss scene remains visible before Results")
	main.pause_game();var frozen:float=main.defeat_hold_time;main._physics_process(1)
	check(main.defeat_hold_time==frozen,"pause freezes the post-loss hold")
	main.resume_game();main._physics_process(0.2)
	check(main.overlay==null and main.mode=="lost" and is_instance_valid(main.ending_continue),"loss offers Continue after the extra hold")
	main._physics_process(45)
	check(main.overlay==null,"the completed snow scene keeps playing until Continue is selected")
	main.ending_continue.pressed.emit()
	check(main.overlay!=null and main.mode=="lost","Continue opens loss Results")
	var matching:bool=main.defeat_regions.size()==12 and main.DEFEAT_WARDROBE.get_image().get_mipmap_count()>0
	for week in range(1,13):
		main.sim.week=week;main.mode="play";main.sim.status="playing"
		var current:int=main.outfit_index()
		main.mode="lost";main.sim.status="lost"
		matching=matching and current==week-1 and main.outfit_index()==current and main.defeat_regions[current].size.y>100
	check(matching,"all twelve defeats select a sad pose matching the level's current outfit")
	var preview_matching:=true
	for week in range(1,13):
		main.sim.week=week
		main.show_season_lab()
		var current:int=main.outfit_index()
		for season in [1,2,0]:
			main.set_preview(season)
			preview_matching=preview_matching and main.outfit_index()==current and current==week-1
	check(preview_matching,"the season preview keeps the current clothing through warning, winter defeat and autumn")
	main.preview_mode=false
	var game=Loop.new()
	var covered:=true
	for p in [Vector2(180,255),Vector2(190,260),Vector2(200,270),Vector2(190,280),Vector2(205,285)]:
		var distance:=INF
		for slot in game.slots:distance=minf(distance,p.distance_to(slot.position))
		covered=covered and distance<10
	check(covered,"the actual central fork gap has nearby foliage throughout its interior")
	check(main.VICTORY_HOLD>=5.5 and main.DEFEAT_HOLD>=3,"both finished endings get several extra seconds before the next screen")
	main.queue_free();await process_frame
	print("Scene continuity: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
