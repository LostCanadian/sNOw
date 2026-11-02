extends SceneTree
## CPU-only full-canopy loss study. Run with Godot --headless --script.
## These timings do not measure GPU work or predict native phone frame rates.
const Main = preload("res://main.tscn")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.sim.status = "lost"
	main.mode = "lost"
	main.begin_winter_fall()
	var physics_usec := 0
	var upload_usec := 0
	var peak_tick_usec := 0
	for frame in range(600):
		var start := Time.get_ticks_usec()
		main.winter_fall.step(1.0 / 60)
		var duration := Time.get_ticks_usec() - start
		physics_usec += duration
		peak_tick_usec = maxi(peak_tick_usec, duration)
		start = Time.get_ticks_usec()
		main.update_winter_batch()
		upload_usec += Time.get_ticks_usec() - start
	print(JSON.stringify({"cpu_only": true, "frames": 600, "leaves": main.winter_fall.records.size(),
		"physics_ms": physics_usec / 1000.0, "renderer_update_ms": upload_usec / 1000.0,
		"peak_physics_tick_ms": peak_tick_usec / 1000.0}))
	main.queue_free()
	await process_frame
	quit()
