extends SceneTree
## CPU stress study; excludes GPU rendering and does not predict phone FPS.
## bash tools/godot.sh --headless --script tools/profile_challenge.gd
## Optional user arguments: --storm --loop=res://path.gd --main=res://path.gd
const FRAMES := 90

func _initialize() -> void:
	run.call_deferred()

func resource_argument(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(key + "="): return argument.substr(key.length() + 1)
	return fallback

func run() -> void:
	var simulation = load(resource_argument("--loop", "res://scripts/loop.gd"))
	var scene = load(resource_argument("--main", "res://scripts/main.gd")).new()
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.mode = "play"
	for count in [50, 100, 200]:
		for capture in [false, true]:
			scene.sim = simulation.new(641023, 0, true)
			for i in range(count):
				if not scene.sim.spawn_leaf(): break
				var leaf: Dictionary = scene.sim.leaves.back()
				leaf.position = Vector2(150 + i % 60, 260 + i % 90)
				leaf.velocity = Vector2(0, -20)
				leaf.lifted = true
				leaf.attach_after = 0.0 if capture else 10000.0
			scene.sim.spawn_timer = 10000
			scene.sim.week_time = 56.8 if "--storm" in OS.get_cmdline_user_args() else 6.0
			scene.canopy_stamp = ""
			scene.update_canopy_batches()
			var physics := PackedFloat64Array()
			var presentation := PackedFloat64Array()
			for frame in range(FRAMES):
				var start := Time.get_ticks_usec()
				scene.sim.step(1.0 / 60, 0, true)
				physics.append((Time.get_ticks_usec() - start) / 1000.0)
				start = Time.get_ticks_usec()
				scene.update_canopy_batches()
				presentation.append((Time.get_ticks_usec() - start) / 1000.0)
			print(JSON.stringify({"cpu_only": true, "initial_airborne": count, "airborne_limit": scene.sim.active_leaf_limit() if scene.sim.has_method("active_leaf_limit") else scene.sim.MAX_ACTIVE,
				"capture_enabled": capture, "final_airborne": scene.sim.leaves.size(),
				"rescued": scene.sim.rescued, "missed": scene.sim.missed,
				"physics": summary(physics), "leaf_presentation": summary(presentation)}))
	scene.queue_free()
	await process_frame
	quit()

func summary(samples: PackedFloat64Array) -> Dictionary:
	var total := 0.0
	for value in samples: total += value
	samples.sort()
	return {"mean_ms": total / samples.size(), "p95_ms": samples[int(samples.size() * 0.95)]}
