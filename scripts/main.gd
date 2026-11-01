extends Node2D
## A small paper theatre: simulation stays separate from cutout presentation and UI.

const Loop = preload("res://scripts/loop.gd")
const BACKDROP = preload("res://assets/art/autumn_stage.png")
const CARETAKER = preload("res://assets/art/caretaker.png")
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
var audio: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var audio_phase := 0.0
var last_frame_ms := 0.0
var test_hooks := false
var telemetry_tick := 0


func _ready() -> void:
	ambient_rng.seed = 90582
	character_region = Rect2(CARETAKER.get_image().get_used_rect())
	for i in range(65):
		snow.append({"x": ambient_rng.randf_range(0, 360), "y": ambient_rng.randf_range(-640, 640), "size": ambient_rng.randf_range(1.0, 3.6), "phase": ambient_rng.randf_range(0, TAU)})
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
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
			show_workshop()
		elif sim.status in ["lost", "won"]:
			mode = sim.status
			ending_time = 0.0
			clear_input()
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
	if test_hooks:
		telemetry_tick += 1
		if telemetry_tick % 6 == 0:
			var snapshot := {"mode": mode, "day": sim.day, "x": sim.x, "charge": sim.charge, "blowing": sim.blowing, "rescued": sim.rescued, "missed": sim.missed, "points": sim.points, "tiers": sim.tiers, "touches": touches.size(), "time": sim.day_time, "weather": weather(), "victory": preview_victory, "logical_size": [get_viewport_rect().size.x, get_viewport_rect().size.y]}
			JavaScriptBridge.eval("window.snowSnapshot = " + JSON.stringify(snapshot), true)


func _input(event: InputEvent) -> void:
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
					if mode == "play": pause_game()
					elif mode == "paused": resume_game()
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
		if mode == "play": pause_game()


func start_run() -> void:
	sim = Loop.new()
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
	if mode != "play": return
	mode = "paused"
	clear_input()
	var panel := new_panel(Rect2(28, 183, 304, 286))
	text_label(panel, "A moment of calm", Rect2(20, 19, 264, 36), 22, INK, true)
	text_label(panel, "Autumn will wait for you.", Rect2(20, 59, 264, 24), 11, INK)
	button(panel, "Resume", Rect2(24, 105, 256, 44), resume_game)
	button(panel, "Restart run", Rect2(24, 159, 256, 40), confirm_restart, true)
	button(panel, "Main menu", Rect2(24, 209, 256, 40), confirm_menu, true)


func resume_game() -> void:
	clear_overlay()
	clear_input()
	mode = "play"


func confirm_restart() -> void:
	confirm_discard(start_run)


func confirm_menu() -> void:
	confirm_discard(show_title)


