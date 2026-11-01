extends Node2D
## A small paper theatre: simulation stays separate from cutout presentation and UI.

const Loop = preload("res://scripts/loop.gd")
const Canopy = preload("res://scripts/canopy.gd")
const Campaign = preload("res://scripts/campaign.gd")
const BACKDROP = preload("res://assets/art/autumn_stage.png")
const PAPER_LEAF = preload("res://assets/art/paper_leaf.png")
const CARETAKER = preload("res://assets/art/caretaker.png")
const TREE = preload("res://assets/art/bare_tree.png")
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
const PAUSE := Rect2(310, 14, 36, 42)

var sim = Loop.new()
var mode := "title"
var ui: Control
var overlay: Control
var touches: Dictionary = {}
var keys: Dictionary = {}
var pointer_positions: Dictionary = {}
var elapsed := 0.0
var ending_time := 0.0
var ambient_rng := RandomNumberGenerator.new()
var snow: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var reduced_effects := false
var muted := false
var preview_weather := -1.0
var preview_victory := false
var preview_mode := false
var anim_move := 0.0
var character_region: Rect2
var leaf_region: Rect2
var wardrobe_regions: Array[Rect2] = []
var ending_regions: Array[Rect2] = []
var campaign = Campaign.new()
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
	wardrobe_regions = atlas_regions(WARDROBE, 4, 3)
	ending_regions = atlas_regions(ENDINGS, 2, 1)
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
	if mode == "play":
		var axis := float(bool(keys.get("right", false))) - float(bool(keys.get("left", false)))
		var blow: bool = keys.get("blow", false)
		for action in touches.values():
			if action == "left":
				axis -= 1.0
			elif action == "right":
				axis += 1.0
			elif action == "blow":
				blow = true
		sim.step(dt, clampf(axis, -1, 1), blow)
		anim_move = move_toward(anim_move, absf(axis), dt * 7.0)
		for event in sim.events:
			if sparks.size() < 50:
				sparks.append({"position": event.position, "time": 0.0, "saved": event.saved})
		if sim.status == "workshop":
			mode = "workshop"
			clear_input()
			save_boundary()
			show_workshop()
		elif sim.status in ["lost", "won"]:
			mode = sim.status
			ending_time = 0.0
			clear_input()
			if mode == "won": save_boundary()
	if mode in ["lost", "won"]:
		ending_time += dt
		if ending_time >= 4.0 and overlay == null:
			show_result()
	if mode != "paused":
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
				"mode": mode, "week": sim.week, "x": sim.x, "charge": sim.charge,
				"blowing": sim.blowing, "rescued": sim.rescued, "missed": sim.missed,
				"points": sim.points, "tiers": sim.tiers, "touches": touches.size(),
				"time": sim.week_time, "weather": weather(), "victory": preview_victory,
				"attached": sim.attached_count(), "slots": sim.slots.size(), "air": sim.leaves.size(),
				"result_visible": mode in ["lost", "won"] and overlay != null,
				"active_slot": active_slot, "phase": sim.status, "temperature": sim.temperature(), "boss_phase": sim.boss_phase(),
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
	if event is InputEventKey:
		if event.echo:
			return
		var action := ""
		match event.physical_keycode:
			KEY_A, KEY_LEFT: action = "left"
			KEY_D, KEY_RIGHT: action = "right"
			KEY_SPACE: action = "blow"
			KEY_ESCAPE:
				if event.pressed:
					if mode == "paused": resume_game()
					else: pause_game()
		if action != "":
			keys[action] = event.pressed and mode == "play"
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
	return ""


func pointer_begin(id: int, point: Vector2) -> void:
	if PAUSE.has_point(point):
		pause_game()
		return
	var action := action_at(point)
	if action != "":
		touches[id] = action
		pointer_positions[id] = point


func pointer_drag(id: int, point: Vector2) -> void:
	if touches.has(id):
		touches[id] = action_at(point)
		pointer_positions[id] = point


