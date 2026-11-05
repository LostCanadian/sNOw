extends SceneTree
const Main = preload("res://main.tscn")
const Scores = preload("res://scripts/high_scores.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	var path := "user://menu-score-test-%d.json" % Time.get_ticks_usec()
	main.high_scores = Scores.new(path)
	check(main.overlay.find_children("*", "CheckButton", true, false).is_empty(), "main menu contains no effects or mute toggles")
	var audio_button = main.overlay.find_child("AudioSettings",true,false)
	check(audio_button != null and audio_button.text.is_empty() and audio_button.icon != null, "audio settings use a speaker icon without a text label")
	audio_button.pressed.emit()
	check(main.mode == "audio_options" and main.overlay.find_children("*","HSlider",true,false).size() == 2 and main.overlay.find_child("MuteAll",true,false) != null, "speaker opens volume controls and mute inside the audio panel")
	main.show_license()
	check(main.mode == "license", "license opens from the menu")
	var sections: Dictionary = main.ThirdParty.sections()
	check(sections["Godot (MIT)"].contains("Permission is hereby granted") and sections["Godot (MIT)"].contains("Juan Linietsky"), "Godot full permission and copyright notices are available offline")
	check(sections["Engine libraries"].contains("FULL LICENSE TERMS") and sections["Engine libraries"].contains("Apache-2.0"), "bundled engine libraries include copyright and full license terms")
	check(sections["DejaVu fonts"].contains("THE FONT SOFTWARE IS PROVIDED") and sections["DejaVu fonts"].contains("public domain"), "font terms load from the shipped resource")
	var license_overlay = main.overlay
	main.pause_game()
	main.resume_game()
	check(main.mode == "license" and main.overlay == license_overlay, "license view survives pause/resume")
	main.show_title()
	for difficulty in range(3):
		main.show_high_scores(difficulty)
		check(main.mode == "scores", "difficulty table %d opens" % difficulty)
	var choices = main.overlay.find_children("*", "Button", true, false)
	check(choices[0].toggle_mode and choices[1].toggle_mode and choices[0].button_group == choices[1].button_group and choices[0].button_pressed and not choices[1].button_pressed, "Campaign and Challenge use an exclusive group with Campaign initially selected")
	choices[1].pressed.emit()
	choices = main.overlay.find_children("*", "Button", true, false)
	check(choices[1].button_pressed and not choices[0].button_pressed and choices[4].button_pressed, "switching score modes preserves the selected Hard difficulty")
	check(choices[2].button_group == choices[4].button_group and choices[0].button_group != choices[2].button_group, "mode and difficulty selectors use separate radio groups")
	choices[3].pressed.emit()
	choices = main.overlay.find_children("*", "Button", true, false)
	check(choices[1].button_pressed and choices[3].button_pressed and not choices[4].button_pressed, "changing difficulty retains Challenge and selects only Medium")
	choices[1].pressed.emit()
	choices = main.overlay.find_children("*", "Button", true, false)
	check(choices[1].button_pressed and choices[3].button_pressed, "the selected mode cannot be deselected by pressing it again")
	main.show_title()
	check(main.mode == "title", "score screen returns to menu")
	main.start_run()
	main.finish_story()
	main.show_high_scores()
	check(main.mode == "play", "High Scores cannot open from active gameplay")
	main.sim.week_handled = main.sim.week_leaf_count()
	main._physics_process(1.0 / 60)
	main.finish_story()
	main.show_workshop()
	await process_frame
	var nodes = main.overlay.find_children("*", "Button", true, false)
	var overlaps := false
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			overlaps = overlaps or nodes[i].get_global_rect().intersects(nodes[j].get_global_rect())
	check(not overlaps and nodes.size() == 16, "the active tab, ten icon nodes and workshop actions have non-overlapping hit areas")
	var bounded := true
	for icon in main.overlay.find_children("*", "TextureRect", true, false):
		bounded = bounded and icon.size.x <= 48 and icon.size.y <= 43
	check(bounded, "equipment textures stay inside their header slots")
	for tab in main.overlay.find_children("*", "Button", true, false):
		if tab.name == "Equipment1":
			tab.pressed.emit()
			break
	check(main.selected_upgrade == Vector2i(1,0), "Blower tab selects its own branching tree")
	main.selected_upgrade = Vector2i(2, 6)
	main.show_workshop()
	var card_text = main.overlay.find_children("*", "RichTextLabel", true, false)
	check(card_text.size() == 1 and card_text[0].size.x <= 300, "full upgrade descriptions wrap inside a separate bounded card")
	main.selected_difficulty = 2
	main.start_run()
	main.finish_story()
	check(main.sim.difficulty == 2, "new campaign uses the chosen difficulty")
	main.sim.score = 4500
	main.sim.status = "lost"
	main.mode = "lost"
	main.show_result()
	main.show_initials()
	check(main.mode == "initials" and main.visual_mode() == "lost", "initials entry retains the ending background")
	var inputs = main.overlay.find_children("*", "LineEdit", true, false)
	check(inputs.size() == 3 and inputs.all(func(input):return input.max_length == 1), "initials use three separate single-letter boxes")
	inputs[0].grab_focus(); inputs[0].select_all()
	for column in range(3):
		var key := InputEventKey.new()
		key.keycode = KEY_X + column
		key.unicode = "xyz".unicode_at(column)
		key.pressed = true
		Input.parse_input_event(key); Input.flush_buffered_events()
		var release: InputEventKey = key.duplicate()
		release.pressed = false
		Input.parse_input_event(release); Input.flush_buffered_events()
		await process_frame
	check(inputs.map(func(input):return input.text) == ["X", "Y", "Z"], "typing advances across the three boxes and normalizes letters to uppercase")
	var increment = main.overlay.find_children("*", "Button", true, false).filter(func(choice):return choice.text == "+")
	var decrement = main.overlay.find_children("*", "Button", true, false).filter(func(choice):return choice.text == "−")
	for column in range(3):
		increment[column].pressed.emit()
		var expected := ["X", "Y", "Z"]
		expected[column] = ["Y", "Z", "A"][column]
		check(inputs.map(func(input):return input.text) == expected, "letter control %d changes only its own box and wraps Z to A" % column)
		decrement[column].pressed.emit()
	var buttons = main.overlay.find_children("*", "Button", true, false)
	for b in buttons:
		if b.text == "Save score": b.pressed.emit()
	check(main.mode == "lost" and main.high_scores.entries(2)[0].initials == "XYZ", "saving normalized initials returns directly to the result")
	check(not main.high_scores.qualifies(main.sim) and not main.result_score_action.visible, "recorded results offer neither duplicate initials nor High Scores")
	for extension in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + extension): DirAccess.remove_absolute(path + extension)
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("License and menu UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
