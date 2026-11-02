extends Node2D
## A small paper theatre: simulation stays separate from cutout presentation and UI.

const StageStory = preload("res://scripts/stage_story.gd")
const FAN_ICON = preload("res://assets/art/fan.svg")
const SURGE_ICON = preload("res://assets/art/surge.svg")
const FROST_ICON = preload("res://assets/art/hud_frost.svg")
const BATTERY_FRAME = preload("res://assets/art/battery_frame.svg")
const Loop = preload("res://scripts/loop.gd")
const PaperActor = preload("res://scripts/paper_actor.gd")
const Canopy = preload("res://scripts/canopy.gd")
const HighScores = preload("res://scripts/high_scores.gd")
const ThirdParty = preload("res://scripts/third_party.gd")
const Campaign = preload("res://scripts/campaign.gd")
const BACKDROP = preload("res://assets/art/autumn_stage.png")
const PAPER_LEAF = preload("res://assets/art/paper_leaf.png")
const CARETAKER = preload("res://assets/art/caretaker.png")
const TREE = preload("res://assets/art/season_tree.png")
const UPGRADE_ICONS = preload("res://assets/art/upgrade_icons.png")
const Upgrades = preload("res://scripts/upgrades.gd")
const WARDROBE = preload("res://assets/art/wardrobe.png")
const ENDINGS = preload("res://assets/art/endings.png")
const SNOWFLAKE = preload("res://assets/art/snowflake.svg")
const BODY_FONT = preload("res://assets/fonts/DejaVuSans.ttf")
const TITLE_FONT = preload("res://assets/fonts/DejaVuSerif.ttf")
const CREAM := Color("fff2d6")
const INK := Color("233f39")
const GOLD := Color("eabe6c")
const RUST := Color("c56338")
const LEFT := Rect2(16, 566, 60, 60)
const RIGHT := Rect2(86, 566, 60, 60)
const BLOW := Rect2(258, 558, 86, 70)
const SURGE := Rect2(166, 562, 68, 66)
const PAUSE := Rect2(310, 14, 36, 42)
const SCORE_BADGE := Rect2(12, 14, 146, 40)
const FROST_BADGE := Rect2(184, 12, 48, 44)
const BATTERY_BADGE := Rect2(242, 14, 56, 40)
const TALLY_DURATION := 2.1

var sim = Loop.new()
var mode := "title"
var ui: Control
var overlay: Control
var touches: Dictionary = {}
var keys: Dictionary = {}
var pointer_positions: Dictionary = {}
var elapsed := 0.0
var ending_time := 0.0
var story_time := 0.0
var result_time := 0.0
var result_key := ""
var result_tallied := false
var result_new_high := false
var result_bars: Array[ProgressBar] = []
var result_numbers: Array[Label] = []
var result_total: Label
var result_badge: Label
var result_score_action: Button
var result_actions: Array[Button] = []
var surge_requested := false
var ambient_rng := RandomNumberGenerator.new()
var snow: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var reduced_effects := false
var muted := false
var preview_weather := -1.0
var preview_victory := false
var preview_mode := false
var actor = PaperActor.new()
var actor_region := Rect2()
var actor_mesh_active := false
var character_region: Rect2
var leaf_region: Rect2
var canopy_batch: MultiMesh
var canopy_shadows: MultiMesh
var canopy_stamp := ""
var canopy_gap_markers: Array[Vector2] = []
var canopy_rank := PackedInt32Array()
var wardrobe_regions: Array[Rect2] = []
var selected_upgrade := Vector2i(0, 1)
var upgrade_regions := [Rect2(35, 35, 710, 655), Rect2(755, 20, 810, 640), Rect2(1640, 35, 485, 640)]
var ending_regions: Array[Rect2] = []
var campaign = Campaign.new()
var high_scores = HighScores.new()
var selected_difficulty := 1
var scores_return_to_result := false
var license_section := "About"
var license_characters := 0
var active_slot := -1
var level_checkpoint: Dictionary = {}
var paused_mode := "play"
var paused_overlay: Control
var lifecycle_callback: JavaScriptObject
var save_notice := ""
var audio: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var audio_phase := 0.0
var last_frame_ms := 0.0
var test_hooks := false
var telemetry_tick := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	get_tree().auto_accept_quit = false
	ambient_rng.seed = 90582
	character_region = Rect2(CARETAKER.get_image().get_used_rect())
	leaf_region = Rect2(PAPER_LEAF.get_image().get_used_rect())
	var canopy_order: Array = range(Canopy.SLOT_COUNT)
	canopy_order.sort_custom(func(a, b): return fmod(a * 0.61803398875, 1.0) > fmod(b * 0.61803398875, 1.0))
	canopy_rank.resize(Canopy.SLOT_COUNT)
	for i in range(canopy_order.size()): canopy_rank[canopy_order[i]] = i
	canopy_batch = make_canopy_batch()
	canopy_shadows = make_canopy_batch()
	wardrobe_regions = atlas_regions(WARDROBE, 4, 3)
	ending_regions = atlas_regions(ENDINGS, 2, 1)
	update_actor_mesh()
	for i in range(65):
		snow.append({"x": ambient_rng.randf_range(0, 360), "y": ambient_rng.randf_range(-640, 640), "size": ambient_rng.randf_range(1.0, 3.6), "phase": ambient_rng.randf_range(0, TAU)})
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	if OS.has_feature("web"):
		lifecycle_callback = JavaScriptBridge.create_callback(func(_args): pause_game())
		JavaScriptBridge.get_interface("window").snowPauseRequested = lifecycle_callback
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = 0.08
	audio = AudioStreamPlayer.new()
	audio.stream = stream
	audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	audio.volume_db = -20
	add_child(audio)
	show_title()
	if "--smoke" in OS.get_cmdline_user_args():
		start_run()
	test_hooks = OS.is_debug_build() and OS.has_feature("web") and "--test-hooks" in OS.get_cmdline_user_args()


