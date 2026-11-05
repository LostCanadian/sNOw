extends SceneTree
const Loop=preload("res://scripts/loop.gd")
const Wind=preload("res://scripts/challenge_wind.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func resolve_all(game)->void:
	for leaf in game.leaves:game.resolve_leaf(leaf,true,leaf.home_slot)
	game.leaves.clear()
func gravity_sample(week:int)->float:
	var game=Loop.new(77);game.week=week;game.spawn_timer=999
	game.spawn_leaf();var leaf:Dictionary=game.leaves[0]
	leaf.position=Vector2(180,200);leaf.velocity=Vector2.ZERO
	leaf.flutter_strength=0;leaf.flutter_rate=0;leaf.flutter_phase=0
	game.step(1.0/60,0,false)
	return leaf.velocity.y
func _initialize()->void:
	for difficulty in range(3):
		var game=Loop.new(77,difficulty,true)
		var quota:int=[30,40,50][difficulty]
		var lull:=true
		for frame in range(1190):
			var before:int=game.spawned
			game.step(1.0/60,0,false)
			if game.week_time>10.1:lull=lull and game.spawned==before
			resolve_all(game)
		check(game.rescued==quota and lull,"difficulty %d releases its full wave then pauses ordinary shedding for recovery"%difficulty)
		var first:int=game.rescued
		while game.week_time<20.1:
			game.step(1.0/60,0,false);resolve_all(game)
		check(game.rescued>first and game.rescued-first<=game.shed_batch_size(),"the next wave begins with one bounded packet and no accumulated burst")
		check(game.active_leaf_limit()==200 and game.active_leaf_limit()>game.capacity(),"the 200-leaf ceiling still permits the difficulty's real loss allowance")
		game.week_time=180;var earlier:float=game.falling_scale()
		game.week_time=300;var later:float=game.falling_scale()
		game.week_time=500
		check(later>earlier and game.falling_scale()>later,"fall pressure continues increasing after the old three-minute plateau")
		# Sample real full-power physics in a localized gust, at identical x but
		# different heights. Isolate weather from flutter, targets and spawning.
		game=Loop.new(77,difficulty,true);game.spawn_timer=999
		game.week_time=11.0-1.0/60
		var profile:Dictionary=Wind.squall(11,difficulty,77)
		game.x=profile.lane-Loop.NOZZLE_OFFSET.x
		for y in [90.0,360.0]:
			game.spawn_leaf();var leaf:Dictionary=game.leaves[-1]
			leaf.position=Vector2(profile.lane,y);leaf.velocity=Vector2.ZERO
			leaf.flutter_strength=0;leaf.flutter_rate=0;leaf.flutter_phase=0
			leaf.lift_response=1;leaf.drag=0.65;leaf.attach_after=999
		game.step(1.0/60,0,true)
		check(game.leaves[0].velocity.y>0 and game.leaves[1].velocity.y<0,"a real squall overcomes distant full-upgrade airflow while close-range lift remains useful, difficulty %d"%difficulty)
	var game=Loop.new(77,1,true)
	for i in range(200):game.spawn_leaf()
	game.spawn_timer=0;game.week_time=11
	var recovered:Dictionary=game.leaves.pop_back();game.resolve_leaf(recovered,true,recovered.home_slot)
	game.step(1.0/60,0,false)
	check(game.leaves.size()==199,"freeing a slot during a lull does not create an overdue wave")
	game.week_time=20;game.step(1.0/60,0,false)
	check(game.leaves.size()==200 and game.challenge_wave_spawned==1,"a blocked wave cannot borrow future recovery slots or exceed the ceiling")
	check(is_equal_approx(gravity_sample(1),gravity_sample(2)) and is_equal_approx(gravity_sample(2),gravity_sample(3)),"the first three campaign weeks retain their actual falling acceleration")
	check(gravity_sample(4)>gravity_sample(3) and gravity_sample(12)>gravity_sample(4),"actual campaign falling acceleration increases from week four onward")
	for week in [1,2,3,4,12,13]:
		game=Loop.new(77);game.week=week
		var expected:float=1.0+0.03*clampi(week-3,0,9)
		check(is_equal_approx(game.falling_scale(),expected),"week %d has the intended fall-pressure progression"%week)
	check([1,2,3,13].all(func(week):return Wind.squall(11,1,77,week).is_empty()),"opening weeks and the North Wind finale do not receive extra squalls")
	check(Wind.squall(11,1,77,12).down>Wind.squall(11,1,77,4).down,"later campaign weeks receive stronger localized downdrafts")
	var warning:Dictionary=Wind.squall(7,1,77)
	var blast:Dictionary=Wind.squall(11,1,77)
	check(warning.warning>0 and warning.down==0 and blast.down>0,"the quiet lead-in precedes the downdraft force")
	check(Wind.exposure(Vector2(blast.lane,90),blast.lane,blast.radius)>Wind.exposure(Vector2(blast.lane,360),blast.lane,blast.radius) and Wind.exposure(Vector2(blast.lane+blast.radius+1,90),blast.lane,blast.radius)==0,"squalls concentrate on high leaves inside the affected column")
	check(Wind.pressure(250)>Wind.pressure(150) and Wind.pressure(400)>Wind.pressure(250) and Wind.pressure(10000)<=2.25,"weather escalates past three minutes and stays bounded")
	var smooth:=true;var previous:=Vector2.ZERO
	for frame in range(40000):
		var gust:Dictionary=Wind.squall(frame*0.01,1,77)
		var force:=Vector2(gust.get("cross",0.0),gust.get("down",0.0))
		smooth=smooth and force.distance_to(previous)<7
		previous=force
	check(smooth,"gust force ramps smoothly across warnings, blasts, gaps and difficulty steps")
	print("Balance pacing: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
