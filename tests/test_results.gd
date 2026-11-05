extends SceneTree
const Main = preload("res://main.tscn")
const Campaign = preload("res://scripts/campaign.gd")
const Scores = preload("res://scripts/high_scores.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func press(main, text: String) -> void:
	for node in main.overlay.find_children("*", "Button", true, false):
		if node.text == text:
			node.pressed.emit()
			return
	check(false, "missing action: " + text)

func complete_week(main, saved: int, fallen: int) -> void:
	for i in range(saved + fallen):
		main.sim.spawn_leaf()
		var leaf: Dictionary = main.sim.leaves[-1]
		main.sim.resolve_leaf(leaf, i < saved, leaf.home_slot)
	main.sim.leaves.clear()
	main.sim.week_handled = main.sim.week_leaf_count()
	main._physics_process(1.0 / 60)
	main.finish_story()

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var main = Main.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	var prefix := "user://results-test-%d" % Time.get_ticks_usec()
	main.campaign = Campaign.new(prefix + "-campaign.json")
	main.high_scores = Scores.new(prefix + "-scores.json")
	main.start_run(0, "Results study", 0)
	main.finish_story()
	complete_week(main, 4, 1)
	var final_score: int = main.sim.score
	check(main.mode == "results" and main.sim.points == 2, "a successful week opens results before optional upgrades")
	check(main.campaign.slots[0].checkpoint.phase == "workshop", "results are already autosaved before choosing any action")
	check(main.result_numbers[0].text == "0" and not main.result_tallied, "the results begin with an untallied display")
	check(main.high_scores.entries(0).is_empty(), "no anonymous score is silently submitted before initials")
	main._physics_process(0.7)
	check(int(main.result_numbers[0].text) > 0 and int(main.result_numbers[0].text) < 4, "saved-leaf count animates toward the actual completed result")
	check(main.sim.score == final_score and main.sim.week_rescued == 4 and main.sim.week_missed == 1, "tallying changes presentation without awarding points or changing leaf counts")
	main.pause_for_focus()
	var frozen: float = main.result_time
	main._physics_process(10)
	check(main.mode == "results" and main.result_time > frozen, "focus loss leaves completed results running")
	main.resume_game()
	main._physics_process(2.2)
	check(main.result_tallied and main.result_badge.text == "New high score!", "a qualifying score is announced only after the tally")
	check(main.result_numbers.map(func(label): return label.text) == ["4", "1 / 135", str(final_score)], "displayed totals match weekly results, with fallen leaves showing the loss allowance")
	check(is_equal_approx(main.result_bars[0].value,4.0/main.sim.week_leaf_count()) and is_equal_approx(main.result_bars[1].value,1.0/main.sim.capacity()), "saved leaves use the weekly quota while fallen leaves use the loss allowance")
	check(main.result_bars.all(func(bar): return bar.size.y <= 12), "result tracks stay slim rather than inheriting the theme's text height")
	var layout := true
	var buttons = main.overlay.find_children("*", "Button", true, false)
	for i in range(buttons.size()):
		layout = layout and Rect2(0, 0, 360, 640).encloses(buttons[i].get_global_rect())
		for j in range(i + 1, buttons.size()): layout = layout and not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect())
	check(layout, "results actions fit the portrait field without overlapping")
	press(main, "Enter initials")
	check(main.mode == "initials" and main.visual_mode() == "workshop", "weekly initials keep the completed scene behind them")
	var initials = main.overlay.find_children("*", "LineEdit", true, false)
	for column in range(3):initials[column].text = "cat"[column]
	press(main, "Save score")
	check(main.mode == "results" and main.high_scores.entries(0)[0].initials == "CAT", "saving weekly initials returns directly to results")
	check(main.high_scores.entries(0)[0].outcome == "workshop", "a completed-week score is distinguished from a loss")
	var text := ""
	for label in main.overlay.find_children("*", "Label", true, false): text += label.text
	check(not text.contains("Best result per campaign") and not text.contains("Local to this device"), "results contain no score-board footnotes")
	main.show_high_scores()
	check(main.mode == "results" and main.result_tallied and main.result_numbers[0].text == "4" and not main.result_score_action.visible, "the score board cannot open from results and saving initials preserves the tally")
	press(main, "Upgrades")
	check(main.mode == "workshop", "upgrades are an explicit optional destination")
	main.purchase(0)
	press(main, "Done")
	check(main.mode == "results" and main.sim.points == 1 and main.sim.tiers == [1,0,0], "closing upgrades returns to results and refreshes the point preview")
	check(main.sim.score == final_score and main.result_tallied, "revisiting results cannot repeat rewards or tally points twice")
	main.show_title()
	main.selected_difficulty = 2
	main.load_slot(0)
	check(main.mode == "results" and main.sim.week_rescued == 4 and main.sim.week_missed == 1 and main.selected_difficulty == 0, "loading a completed checkpoint restores its summary and selects its difficulty for scores")
	main._physics_process(2.2)
	check(main.result_numbers[2].text == str(final_score) and main.high_scores.entries(0).size() == 1, "the saved weekly score baseline survives reload without duplicating scores")
	press(main, "Week 2 →")
	main.finish_story()
	check(main.mode == "play" and main.sim.week_start_score == final_score and main.sim.week_rescued == 0, "next week resets weekly counters and retains the cumulative score baseline")
	complete_week(main, 1, 0)
	main._physics_process(2.2)
	check(main.result_new_high and main.high_scores.entries(0).size() == 1 and main.high_scores.entries(0)[0].score == main.sim.score, "subsequent improvements update the existing score automatically after tallying")
	check(main.high_scores.entries(0)[0].initials == "CAT", "later completed weeks retain the entered initials")
	check(int(main.result_numbers[2].text) == main.sim.score - final_score, "points earned count only the just-completed week")
	check(Scores.new(prefix + "-scores.json").entries(0)[0].score == main.sim.score, "automatic improvements persist to durable score storage")
	var checkpoint: Dictionary = Campaign.snapshot(main.sim)
	var legacy := checkpoint.duplicate(true)
	legacy.erase("week_start_score")
	var restored = Campaign.restore(legacy)
	check(restored != null and restored.week_start_score == -1, "older completed saves remain readable without inventing a weekly score breakdown")
	checkpoint.week_start_score = checkpoint.score + 1
	check(not Campaign.valid_checkpoint(checkpoint), "invalid weekly score baselines are rejected")
	var old: Dictionary = main.high_scores.entries(0)[0].duplicate(true)
	old.erase("outcome")
	check(Scores.valid_record(old), "older scores without completion metadata remain readable")
	main.reduced_effects = true
	main.sim.week_missed = 0
	var small: float = main.frost_radius()
	main.sim.week_missed = main.sim.capacity() - 1
	check(main.frost_radius() > small * 1.8, "growing winter danger remains visible with pulse motion disabled")
	var badges := [main.SCORE_BADGE, main.FROST_BADGE, main.BATTERY_BADGE, main.PAUSE]
	var compact := true
	for i in range(badges.size()):
		compact = compact and badges[i].end.y <= 56
		for j in range(i + 1, badges.size()): compact = compact and not badges[i].intersects(badges[j])
	check(compact, "independent HUD badges leave the lower playfield free and avoid pause")
	check(main.FROST_ICON.get_image().get_mipmap_count() > 0 and main.BATTERY_FRAME.get_image().get_mipmap_count() > 0, "new frost and battery assets are smoothly mipmapped")
	for difficulty in range(3):
		for challenge in [false,true]:
			main.sim=main.Loop.new(55,difficulty,challenge)
			main.sim.status="lost";main.sim.week_handled=600;main.sim.week_rescued=200
			main.sim.week_missed=main.sim.capacity()
			main.show_result();main.result_tallied=true;main.update_result_tally()
			check(main.result_bars[1].value==1 and main.result_numbers[1].text=="%d / %d"%[main.sim.capacity(),main.sim.capacity()],"the fallen bar reaches full at the actual loss threshold on difficulty %d, Challenge=%s"%[difficulty,challenge])
			main.sim.week_missed=main.sim.capacity()/2
			main.update_result_tally()
			check(is_equal_approx(main.result_bars[1].value,float(main.sim.week_missed)/main.sim.capacity()),"fallen scale follows the allowance independently of run length and rescue count")
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with(prefix.get_file()): DirAccess.remove_absolute("user://" + name)
	main.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("Results, HUD and weekly scores: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
