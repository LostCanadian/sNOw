extends SceneTree
const Loop=preload("res://scripts/loop.gd")
const Pose=preload("res://scripts/blower_pose.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func setup(owned:Array=[]) -> RefCounted:
	var game=Loop.new(77)
	game.owned.assign(owned);game.tiers=Loop.Upgrades.counts(owned)
	game.spawn_leaf();game.spawn_timer=999
	var leaf:Dictionary=game.leaves[0]
	leaf.attach_after=999;leaf.lift_response=1.0;leaf.drag=0.65
	leaf.flutter_rate=0;leaf.flutter_phase=0;leaf.flutter_strength=0
	leaf.position=game.nozzle()+Vector2(0,-50);leaf.velocity=Vector2.ZERO
	return game
func sample(distance:float,frames:int=1,owned:Array=[],weak:bool=false,angle:float=0) -> Dictionary:
	var game=setup(owned);var leaf:Dictionary=game.leaves[0]
	game.energy_locked=weak;game.charge=0 if weak else 1
	# Isolate distance while accumulating actual physics velocity at a fixed
	# point in the cone. No canopy targets or flutter can mask the response.
	for frame in range(frames):
		game.aim=angle+signf(angle)*Pose.TURN_SPEED/60.0
		leaf.position=Vector2(game.x,Loop.GROUND)+Pose.nozzle_offset(1,angle)+Pose.axis(angle)*distance
		game.step(1.0/60,0,true)
	return leaf
func _initialize() -> void:
	var near:=sample(50);var middle:=sample(170);var far:=sample(300)
	check(near.velocity.y<middle.velocity.y and middle.velocity.y<far.velocity.y and far.velocity.y<0,"actual upward acceleration decreases along the blower cone while the far end still lifts")
	near=sample(50,120);middle=sample(170,120);far=sample(300,120)
	check(near.velocity.y<middle.velocity.y and middle.velocity.y<far.velocity.y,"sustained lift remains slower at distance instead of reaching the same speed cap")
	check(absf(far.velocity.y)<absf(near.velocity.y)*0.5 and far.velocity.y<0,"distant leaves rise visibly more slowly without dropping out of full-power lift")
	var beyond:=sample(345)
	check(beyond.velocity.y>0 and not beyond.lifted,"the existing maximum range still bounds the breeze")
	var upgraded:=sample(300,120,[10,11,14]);var torque:=sample(300,120,[10])
	check(upgraded.velocity.y<torque.velocity.y,"the reach upgrade extends useful lift at the same distance")
	near=sample(50,1,[],false,Pose.MOVING_TILT);far=sample(250,1,[],false,Pose.MOVING_TILT)
	check(near.velocity.y<far.velocity.y and far.velocity.y<0,"falloff follows the aimed nozzle axis during movement")
	near=sample(65,30,[],true);far=sample(130,30,[],true)
	check(near.velocity.y<far.velocity.y and far.velocity.y<0 and not near.lifted and not far.lifted,"the recharge draft retains gravity support and gentler lift, without marking leaves for capture")
	var game=setup();var leaf:Dictionary=game.leaves[0]
	var lower_speed:=0.0;var upper_speed:=0.0
	for frame in range(330):
		game.step(1.0/60,0,true)
		var height:float=(leaf.position-game.nozzle()).dot(game.air_axis())
		if height>85 and height<120:lower_speed=maxf(lower_speed,-leaf.velocity.y)
		if height>260 and height<300:upper_speed=maxf(upper_speed,-leaf.velocity.y)
		if height>=300:break
	check(lower_speed>100 and upper_speed>0 and upper_speed<lower_speed*0.65,"a freely rising leaf visibly slows as it climbs into the upper canopy")
	check(game.rescued==0 and game.missed==0 and leaf.state=="air","distance falloff cannot create an attachment or change leaf accounting")
	print("Distance lift: lower=%.2f upper=%.2f"%[lower_speed,upper_speed])
	print("Airflow attenuation: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
