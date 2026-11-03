extends SceneTree
## Authoring benchmark: CPU presentation work only, no GPU or timing assertions.
## bash tools/godot.sh --headless --script tools/profile_canopy.gd
const Main=preload("res://main.tscn")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false);main.muted=true;main.sounds.muted=true
	main.mode="play";main.update_canopy_batches()
	for scenario in ["idle","air_50","ground_100","reduced","victory","finished_victory"]:
		main.sim.leaves.clear();main.sim.ground_leaves.clear();main.canopy_stamp=""
		main.reduced_effects=scenario=="reduced"
		if scenario=="air_50":
			for i in range(50):main.sim.spawn_leaf()
		if scenario=="ground_100":
			for i in range(100):
				main.sim.spawn_leaf();var leaf:Dictionary=main.sim.leaves.pop_back();main.sim.resolve_leaf(leaf,false)
		var win:bool=scenario.contains("victory")
		main.ending_time=12.0 if scenario=="finished_victory" else 0.0
		main.update_canopy_batches(win)
		var times:=PackedFloat64Array()
		for frame in range(60):
			main.world.clock+=1.0/60;main.ending_time+=1.0/60
			var start:=Time.get_ticks_usec();main.update_canopy_batches(win);times.append((Time.get_ticks_usec()-start)/1000.0)
		times.sort();var mean:=0.0
		for t in times:mean+=t/times.size()
		print(scenario,": mean_ms=",snappedf(mean,.001)," p95_ms=",times[56])
	main.queue_free();await process_frame;await create_timer(0.3).timeout;quit()