func confirm_discard(next: Callable) -> void:
	var panel := new_panel(Rect2(28, 203, 304, 224))
	text_label(panel, "Leave this run?", Rect2(20, 18, 264, 38), 22, INK, true)
	text_label(panel, "This run and its upgrades will be lost.", Rect2(14, 66, 276, 23), 10, INK)
	button(panel, "Keep playing", Rect2(24, 109, 256, 40), resume_game)
	button(panel, "Leave run", Rect2(24, 160, 256, 40), next, true)


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
	button(panel, "Keep winter waiting", Rect2(25, 147, 258, 45), start_run)
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
	text_label(panel, "DAY %d KEPT WARM  ·  %d LEAVES SAVED" % [sim.day, sim.day_rescued], Rect2(10, 47, 304, 22), 9, INK)
	text_label(panel, "%d upgrade point%s  ·  score %s" % [sim.points, "" if sim.points == 1 else "s", str(sim.score)], Rect2(10, 72, 304, 23), 11, INK)
	var titles := ["BOOTS", "BLOWER", "BATTERY"]
	var names := [["Trail boots", "Sure footing"], ["Torque fan", "Heavy duty"], ["Efficiency", "Larger pack"]]
	var details := [["Run +10%", "Less pile drag"], ["Force +25%\nHeavier; drain +15%", "Force +50%, wider\nHeavier; drain +30%"], ["Energy draw −22%", "Capacity +30%\nSlightly heavier"]]
	for branch in range(3):
		var bx := 8.0 + branch * 105.0
		text_label(panel, titles[branch], Rect2(bx, 108, 98, 23), 11, INK, true)
		for tier in range(2):
			var owned: bool = sim.tiers[branch] > tier
			var cost := 1 if tier == 0 else 2
			var label: String = ("✓ " if owned else "") + names[branch][tier] + "\n" + ("Owned" if owned else "%d point%s" % [cost, "" if cost == 1 else "s"])
			var b := button(panel, label, Rect2(bx + 1, 138 + tier * 93, 95, 45), func(): purchase(branch))
			b.add_theme_font_size_override("font_size", 10)
			b.disabled = owned or sim.tiers[branch] != tier or sim.points < cost
			text_label(panel, details[branch][tier], Rect2(bx - 1, 186 + tier * 93, 101, 30), 8, INK)
	var s: Dictionary = sim.stats()
	text_label(panel, "YOUR KIT  ·  Speed %d%%  ·  Force %d%%\nBurst %.1fs  ·  Recharge %.1fs  ·  Max pile drag %d%%" % [roundi(s.speed / Loop.BASE_SPEED * 100), roundi(s.force / 410.0 * 100), s.burst, s.recharge, roundi(s.pile_penalty * 100)], Rect2(8, 326, 308, 44), 10, INK)
	button(panel, "Reallocate", Rect2(15, 384, 106, 35), func(): sim.refund_build(); show_workshop(), true)
	button(panel, "Start day %d →" % (sim.day + 1), Rect2(132, 384, 177, 35), continue_day)
	text_label(panel, "You can bank points. Your build lasts for this run.", Rect2(7, 431, 310, 23), 9, INK)


func purchase(branch: int) -> void:
	if sim.buy(branch): show_workshop()


func continue_day() -> void:
	if sim.next_day():
		clear_overlay()
		clear_input()
		mode = "play"


func show_result() -> void:
	var won := mode == "won"
	var panel := new_panel(Rect2(30, 205, 300, 250))
	text_label(panel, "Winter can wait!" if won else "Winter found a way.", Rect2(10, 17, 280, 37), 23, INK, true)
	text_label(panel, "Seven days of stubborn sunshine." if won else "A warm little effort. Another autumn awaits.", Rect2(8, 58, 284, 23), 10, INK)
	text_label(panel, "%s points  ·  day %d\n%d leaves returned to the trees" % [str(sim.score), sim.day, sim.rescued], Rect2(10, 88, 280, 40), 12, INK)
	button(panel, "Try another autumn", Rect2(24, 144, 252, 39), start_run)
	button(panel, "Main menu", Rect2(24, 195, 252, 35), show_title, true)


func weather() -> float:
	if preview_mode: return maxf(preview_weather, 0.0)
	if mode == "lost": return 1.0
	if mode in ["title", "won"]: return 0.0
	return sim.pressure()