func _physics_process(dt: float) -> void:
	last_frame_ms = dt * 1000.0
	var was_story := mode in ["intro", "outro"]
	if was_story:
		story_time += dt
		if story_time >= StageStory.DURATION: finish_story()
	if mode == "play" and not was_story:
		var axis := float(bool(keys.get("right", false))) - float(bool(keys.get("left", false)))
		var blow: bool = keys.get("blow", false)
		var surge: bool = keys.get("surge", false)
		for action in touches.values():
			if action == "left":
				axis -= 1.0
			elif action == "right":
				axis += 1.0
			elif action == "blow":
				blow = true
			elif action == "surge":
				surge = true
		var previous_x: float = sim.x
		if surge_requested: sim.surge_held = false
		sim.step(dt, clampf(axis, -1, 1), blow, surge or surge_requested)
		surge_requested = false
		actor.advance(sim.x - previous_x, dt, sim.blowing or sim.surge_left > 0, reduced_effects, sim.facing, sim.aim)
		update_actor_mesh()
		for event in sim.events:
			if sparks.size() < 50:
				sparks.append({"position": event.position, "time": 0.0, "saved": event.saved})
		if sim.status == "workshop":
			mode = "outro"
			story_time = 0
			clear_input()
			save_boundary()
		elif sim.status in ["lost", "won"]:
			mode = sim.status
			ending_time = 0.0
			clear_input()
			if mode == "won": save_boundary()
	if mode in ["lost", "won"]:
		ending_time += dt
		if ending_time >= 4.0 and overlay == null:
			show_result()
	if mode in ["results", "lost", "won"] and is_instance_valid(overlay):
		result_time = minf(TALLY_DURATION, result_time + dt)
		if result_time >= TALLY_DURATION and not result_tallied: finish_tally()
		update_result_tally()
	if mode != "paused":
		if mode in ["outro", "results", "workshop"]: actor.advance(0, dt, false, reduced_effects, sim.facing, 0)
		if mode != "play": update_actor_mesh()
		elapsed += dt
		for flake in snow:
			flake.y += dt * (12.0 + flake.size * 8.0)
			if flake.y > 650:
				flake.y = -10.0
				flake.x = ambient_rng.randf_range(0, 360)
		for spark in sparks:
			spark.time += dt
		sparks = sparks.filter(func(spark: Dictionary) -> bool: return spark.time < 0.8)
	queue_redraw()
	fill_audio()
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("window").snowShouldConfirmExit = active_slot >= 0 and sim.status == "playing" and sim.week_time > 0
	if test_hooks:
		telemetry_tick += 1
		if telemetry_tick % 6 == 0:
			var snapshot := {
				"mode": mode, "score": sim.score, "week": sim.week, "x": sim.x, "charge": sim.charge,
				"ground_positions": sim.ground_leaves.map(func(leaf): return [leaf.id, leaf.position.x, leaf.position.y, leaf.velocity.x]),
				"story_time": story_time, "grounded": sim.ground_leaves.size(), "surge_charge": sim.surge_charge, "surge_active": sim.surge_left > 0, "surge_unlocked": sim.surge_unlocked(),
				"result_time": result_time, "result_tallied": result_tallied, "result_new_high": result_new_high,
				"week_rescued": sim.week_rescued, "week_points": sim.score - sim.week_start_score if sim.week_start_score >= 0 else -1,
				"result_display": result_numbers.map(func(label): return label.text if is_instance_valid(label) else ""),
				"blowing": sim.blowing, "rescued": sim.rescued, "missed": sim.missed,
				"points": sim.points, "tiers": sim.tiers, "selected_upgrade": [selected_upgrade.x, selected_upgrade.y], "touches": touches.size(),
				"week_missed": sim.week_missed, "regrown": sim.regrown, "week_regrown": sim.week_regrown,
				"airborne": sim.leaves.map(func(leaf): return [leaf.position.x, leaf.position.y, leaf.id]),
				"time": sim.week_time, "weather": weather(), "victory": preview_victory,
				"attached": sim.attached_count(), "slots": sim.slots.size(), "air": sim.leaves.size(),
				"result_visible": mode in ["lost", "won"] and overlay != null,
				"active_slot": active_slot, "phase": sim.status, "temperature": sim.temperature(), "boss_phase": sim.boss_phase(),
				"difficulty": sim.difficulty, "capacity": sim.capacity(),
				"score_rows": [high_scores.entries(0).size(), high_scores.entries(1).size(), high_scores.entries(2).size()],
				"license_section": license_section, "license_characters": license_characters,
				"facing": sim.facing, "aim": sim.aim, "nozzle": [sim.nozzle().x, sim.nozzle().y],
				"gait_phase": actor.phase(), "travel": actor.travel, "motor": actor.motor,
				"save_error": save_notice, "storage_error": campaign.error,
				"gaps": sim.slots.filter(func(slot: Dictionary): return slot.leaf_id < 0).map(func(slot: Dictionary): return [slot.position.x, slot.position.y]),
				"logical_size": [get_viewport_rect().size.x, get_viewport_rect().size.y],
			}
			JavaScriptBridge.eval("window.snowSnapshot = " + JSON.stringify(snapshot), true)


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed and not event.canceled) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if pressed and PAUSE.has_point(event.position):
		if mode == "paused": resume_game()
		else: pause_game()
		get_viewport().set_input_as_handled()
		return
	if mode in ["intro", "outro"]:
		var skip_key: bool = event is InputEventKey and event.pressed and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
		if pressed or skip_key:
			if story_time >= 0.65: finish_story()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey:
		if event.echo:
			return
		var action := ""
		match event.physical_keycode:
			KEY_A, KEY_LEFT: action = "left"
			KEY_D, KEY_RIGHT: action = "right"
			KEY_SPACE: action = "blow"
			KEY_E: action = "surge"
			KEY_ESCAPE:
				if event.pressed:
					if mode == "paused": resume_game()
					else: pause_game()
		if action != "":
			keys[action] = event.pressed and mode == "play"
			if action == "surge" and event.pressed and mode == "play": surge_requested = true
			if mode == "play": get_viewport().set_input_as_handled()
	if mode != "play":
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			pointer_begin(event.index, event.position)
		else:
			touches.erase(event.index)
			pointer_positions.erase(event.index)
	elif event is InputEventScreenDrag:
		pointer_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_begin(-1, event.position)
		else:
			touches.erase(-1)
			pointer_positions.erase(-1)
	elif event is InputEventMouseMotion and touches.has(-1):
		pointer_drag(-1, event.position)


func action_at(point: Vector2) -> String:
	if LEFT.has_point(point): return "left"
	if RIGHT.has_point(point): return "right"
	if BLOW.has_point(point): return "blow"
	if SURGE.has_point(point) and sim.surge_unlocked(): return "surge"
	return ""


func pointer_begin(id: int, point: Vector2) -> void:
	if PAUSE.has_point(point):
		pause_game()
		return
	var action := action_at(point)
	if action != "":
		touches[id] = action
		if action == "surge": surge_requested = true
		pointer_positions[id] = point


func pointer_drag(id: int, point: Vector2) -> void:
	if touches.has(id):
		if action_at(point) == "surge" and touches[id] != "surge": surge_requested = true
		touches[id] = action_at(point)
		pointer_positions[id] = point


func clear_input() -> void:
	surge_requested = false
	touches.clear()
	pointer_positions.clear()
	keys.clear()
	sim.blowing = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_input()
		if is_instance_valid(ui) and mode != "paused": pause_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui):
		if mode != "paused": pause_game()
		confirm_discard(func(): get_tree().quit())


func start_run(slot_index := -1, slot_name := "", difficulty := -1) -> void:
	clear_paused_overlay()
	sim = Loop.new(641023, selected_difficulty if difficulty < 0 else difficulty)
	selected_difficulty = sim.difficulty
	actor.reset()
	update_actor_mesh(true)
	active_slot = slot_index
	result_key = ""
	level_checkpoint = Campaign.snapshot(sim)
	if active_slot >= 0:
		campaign.store(active_slot, slot_name, level_checkpoint)
		save_notice = campaign.error
	preview_mode = false
	preview_weather = -1
	preview_victory = false
	sparks.clear()
	clear_overlay()
	clear_input()
	begin_intro()
	if DisplayServer.get_name() != "headless" and not audio.playing:
		audio.play()
		playback = audio.get_stream_playback()


func _exit_tree() -> void:
	if is_instance_valid(audio): audio.stop()
	playback = null


func pause_game() -> void:
	if mode == "paused" or not is_instance_valid(ui): return
	paused_mode = mode
	paused_overlay = overlay
	if is_instance_valid(paused_overlay): paused_overlay.hide()
	overlay = null
	mode = "paused"
	clear_input()
	var panel := new_panel(Rect2(28, 158, 304, 333))
	text_label(panel, "A moment of calm", Rect2(20, 19, 264, 36), 22, INK, true)
	text_label(panel, "Autumn will wait for you.", Rect2(20, 59, 264, 24), 11, INK)
	button(panel, "Resume", Rect2(24, 105, 256, 44), resume_game)
	if not level_checkpoint.is_empty(): button(panel, "Restart current level", Rect2(24, 159, 256, 40), confirm_restart, true)
	button(panel, "Exit to menu", Rect2(24, 209, 256, 40), confirm_menu, true)
	text_label(panel, "Completed weeks are saved.\nThis level resumes only when you choose.", Rect2(14, 265, 276, 45), 10, INK)


func resume_game() -> void:
	if mode != "paused": return
	clear_overlay()
	clear_input()
	overlay = paused_overlay
	paused_overlay = null
	if is_instance_valid(overlay): overlay.show()
	mode = paused_mode


func confirm_restart() -> void:
	confirm_discard(restart_level)


func confirm_menu() -> void:
	confirm_discard(show_title)


func confirm_discard(next: Callable) -> void:
	var panel := new_panel(Rect2(28, 203, 304, 224))
	text_label(panel, "Are you sure you want to exit?", Rect2(12, 18, 280, 38), 16, INK, true)
	text_label(panel, "Current level progress will be lost.\nCompleted weeks remain saved.", Rect2(14, 66, 276, 38), 10, INK)
	button(panel, "Keep playing", Rect2(24, 109, 256, 40), resume_game)
	button(panel, "Exit", Rect2(24, 160, 256, 40), next, true)


func clear_paused_overlay() -> void:
	if is_instance_valid(paused_overlay): paused_overlay.queue_free()
	paused_overlay = null


func atlas_regions(texture: Texture2D, columns: int, rows: int) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	var image := texture.get_image()
	var cell := Vector2i(image.get_width() / columns, image.get_height() / rows)
	for row in range(rows):
		for column in range(columns):
			var origin := Vector2i(column, row) * cell
			var used := image.get_region(Rect2i(origin, cell)).get_used_rect()
			regions.append(Rect2(used.position + origin, used.size))
	return regions


func save_boundary() -> void:
	var checkpoint := Campaign.snapshot(sim)
	if active_slot >= 0 and campaign.slots[active_slot] != null:
		campaign.store(active_slot, campaign.slots[active_slot].name, checkpoint)
		save_notice = campaign.error
	if sim.status == "playing": level_checkpoint = checkpoint


func restart_level() -> void:
	var restored = Campaign.restore(level_checkpoint)
	if restored == null: return
	clear_paused_overlay()
	clear_overlay()
	clear_input()
	sim = restored
	result_key = ""
	actor.reset()
	update_actor_mesh(true)
	begin_intro()
	ending_time = 0
	sparks.clear()


