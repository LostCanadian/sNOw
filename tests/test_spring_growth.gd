extends SceneTree
const Growth=preload("res://scripts/spring_growth.gd")
const Main=preload("res://main.tscn")
const Campaign=preload("res://scripts/campaign.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func visible_area(main) -> float:
	var total:=0.0
	for lane in [0,2]:
		var data:PackedFloat32Array=main.leaf_renderer.buffers[lane]
		for i in range(main.Canopy.SLOT_COUNT):
			var o:=i*12
			total+=absf(data[o]*data[o+5]-data[o+1]*data[o+4])
	return total
func run() -> void:
	check(Growth.flash(0)==0 and Growth.flash(0.2)>0.9 and Growth.flash(1.5)==0,"tree light is a short smooth burst")
	check(Growth.wardrobe(0)==0 and Growth.wardrobe(2)>0 and Growth.wardrobe(2)<1 and Growth.wardrobe(3.5)==1,"winter and summer outfits overlap through the transition")
	check(Growth.greening(0)==0 and Growth.greening(3)<1 and Growth.greening(5.5)==1,"grass greening continues gently after the canopy grows")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false);main.muted=true
	main.sim.week=13;main.sim.retire_seasonal_foliage();main.sim.status="won";main.mode="won"
	var before:Dictionary=Campaign.snapshot(main.sim)
	main.ending_time=0;main.update_canopy_batches(true);var start:=visible_area(main)
	main.ending_time=1.5;main.update_canopy_batches(true);var middle:=visible_area(main)
	main.ending_time=3.5;main.update_canopy_batches(true);var full:=visible_area(main)
	check(start>0 and start<middle and middle<full,"the actual render buffers grow a sparse crown into a full crown over multiple frames")
	check(is_equal_approx(full,main.Canopy.SLOT_COUNT*main.Canopy.RADIUS*main.Canopy.RADIUS),"each branch receives exactly one full-size leaf after growth completes")
	check(Campaign.snapshot(main.sim)==before,"the victory growth cannot mutate gameplay, score, leaf identities or RNG")
	var progressive:=true
	for i in range(200):
		var p:=Vector2(50+i,160+i%150)
		var last:=0.0
		for frame in range(211):
			var amount:=Growth.bud(i,p,frame/60.0)
			progressive=progressive and amount>=last and amount-last<0.04;last=amount
		progressive=progressive and last==1
	check(progressive,"new leaves expand continuously from buds without a single-frame size jump")
	main.queue_free();await process_frame;await create_timer(0.15).timeout
	print("Spring growth: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