func clear_input() -> void:
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


func start_run(slot_index := -1, slot_name := "") -> void:
	clear_paused_overlay()
	sim = Loop.new()
	active_slot = slot_index
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
	mode = "play"
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
	mode = "play"
	ending_time = 0
	sparks.clear()


func show_slots() -> void:
	clear_paused_overlay()
	clear_input()
	mode = "slots"
	var panel := new_panel(Rect2(18, 116, 324, 409))
	text_label(panel, "Your autumn gardens", Rect2(8, 17, 308, 34), 23, INK, true)
	text_label(panel, "3 local save slots · autosave after each level", Rect2(8, 56, 308, 24), 10, INK)
	for i in range(3):
		var record = campaign.slots[i]
		var y := 98 + i * 80
		if record == null:
			button(panel, "Slot %d · New garden" % (i + 1), Rect2(16, y, 292, 57), func(): show_slot_name(i, false))
		else:
			var checkpoint: Dictionary = record.checkpoint
			var progress := "Final encounter" if checkpoint.week == Loop.BOSS_STAGE else "Week %d" % int(checkpoint.week)
			if checkpoint.phase == "workshop": progress += " complete"
			if checkpoint.phase == "won": progress = "Winter defeated!"
			button(panel, record.name + "\n" + progress, Rect2(16, y, 202, 57), func(): load_slot(i))
			button(panel, "Edit", Rect2(229, y, 79, 57), func(): show_slot_name(i, true), true)
	button(panel, "Back to menu", Rect2(78, 351, 168, 36), show_title, true)
	if campaign.error != "": text_label(panel, campaign.error, Rect2(8, 386, 308, 19), 8, INK)


func show_slot_name(index: int, editing: bool) -> void:
	mode = "name"
	var panel := new_panel(Rect2(25, 187, 310, 275))
	text_label(panel, "Name your garden", Rect2(10, 18, 290, 36), 22, INK, true)
	var input := LineEdit.new()
	input.position = Vector2(24, 75)
	input.size = Vector2(262, 40)
	input.max_length = 18
	input.text = campaign.slots[index].name if editing else "Garden %d" % (index + 1)
	input.add_theme_font_override("font", BODY_FONT)
	input.add_theme_font_size_override("font_size", 16)
	panel.add_child(input)
	var accept := func():
		if editing:
			campaign.rename_slot(index, input.text)
			show_slots()
		else: start_run(index, input.text)
	button(panel, "Save name" if editing else "Start week 1", Rect2(24, 135, 262, 40), accept)
	button(panel, "Back", Rect2(24, 187, 120, 36), show_slots, true)
	if editing: button(panel, "Start over", Rect2(158, 187, 128, 36), func(): confirm_reset_slot(index), true)
	input.text_submitted.connect(func(_text): accept.call())
	input.grab_focus()
	input.select_all()


func confirm_reset_slot(index: int) -> void:
	var panel := new_panel(Rect2(25, 202, 310, 236))
	text_label(panel, "Start this garden over?", Rect2(10, 20, 290, 35), 20, INK, true)
	text_label(panel, "This replaces its saved campaign.\nYour other gardens will not change.", Rect2(10, 65, 290, 43), 11, INK)
	button(panel, "Keep my save", Rect2(24, 125, 262, 36), show_slots)
	button(panel, "Replace with a new campaign", Rect2(24, 176, 262, 36), func(): start_run(index, campaign.slots[index].name), true)


func load_slot(index: int) -> void:
	var record = campaign.slots[index]
	if record == null: return
	var restored = Campaign.restore(record.checkpoint)
	if restored == null: return
	active_slot = index
	sim = restored
	level_checkpoint = record.checkpoint.duplicate(true) if sim.status == "playing" else {}
	clear_overlay()
	clear_input()
	preview_mode = false
	preview_weather = -1
	preview_victory = false
	sparks.clear()
	if sim.status == "workshop":
		mode = "workshop"
		show_workshop()
	elif sim.status == "won":
		mode = "won"
		ending_time = 6.0
		show_result()
	else:
		mode = "play"
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
	return b