func _draw() -> void:
	draw_texture_rect(BACKDROP, Rect2(0, 0, 360, 640), false)
	var cold := weather()
	var winter := mode == "lost" or (preview_mode and preview_weather >= 1.0)
	var victory := mode == "won" or preview_victory
	var ending := clampf(ending_time / 3.5, 0.0, 1.0)
	if cold > 0.45:
		draw_rect(Rect2(0, 0, 360, 640), Color(0.12, 0.24, 0.38, (cold - 0.45) * 0.65))
	draw_light(victory)
	draw_fog(cold)
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
			draw_leaf(leaf.position, leaf.angle, leaf.colour, 6.7)
	if sim.blowing and mode == "play": draw_gust()
	draw_character(winter, victory)
	for spark in sparks:
		var alpha: float = 1.0 - spark.time / 0.8
		if spark.saved:
			draw_arc(spark.position, 5 + spark.time * 13, 0, TAU, 18, Color(1, 0.94, 0.68, alpha), 1.2, true)
			write("+", spark.position + Vector2(6, -spark.time * 15), 12, Color(1, 1, 0.86, alpha))
	if mode in ["play", "paused", "workshop"]:
		draw_hud()
	if mode == "play": draw_controls()
	if mode == "play" and sim.day == 1 and sim.day_time < 8.0:
		var hint := "Hold the fan to lift leaves into the canopy"
		if sim.day_time > 4.0: hint = "Release to recharge. Keep the path clear."
		paper_box(Rect2(24, 525, 312, 25), Color(0.13, 0.23, 0.20, 0.88), 6)
		write_center(hint, 180, 541, 10, CREAM)


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
	for side in [0.0, 255.0]:
		for i in range(5):
			var p := Vector2(side + i * 22, 151 + sin(i * 0.7) * 25)
			draw_line(p, p + Vector2(25, -6), Color(0.95, 0.97, 0.98, amount * 0.8), 7.0, true)


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
	var shape := PackedVector2Array([Vector2(0, -1), Vector2(0.33, -0.5), Vector2(0.84, -0.67), Vector2(0.65, -0.12), Vector2(1, 0.05), Vector2(0.48, 0.40), Vector2(0.45, 0.78), Vector2(0, 0.55), Vector2(-0.45, 0.78), Vector2(-0.48, 0.4), Vector2(-1, 0.05), Vector2(-0.65, -0.12), Vector2(-0.84, -0.67), Vector2(-0.33, -0.5)])
	var points := PackedVector2Array()
	var shadow := PackedVector2Array()
	for vertex in shape:
		var v := p + (vertex * size_px).rotated(angle)
		points.append(v)
		shadow.append(v + Vector2(1.3, 1.6))
	draw_colored_polygon(shadow, Color(0.16, 0.16, 0.11, 0.25))
	draw_colored_polygon(points, colour)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, colour.darkened(0.45), 0.65, true)
	draw_line(p + Vector2(0, -size_px * 0.7).rotated(angle), p + Vector2(0, size_px).rotated(angle), colour.darkened(0.3), 0.65, true)


func draw_character(winter: bool, victory: bool) -> void:
	var px: float = 180.0 if mode in ["title", "preview"] else sim.x
	var bob := sin(elapsed * 17.0) * 1.5 * anim_move if mode == "play" else 0.0
	var height := 73.0
	var width := height * character_region.size.x / character_region.size.y
	draw_set_transform(Vector2(px, Loop.GROUND + 1))
	draw_set_transform(Vector2(px, Loop.GROUND + 1), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 23, Color(0.12, 0.16, 0.1, 0.24))
	draw_set_transform(Vector2.ZERO)
	var rect := Rect2(px - width * 0.48, Loop.GROUND - height + bob, width, height)
	var tint := Color("cbd9e4") if winter else Color.WHITE
	draw_texture_rect_region(CARETAKER, rect, character_region, tint)
	if victory:
		write_center("✦", px, Loop.GROUND - 82 + sin(elapsed * 2.0) * 3, 19, GOLD)


func draw_gust() -> void:
	var origin: Vector2 = sim.nozzle()
	for trail in range(3 if not reduced_effects else 1):
		var points := PackedVector2Array()
		for j in range(32):
			var h := j * 9.0
			var spread := 3.0 + h * 0.085
			points.append(origin + Vector2(sin(j * 0.40 - elapsed * 6.0 + trail * 2.0) * spread + sim.direction * h * 0.15, -h))
		draw_polyline(points, Color(1.0, 0.97, 0.77, 0.20), 3.2, true)
		draw_polyline(points, Color(1.0, 0.99, 0.89, 0.52), 0.8, true)


func draw_hud() -> void:
	paper_box(Rect2(12, 12, 291, 65), Color(0.10, 0.20, 0.17, 0.92), 9)
	write("DAY %d / 7" % sim.day, Vector2(24, 31), 11, GOLD)
	write("%05d" % sim.score, Vector2(24, 59), 22, CREAM, true)
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
