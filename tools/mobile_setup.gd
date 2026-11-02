extends SceneTree
## Runs only inside an isolated export staging project, before the actual export.
func _initialize() -> void:
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://mobile_config.json"))
	if not config is Dictionary:
		push_error("Invalid mobile export configuration.")
		quit(1)
		return
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	if ProjectSettings.save() != OK:
		quit(1)
		return
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var section: String = config.section
	for key in config.options:
		var value = config.options[key]
		if value is float and value == floor(value): value = int(value)
		presets.set_value(section + ".options", key, value)
	# Exclude staging helpers and configuration from the packaged application.
	presets.set_value(section, "exclude_filter", presets.get_value(section,"exclude_filter","") + ",mobile_config.json,mobile_setup.gd")
	if presets.save("res://export_presets.cfg") != OK:
		quit(1)
		return
	if config.has("android_sdk"):
		var settings = EditorInterface.get_editor_settings()
		settings.set_setting("export/android/android_sdk_path", config.android_sdk)
		settings.set_setting("export/android/java_sdk_path", config.java_home)
		if ResourceSaver.save(settings, settings.resource_path) != OK:
			push_error("Could not save Android SDK paths for the command-line exporter.")
			quit(1)
			return
	print("Mobile export configuration ready.")
	quit()