func show_title() -> void:
	clear_paused_overlay()
	sim = Loop.new()
	active_slot = -1
	level_checkpoint = {}
	mode = "title"
	preview_weather = -1
	preview_victory = false
	preview_mode = false
	clear_input()
	var panel := new_panel(Rect2(26, 154, 308, 338))
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
	text_label(panel, "P A P E R  &  L A N T E R N S", Rect2(12, 77, 284, 20), 9, INK)
	text_label(panel, "A little blower. One stubborn autumn.", Rect2(12, 107, 284, 22), 11, INK)
	button(panel, "Continue / New garden", Rect2(25, 147, 258, 45), show_slots)
	button(panel, "Explore the seasons", Rect2(25, 203, 258, 40), show_season_lab, true)
	text_label(panel, "Move: A / D or arrows  ·  Blow: hold Space\nOn a phone, hold the buttons below.", Rect2(12, 254, 284, 43), 10, INK)
	add_options(panel, 302)


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
	var panel := new_panel(Rect2(18, 84, 324, 467))
	text_label(panel, "The paper workshop", Rect2(10, 12, 304, 34), 23, INK, true)
	text_label(panel, "WEEK %d KEPT WARM  ·  %d LEAVES SAVED" % [sim.week, sim.week_rescued], Rect2(10, 47, 304, 22), 9, INK)
	text_label(panel, "%d upgrade point%s  ·  score %s" % [sim.points, "" if sim.points == 1 else "s", str(sim.score)], Rect2(10, 72, 304, 23), 11, INK)
	var titles := ["BOOTS", "BLOWER", "BATTERY"]
	var names := [["Trail boots", "Sure footing"], ["Torque fan", "Heavy duty"], ["Efficiency", "Larger pack"]]
	var details := [["Run +10%", "Less pile drag"], ["Force +25%\nHeavier; drain +15%", "Force +50%, wider\nHeavier; drain +30%"], ["Energy draw −22%", "Capacity +30%\nSlightly heavier"]]
	for branch in range(3):
		var bx := 8.0 + branch * 105.0
		text_label(panel, titles[branch], Rect2(bx, 108, 98, 23), 11, INK, true)
		for tier in range(2):
			var owned: bool = sim.tiers[branch] > tier
			var cost := 1 if tier == 0 else 3
			var label: String = ("✓ " if owned else "") + names[branch][tier] + "\n" + ("Owned" if owned else "%d point%s" % [cost, "" if cost == 1 else "s"])
			var b := button(panel, label, Rect2(bx + 1, 138 + tier * 93, 95, 45), func(): purchase(branch))
			b.add_theme_font_size_override("font_size", 10)
			b.disabled = owned or sim.tiers[branch] != tier or sim.points < cost
			text_label(panel, details[branch][tier], Rect2(bx - 1, 186 + tier * 93, 101, 30), 8, INK)
	var s: Dictionary = sim.stats()
	text_label(panel, "YOUR KIT  ·  Speed %d%%  ·  Force %d%%\nBurst %.1fs  ·  Recharge %.1fs  ·  Max pile drag %d%%" % [roundi(s.speed / Loop.BASE_SPEED * 100), roundi(s.force / 410.0 * 100), s.burst, s.recharge, roundi(s.pile_penalty * 100)], Rect2(8, 326, 308, 44), 10, INK)
	button(panel, "Reallocate", Rect2(15, 384, 106, 35), func(): sim.refund_build(); save_boundary(); show_workshop(), true)
	button(panel, "Face the North Wind →" if sim.week == Loop.MAIN_WEEKS else "Start week %d →" % (sim.week + 1), Rect2(132, 384, 177, 35), continue_week)
	text_label(panel, "Autosaved locally." if active_slot >= 0 and save_notice == "" else (save_notice if save_notice != "" else "You can bank points. Upgrades last for this campaign."), Rect2(7, 431, 310, 23), 9, INK)


