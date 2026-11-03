extends Node
## Original rendered MIDI score plus layered effects; no runtime synthesis dependency.
## Short Web effects use Godot samples; long Web music uses compressed media streaming.
const MUSIC := ["menu", "workshop", "boss", "results", "victory", "winter",
	"week_01", "week_02", "week_03", "week_04", "week_05", "week_06",
	"week_07", "week_08", "week_09", "week_10", "week_11", "week_12"]
const EFFECTS := ["menu_tap", "menu_focus", "upgrade", "reset", "shuffle", "whirlwind", "leaf_saved", "leaf_fallen", "battery_low", "week_clear"]
const SETTINGS_KEY := "snow.audio.v1"
var preferences_path := "user://audio.json"
var muted := false
var music_volume := 0.55
var effects_volume := 0.65
var track := ""
var players: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var streams := {}
var motor: AudioStreamPlayer
var current := 0
var fade: Tween
var unlocked := false
var walking_step := 0
var previous_surge := false
var previous_low := false
var last_leaf_cue := 0.0
var cue_time := 0.0
var cue_counts := {}
var paused := false

func _ready() -> void:
	read_preferences()
	setup_web_music()
	for name in MUSIC:
		if OS.has_feature("web"):
			streams[name] = null
			continue
		var stream: AudioStreamOggVorbis = load("res://assets/audio/%s.ogg" % name)
		stream.loop = true
		streams[name] = stream
	for name in EFFECTS: streams[name] = load("res://assets/audio/%s.ogg" % name)
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
		player.volume_db = -60
		add_child(player)
		players.append(player)
	for i in range(10):
		var voice := AudioStreamPlayer.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
		add_child(voice)
		voices.append(voice)
	motor = AudioStreamPlayer.new()
	motor.playback_type = AudioServer.PLAYBACK_TYPE_DEFAULT
	motor.stream = load("res://assets/audio/blower.ogg")
	motor.stream.loop = true
	motor.volume_db = -60
	add_child(motor)

func unlock() -> void:
	# Called by real input; browsers resume their audio context on the same gesture.
	unlocked = true
	if OS.has_feature("web"): JavaScriptBridge.eval("window.snowMusic?.unlock()", true)

func read_preferences() -> void:
	var raw := ""
	if OS.has_feature("web"):
		raw = str(JavaScriptBridge.eval("(() => {try{return localStorage.getItem('snow.audio.v1') || '';}catch(_){return '';}})()", true))
	elif FileAccess.file_exists(preferences_path):
		raw = FileAccess.get_file_as_string(preferences_path)
	var preferences = JSON.parse_string(raw) if not raw.is_empty() else null
	if not preferences is Dictionary: return
	muted = preferences.get("muted", false) == true
	for key in ["music_volume", "effects_volume"]:
		var value = preferences.get(key)
		if (value is float or value is int) and is_finite(float(value)) and value >= 0 and value <= 1: set(key, float(value))

func save_preferences() -> void:
	var payload := JSON.stringify({"muted":muted,"music_volume":music_volume,"effects_volume":effects_volume})
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(() => {try{localStorage.setItem('snow.audio.v1',%s);}catch(_){}})()" % JSON.stringify(payload), true)
	else:
		var file := FileAccess.open(preferences_path, FileAccess.WRITE)
		if file: file.store_string(payload)

func scene_track(mode: String, week: int) -> String:
	if mode == "workshop": return "workshop"
	if mode in ["results", "outro"]: return "results"
	if mode == "won": return "victory"
	if mode == "lost": return "winter"
	if mode in ["play", "intro", "continue"]:
		return "boss" if week == 13 else "week_%02d"%clampi(week,1,12)
	return "menu"

func play_cue(name: String, volume := 1.0) -> void:
	if muted or not unlocked or paused or effects_volume <= 0 or not streams.has(name): return
	for voice in voices:
		if voice.playing: continue
		voice.stream = streams[name]
		voice.volume_db = linear_to_db(maxf(0.00001, effects_volume * volume)) - 8
		voice.pitch_scale = 1.0
		voice.play()
		cue_counts[name] = cue_counts.get(name, 0) + 1
		return

func select_track(name: String) -> void:
	if name == track: return
	track = name
	if fade: fade.kill()
	var old := players[current]
	current = 1-current
	var next := players[current]
	next.stop()
	if OS.has_feature("web"):
		select_web_track(name)
	else:
		next.stream = streams[name]
	next.volume_db = -60
	if unlocked and not muted and not OS.has_feature("web"): next.play()
	fade = create_tween().set_parallel(true)
	fade.tween_property(old, "volume_db", -60.0, 0.45)
	fade.tween_property(next, "volume_db", linear_to_db(maxf(0.00001,music_volume)) - 4, 0.45)