func show_slots() -> void:
	clear_paused_overlay()
	clear_input()
	mode = "slots"
	var panel := new_panel(Rect2(18, 116, 324, 409))
	text_label(panel, "Save Slots", Rect2(8, 17, 308, 34), 23, INK, true)
	text_label(panel, "3 local save slots · autosave after each level", Rect2(8, 56, 308, 24), 10, INK)
	for i in range(3):
		var record = campaign.slots[i]
		var y := 98 + i * 80
		if record == null:
			button(panel, "Slot %d · New save" % (i + 1), Rect2(16, y, 292, 57), func(): show_slot_name(i, false))
		else:
			var checkpoint: Dictionary = record.checkpoint
			var progress := "Final encounter" if checkpoint.week == Loop.BOSS_STAGE else "Week %d" % int(checkpoint.week)
			if checkpoint.phase == "workshop": progress += " complete"
			if checkpoint.phase == "won": progress = "Winter defeated!"
			button(panel, record.name + "\n" + progress + " · " + Loop.DIFFICULTIES[int(checkpoint.get("difficulty", 1))].name, Rect2(16, y, 202, 57), func(): load_slot(i))
			button(panel, "Edit", Rect2(229, y, 79, 57), func(): show_slot_name(i, true), true)
	button(panel, "Back to menu", Rect2(78, 351, 168, 36), show_title, true)
	if campaign.error != "": text_label(panel, campaign.error, Rect2(8, 386, 308, 19), 8, INK)


func show_slot_name(index: int, editing: bool, replacing := false) -> void:
	mode = "name"
	var panel := new_panel(Rect2(25, 157, 310, 355))
	text_label(panel, "Name your save", Rect2(10, 18, 290, 36), 22, INK, true)
	var input := LineEdit.new()
	input.position = Vector2(24, 105)
	input.size = Vector2(262, 40)
	input.max_length = 18
	input.text = campaign.slots[index].name if editing or replacing else "Save %d" % (index + 1)
	input.add_theme_font_override("font", BODY_FONT)
	input.add_theme_font_size_override("font_size", 16)
	panel.add_child(input)
	if not editing:
		if replacing: selected_difficulty = int(campaign.slots[index].checkpoint.get("difficulty", 1))
		var group := ButtonGroup.new()
		for i in range(3):
			var choice := button(panel, Loop.DIFFICULTIES[i].name, Rect2(18 + i * 92, 60, 88, 35), func(): selected_difficulty = i, true)
			choice.add_theme_font_size_override("font_size", 10)
			choice.add_theme_stylebox_override("pressed", panel_style(INK, 8))
			choice.add_theme_color_override("font_pressed_color", CREAM)
			choice.toggle_mode = true
			choice.button_group = group
			choice.button_pressed = selected_difficulty == i
		text_label(panel, "Choose a fresh difficulty.\nYour save stays until confirmation." if replacing else "Difficulty stays with this campaign.\nEach has its own local top ten.", Rect2(14, 213, 282, 43), 10, INK)
	else:
		var difficulty: int = campaign.slots[index].checkpoint.get("difficulty", 1)
		text_label(panel, Loop.DIFFICULTIES[difficulty].name + " · Difficulty stays with this campaign", Rect2(12, 62, 286, 28), 10, INK)
	var accept := func():
		if editing:
			campaign.rename_slot(index, input.text)
			show_slots()
		else:
			if replacing: confirm_reset_slot(index, input.text, selected_difficulty)
			else: start_run(index, input.text)
	button(panel, "Save name" if editing else ("Review fresh start" if replacing else "Start week 1"), Rect2(24, 165, 262, 40), accept)
	button(panel, "Back", Rect2(24, 278, 120, 36), show_slots, true)
	if editing: button(panel, "Start fresh…", Rect2(158, 278, 128, 36), func(): show_slot_name(index, false, true), true)
	input.text_submitted.connect(func(_text): accept.call())
	input.grab_focus()
	input.select_all()


func confirm_reset_slot(index: int, save_name: String, difficulty: int) -> void:
	var panel := new_panel(Rect2(25, 202, 310, 236))
	text_label(panel, "Start this campaign over?", Rect2(10, 20, 290, 35), 20, INK, true)
	text_label(panel, "This replaces its saved campaign.\nYour other saves will not change.", Rect2(10, 65, 290, 43), 11, INK)
	button(panel, "Keep my save", Rect2(24, 125, 262, 36), func(): show_slot_name(index, true))
	button(panel, "Start fresh · %s" % Loop.DIFFICULTIES[difficulty].name, Rect2(24, 176, 262, 36), func(): start_run(index, save_name, difficulty), true)


func load_slot(index: int) -> void:
	var record = campaign.slots[index]
	if record == null: return
	var restored = Campaign.restore(record.checkpoint)
	if restored == null: return
	active_slot = index
	sim = restored
	selected_difficulty = sim.difficulty
	result_key = ""
	actor.reset()
	update_actor_mesh(true)
	level_checkpoint = record.checkpoint.duplicate(true) if sim.status == "playing" else {}
	clear_overlay()
	clear_input()
	preview_mode = false
	preview_weather = -1
	preview_victory = false
	sparks.clear()
	if sim.status == "workshop":
		show_result()
	elif sim.status == "won":
		mode = "won"
		ending_time = 6.0
		show_result()
	else:
		begin_intro()
		pause_game()
	if DisplayServer.get_name() != "headless" and not audio.playing:
		audio.play()
		playback = audio.get_stream_playback()


func clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func panel_style(colour: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	style.border_color = Color("e0c493")
	style.set_border_width_all(1)
	style.shadow_color = Color(0.07, 0.11, 0.09, 0.25)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	return style


func new_panel(rect: Rect2) -> Panel:
	clear_overlay()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.10, 0.09, 0.22)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", panel_style(CREAM))
	overlay.add_child(panel)
	return panel


func text_label(parent: Node, content: String, rect: Rect2, size_px := 12, colour := CREAM, serif := false) -> Label:
	var label := Label.new()
	label.text = content
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", TITLE_FONT if serif else BODY_FONT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.size = rect.size
	return label


