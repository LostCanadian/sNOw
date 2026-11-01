extends SceneTree

const Main = preload("res://main.tscn")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	check(main.mode == "title", "main scene opens at the menu")
	var clouds_valid := true
	for layer in range(3):
		for frame in range(61):
			clouds_valid = clouds_valid and not Geometry2D.triangulate_polygon(main.cloud_polygon(layer, frame / 60.0)).is_empty()
	check(clouds_valid, "cloud cutouts remain valid through their entire entrance")
	main.start_run()
	check(main.mode == "play" and main.overlay == null, "start enters playable scene")
	main.pointer_begin(0, Vector2(116, 596))
	main.pointer_begin(1, Vector2(301, 593))
	main._physics_process(1.0 / 60.0)
	check(main.sim.x > 180.0 and main.sim.blowing, "two simultaneous touches move and blow")
	main.pointer_drag(0, Vector2(46, 596))
	check(main.touches[0] == "left", "finger can slide between direction buttons")
	main.pointer_drag(1, Vector2(200, 540))
	main._physics_process(1.0 / 60.0)
	check(not main.sim.blowing, "dragging out of the blower releases it")
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	main._input(release)
	check(not main.touches.has(0), "touch release clears its independent contact")
	main.pointer_begin(4, Vector2(301, 593))
	var cancel := InputEventScreenTouch.new()
	cancel.index = 4
	cancel.pressed = false
	cancel.canceled = true
	main._input(cancel)
	check(not main.touches.has(4), "cancelled touch cannot leave blower stuck")
	main.keys["right"] = true
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.mode == "paused" and main.keys.is_empty() and main.touches.is_empty(), "focus loss pauses and releases every input")
	var before: float = main.sim.day_time
	main._physics_process(1.0)
	check(main.sim.day_time == before, "pause freezes the simulation")
	main.resume_game()
	main.sim.leaves.clear()
	main.sim.spawned = main.sim.day_leaf_count()
	main._physics_process(1.0 / 60.0)
	check(main.mode == "workshop" and main.sim.points == 1, "day boundary opens workshop")
	main.purchase(1)
	check(main.sim.tiers == [0, 1, 0] and main.sim.points == 0, "workshop purchase applies the equipment build")
	main.continue_day()
	check(main.mode == "play" and main.sim.day == 2 and main.sim.tiers[1] == 1, "workshop continues into the next day with upgrades")
	main.show_title()
	main.show_season_lab()
	main.set_preview(1)
	check(is_equal_approx(main.weather(), 0.83), "warning preview shows pressure-driven weather")
	main.set_preview(2)
	check(main.weather() == 1.0, "winter preview is available without deliberately losing")
	main.set_preview(3)
	check(main.preview_victory, "victory art preview is available")
	main.show_title()
	main.start_run()
	check(main.sim.tiers == [0, 0, 0] and main.sim.points == 0 and main.sim.score == 0, "new run resets equipment, currency and score")
	main.audio.stop()
	main.playback = null
	main.queue_free()
	await process_frame
	await process_frame
	print("Scene/input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