func update(mode: String, week: int, blowing: bool, charge: float, distance: float, moving: bool, surge: bool, dt: float, low_power:=false) -> void:
	cue_time += dt
	paused = mode == "paused"
	if not paused: select_track(scene_track(mode, week))
	for i in range(players.size()):
		players[i].stream_paused = paused or muted
	if unlocked and not paused and not muted and not OS.has_feature("web") and not players[current].playing and track != "": players[current].play()
	if not fade or not fade.is_running(): players[current].volume_db = linear_to_db(maxf(0.00001,music_volume)) - 4
	if paused or muted:
		for voice in voices: voice.stop()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.snowMusic?.update(%s,%s,%f,%f)" % [str(paused),str(muted),db_to_linear(players[0].volume_db),db_to_linear(players[1].volume_db)], true)
	var motor_on := unlocked and mode == "play" and blowing and not muted and effects_volume > 0
	if motor_on and not motor.playing: motor.play()
	motor.pitch_scale=0.72 if low_power else lerpf(0.92,1.07,charge)
	motor.volume_db = move_toward(motor.volume_db, linear_to_db(maxf(0.00001,effects_volume)) - (17 if low_power else 11) if motor_on else -60.0, dt * 160)
	if not motor_on and motor.volume_db <= -59: motor.stop()
	if mode == "play":
		var step := floori(distance / 14.5)
		if moving and step != walking_step: play_cue("shuffle",0.23)
		walking_step = step
		if surge and not previous_surge: play_cue("whirlwind",0.9)
		var low := charge < 0.12
		if low and not previous_low: play_cue("battery_low",0.35)
		previous_low = low
	previous_surge = surge

func leaf_cue(saved: bool) -> void:
	if not saved: return
	# Ten-leaf batches should sound like one small rustle, not ten stacked samples.
	if cue_time-last_leaf_cue < 0.12: return
	last_leaf_cue = cue_time
	play_cue("leaf_saved",0.35)

func setup_web_music() -> void:
	if not OS.has_feature("web"): return
	JavaScriptBridge.eval("""(() => {
		const context = new (window.AudioContext || window.webkitAudioContext)();
		const players = [new Audio(), new Audio()];
		for (const player of players) {
			player.loop = true; player.preload = 'auto'; player.volume = 0;
			context.createMediaElementSource(player).connect(context.destination);
		}
		window.snowMusic = {
			players, context, unlocked: false, urls: {}, current: 1,
			setTrack(index, name, encoded) {
				if (!this.urls[name]) {
					const binary = atob(encoded), bytes = new Uint8Array(binary.length);
					for (let i=0; i<binary.length; i++) bytes[i] = binary.charCodeAt(i);
					this.urls[name] = URL.createObjectURL(new Blob([bytes], {type:'audio/mpeg'}));
				}
				this.current = index;
				players[index].pause(); players[index].volume = 0;
				players[index].src = this.urls[name];
			},
			unlock() {
				this.unlocked = true; context.resume().catch(() => {});
				const active = players[this.current];
				// Prime both persistent elements in the same real input gesture for mobile Safari.
				for (const player of players) {
					if (!player.src && active.src) player.src = active.src;
					if (player.src) player.play().catch(() => {});
				}
			},
			update(paused, muted, a, b) {
				for (let i=0; i<2; i++) {
					const player=players[i]; player.volume=Math.max(0,Math.min(1,i===0?a:b));
					if (paused || muted || !this.unlocked || (i!==this.current && player.volume<0.00002)) player.pause();
					else if (player.src && player.paused) player.play().catch(() => {});
				}
			},
			dispose() {
				players.forEach(p => {p.pause(); p.removeAttribute('src'); p.load();});
				Object.values(this.urls).forEach(url => URL.revokeObjectURL(url));
				context.close().catch(() => {});
			}
		};
	})()""", true)


func select_web_track(name: String) -> void:
	var file := FileAccess.get_file_as_bytes("res://assets/audio/streams/%s.mp3data" % name)
	# Audio files remain inside the game package; no additional network request is needed.
	JavaScriptBridge.eval("window.snowMusic?.setTrack(%d,%s,%s)" % [current, JSON.stringify(name), JSON.stringify(Marshalls.raw_to_base64(file))], true)


func _exit_tree() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.snowMusic?.dispose()", true)
	if fade: fade.kill()
	for player in players + voices:
		player.stop()
		player.stream = null
	if is_instance_valid(motor):
		motor.stop()
		motor.stream = null
	streams.clear()
