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


func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap_button(main, content: String) -> void:
	for choice in main.overlay.find_children("*", "Button", true, false):
		if choice.text == content:
			var point: Vector2 = choice.get_global_rect().get_center()
			touch(0, point, true)
			touch(0, point, false)
			await process_frame
			return
	check(false, "missing touch target: " + content)


func run() -> void:
	root.size = Vector2i(360, 640)
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	await process_frame
	await process_frame
	check(Input.emulate_mouse_from_touch, "touches generate the mouse events used by standard menu controls")
	await tap_button(main, "High Scores")
	check(main.mode == "scores", "touch opens High Scores from the main menu")
	await tap_button(main, "Challenge")
	var selected: Array[Node] = main.overlay.find_children("*", "Button", true, false).filter(func(choice):return choice.button_pressed)
	check(selected.size() == 2 and selected[0].text == "Challenge" and selected[1].text == "Medium", "touching Challenge selects its radio button and retains the difficulty")
	await tap_button(main, "Hard")
	selected = main.overlay.find_children("*", "Button", true, false).filter(func(choice):return choice.button_pressed)
	check(selected.size() == 2 and selected[0].text == "Challenge" and selected[1].text == "Hard", "touch changes difficulty independently of the selected score mode")
	await tap_button(main, "Back to menu")
	check(main.mode == "title", "the score dialog returns to the main menu")
	var explore: Button
	for candidate in main.overlay.find_children("*", "Button", true, false):
		if candidate.text == "Explore the seasons": explore = candidate
	var center := explore.get_global_rect().get_center()
	touch(0, center, true)
	touch(0, center, false)
	await process_frame
	check(main.mode == "preview", "a real touch press/release activates a standard menu button")
	main.start_run()
	main.finish_story()
	await process_frame
	touch(0, Vector2(116, 596), true)
	touch(1, Vector2(301, 593), true)
	main._physics_process(1.0 / 60.0)
	check(main.touches.size() == 2 and not main.touches.has(-1), "two fingers stay independent without an extra emulated mouse contact")
	check(main.sim.x > 180 and main.sim.blowing, "touch movement and blower work simultaneously")
	touch(0, Vector2(116, 596), false)
	main._physics_process(1.0 / 60.0)
	check(main.touches.size() == 1 and main.sim.blowing, "releasing movement keeps the other finger's blower active")
	touch(1, Vector2(301, 593), false)
	main._physics_process(1.0 / 60.0)
	check(main.touches.is_empty() and not main.sim.blowing, "releasing both fingers clears all gameplay contacts")
	var previous_x:float=main.sim.x
	touch(0, Vector2(4,550), true)
	main._physics_process(1.0/60)
	check(main.sim.x<previous_x and main.touches.get(0)=="left","a thumb just above and left of the visible arrow still moves left")
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(78,638)
	Input.parse_input_event(drag);Input.flush_buffered_events()
	check(main.touches.get(0)=="left","sliding beyond the visible arrow stays held inside its enlarged target")
	touch(0,drag.position,false)
	previous_x=main.sim.x
	touch(0,Vector2(155,550),true)
	touch(1,main.BLOW.get_center(),true)
	main._physics_process(1.0/60)
	check(main.sim.x>previous_x and main.sim.blowing,"the larger right-arrow target works alongside a separate blower finger")
	touch(0,Vector2(155,550),false);touch(1,main.BLOW.get_center(),false)
	check(main.action_at(Vector2(80,596))=="left" and main.action_at(Vector2(81,596))=="right" and main.action_at(Vector2(164,596)).is_empty(),"arrow targets meet without ambiguity and stop before the Whirlwind button")
	touch(0, main.PAUSE.get_center(), true)
	touch(0, main.PAUSE.get_center(), false)
	check(main.mode == "paused", "a touch pauses once without its emulated click immediately resuming")
	touch(0, main.PAUSE.get_center(), true)
	touch(0, main.PAUSE.get_center(), false)
	check(main.mode == "play", "a second touch resumes once")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(301, 593)
	mouse.pressed = true
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	check(main.touches.has(-1), "a physical mouse still operates gameplay controls")
	mouse = mouse.duplicate()
	mouse.pressed = false
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	check(main.touches.is_empty(), "physical mouse release clears its contact")
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("Touch UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
