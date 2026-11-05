extends SceneTree
## Rendered art fixtures. No claim of human-played survival or earned scores.
## Run with tools/godot.sh --script tests/visual_challenge_cycle.gd on a display.
const Main=preload("res://main.tscn")
const World=preload("res://scripts/ambient_world.gd")
func _initialize() -> void:
	run.call_deferred()
func capture(path:String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work/cycle-visual")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	main.campaign.highest_completed_difficulty=2;main.start_challenge()
	# Art fixture: sparse foliage exposes painted perches; no gameplay claim.
	for slot in main.sim.slots:
		if int(slot.leaf_id)%3!=0:slot.leaf_id=-1
	main.sim.index_canopy()
	var previous:=0.0
	for time in [3.0,15.0,35.0,57.8,95.0,295.0,305.0]:
		for tick in range(roundi((time-previous)*10)):
			main.world.configure(main.sim.run_id,8,false,true,previous+tick/10.0)
			main.world.advance(0.1,false,false,false,false,0)
		main.sim.week_time=time;main.sim.spawn_timer=999;main._physics_process(0)
		for layer in main.scenery_layers:layer.queue_redraw()
		main.queue_redraw()
		await capture("res://work/cycle-visual/game-%05.1f.png"%time)
		previous=time
	main.hide()
	var world=World.new();root.add_child(world)
	for time in [0.0,35.0,55.0,95.0,175.0]:
		world.configure("visual",8,false,true,time);world.advance(0,false,false,false,false,0)
		await capture("res://work/cycle-visual/valley-%05.1f.png"%time)
	main.queue_free();world.queue_free();await process_frame
	await create_timer(0.5).timeout
	quit()