func button(parent: Node, content: String, rect: Rect2, callback: Callable, secondary := false) -> Button:
	var b := Button.new()
	b.text = content
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", BODY_FONT)
	b.add_theme_font_size_override("font_size", 12)
	var normal := GOLD if secondary else INK
	b.add_theme_stylebox_override("normal", panel_style(normal, 8))
	b.add_theme_stylebox_override("hover", panel_style(normal.lightened(0.12), 8))
	b.add_theme_stylebox_override("pressed", panel_style(normal.darkened(0.12), 8))
	b.add_theme_stylebox_override("focus", panel_style(normal.lightened(0.15), 8))
	b.add_theme_stylebox_override("disabled", panel_style(Color("c9c5ac"), 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK if secondary else CREAM)
	b.add_theme_color_override("font_disabled_color", Color("687064"))
	b.pressed.connect(callback)
	parent.add_child(b)
	b.position = rect.position
	b.size = rect.size
	return b


func show_title() -> void:
	clear_paused_overlay()
	sim = Loop.new()
	actor.reset()
	update_actor_mesh(true)
	active_slot = -1
	level_checkpoint = {}
	result_key = ""
	mode = "title"
	preview_weather = -1
	preview_victory = false
	preview_mode = false
	clear_input()
	var panel := new_panel(Rect2(26, 154, 308, 405))
	var logo := RichTextLabel.new()
	logo.bbcode_enabled = true
	logo.text = "[center]s[color=#bd5430]NO[/color]w[/center]"
	logo.position = Vector2(12, 13)
	logo.size = Vector2(284, 65)
	logo.add_theme_font_override("normal_font", TITLE_FONT)
	logo.add_theme_font_size_override("normal_font_size", 49)
	logo.add_theme_color_override("default_color", INK)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(logo)
	text_label(panel, "KEEP WINTER WAITING", Rect2(12, 77, 284, 20), 9, INK)
	text_label(panel, "Keep a little autumn alive.", Rect2(12, 107, 284, 22), 11, INK)
	button(panel, "Continue / New game", Rect2(25, 147, 258, 45), show_slots)
	button(panel, "Explore the seasons", Rect2(25, 203, 258, 40), show_season_lab, true)
	text_label(panel, "Move: A / D or arrows · Blow: hold Space\nE: Leaflift Surge (unlock in the workshop)", Rect2(12, 299, 284, 43), 10, INK)
	button(panel, "High Scores", Rect2(25, 254, 123, 38), func(): show_high_scores(), true)
	button(panel, "License", Rect2(160, 254, 123, 38), show_license, true)
	add_options(panel, 354)


func add_options(parent: Node, y: float) -> void:
	var effects := CheckButton.new()
	effects.text = "Soft effects"
	effects.position = Vector2(18, y)
	effects.size = Vector2(143, 30)
	effects.button_pressed = reduced_effects
	effects.add_theme_font_override("font", BODY_FONT)
	effects.add_theme_font_size_override("font_size", 10)
	effects.add_theme_color_override("font_color", INK)
	effects.toggled.connect(func(value: bool): reduced_effects = value)
	parent.add_child(effects)
	var sound := CheckButton.new()
	sound.text = "Mute"
	sound.position = Vector2(182, y)
	sound.size = Vector2(100, 30)
	sound.button_pressed = muted
	sound.add_theme_font_override("font", BODY_FONT)
	sound.add_theme_font_size_override("font_size", 10)
	sound.add_theme_color_override("font_color", INK)
	sound.toggled.connect(func(value: bool): muted = value)
	parent.add_child(sound)


func show_license() -> void:
	clear_input()
	mode = "license"
	var panel := new_panel(Rect2(18, 74, 324, 492))
	text_label(panel, "License & acknowledgements", Rect2(8, 14, 308, 35), 18, INK, true)
	var sections := ThirdParty.sections()
	var content := RichTextLabel.new()
	content.position = Vector2(16, 154)
	content.size = Vector2(292, 284)
	content.selection_enabled = true
	content.add_theme_font_override("normal_font", BODY_FONT)
	content.add_theme_font_size_override("normal_font_size", 11)
	content.add_theme_color_override("default_color", INK)
	content.text = sections.values()[0]
	license_section = "About"
	license_characters = content.text.length()
	panel.add_child(content)
	var group := ButtonGroup.new()
	for index in range(sections.size()):
		var select := func():
			content.text = sections.values()[index]
			license_section = sections.keys()[index]
			license_characters = content.text.length()
			content.scroll_to_line(0)
		var tab := button(panel, sections.keys()[index], Rect2(16 + (index % 2) * 152, 58 + int(index / 2) * 46, 140, 40), select, true)
		tab.add_theme_font_size_override("font_size", 11)
		tab.add_theme_stylebox_override("pressed", panel_style(INK, 8))
		tab.add_theme_color_override("font_pressed_color", CREAM)
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = index == 0
	button(panel, "Back to menu", Rect2(80, 449, 164, 36), show_title, true)


func show_high_scores(difficulty := -1, from_result := false, rules := HighScores.RULES) -> void:
	clear_input()
	mode = "scores"
	scores_return_to_result = from_result
	var selected: int = selected_difficulty if difficulty < 0 else difficulty
	var panel := new_panel(Rect2(18, 70, 324, 514))
	text_label(panel, "High Scores", Rect2(8, 15, 308, 36), 25, INK, true)
	for i in range(3):
		var tab := button(panel, Loop.DIFFICULTIES[i].name, Rect2(12 + i * 102, 65, 96, 38), func(): show_high_scores(i, from_result, rules), i != selected)
		tab.add_theme_font_size_override("font_size", 11)
	text_label(panel, "PREVIOUS RULES %d · ARCHIVED SCORES" % rules if rules != HighScores.RULES else "LOCAL TOP TEN · INITIALS / SCORE / PROGRESS", Rect2(8, 111, 308, 21), 9, INK)
	var table: Array = high_scores.entries(selected, rules)
	if table.is_empty():
		text_label(panel, "No scores yet.\n\nFinish a week, then enter your initials\non the results screen.", Rect2(10, 175, 304, 125), 13, INK)
	for i in range(table.size()):
		var record: Dictionary = table[i]
		var y := 139 + i * 27
		text_label(panel, str(i + 1), Rect2(9, y, 22, 25), 10, INK)
		text_label(panel, record.initials, Rect2(32, y, 41, 25), 12, INK)
		text_label(panel, "%06d" % int(record.score), Rect2(76, y, 83, 25), 13, INK)
		var stage := "Final encounter" if record.week == Loop.BOSS_STAGE else "Week %d" % int(record.week)
		var outcome: String = record.get("outcome", "won" if record.won else "lost")
		var progress: String = "CLEARED" if outcome == "workshop" else ("WIN" if outcome == "won" else "LOSS")
		text_label(panel, progress + " · " + stage + "\nBoots %d · Fan %d · Cell %d" % [record.tiers[0], record.tiers[1], record.tiers[2]], Rect2(164, y, 152, 26), 8, INK)
	var versions: Array[int] = high_scores.available_rules(selected)
	var archived := versions.size() > 1 or rules != HighScores.RULES
	var next_version: int = versions[(versions.find(rules) + 1) % versions.size()]
	if archived: button(panel, "Current scores" if next_version == HighScores.RULES else "Previous scores (%d)" % next_version, Rect2(80, 414, 164, 29), func(): show_high_scores(selected, from_result, next_version), true)
	if not high_scores.error.is_empty():
		var notice := text_label(panel, high_scores.error, Rect2(12, 445 if archived else 416, 300, 19 if archived else 40), 8 if archived else 10, INK)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(panel, "Back" if from_result else "Back to menu", Rect2(80, 465, 164, 36), return_from_scores, true)


func return_from_scores() -> void:
	if scores_return_to_result:
		show_result()
	else: show_title()


func show_initials() -> void:
	if not high_scores.qualifies(sim):
		show_high_scores(sim.difficulty, true)
		return
	clear_input()
	mode = "initials"
	var panel := new_panel(Rect2(28, 145, 304, 352))
	text_label(panel, "Make your mark", Rect2(10, 16, 284, 35), 23, INK, true)
	text_label(panel, "%d points · %s" % [sim.score, Loop.DIFFICULTIES[sim.difficulty].name], Rect2(10, 55, 284, 27), 12, INK)
	var input := LineEdit.new()
	input.position = Vector2(70, 92)
	input.size = Vector2(164, 42)
	var previous_initials: String = high_scores.initials_for(sim)
	input.text = previous_initials if not previous_initials.is_empty() else "AAA"
	input.max_length = 3
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_override("font", BODY_FONT)
	input.add_theme_font_size_override("font_size", 24)
	panel.add_child(input)
	input.text_changed.connect(func(value):
		var clean := ""
		for character in value.to_upper():
			if character >= "A" and character <= "Z": clean += character
		if input.text != clean:
			var caret := input.caret_column
			input.text = clean
			input.caret_column = mini(caret, clean.length()))
	for column in range(3):
		for direction in [-1, 1]:
			button(panel, "+" if direction == 1 else "−", Rect2(54 + column * 68, 149 if direction == 1 else 194, 54, 38), func():
				var initials := HighScores.clean_initials(input.text)
				initials[column] = char(65 + posmod(initials.unicode_at(column) - 65 + direction, 26))
				input.text = initials, true)
	text_label(panel, "A–Z · Type or use the letter buttons", Rect2(8, 236, 288, 23), 10, INK)
	var submit := func():
		high_scores.submit(sim, input.text)
		show_high_scores(sim.difficulty, true)
	button(panel, "Save score", Rect2(18, 279, 140, 42), submit)
	button(panel, "Not now", Rect2(170, 279, 116, 42), show_result, true)
	input.text_submitted.connect(func(_text): submit.call())
	if not DisplayServer.is_touchscreen_available():
		input.grab_focus()
		input.select_all()


func show_season_lab() -> void:
	preview_mode = true
	mode = "preview"
	preview_weather = 0.0
	preview_victory = false
	clear_overlay()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	text_label(overlay, "THE PAPER THEATRE", Rect2(20, 28, 320, 30), 16, CREAM, true)
	var labels := ["Autumn", "Warning", "Winter", "Victory"]
	for i in range(4):
		button(overlay, labels[i], Rect2(10 + i * 87, 542, 79, 39), func(): set_preview(i), true)
	button(overlay, "Back to menu", Rect2(95, 590, 170, 34), show_title)


func set_preview(index: int) -> void:
	preview_weather = [0.0, 0.83, 1.0, 0.0][index]
	preview_victory = index == 3
	ending_time = 6.0 if index in [2, 3] else 0.0


func show_workshop() -> void:
	if sim.status != "workshop": return
	mode = "workshop"
	clear_input()
	var panel := new_panel(Rect2(12, 78, 336, 492))
	text_label(panel, "Upgrade workshop", Rect2(8, 10, 320, 31), 23, INK, true)
	text_label(panel, "WEEK %d COMPLETE · %d POINT%s" % [sim.week, sim.points, "" if sim.points == 1 else "S"], Rect2(8, 45, 226, 23), 10, INK)
	button(panel, "Reset kit", Rect2(244, 44, 80, 27), func():
		sim.refund_build()
		selected_upgrade = Vector2i(0, 1)
		save_boundary()
		show_workshop(), true)
	for branch in range(3):
		var x := 10 + branch * 108
		var icon := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = UPGRADE_ICONS
		atlas.region = upgrade_regions[branch]
		icon.texture = atlas
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(x + 27, 73)
		icon.size = Vector2(44, 35)
		panel.add_child(icon)
		text_label(panel, Upgrades.TITLES[branch], Rect2(x, 109, 100, 17), 10, INK)
		var connector := Line2D.new()
		connector.points = PackedVector2Array([Vector2(x + 49, 143), Vector2(x + 49, 285)])
		connector.width = 2
		connector.default_color = Color("b7a17c")
		panel.add_child(connector)
		for rank in range(1, Upgrades.MAX_RANK + 1):
			var owned: bool = sim.tiers[branch] >= rank
			var available: bool = sim.tiers[branch] == rank - 1
			var chosen := selected_upgrade == Vector2i(branch, rank)
			var label: String = ("✓ " if owned else "%d " % rank) + Upgrades.NAMES[branch][rank - 1]
			var node := button(panel, label, Rect2(x, 132 + (rank - 1) * 28, 100, 25), func():
				selected_upgrade = Vector2i(branch, rank)
				show_workshop(), true)
			node.add_theme_font_size_override("font_size", 9)
			var colour := INK if owned else (GOLD if available else Color("e5dcc6"))
			for state in ["normal", "hover", "pressed", "focus"]:
				var style := panel_style(colour.lightened(0.08) if state == "hover" else colour, 5)
				style.shadow_size = 0
				style.shadow_offset = Vector2.ZERO
				style.set_border_width_all(2 if chosen else 1)
				style.border_color = RUST if chosen else Color("b6a17a")
				node.add_theme_stylebox_override(state, style)
			for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				node.add_theme_color_override(state, CREAM if owned else INK)
			node.size = Vector2(100, 25)
	var branch := selected_upgrade.x
	var rank := selected_upgrade.y
	var owned: bool = sim.tiers[branch] >= rank
	var available: bool = sim.tiers[branch] == rank - 1
	var status := "Owned" if owned else ("Costs 1 point" if available else "Requires rank %d in this branch" % (rank - 1))
	var card := Panel.new()
	card.position = Vector2(10, 310)
	card.size = Vector2(316, 86)
	var style := panel_style(Color("eee3c9"), 6)
	style.shadow_size = 0
	card.add_theme_stylebox_override("panel", style)
	panel.add_child(card)
	text_label(card, "%s · %s" % [Upgrades.NAMES[branch][rank - 1], status], Rect2(8, 3, 300, 22), 11, INK, true)
	var detail := RichTextLabel.new()
	detail.position = Vector2(9, 26)
	detail.size = Vector2(298, 54)
	detail.add_theme_font_override("normal_font", BODY_FONT)
	detail.add_theme_font_size_override("normal_font_size", 10)
	detail.add_theme_color_override("default_color", INK)
	detail.text = Upgrades.description(branch, rank)
	card.add_child(detail)
	var s: Dictionary = sim.stats()
	var ability_stat := "Surge %.0fs" % s.surge_cooldown if sim.surge_unlocked() else "Surge locked"
	text_label(panel, "Speed %d%% · Force %d%% · Burst %.1fs\nRecharge %.1fs · Max pile drag %d%% · %s" % [roundi(s.speed / Loop.BASE_SPEED * 100), roundi(s.force / 410 * 100), s.burst, s.recharge, roundi(s.pile_penalty * 100), ability_stat], Rect2(8, 400, 320, 29), 9, INK)
	var buy := button(panel, "Owned" if owned else "Buy · 1 point", Rect2(12, 439, 144, 38), func(): purchase(branch))
	buy.disabled = owned or not available or sim.points < 1
	button(panel, "Back to results", Rect2(174, 439, 150, 38), show_result, true)
	var regrowth: int = maxi(0, Loop.RECOVERY_FLOOR - sim.attached_count())
	var forecast := "Saved · Same canopy next week · New miss allowance" if regrowth == 0 else "Saved · %d leaves regrow next week · New miss allowance" % regrowth
	text_label(panel, forecast if save_notice.is_empty() else save_notice, Rect2(8, 480, 320, 13), 8, INK)


func purchase(branch: int) -> void:
	if sim.buy(branch):
		selected_upgrade = Vector2i(branch, mini(Upgrades.MAX_RANK, sim.tiers[branch] + 1))
		save_boundary()
		show_workshop()


func continue_week() -> void:
	if sim.next_week():
		actor.reset()
		update_actor_mesh(true)
		save_boundary()
		clear_overlay()
		clear_input()
		begin_intro()


func show_result() -> void:
	if sim.status not in ["workshop", "lost", "won"]: return
	clear_input()
	var key := "%s:%d:%s:%d" % [sim.run_id, sim.week, sim.status, sim.score]
	if key != result_key:
		result_key = key
		result_time = 0
		result_tallied = false
		result_new_high = false
	mode = "results" if sim.status == "workshop" else sim.status
	result_bars.clear()
	result_numbers.clear()
	result_actions.clear()
	var panel := new_panel(Rect2(24, 99, 312, 475))
	var title := "Week %d complete" % sim.week
	if sim.status == "lost": title = "Winter found a way."
	if sim.status == "won": title = "Winter can wait!"
	text_label(panel, title, Rect2(8, 12, 296, 37), 22, INK, true)
	var stage := "The North Wind" if sim.is_boss() else "Week %d" % sim.week
	text_label(panel, "%s · %d°C · %s" % [stage, sim.temperature(), Loop.DIFFICULTIES[sim.difficulty].name], Rect2(8, 52, 296, 22), 11, INK)
	var names := ["Leaves saved", "Leaves fallen", "Points earned"]
	var colours := [Color("76944c"), RUST, GOLD]
	for i in range(3):
		var y := 84 + i * 48
		var label := text_label(panel, names[i], Rect2(24, y, 180, 22), 12, INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var number := text_label(panel, "0", Rect2(204, y, 84, 22), 13, INK)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		result_numbers.append(number)
		var bar := ProgressBar.new()
		bar.position = Vector2(24, y + 25)
		bar.size = Vector2(264, 10)
		bar.show_percentage = false
		bar.add_theme_font_size_override("font_size", 1)
		bar.max_value = 1
		var track := panel_style(Color("dbd1b8"), 4)
		track.shadow_size = 0
		track.set_border_width_all(0)
		bar.add_theme_stylebox_override("background", track)
		var fill := track.duplicate()
		fill.bg_color = colours[i]
		bar.add_theme_stylebox_override("fill", fill)
		panel.add_child(bar)
		bar.size = Vector2(264, 10)
		result_bars.append(bar)
	result_total = text_label(panel, "", Rect2(12, 231, 288, 28), 18, INK, true)
	result_badge = text_label(panel, "Counting the leaves…", Rect2(10, 263, 292, 23), 14, RUST, true)
	result_score_action = button(panel, "Enter initials", Rect2(46, 294, 220, 34), show_initials, true)
	if sim.status == "workshop":
		result_actions.append(button(panel, "Upgrades · %d point%s available" % [sim.points, "" if sim.points == 1 else "s"], Rect2(16, 338, 280, 38), show_workshop, true))
		result_actions.append(button(panel, "Face the North Wind →" if sim.week == Loop.MAIN_WEEKS else "Start week %d →" % (sim.week + 1), Rect2(16, 385, 280, 38), continue_week))
	elif sim.status == "lost":
		text_label(panel, "Your checkpoint is safe.", Rect2(16, 338, 280, 30), 11, INK)
		result_actions.append(button(panel, "Retry this level", Rect2(16, 385, 280, 38), restart_level))
	else:
		text_label(panel, StageStory.chapter(Loop.BOSS_STAGE)[2].replace("\n", " "), Rect2(10, 335, 292, 38), 11, INK, true)
		result_actions.append(button(panel, "Save Slots", Rect2(16, 385, 280, 38), show_slots))
	result_actions.append(button(panel, "Main menu", Rect2(16, 430, 280, 30), show_title, true))
	update_result_tally()


func finish_tally() -> void:
	result_tallied = true
	result_new_high = high_scores.qualifies(sim)
	# Enter initials once; later improvements from this campaign update that row.
	var initials: String = high_scores.initials_for(sim)
	if result_new_high and not initials.is_empty(): high_scores.submit(sim, initials)


func update_result_tally() -> void:
	if not is_instance_valid(result_total) or result_numbers.size() != 3: return
	var earned: int = sim.score - sim.week_start_score if sim.week_start_score >= 0 else -1
	var values := [sim.week_rescued, sim.week_missed, earned]
	for i in range(3):
		var progress := 1.0 if reduced_effects or result_tallied else smoothstep(i * 0.25, 1.5 + i * 0.25, result_time)
		result_numbers[i].text = "—" if values[i] < 0 else str(roundi(values[i] * progress))
		result_bars[i].value = (float(values[i]) / maxf(1, sim.week_leaf_count()) if i < 2 else 1.0) * progress if values[i] >= 0 else 0
	var base: int = sim.week_start_score if sim.week_start_score >= 0 else sim.score
	var points_progress := 1.0 if reduced_effects or result_tallied else smoothstep(0.5, TALLY_DURATION, result_time)
	result_total.text = "Total score  %05d" % roundi(lerpf(base, sim.score, points_progress))
	result_badge.text = "New high score!" if result_tallied and result_new_high else ("Another week kept." if result_tallied and sim.status == "workshop" else ("" if result_tallied else "Counting the leaves…"))
	result_score_action.text = "Enter initials" if high_scores.qualifies(sim) else "High Scores"
	result_score_action.disabled = not result_tallied
	for action in result_actions: action.disabled = not result_tallied
	if not high_scores.error.is_empty() and result_tallied:
		result_badge.text = high_scores.error
		result_badge.add_theme_font_size_override("font_size", 9)



func weather() -> float:
	if preview_mode: return maxf(preview_weather, 0.0)
	if visual_mode() == "lost": return 1.0
	if visual_mode() in ["title", "won"]: return 0.0
	return sim.pressure()


func visual_mode() -> String:
	var current := paused_mode if mode == "paused" else mode
	if current == "intro": return "play"
	if current in ["outro", "results"]: return "workshop"
	if current == "initials" or (current == "scores" and scores_return_to_result): return sim.status
	return current


func _draw() -> void:
	draw_texture_rect(BACKDROP, Rect2(0, 0, 360, 640), false)
	var cold := weather()
	var scene_mode := visual_mode()
	var winter := scene_mode == "lost" or (preview_mode and preview_weather >= 1.0)
	var victory := scene_mode == "won" or preview_victory
	var ending := clampf(ending_time / 3.5, 0.0, 1.0)
	if cold > 0.45:
		draw_rect(Rect2(0, 0, 360, 640), Color(0.12, 0.24, 0.38, (cold - 0.45) * 0.65))
	if sim.week > 1 and mode != "title" and not victory:
		draw_rect(Rect2(0, 0, 360, 640), Color(0.25, 0.38, 0.52, (mini(sim.week, 12) - 1) * 0.012))
	draw_light(victory)
	draw_fog(cold)
	if sim.is_boss() and scene_mode == "play": draw_boss()
	draw_trees()
	draw_canopy(winter, ending, victory)
	if cold > 0.55:
		draw_clouds(cold, ending if winter else 0.4)
		draw_snow(cold, winter)
	if winter:
		draw_snow_cover(ending)
	if victory:
		draw_flowers(ending)
	if mode not in ["title", "preview"]:
		draw_piles()
	for leaf in sim.leaves:
		if mode not in ["title", "preview"]:
			draw_leaf(leaf.position, leaf.angle, leaf.colour, 5.0, leaf.get("roll", 1.0))
	if sim.blowing and mode == "play": draw_gust()
	if sim.surge_left > 0: draw_surge()
	draw_character(winter, victory)
	for spark in sparks:
		var alpha: float = 1.0 - spark.time / 0.8
		if spark.saved:
			draw_arc(spark.position, 5 + spark.time * 13, 0, TAU, 18, Color(1, 0.94, 0.68, alpha), 1.2, true)
			write("+", spark.position + Vector2(6, -spark.time * 15), 12, Color(1, 1, 0.86, alpha))
	if scene_mode == "play":
		draw_hud()
	if mode == "play": draw_controls()
	if mode == "play" and sim.week == 1 and sim.week_time < 8.0:
		var hint := "Blow leaves into empty spots on the branches"
		if sim.week_time > 4.0: hint = "Leaves click back on. Release to recharge."
		paper_box(Rect2(24, 525, 312, 25), Color(0.13, 0.23, 0.20, 0.88), 6)
		write_center(hint, 180, 541, 10, CREAM)
	if mode == "play" and sim.week_regrown > 0 and sim.week_time < 6.0:
		paper_box(Rect2(24, 525, 312, 25), INK, 6)
		write_center("%d leaves regrew overnight · Fresh weekly frost limit" % sim.week_regrown, 180, 541, 9, CREAM)
	if save_notice != "" and mode == "play":
		paper_box(Rect2(10, 521, 340, 27), INK, 5)
		write_center(save_notice, 180, 538, 8, CREAM)
	var story_mode := paused_mode if mode == "paused" else mode
	if story_mode in ["intro", "outro"]: draw_story_card(story_mode)
	draw_pause_button()


func draw_light(victory: bool) -> void:
	if reduced_effects: return
	var strength := 0.075 if victory else 0.035
	var drift := sin(elapsed * 0.13) * 8.0
	for i in range(3):
		var points := PackedVector2Array([Vector2(130 + i * 27, 74), Vector2(141 + i * 27, 74), Vector2(300 + i * 30 + drift, 521), Vector2(215 + i * 32 + drift, 521)])
		draw_colored_polygon(points, Color(1, 0.91, 0.62, strength))


func draw_fog(cold: float) -> void:
	if reduced_effects: return
	for layer in range(3):
		var y := 330.0 + layer * 26.0 + sin(elapsed * 0.15 + layer) * 8.0
		var pts := PackedVector2Array([Vector2(-10, y)])
		for i in range(19):
			pts.append(Vector2(i * 21, y + sin(i * 0.6 + elapsed * 0.12 + layer) * 10))
		pts.append(Vector2(380, y + 45))
		pts.append(Vector2(-10, y + 45))
		draw_colored_polygon(pts, Color(0.89, 0.88, 0.74, 0.032 + cold * 0.018))


func draw_trees() -> void:
	draw_texture_rect(TREE, Rect2(Canopy.TREE_RECT.position + Vector2(2, 3), Canopy.TREE_RECT.size), false, Color(0.13, 0.14, 0.10, 0.16))
	draw_texture_rect(TREE, Canopy.TREE_RECT, false)


func make_canopy_batch() -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_2D
	batch.use_colors = true
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var aspect := leaf_region.size.y / leaf_region.size.x
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, -aspect, 0), Vector3(1, -aspect, 0), Vector3(1, aspect, 0), Vector3(-1, aspect, 0)])
	var tex_size := Vector2(PAPER_LEAF.get_size())
	var uv := leaf_region.position / tex_size
	var end := leaf_region.end / tex_size
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([uv, Vector2(end.x, uv.y), end, Vector2(uv.x, end.y)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	batch.mesh = quad
	batch.instance_count = Canopy.SLOT_COUNT
	return batch


func draw_canopy(winter: bool, ending: float, victory: bool) -> void:
	var stamp := "%s:%d:%d:%s:%s:%.3f" % [sim.run_id, sim.canopy_revision, sim.week, winter, victory, preview_weather if preview_mode else -1.0]
	if stamp != canopy_stamp:
		canopy_stamp = stamp
		canopy_gap_markers.clear()
		var marked := {}
		for i in range(sim.slots.size()):
			var slot: Dictionary = sim.slots[i]
			var keep: bool = slot.leaf_id >= 0
			if preview_mode: keep = fmod(i * 0.61803398875, 1.0) >= preview_weather * 0.80
			if victory: keep = true
			var colour_week: int = 11 if preview_mode and preview_weather > 0.5 else sim.week
			if victory: colour_week = 1
			var colour: Color = sim.leaf_colour(slot.leaf_id if slot.leaf_id >= 0 else i, colour_week)
			if winter: colour = colour.lerp(Color("aabac3"), 0.4)
			var scale := Vector2.ONE * (6.0 if keep else 0.0)
			var instance := canopy_rank[i]
			canopy_batch.set_instance_transform_2d(instance, Transform2D(slot.angle, scale, 0, slot.position))
			canopy_batch.set_instance_color(instance, colour)
			canopy_shadows.set_instance_transform_2d(instance, Transform2D(slot.angle, scale, 0, slot.position + Vector2(0.9, 1.0)))
			canopy_shadows.set_instance_color(instance, Color(0.17, 0.17, 0.10, 0.20))
			if not keep:
				var cell := Vector2i(slot.position / 16.0)
				if not marked.has(cell):
					marked[cell] = true
					canopy_gap_markers.append(slot.position)
	# Authored branch connections stay visible beneath each denser twig spray.
	# Preordered instances let winter erase foliage without rebuilding 2,880 transforms each frame.
	var visible := roundi((1.0 - ending) * Canopy.SLOT_COUNT) if winter else -1
	canopy_batch.visible_instance_count = visible
	canopy_shadows.visible_instance_count = visible
	for i in range(Canopy.PREVIOUS_COUNT):
		var slot: Dictionary = sim.slots[i]
		draw_line(slot.stem, slot.position + Vector2(0, 5).rotated(slot.angle), Color("886341"), 0.7, true)
	draw_multimesh(canopy_shadows, PAPER_LEAF)
	draw_multimesh(canopy_batch, PAPER_LEAF)
	if mode == "play":
		for point in canopy_gap_markers:
			draw_arc(point, 2.0, 0, TAU, 12, Color(0.65, 0.38, 0.14, 0.42), 0.7, true)


func draw_clouds(cold: float, progress: float) -> void:
	for layer in range(3):
		var shade := Color("697e91").darkened(layer * 0.10)
		shade.a = clampf((cold - 0.5) * 1.8, 0, 0.92)
		draw_colored_polygon(cloud_polygon(layer, progress), shade)


func cloud_polygon(layer: int, progress: float) -> PackedVector2Array:
	var y := -80.0 + progress * 65.0 + layer * 18.0
	# Keep the top edge above every animated scallop, including the opening frame.
	var pts := PackedVector2Array([Vector2(-20, -150), Vector2(380, -150)])
	for i in range(20, -1, -1):
		pts.append(Vector2(i * 20.0 - 20.0, y + 65.0 + sin(i * 1.7 + layer) * 12.0))
	return pts


func draw_snow(cold: float, winter: bool) -> void:
	var count := 12 if cold < 0.8 else (28 if cold < 0.95 else 45)
	if winter: count = 65
	if reduced_effects: count = 4 if winter else 0
	for i in range(count):
		var f: Dictionary = snow[i]
		var p := Vector2(f.x + sin(elapsed * 0.8 + f.phase) * 12.0, f.y)
		if winter and i % 9 == 0:
			draw_set_transform(p, f.phase + elapsed * 0.15)
			var size_px: float = f.size * 4.0
			draw_texture_rect(SNOWFLAKE, Rect2(-size_px, -size_px, size_px * 2, size_px * 2), false, Color(1, 1, 1, 0.9))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_snowflake(p, f.size * 0.75, f.phase, Color(0.95, 0.98, 1, 0.6))


func draw_snowflake(p: Vector2, size_px: float, angle: float, colour: Color) -> void:
	for arm in range(6):
		var a := angle + arm * TAU / 6.0
		var tip := p + Vector2.from_angle(a) * size_px
		draw_line(p, tip, colour, maxf(0.6, size_px * 0.12), true)
		if size_px > 4:
			var middle := p + Vector2.from_angle(a) * size_px * 0.58
			for side in [-1, 1]:
				draw_line(middle, middle + Vector2.from_angle(a + side * 0.8) * size_px * 0.32, colour, 1.0, true)


func draw_snow_cover(amount: float) -> void:
	var pts := PackedVector2Array([Vector2(0, 640), Vector2(0, 508)])
	for i in range(37):
		pts.append(Vector2(i * 10, 508 - amount * (13.0 + sin(i * 0.6) * 6.0)))
	pts.append(Vector2(360, 640))
	draw_colored_polygon(pts, Color(0.88, 0.93, 0.96, amount * 0.9))
	# Snow rests on the painted branches, not on every leaf in a dense spray.
	for i in range(Canopy.PREVIOUS_COUNT):
		var p: Vector2 = sim.slots[i].stem
		draw_arc(p + Vector2(0, -2), 3.0, PI, TAU, 12, Color(0.95, 0.97, 0.98, amount * 0.8), 2.0, true)


func draw_flowers(amount: float) -> void:
	for i in range(21):
		var p := Vector2(12 + i * 17, 510 + sin(i * 2.8) * 9.0)
		var h := (12.0 + fmod(i * 13.0, 14.0)) * amount
		draw_line(p, p + Vector2(0, -h), Color("64794b"), 1.6, true)
		var colour: Color = [Color("f4b7ac"), Color("f4d47a"), Color("fff3d9")][i % 3]
		for petal in range(5):
			var center := p + Vector2(0, -h) + Vector2.from_angle(petal * TAU / 5) * 3.1 * amount
			draw_circle(center + Vector2(0.6, 0.8), 3.0 * amount, Color(0.1, 0.2, 0.1, 0.15))
			draw_circle(center, 2.8 * amount, colour)
		draw_circle(p + Vector2(0, -h), 1.8 * amount, RUST)


func draw_piles() -> void:
	for leaf in sim.ground_leaves:
		draw_leaf(leaf.position, leaf.angle, leaf.colour, 5.0, leaf.get("roll", 1.0))


func draw_leaf(p: Vector2, angle: float, colour: Color, size_px: float, roll := 1.0) -> void:
	var dimensions := Vector2(size_px * 2, size_px * 2 * leaf_region.size.y / leaf_region.size.x)
	draw_set_transform(p, angle, Vector2(roll, 1))
	draw_texture_rect_region(PAPER_LEAF, Rect2(-dimensions * 0.5 + Vector2(1.2, 1.5), dimensions), leaf_region, Color(0.17, 0.17, 0.10, 0.22))
	draw_texture_rect_region(PAPER_LEAF, Rect2(-dimensions * 0.5, dimensions), leaf_region, colour)
	draw_set_transform(Vector2.ZERO)


func update_actor_mesh(force := false) -> void:
	if wardrobe_regions.is_empty(): return
	var stage: int = clampi(sim.week - 1, 0, 11)
	if preview_mode: stage = 10 if preview_weather > 0.5 else 0
	var region: Rect2 = wardrobe_regions[stage]
	if not force and region == actor_region:
		if actor.movement == 0 and not actor.motor and not actor_mesh_active: return
		if (actor.movement > 0 or actor.motor) and Engine.get_physics_frames() % 2 != 0: return
	actor.rebuild(WARDROBE, region)
	actor_region = region
	actor_mesh_active = actor.movement > 0 or actor.motor


func draw_character(winter: bool, victory: bool) -> void:
	var px: float = 180.0 if visual_mode() in ["title", "preview"] else sim.x
	draw_set_transform(Vector2(px, Loop.GROUND + 1), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 22, Color(0.12, 0.16, 0.1, 0.24))
	draw_set_transform(Vector2.ZERO)
	if not winter and not victory:
		var turn := 1.0
		if sim.surge_left > 0:
			turn = cos((1.0 - sim.surge_left / Loop.SURGE_DURATION) * TAU)
			if absf(turn) < 0.08: turn = 0.08 if turn >= 0 else -0.08
		draw_set_transform(Vector2(px, Loop.GROUND), 0, Vector2(actor.direction * turn, 1))
		draw_mesh(actor.mesh, WARDROBE)
		draw_set_transform(Vector2.ZERO)
		return
	var region: Rect2 = ending_regions[0 if victory else 1]
	var bob := sin(elapsed * 4.0) * 1.5 if victory and not reduced_effects else 0.0
	var height := 76.0
	var width := height * region.size.x / region.size.y
	var rect := Rect2(px - width * 0.48, Loop.GROUND - height + bob, width, height)
	draw_texture_rect_region(ENDINGS, rect, region, Color("d8e4eb") if winter else Color.WHITE)


func draw_gust() -> void:
	var origin := Vector2(sim.x, Loop.GROUND) + actor.nozzle()
	var strength: Dictionary = sim.stats()
	for trail in range(16 if not reduced_effects else 5):
		var cycle := fmod(elapsed * 1.4 + trail * 0.61803398875, 1.0)
		var lane := sin(trail * 9.3)
		var height := cycle * 290.0
		var length_px := 16.0 + fmod(trail * 13.0, 24.0)
		var points := PackedVector2Array()
		for j in range(6):
			var h := height + j * length_px / 5.0
			var spread: float = strength.width * (0.12 + h / 420.0)
			# Short streaks travel away from the nozzle. Only a shallow bend, no helix.
			points.append(origin + sim.air_axis() * h + sim.air_axis().orthogonal() * (lane * spread + sin(h * 0.012 + trail) * 2.0))
		var alpha := sin(cycle * PI) * 0.55
		draw_polyline(points, Color(1.0, 0.99, 0.89, alpha * 0.3), 2.0, true)
		draw_polyline(points, Color(1.0, 0.99, 0.89, alpha), 0.85, true)


func frost_radius() -> float:
	var pressure: float = sim.pressure()
	var pulse := 0.0 if reduced_effects else sin(elapsed * (1.7 + pressure * 2.8)) * (0.025 + pressure * 0.075)
	return lerpf(7.5, 17.0, pressure) * (1.0 + pulse)


func battery_colour() -> Color:
	if sim.charge > 0.5: return Color("8bc66a")
	if sim.charge > 0.2: return Color("f1cc62")
	return Color("e98068")


func draw_hud() -> void:
	paper_box(SCORE_BADGE, Color(0.10, 0.20, 0.17, 0.94), 9)
	write("%05d" % sim.score, Vector2(24, 41), 19, CREAM, true)
	paper_box(FROST_BADGE, Color(0.10, 0.20, 0.17, 0.90), 12)
	var frost_center := FROST_BADGE.get_center()
	var pressure: float = sim.pressure()
	var radius := frost_radius()
	if pressure > 0.55:
		var danger := smoothstep(0.55, 1.0, pressure)
		draw_circle(frost_center, radius + 3, Color(0.63, 0.78, 0.91, danger * 0.22))
		draw_arc(frost_center, radius + 4, -PI / 2, -PI / 2 + TAU * danger, 64, Color(0.87, 0.66, 0.57, danger * 0.85), 1.3, true)
	var tint := Color("d7e6de").lerp(Color("b3d7f4"), pressure)
	draw_texture_rect(FROST_ICON, Rect2(frost_center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, tint)
	paper_box(BATTERY_BADGE, Color(0.10, 0.20, 0.17, 0.90), 9)
	var rect := Rect2(248, 21, 44, 26)
	var fill := Rect2(rect.position + Vector2(4.3, 6.2), Vector2(32.5 * sim.charge, 13.6))
	if sim.charge > 0:
		var paint := panel_style(battery_colour(), 1)
		paint.shadow_size = 0
		paint.set_border_width_all(0)
		draw_style_box(paint, fill)
	draw_texture_rect(BATTERY_FRAME, rect, false, CREAM)
	if not sim.blowing and sim.charge < 0.999 and sim.idle_charge_time > 0.5:
		draw_polyline(PackedVector2Array([Vector2(273, 26), Vector2(266, 35), Vector2(272, 35), Vector2(267, 42)]), CREAM, 1.5, true)



func draw_controls() -> void:
	var controls := [[LEFT, "left"], [RIGHT, "right"], [BLOW, "blow"]]
	if sim.surge_unlocked(): controls.append([SURGE, "surge"])
	for control in controls:
		var rect: Rect2 = control[0]
		var action: String = control[1]
		var down: bool = keys.get(action, false) or action in touches.values()
		var center := rect.get_center()
		var radius := 32.0 if action == "blow" else (26.0 if action == "surge" else 28.0)
		draw_circle(center + Vector2(0, 3), radius, Color(0.03, 0.08, 0.06, 0.3))
		draw_circle(center, radius, GOLD if down else Color(0.13, 0.23, 0.19, 0.85))
		draw_arc(center, radius, 0, TAU, 60, Color(0.96, 0.86, 0.65, 0.8), 1.1, true)
		var colour := INK if down else CREAM
		if action == "blow":
			draw_fan(center, 15, elapsed * 6.0 if sim.blowing or sim.surge_left > 0 else 0.0, colour)
		elif action == "surge":
			var ready: bool = sim.surge_charge >= 1.0
			draw_texture_rect(SURGE_ICON, Rect2(center - Vector2(12, 18), Vector2(24, 24)), false, colour if ready else Color(colour, 0.45))
			draw_arc(center, radius + 3, -PI / 2, -PI / 2 + TAU * sim.surge_charge, 96, GOLD, 2.0, true)
			write_center("SURGE" if ready else "%ds" % ceili((1 - sim.surge_charge) * sim.stats().surge_cooldown), center.x, center.y + 16, 8, colour)
		else:
			var sign_x := -1 if action == "left" else 1
			draw_polyline(PackedVector2Array([center + Vector2(-sign_x * 4, -8), center + Vector2(sign_x * 4, 0), center + Vector2(-sign_x * 4, 8)]), colour, 2.5, true)


func draw_pause_button() -> void:
	paper_box(PAUSE, INK, 8)
	if mode == "paused":
		draw_colored_polygon(PackedVector2Array([Vector2(323, 27), Vector2(334, 35), Vector2(323, 43)]), CREAM)
	else:
		draw_line(Vector2(324, 28), Vector2(324, 42), CREAM, 2)
		draw_line(Vector2(332, 28), Vector2(332, 42), CREAM, 2)


func draw_boss() -> void:
	var phase: String = sim.boss_phase()
	var position := Vector2(180 + sin(elapsed * 0.7) * 35, 120)
	for i in range(5):
		draw_circle(position + Vector2((i - 2) * 11, sin(i) * 5), 15, Color("8aabbb"))
	draw_circle(position + Vector2(-8, -1), 2, INK)
	draw_circle(position + Vector2(8, -1), 2, INK)
	draw_arc(position + Vector2(0, 5), 5, 0, PI, 12, INK, 1.4, true)
	var message := "THE NORTH WIND · Catch your breath"
	if phase == "warning": message = "THE NORTH WIND · Gust incoming!"
	elif phase == "blast": message = "THE NORTH WIND · Hold those leaves!"
	paper_box(Rect2(40, 150, 280, 23), Color(0.13, 0.23, 0.25, 0.9), 6)
	write_center(message, 180, 165, 9, CREAM)
	if phase == "blast": draw_snow(0.9, false)


func draw_fan(p: Vector2, radius: float, angle: float, colour: Color) -> void:
	draw_set_transform(p, angle)
	draw_texture_rect(FAN_ICON, Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2), false, colour)
	draw_set_transform(Vector2.ZERO)


func draw_bar(rect: Rect2, amount: float, colour: Color) -> void:
	paper_box(rect, Color(0.97, 0.95, 0.86, 0.18), 3)
	if amount > 0.001:
		paper_box(Rect2(rect.position, Vector2(rect.size.x * clampf(amount, 0, 1), rect.size.y)), colour, 3)


func paper_box(rect: Rect2, colour: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)


func write(content: String, p: Vector2, size_px: int, colour: Color, serif := false) -> void:
	draw_string(TITLE_FONT if serif else BODY_FONT, p, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)


func write_center(content: String, x: float, y: float, size_px: int, colour: Color, serif := false) -> void:
	var font: Font = TITLE_FONT if serif else BODY_FONT
	var width := font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	write(content, Vector2(x - width / 2.0, y), size_px, colour, serif)


func fill_audio() -> void:
	if playback == null: return
	var available := playback.get_frames_available()
	var active: bool = (sim.blowing or sim.surge_left > 0) and mode == "play" and not muted
	for i in range(available):
		audio_phase += TAU * (145.0 if sim.surge_left > 0 else 105.0) / 22050.0
		if audio_phase > TAU: audio_phase -= TAU
		var sample := sin(audio_phase) * 0.12 + sin(audio_phase * 2.0) * 0.03
		playback.push_frame(Vector2.ONE * sample * (1.0 if active else 0.0))


func begin_intro() -> void:
	clear_overlay()
	clear_input()
	mode = "intro"
	story_time = 0


func finish_story() -> void:
	if mode == "intro":
		clear_input()
		mode = "play"
	elif mode == "outro":
		show_result()


func draw_story_card(kind: String) -> void:
	var alpha := 1.0 if reduced_effects else smoothstep(0, 0.32, story_time) * (1.0 - smoothstep(StageStory.DURATION - 0.65, StageStory.DURATION, story_time))
	if kind == "intro" and not reduced_effects:
		draw_rect(Rect2(0, 0, 360, 640), Color(0.06, 0.12, 0.10, (1.0 - smoothstep(0, 0.85, story_time)) * 0.95))
	var rect := Rect2(24, 222, 312, 168)
	var style := panel_style(CREAM, 12)
	style.bg_color = Color(CREAM, alpha * 0.98)
	style.border_color = Color(GOLD, alpha)
	style.shadow_color = Color(0.05, 0.09, 0.07, alpha * 0.3)
	draw_style_box(style, rect)
	var chapter: Array = StageStory.chapter(sim.week)
	write_center(sim.stage_title() if kind == "intro" else "ANOTHER WEEK KEPT", 180, rect.position.y + 26, 10, Color(RUST, alpha))
	write_center(chapter[0], 180, rect.position.y + 53, 16, Color(INK, alpha), true)
	var lines: PackedStringArray = str(chapter[1 if kind == "intro" else 2]).split("\n")
	for i in range(lines.size()):
		write_center(lines[i], 180, rect.position.y + 87 + i * 23, 15, Color(INK, alpha), true)


func draw_surge() -> void:
	var phase: float = 1.0 - sim.surge_left / Loop.SURGE_DURATION
	var alpha := sin(phase * PI)
	var turn := cos(phase * TAU)
	var tip: Vector2 = actor.nozzle()
	tip.x *= turn
	var start := Vector2(sim.x, Loop.GROUND) + tip
	# Downward blast meets the ground and fans upward into a fountain of real leaves.
	for side in [-1, 1]:
		for lane in range(3):
			var spread: float = side * (32 + lane * 25) * sin(phase * PI * 0.7)
			var path := PackedVector2Array([start, Vector2(sim.x + side * 15, Loop.GROUND - 4), Vector2(sim.x + spread * 0.6, Loop.GROUND - 22), Vector2(sim.x + spread, Loop.GROUND - 50 - phase * 80)])
			draw_polyline(path, Color(CREAM, alpha * 0.65), 1.5, true)
	draw_arc(Vector2(sim.x, Loop.GROUND - 3), 15 + phase * float(sim.stats().surge_radius), PI, TAU, 96, Color(GOLD, alpha * 0.6), 2, true)
