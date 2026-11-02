extends SceneTree
const Director = preload("res://scripts/audio_director.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var audio = Director.new()
	audio.preferences_path = "user://audio-test-%d.json" % Time.get_ticks_usec()
	root.add_child(audio)
	check(audio.streams.size() == 19, "nine music scores and ten event effects are available offline, plus the separate motor loop")
	check(audio.scene_track("play",1) == "spring" and audio.scene_track("play",6) == "autumn" and audio.scene_track("play",12) == "frost" and audio.scene_track("play",13) == "boss", "music follows the campaign season and final encounter")
	check(audio.scene_track("workshop",9) == "workshop" and audio.scene_track("results",9) == "results" and audio.scene_track("won",13) == "victory" and audio.scene_track("lost",7) == "winter", "workshop, results and both endings have distinct scores")
	var loops := true
	for name in audio.MUSIC: loops = loops and audio.streams[name].loop and audio.streams[name].get_length() > 14
	check(loops, "all original score renderings are loopable and long enough to contain their eight-bar composition")
	audio.play_cue("upgrade")
	check(audio.cue_counts.is_empty(), "no sound starts before user interaction")
	audio.unlock()
	audio.update("play",1,true,1,16,true,true,1.0/60)
	check(audio.motor.playing and audio.cue_counts.get("whirlwind",0) == 1 and audio.cue_counts.get("shuffle",0) == 1, "blower, real steps and ability activation produce independent layers")
	for i in range(10): audio.update("play",1,true,1,16,false,true,1.0/60)
	check(audio.cue_counts.whirlwind == 1, "a held ability does not retrigger its effect every frame")
	audio.update("play",1,true,0.4,16,false,false,1,true)
	check(audio.motor.playing and audio.motor.pitch_scale<0.8,"low-power recovery keeps a quieter lower-pitched blower layer")
	# An impact is completely silent and cannot consume the rescue-cue throttle.
	var cue_before:Dictionary=audio.cue_counts.duplicate()
	var time_before:float=audio.last_leaf_cue
	for i in range(20):audio.leaf_cue(false)
	check(audio.cue_counts==cue_before and audio.last_leaf_cue==time_before,"a batch of ground impacts plays no sound and does not throttle a following rescue")
	audio.leaf_cue(true)
	check(audio.cue_counts.get("leaf_saved",0)==1 and not audio.cue_counts.has("leaf_fallen"),"reattachment keeps its soft cue while grounded leaves stay silent")
	audio.update("paused",1,true,1,16,false,true,1)
	check(not audio.motor.playing and audio.players[audio.current].stream_paused and audio.voices.all(func(voice): return not voice.playing), "pause stops effects and suspends music")
	audio.muted = true
	audio.update("play",1,true,1,16,false,false,1)
	check(not audio.motor.playing and audio.players[audio.current].stream_paused, "mute silences both music and effects")
	audio.music_volume = 0.25
	audio.effects_volume = 0.4
	audio.save_preferences()
	var loaded = Director.new()
	loaded.preferences_path = audio.preferences_path
	root.add_child(loaded)
	check(loaded.muted and loaded.music_volume == 0.25 and loaded.effects_volume == 0.4, "independent audio settings survive a native reload")
	DirAccess.remove_absolute(audio.preferences_path)
	audio.queue_free()
	loaded.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Audio routing and controls: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