func purchase(branch: int) -> void:
	if sim.buy(branch):
		save_boundary()
		show_workshop()


func continue_week() -> void:
	if sim.next_week():
		save_boundary()
		clear_overlay()
		clear_input()
		mode = "play"


func show_result() -> void:
	var won := mode == "won"
	var panel := new_panel(Rect2(30, 205, 300, 250))
	text_label(panel, "Winter can wait!" if won else "Winter found a way.", Rect2(10, 17, 280, 37), 23, INK, true)
	text_label(panel, "Twelve weeks. One North Wind defeated." if won else "Your checkpoint is safe. Try this level again.", Rect2(8, 58, 284, 23), 10, INK)
	text_label(panel, "%s points · %s\n%d leaves returned to the trees" % [str(sim.score), "Final encounter" if sim.is_boss() else "Week %d" % sim.week, sim.rescued], Rect2(10, 88, 280, 40), 12, INK)
	button(panel, "Your gardens" if won else "Retry this level", Rect2(24, 144, 252, 39), show_slots if won else restart_level)
	button(panel, "Main menu", Rect2(24, 195, 252, 35), show_title, true)


func weather() -> float:
	if preview_mode: return maxf(preview_weather, 0.0)
	if visual_mode() == "lost": return 1.0
	if visual_mode() in ["title", "won"]: return 0.0
	return sim.pressure()


func visual_mode() -> String:
	return paused_mode if mode == "paused" else mode


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
			draw_leaf(leaf.position, leaf.angle, leaf.colour, 9.5)
	if sim.blowing and mode == "play": draw_gust()
	draw_character(winter, victory)
	for spark in sparks:
		var alpha: float = 1.0 - spark.time / 0.8
		if spark.saved:
			draw_arc(spark.position, 5 + spark.time * 13, 0, TAU, 18, Color(1, 0.94, 0.68, alpha), 1.2, true)
			write("+", spark.position + Vector2(6, -spark.time * 15), 12, Color(1, 1, 0.86, alpha))
	if scene_mode in ["play", "workshop"]:
		draw_hud()
	if mode == "play": draw_controls()
	if mode == "play" and sim.week == 1 and sim.week_time < 8.0:
		var hint := "Blow leaves into empty spots on the branches"
		if sim.week_time > 4.0: hint = "Leaves click back on. Release to recharge."
		paper_box(Rect2(24, 525, 312, 25), Color(0.13, 0.23, 0.20, 0.88), 6)
		write_center(hint, 180, 541, 10, CREAM)
	if save_notice != "" and mode == "play":
		paper_box(Rect2(10, 521, 340, 27), INK, 5)
		write_center(save_notice, 180, 538, 8, CREAM)
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
	for side in range(2):
		if side == 1: draw_set_transform(Vector2(360, 0), 0, Vector2(-1, 1))
		draw_texture_rect(TREE, Rect2(Canopy.TREE_RECT.position + Vector2(2, 3), Canopy.TREE_RECT.size), false, Color(0.13, 0.14, 0.10, 0.16))
		draw_texture_rect(TREE, Canopy.TREE_RECT, false)
		draw_set_transform(Vector2.ZERO)


