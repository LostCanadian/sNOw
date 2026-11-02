extends SceneTree

const Main = preload("res://main.tscn")
const Campaign = preload("res://scripts/campaign.gd")
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
	check(main.wardrobe_regions.size() == 12 and main.ending_regions.size() == 2, "twelve weekly outfits and distinct warm/sad ending art load")
	check(main.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "paper art is smoothly filtered with mipmaps")
	var oriented := true
	check(main.TREE.resource_path == "res://assets/art/season_tree.png", "runtime selects the user-reference Season Tree asset")
	var tree_image: Image = main.TREE.get_image()
	for slot in main.sim.slots:
		var direction: Vector2 = (slot.position - slot.stem).normalized()
		oriented = oriented and direction.dot(Vector2.UP.rotated(slot.angle)) > 0.999
	for tip in main.Canopy.TWIG_TIPS:
		oriented = oriented and tree_image.get_pixelv(Vector2i(tip)).a > 0.4
	for twig in main.Canopy.Sprays.POINTS:
		oriented = oriented and tree_image.get_pixel(int(twig.x), int(twig.y)).a > 0.7
	check(oriented, "leaf stems meet the illustrated twig silhouette and point organically outward")
	var clouds_valid: bool = main.WINTER_CLOUDS.get_image().get_mipmap_count()>0
	for frame in range(61):
		main.elapsed=frame*10.0
		var rect:Rect2=main.cloud_rect(frame/60.0)
		clouds_valid=clouds_valid and rect.position.x<0 and rect.end.x>360 and rect.position.y<0
	check(clouds_valid,"paper cloud textures use mipmaps and cover the sky across their entrance and drift")
	main.start_run()
	main.finish_story()
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
	var actor_time: float = main.actor.time
	var actor_travel: float = main.actor.travel
	var before: float = main.sim.week_time
	main._physics_process(1.0)
	check(main.sim.week_time == before, "pause freezes the simulation")
	check(main.actor.time == actor_time and main.actor.travel == actor_travel, "pause freezes both motor and stride clocks")
	main.resume_game()
	main.sim.leaves.clear()
	main.sim.spawned = main.sim.week_leaf_count()
	main._physics_process(1.0 / 60.0)
	main.finish_story()
	check(main.mode == "results" and main.sim.points == 2, "week boundary opens its results before upgrades")
	main.show_workshop()
	main.purchase(1)
	check(main.sim.tiers == [0, 1, 0] and main.sim.points == 1, "workshop purchase applies the equipment build")
	main.continue_week()
	main.finish_story()
	check(main.mode == "play" and main.sim.week == 2 and main.sim.tiers[1] == 1, "workshop continues into the next week with upgrades")
	main.show_title()
	main.show_season_lab()
	main.set_preview(1)
	check(is_equal_approx(main.weather(), 0.83), "warning preview shows pressure-driven weather")
	main.set_preview(2)
	check(main.weather() == 1.0, "winter preview is available without deliberately losing")
	main.set_preview(3)
	check(main.preview_victory, "victory art preview is available")
	main.pause_game()
	var frozen_elapsed: float = main.elapsed
	main._physics_process(1.0)
	check(main.mode == "paused" and main.elapsed == frozen_elapsed, "pause also freezes the art preview")
	main.resume_game()
	check(main.mode == "preview" and main.overlay != null and main.overlay.visible, "resume restores the original preview controls")
	main.show_title()
	main.start_run()
	main.finish_story()
	check(main.sim.tiers == [0, 0, 0] and main.sim.points == 0 and main.sim.score == 0, "new run resets equipment, currency and score")
	for ending in ["lost", "won"]:
		main.sim.status = ending
		main._physics_process(1.0 / 60.0)
		main._physics_process(4.1)
		for frame in range(900):
			if main.overlay != null: break
			main._physics_process(1.0 / 60)
		check(main.mode == ending and main.overlay != null, ending + " opens its result controls after the cinematic")
		main.pause_game()
		var frozen_ending: float = main.ending_time
		main._physics_process(1.0)
		check(main.mode == ending and main.ending_time > frozen_ending, "completed " + ending + " results need no pause overlay")
		check(main.visual_mode() == ending, "pausing preserves the " + ending + " character and weather presentation")
		main.resume_game()
		check(main.mode == ending and main.overlay.visible, "resume restores " + ending + " results")
		main.show_title()
		main.start_run()
		main.finish_story()
	var path := "user://scene-save-test-%d.json" % Time.get_ticks_usec()
	main.campaign = Campaign.new(path)
	main.start_run(0, "Scene garden")
	main.finish_story()
	main.sim.spawned = main.sim.week_leaf_count()
	main._physics_process(1.0 / 60)
	check(main.campaign.slots[0].checkpoint.phase == "workshop", "scene completion automatically writes the named slot")
	main.finish_story()
	main.pause_game()
	main._physics_process(1.0)
	main.resume_game()
	check(main.mode == "results", "weekly results survive pause and explicit resume")
	main.show_workshop()
	main.purchase(0)
	main.continue_week()
	main.finish_story()
	var checkpoint_score: int = main.sim.score
	main.sim.score += 999
	main.restart_level()
	main.finish_story()
	check(main.sim.week == 2 and main.sim.score == checkpoint_score and main.sim.tiers[0] == 1, "retry restores the current week and its build without retaining attempt points")
	main.show_title()
	main.campaign = Campaign.new(path)
	main.load_slot(0)
	check(main.mode == "continue" and main.sim.week == 2 and main.sim.week_time == 0, "loaded campaigns show Continue at the level boundary")
	main.begin_intro()
	main.finish_story()
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(main.mode == "paused", "returning from another app never auto-resumes")
	main.resume_game()
	main._physics_process(1.0 / 60)
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(main.mode == "paused" and main.overlay != null, "native close requests open a confirmation rather than terminating immediately")
	for extension in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + extension): DirAccess.remove_absolute(path + extension)
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("Scene/input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
