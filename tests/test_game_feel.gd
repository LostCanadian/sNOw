extends SceneTree
const Loop=preload("res://scripts/loop.gd")
const Campaign=preload("res://scripts/campaign.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var game=Loop.new(55)
	game.spawn_leaf();var leaf:Dictionary=game.leaves[0]
	var home:int=leaf.home_slot;var point:Vector2=game.slots[home].position
	check(game.capture_slot(point,point)==-1,"a freshly vacated branch cannot immediately recapture a leaf")
	game.week_time=4.99
	check(game.capture_slot(point,point)==-1,"the vacated spot remains unavailable for the complete five seconds")
	game.week_time=5.01
	check(game.capture_slot(point+Vector2(0,25),point-Vector2(0,25))==home,"the same spot accepts a swept capture after its cooldown")
	game.week_time=0;game.spawn_leaf();var other:int=game.leaves[1].home_slot
	game.slots[other].capture_after=0
	var p:Vector2=game.slots[other].position
	check(game.capture_slot(p,p)==other,"an older empty spot is still available while a fresh spot cools")
	game.prepare_shedding()
	check(game.slots[home].capture_after==0,"a new level schedule resets temporary branch cooldowns")
	game=Loop.new(77)
	for i in range(8):game.spawn_leaf()
	game.spawn_timer=999
	for falling in game.leaves:
		falling.position=game.nozzle()+Vector2(0,-55);falling.velocity=Vector2.ZERO
		falling.drag=0.65;falling.flutter_rate=0;falling.flutter_phase=0
	game.step(1.0/60,0,true)
	var speeds:Array=game.leaves.map(func(l):return l.velocity.y)
	check(speeds.max()-speeds.min()>0.4,"an overlapping clump receives different vertical blower accelerations")
	for frame in range(40):game.step(1.0/60,0,true)
	var heights:Array=game.leaves.map(func(l):return l.position.y)
	check(game.leaves.size()==8 and heights.max()-heights.min()>8,"vertical response and lift-speed variation spread a clump over time")
	var retry=Loop.new(77)
	for i in range(8):retry.spawn_leaf()
	check(retry.leaves.map(func(l):return l.lift_response)==game.leaves.map(func(l):return l.lift_response),"leaf response is deterministic across retries")
	retry.energy_locked=true;retry.charge=.2;retry.spawn_timer=999
	for falling in retry.leaves:
		falling.position=retry.nozzle()+Vector2(0,-55);falling.velocity=Vector2.ZERO
		falling.drag=.65;falling.flutter_rate=0;falling.flutter_phase=0
	retry.step(1.0/60,0,true)
	check(retry.low_power and is_equal_approx(retry.leaves[0].velocity.y,retry.leaves[1].velocity.y),"the gentle recharge draft retains its existing holding power")
	for seed_value in [17,55,77,193]:
		var wind=Loop.new(seed_value,1);wind.week=13;wind.retire_seasonal_foliage();wind.prepare_shedding()
		var previous_cycle:=0;var previous_count:=0;var passes:=0;var consistent:=true
		var rng_before:int=wind.rng.state;wind.choose_wind_lane()
		check(wind.rng.state==rng_before,"wind lane selection cannot consume leaf-physics RNG")
		for frame in range(1300):
			wind.step(1.0/60,0,false)
			for falling in wind.leaves:wind.resolve_leaf(falling,true,falling.home_slot)
			wind.leaves.clear()
			if wind.wind_cycle!=previous_cycle:
				consistent=consistent and previous_count>=40 and previous_count<=56
				passes+=1;previous_cycle=wind.wind_cycle
			previous_count=wind.wind_released
			if passes==4:break
		check(consistent and passes==4,"seed %d sweeps full corridors in bounded packets instead of mostly empty passes"%seed_value)
	var saved:Dictionary=Campaign.snapshot(Loop.new());saved.rules=9
	check(Campaign.valid_checkpoint(saved) and Campaign.restore(saved)!=null,"earlier saved campaigns remain compatible with the gameplay refinement")
	print("Game feel: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
