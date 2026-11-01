extends RefCounted
## Keep native saves readable after removing the former style label from the app title.
static func legacy_raw(filename: String, backup: bool) -> String:
	if OS.has_feature("web"): return ""
	var directory := OS.get_user_data_dir().get_base_dir().path_join("sNOw — Paper & Lanterns")
	var source := directory.path_join(filename + (".bak" if backup else ""))
	if FileAccess.file_exists(source): return FileAccess.get_file_as_string(source)
	if backup: return legacy_raw(filename, false)
	return ""
