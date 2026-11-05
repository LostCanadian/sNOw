extends SceneTree
const Main = preload("res://main.tscn")
const Campaign = preload("res://scripts/campaign.gd")
var checks := 0
var failures := 0
var main

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func shadow_bounds(button: Button) -> Rect2:
	var style: StyleBox = button.get_theme_stylebox("normal")
	if not style is StyleBoxFlat:return button.get_global_rect()
	var rect := button.get_global_rect().grow(style.shadow_size)
	rect.position += style.shadow_offset
	return rect.merge(button.get_global_rect())

func review(name: String) -> void:
	await process_frame
	await process_frame
	var panel: Panel = main.overlay.find_children("*", "Panel", true, false)[0]
	var buttons: Array[Node] = main.overlay.find_children("*", "Button", true, false)
	var fits := true
	var separated := true
	for i in range(buttons.size()):
		fits = fits and panel.get_global_rect().grow(-6).encloses(shadow_bounds(buttons[i]))
		for j in range(i + 1, buttons.size()):
			separated = separated and not shadow_bounds(buttons[i]).intersects(shadow_bounds(buttons[j]))
	check(fits, name + " keeps button shadows inside the panel with margins")
	check(separated, name + " leaves space between neighbouring button shadows")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://work/menu-review")
		root.get_texture().get_image().save_png("res://work/menu-review/" + name + ".png")

func run() -> void:
	root.size = Vector2i(540, 960)
	main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.sounds.muted = true
	var path := "user://menu-layout-%d.json" % Time.get_ticks_usec()
	main.campaign = Campaign.new(path)
	main.high_scores = main.HighScores.new(path + ".scores")
	main.challenge_scores = main.HighScores.new(path + ".challenge", "snow.challenge_scores.v1")
	check(main.Loop.DIFFICULTIES.map(func(profile):return profile.name) == ["Easy", "Medium", "Hard"], "difficulty labels are Easy, Medium and Hard without changing stored indices")
	main.show_title(); await review("title")
	main.show_slots("new"); await review("save-slots")
	main.show_slot_name(0, false); await review("new-game")
	main.start_run(0, "Layout study"); main.finish_story()
	main.show_slot_name(0, true); await review("rename-save")
	main.confirm_reset_slot(0, "Layout study", 2); await review("replace-save")
	main.campaign.unlock_challenge(2)
	main.show_challenge(); await review("challenge-setup")
	check(main.overlay.find_children("*", "Button", true, false).all(func(choice):return choice.text in ["Easy", "Medium", "Hard", "Back"]), "Challenge setup offers only difficulty choices and Back")
	var score_study = main.Loop.new(55, 1)
	score_study.status = "lost"; score_study.week = 13; score_study.tiers = [4,4,4]
	for row in range(10):
		score_study.run_id = ("layout-score-%d" % row).sha256_text()
		score_study.score = 10000 - row * 500
		main.high_scores.tables[1].append(main.high_scores.candidate(score_study, "AAA"))
		main.challenge_scores.tables[1].append(main.challenge_scores.candidate(score_study, "AAA"))
	for challenge in [false, true]:
		main.show_title()
		main.show_high_scores(1, challenge)
		await review("challenge-scores" if challenge else "campaign-scores")
		var tabs: Array[Node] = main.overlay.find_children("*", "Button", true, false)
		check(tabs[0].text == "Campaign" and tabs[1].text == "Challenge" and tabs[0].global_position.y == tabs[1].global_position.y and tabs[0].get_global_rect().end.y < tabs[2].global_position.y, "Campaign and Challenge form a centered row above the difficulty selectors")
		check(is_equal_approx((tabs[0].get_global_rect().position.x + tabs[1].get_global_rect().end.x) / 2.0, 180), "the mode selector row is centered in the score dialog")
		var rows: Array[Node] = main.overlay.find_children("*", "Label", true, false).filter(func(label):return label.text == "AAA")
		check(rows.size() == 10 and rows[-1].get_global_rect().end.y < tabs[-1].get_global_rect().position.y - 8, "all ten score rows fit below the selectors and above Back")
	main.high_scores.tables[1].clear(); main.challenge_scores.tables[1].clear()
	main.show_license(); await review("license")
	main.show_audio_options(); await review("audio")
	main.show_continue(); await review("continue")
	main.begin_intro(); main.finish_story(); main.pause_game(); await review("pause")
	main.confirm_restart(); await review("restart-level")
	main.confirm_menu(); await review("exit-level")
	main.resume_game(); main.sim.status = "workshop"; main.sim.score = 1000; main.show_result(); main.finish_tally(); await review("results")
	main.show_initials(); await review("initials")
	var letters: Array[Node] = main.overlay.find_children("*", "LineEdit", true, false)
	var increment: Array[Node] = main.overlay.find_children("*", "Button", true, false).filter(func(choice):return choice.text == "+")
	var boxes_fit := letters.size() == 3
	for column in range(letters.size()):
		boxes_fit = boxes_fit and letters[column].size.x <= 54 and is_equal_approx(letters[column].get_global_rect().get_center().x, increment[column].get_global_rect().get_center().x)
		if column > 0:boxes_fit = boxes_fit and letters[column-1].get_global_rect().end.x + 8 <= letters[column].global_position.x
	check(boxes_fit, "the three initials boxes stay separate and align with their own letter controls")
	main.show_workshop(); await review("workshop")
	main.confirm_reset_upgrades(); await review("reset-upgrades")
	main.start_run(-1, "", 1, true); main.pause_game(); main.confirm_restart(); await review("restart-challenge")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):DirAccess.remove_absolute(path + suffix)
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("Menu layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