func draw_canopy(winter: bool, ending: float, victory: bool) -> void:
	for i in range(sim.slots.size()):
		var slot: Dictionary = sim.slots[i]
		var keep: bool = slot.leaf_id >= 0
		if preview_mode:
			# Preview actual bare/occupied positions without changing a live run.
			keep = fmod(i * 0.61803398875, 1.0) >= preview_weather * Loop.CAPACITY / sim.slots.size()
		if winter and fmod(i * 0.61803398875, 1.0) < ending: keep = false
		if victory: keep = true
		var p: Vector2 = slot.position
		draw_line(slot.stem, p + Vector2(0, 9).rotated(slot.angle), Color("886341"), 1.0, true)
		if keep:
			var colour_week: int = 11 if preview_mode and preview_weather > 0.5 else sim.week
			if victory: colour_week = 1
			var colour: Color = sim.leaf_colour(slot.leaf_id if slot.leaf_id >= 0 else i, colour_week)
			if winter: colour = colour.lerp(Color("aabac3"), ending * 0.8)
			var sway := 0.0 if reduced_effects else sin(elapsed * 1.5 + i) * 0.045
			draw_leaf(p, slot.angle + sway, colour, 12.5)
			var since: float = sim.week_time - slot.attached_at
			if since >= 0 and since < 0.5 and mode == "play":
				draw_arc(p, 10 + since * 10, 0, TAU, 24, Color(1, 0.92, 0.6, 0.8 * (1.0 - since * 2)), 1.2, true)
		elif mode == "play":
			draw_arc(p, 2.7, 0, TAU, 12, Color(0.65, 0.38, 0.14, 0.6), 0.85, true)


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
	for slot in sim.slots:
		var p: Vector2 = slot.stem
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
	for segment in range(sim.piles.size()):
		var count: int = mini(sim.piles[segment], 12)
		for i in range(count * 3):
			var px := segment * 30 + 3 + fmod(i * 13.7, 27.0)
			var py := Loop.GROUND + 4.0 - (i / 3.0) * 1.6 + sin(i * 2.0) * 2.0
			draw_leaf(Vector2(px, py), i * 2.4, Loop.LEAF_COLOURS[(segment + i) % 4], 5.0)


func draw_leaf(p: Vector2, angle: float, colour: Color, size_px: float) -> void:
	var dimensions := Vector2(size_px * 2, size_px * 2 * leaf_region.size.y / leaf_region.size.x)
	draw_set_transform(p, angle)
	draw_texture_rect_region(PAPER_LEAF, Rect2(-dimensions * 0.5 + Vector2(1.2, 1.5), dimensions), leaf_region, Color(0.17, 0.17, 0.10, 0.22))
	draw_texture_rect_region(PAPER_LEAF, Rect2(-dimensions * 0.5, dimensions), leaf_region, colour)
	draw_set_transform(Vector2.ZERO)


func draw_character(winter: bool, victory: bool) -> void:
	var px: float = 180.0 if visual_mode() in ["title", "preview"] else sim.x
	var bob := sin(elapsed * 12.0) * 1.2 * anim_move if mode == "play" and not reduced_effects else 0.0
	var stage: int = clampi(sim.week - 1, 0, 11)
	if preview_mode: stage = 10 if preview_weather > 0.5 else 0
	var region: Rect2 = wardrobe_regions[stage]
	var texture: Texture2D = WARDROBE
	if winter or victory:
		texture = ENDINGS
		region = ending_regions[0 if victory else 1]
		bob = sin(elapsed * 4.0) * 1.5 if victory and not reduced_effects else 0.0
	var height := 76.0
	var width := height * region.size.x / region.size.y
	draw_set_transform(Vector2(px, Loop.GROUND + 1), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 22, Color(0.12, 0.16, 0.1, 0.24))
	draw_set_transform(Vector2.ZERO)
	var rect := Rect2(px - width * 0.48, Loop.GROUND - height + bob, width, height)
	draw_texture_rect_region(texture, rect, region, Color("d8e4eb") if winter else Color.WHITE)


func draw_gust() -> void:
	var origin: Vector2 = sim.nozzle()
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
			points.append(origin + Vector2(lane * spread + sim.direction * h * 0.15 + sin(h * 0.012 + trail) * 2.0, -h))
		var alpha := sin(cycle * PI) * 0.55
		draw_polyline(points, Color(1.0, 0.99, 0.89, alpha * 0.3), 2.0, true)
		draw_polyline(points, Color(1.0, 0.99, 0.89, alpha), 0.85, true)


