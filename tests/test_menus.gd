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
	main.return_from_scores()
	check(main.mode == "title", "score screen returns to menu")
	main.start_run()
	main.sim.spawned = main.sim.week_leaf_count()
	main._physics_process(1.0 / 60)
	await process_frame
	var nodes = main.overlay.find_children("*", "Button", true, false)
	var overlaps := false
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			overlaps = overlaps or nodes[i].get_global_rect().intersects(nodes[j].get_global_rect())
	check(not overlaps and nodes.size() == 21, "all eighteen upgrade nodes and workshop actions have non-overlapping hit areas")
	var bounded := true
	for icon in main.overlay.find_children("*", "TextureRect", true, false):
		bounded = bounded and icon.size.x <= 44 and icon.size.y <= 35
	check(bounded, "equipment textures stay inside their header slots")
	main.selected_upgrade = Vector2i(2, 6)
	main.show_workshop()
	var card_text = main.overlay.find_children("*", "RichTextLabel", true, false)
	check(card_text.size() == 1 and card_text[0].size.x <= 300, "full upgrade descriptions wrap inside a separate bounded card")
	main.selected_difficulty = 2
	main.start_run()
	check(main.sim.difficulty == 2, "new campaign uses the chosen difficulty")
	main.sim.score = 4500
	main.sim.status = "lost"
	main.mode = "lost"
	main.show_result()
	main.show_initials()
	check(main.mode == "initials" and main.visual_mode() == "lost", "initials entry retains the ending background")
	var inputs = main.overlay.find_children("*", "LineEdit", true, false)
	inputs[0].text = "xyz"
	var buttons = main.overlay.find_children("*", "Button", true, false)
	for b in buttons:
		if b.text == "Save score": b.pressed.emit()
	check(main.mode == "scores" and main.high_scores.entries(2)[0].initials == "XYZ", "the score-entry form submits normalized initials to the right table")
	main.return_from_scores()
	check(main.mode == "lost" and not main.high_scores.qualifies(main.sim), "returning to a result cannot duplicate its score")
	for extension in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + extension): DirAccess.remove_absolute(path + extension)
	main.queue_free()
	await process_frame
	await process_frame
	print("License and menu UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
