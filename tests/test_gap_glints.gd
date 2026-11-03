extends SceneTree
const Glints=preload("res://scripts/gap_glints.gd")
const Loop=preload("res://scripts/loop.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var slots:Array=[];var ids:Array[int]=[]
	for i in range(40):slots.append({"position":Vector2(i*9,100),"leaf_id":-1,"capture_after":0.0});ids.append(i)
	var glints=Glints.new();glints.configure("quiet-crown");glints.set_candidates(ids)
	var peak:=0;var seen:={};var partial:=false;var starts_dark:=true
	for frame in range(2400):
		glints.advance(1.0/60,slots,frame/60.0)
		peak=maxi(peak,glints.poses().size())
		for pose in glints.poses():seen[pose.slot]=true;partial=partial or pose.alpha<0.1
		for light in glints.lights:
			if light.age==0:starts_dark=starts_dark and glints.poses().all(func(p):return p.slot!=light.slot)
	check(peak<=5 and peak>=3,"even a fully bare crown displays at most five glints at once")
	check(seen.size()==40,"the shuffled cycle eventually suggests every candidate area")
	check(starts_dark and partial,"each suggestion fades from and back toward complete transparency")
	glints.set_candidates([])
	for frame in range(180):glints.advance(1.0/60,slots,50)
	check(glints.poses().is_empty(),"old glints fade completely out instead of staying permanently lit")
	glints.configure("cooldown");glints.set_candidates([0]);slots[0].capture_after=5
	glints.advance(.1,slots,0)
	check(glints.lights.is_empty(),"cooling branches are not suggested as ready attachment spots")
	glints.advance(1,slots,6);slots[0].leaf_id=7;glints.advance(.1,slots,6.1)
	check(glints.lights.is_empty(),"a filled branch immediately stops twinkling")
	var game=Loop.new();game.spawn_leaf();game.week_time=5.01
	var index:int=game.leaves[0].home_slot;var point:Vector2=game.slots[index].position
	check(game.capture_slot(point,point)==index and glints.poses().is_empty(),"an unlit eligible spot can still capture leaves")
	print("Gap glints: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