func draw_hud() -> void:
	paper_box(Rect2(12, 12, 291, 65), Color(0.10, 0.20, 0.17, 0.92), 9)
	write(sim.stage_title(), Vector2(24, 31), 8 if sim.is_boss() else 10, GOLD)
	write("%05d" % sim.score, Vector2(24, 53), 18, CREAM, true)
	write("%d°C" % sim.temperature(), Vector2(88, 66), 10, GOLD)
	draw_snowflake(Vector2(141, 30), 6.0, 0, CREAM)
	write("WINTER", Vector2(155, 27), 8, CREAM)
	write("%d / %d" % [sim.missed, Loop.CAPACITY], Vector2(254, 27), 8, CREAM)
	draw_bar(Rect2(155, 33, 133, 7), sim.pressure(), Color("c5deea"))
	draw_fan(Vector2(141, 57), 6, elapsed * 4 if sim.blowing else 0, GOLD)
	write("BATTERY", Vector2(155, 52), 8, CREAM)
	write("%d%%" % roundi(sim.charge * 100), Vector2(261, 52), 8, CREAM)
	draw_bar(Rect2(155, 58, 133, 7), sim.charge, GOLD if sim.charge > 0.22 else Color("e8a075"))
	paper_box(PAUSE, Color(0.1, 0.2, 0.17, 0.93), 8)
	draw_line(Vector2(324, 28), Vector2(324, 42), CREAM, 2)
	draw_line(Vector2(332, 28), Vector2(332, 42), CREAM, 2)
	if sim.energy_locked:
		write_center("Release the fan to recharge", 180, 95, 11, INK)
	elif not sim.blowing and sim.charge < 0.99 and sim.idle_charge_time > 0.5:
		write_center("Recharging…", 180, 95, 10, INK)
	elif sim.combo >= 5:
		write_center("%d leaves in a row" % sim.combo, 180, 95, 11, INK)


func draw_controls() -> void:
	for control in [[LEFT, "left"], [RIGHT, "right"], [BLOW, "blow"]]:
		var rect: Rect2 = control[0]
		var action: String = control[1]
		var down: bool = keys.get(action, false) or action in touches.values()
		var center := rect.get_center()
		var radius := 32.0 if action == "blow" else 28.0
		draw_circle(center + Vector2(0, 3), radius, Color(0.03, 0.08, 0.06, 0.3))
		draw_circle(center, radius, GOLD if down else Color(0.13, 0.23, 0.19, 0.85))
		draw_arc(center, radius, 0, TAU, 60, Color(0.96, 0.86, 0.65, 0.8), 1.1, true)
		var colour := INK if down else CREAM
		if action == "blow":
			draw_fan(center + Vector2(0, -4), 12, elapsed * 6.0 if down else 0.0, colour)
			write_center("HOLD", center.x, center.y + 22, 7, colour)
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
	for i in range(3):
		var a := angle + i * TAU / 3
		var pts := PackedVector2Array([p, p + Vector2.from_angle(a) * radius, p + Vector2.from_angle(a + 0.65) * radius, p + Vector2.from_angle(a + 1.15) * radius * 0.35])
		draw_colored_polygon(pts, colour)
	draw_circle(p, radius * 0.22, colour.darkened(0.2))


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


func write_center(content: String, x: float, y: float, size_px: int, colour: Color) -> void:
	var width := BODY_FONT.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	write(content, Vector2(x - width / 2.0, y), size_px, colour)


func fill_audio() -> void:
	if playback == null: return
	var available := playback.get_frames_available()
	var active: bool = sim.blowing and mode == "play" and not muted
	for i in range(available):
		audio_phase += TAU * 105.0 / 22050.0
		if audio_phase > TAU: audio_phase -= TAU
		var sample := sin(audio_phase) * 0.12 + sin(audio_phase * 2.0) * 0.03
		playback.push_frame(Vector2.ONE * sample * (1.0 if active else 0.0))
