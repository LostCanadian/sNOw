extends SceneTree
const Main=preload("res://main.tscn")
class CountedBatch:
	extends "res://scripts/leaf_batch.gd"
	var uploads:=0
	func _init(meshes:Array[MultiMesh]) -> void:super(meshes)
	func upload() -> void:
		uploads+=1;super.upload()
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false);main.muted=true;main.sounds.muted=true
	var batch=CountedBatch.new([main.canopy_batch,main.canopy_shadows,main.front_batch,main.front_shadows])
	main.leaf_renderer=batch;main.mode="play";main.update_canopy_batches()
	var uploads:int=batch.uploads
	for frame in range(60):main.world.clock+=1.0/60;main.update_canopy_batches()
	check(batch.uploads==uploads,"ambient rustling does not rebuild or upload a stationary crown")
	var id:int=main.sim.slots[0].leaf_id
	var rank:int=batch.rank[id]
	var mask_offset:int=batch.PALETTE_WIDTH*batch.PALETTE_HEIGHT*4+rank*4
	check(batch.palette_bytes[mask_offset]==255,"the GPU breeze mask includes attached leaves")
	main.sim.spawn_leaf();main.update_canopy_batches()
	var detached:int=main.sim.leaves[-1].id
	var offset:int=batch.PALETTE_WIDTH*batch.PALETTE_HEIGHT*4+batch.rank[detached]*4
	check(batch.palette_bytes[offset]==0,"a falling leaf stops receiving cosmetic branch rustle")
	var palette:Image=batch.palette_image()
	check(palette.get_pixel(batch.rank[detached]%128,batch.rank[detached]/128).is_equal_approx(main.sim.leaves[-1].colour),"motion metadata cannot alter the Compatibility colour palette")
	main.sim.leaves.clear();main.sim.status="won";main.mode="won";main.ending_time=6;main.update_canopy_batches(true);uploads=batch.uploads
	for frame in range(60):main.ending_time+=1.0/60;main.world.clock+=1.0/60;main.update_canopy_batches(true)
	check(batch.uploads==uploads,"a completed victory stops rebuilding the crown permanently")
	main.preview_victory=true;main.update_canopy_batches(true);uploads=batch.uploads
	for frame in range(30):main.ending_time+=1.0/60;main.update_canopy_batches(true)
	check(batch.uploads==uploads,"the static victory preview also keeps its canopy cache")
	main.sim=main.Loop.new(77);main.sim.shedding_order.resize(1);main.sim.spawn_timer=999
	main.preview_victory=false;main.mode="play"
	main.sim.spawn_leaf();main.sim.spawn_leaf()
	main.sim.leaves[0].position.y=main.Loop.GROUND
	main.sim.step(1.0/60,0,false);main.mode="outro";main.update_canopy_batches()
	var pending:Dictionary=main.sim.leaves[0]
	main.pause_game();var frozen:Vector2=pending.position
	main._physics_process(2)
	check(pending.position==frozen,"pausing a quota ending freezes its remaining decorative leaves")
	main.resume_game()
	for frame in range(900):main.sim.advance_completed_leaves(1.0/60);main.update_canopy_batches()
	uploads=batch.uploads
	for frame in range(60):main.update_canopy_batches()
	check(main.sim.closing_settled and batch.uploads==uploads,"a completed weekly ending caches its decorative piles instead of uploading forever")
	main.queue_free();await process_frame;await create_timer(.3).timeout
	print("Canopy updates: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
