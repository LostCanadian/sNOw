extends RefCounted
## Notices come from the engine actually running the game, including export templates.

static func sections() -> Dictionary:
	var libraries := PackedStringArray()
	for component in Engine.get_copyright_info():
		libraries.append(component.name)
		for part in component.parts:
			libraries.append("Copyright: " + "; ".join(part.copyright))
			libraries.append("License: " + part.license)
			libraries.append("Files: " + ", ".join(part.files))
		libraries.append("")
	libraries.append("FULL LICENSE TERMS\n")
	var terms: Dictionary = Engine.get_license_info()
	for name in terms.keys():
		libraries.append(str(name) + "\n" + str(terms[name]) + "\n")
	return {
		"About": "sNOw\n\nBuilt with Godot Engine %s, GDScript and the Compatibility renderer.\n\nGodot is licensed under the MIT license. Its bundled libraries have their own licenses and copyright notices, reproduced in Engine libraries.\n\nDejaVu Sans and DejaVu Serif are distributed under the Bitstream Vera terms, with DejaVu changes in the public domain.\n\nNo additional third-party gameplay plugins are used. Game code, paper artwork and synthesized sound are separate from these third-party components. Their licenses apply to the components identified here.\n\nAll notices are available offline.\n\nSources:\nhttps://godotengine.org/license/\nhttps://github.com/godotengine/godot\nhttps://dejavu-fonts.github.io/" % Engine.get_version_info().string,
		"Godot (MIT)": "GODOT ENGINE — MIT LICENSE\n\n" + Engine.get_license_text(),
		"Engine libraries": "BUNDLED ENGINE COMPONENTS\n\n" + "\n".join(libraries),
		"DejaVu fonts": FileAccess.get_file_as_string("res://assets/licenses/DEJAVU.txt"),
	}
