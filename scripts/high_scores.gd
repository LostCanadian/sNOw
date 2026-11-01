extends RefCounted
## Top ten per difficulty, one best result per campaign. No accounts or network API.
const Campaign = preload("res://scripts/campaign.gd")
const RULES := 1
const WEB_KEY := "snow.highscores.v1"
const LIMIT := 10
var tables: Array = [[], [], []]
var path: String
var browser_storage := false
var error := ""

func _init(file_path := "user://highscores.json") -> void:
	path = file_path
	browser_storage = OS.has_feature("web") and file_path == "user://highscores.json"
	for backup in [false, true]:
		var raw := read_raw(backup)
		if raw.is_empty(): continue
		var document = Campaign.read_document(raw)
		if valid_document(document):
			tables = document.tables
			for table in tables:
				for record in table:
					for field in ["score", "week", "difficulty", "rules"]: record[field] = int(record[field])
					record.tiers = record.tiers.map(func(tier): return int(tier))
			if backup: error = "Recovered the last good local scores."
			return
		error = "Saved scores could not be read. Existing data was preserved."

static func clean_initials(value: String) -> String:
	var result := ""
	for character in value.to_upper():
		if character >= "A" and character <= "Z": result += character
	return result.substr(0, 3).rpad(3, "A")

static func valid_record(record) -> bool:
	if not record is Dictionary: return false
	if not record.get("id") is String or record.id.length() < 16 or record.id.length() > 80: return false
	if not record.get("initials") is String or record.initials.length() != 3 or record.initials != clean_initials(record.initials): return false
	for field in ["score", "week", "difficulty", "rules"]:
		if not Campaign.whole(record.get(field), 0, 1000000000): return false
	if record.score <= 0 or record.week < 1 or record.week > 13 or record.difficulty > 2 or record.rules != RULES: return false
	if not record.get("won") is bool or (record.won and record.week != 13): return false
	if not record.get("tiers") is Array or record.tiers.size() != 3: return false
	for tier in record.tiers:
		if not Campaign.whole(tier, 0, 2): return false
	return true

static func better(a: Dictionary, b: Dictionary) -> bool:
	return a.score > b.score or (a.score == b.score and a.week > b.week)

static func valid_document(data) -> bool:
	if not data is Dictionary or not Campaign.whole(data.get("version"), 1, 1): return false
	if not data.get("tables") is Array or data.tables.size() != 3: return false
	var ids := {}
	for difficulty in range(3):
		var table = data.tables[difficulty]
		if not table is Array or table.size() > LIMIT: return false
		for i in range(table.size()):
			var record = table[i]
			if not valid_record(record) or record.difficulty != difficulty or ids.has(record.id): return false
			if i > 0 and better(record, table[i - 1]): return false
			ids[record.id] = true
	return true

func candidate(game, initials: String) -> Dictionary:
	return {"id": game.run_id, "initials": clean_initials(initials), "score": game.score,
		"week": game.week, "won": game.status == "won", "tiers": game.tiers.duplicate(),
		"difficulty": game.difficulty, "rules": RULES}

func qualifies(game) -> bool:
	var record := candidate(game, "AAA")
	if game.status not in ["lost", "won"] or not valid_record(record): return false
	var table: Array = tables[game.difficulty]
	for old in table:
		if old.id == record.id: return better(record, old)
	return table.size() < LIMIT or better(record, table[-1])

func submit(game, initials: String) -> bool:
	if not qualifies(game): return false
	var record := candidate(game, initials)
	var table: Array = tables[game.difficulty].filter(func(old): return old.id != record.id)
	# Insert after exact ties so their original order is retained.
	var index := 0
	while index < table.size() and not better(record, table[index]): index += 1
	table.insert(index, record)
	if table.size() > LIMIT: table.resize(LIMIT)
	tables[game.difficulty] = table
	return flush()

func read_raw(backup: bool) -> String:
	if not browser_storage:
		var source := path + (".bak" if backup else "")
		return FileAccess.get_file_as_string(source) if FileAccess.file_exists(source) else ""
	var js := "(() => {try {return JSON.stringify({ok:true,data:localStorage.getItem(%s)});}catch(_){return JSON.stringify({ok:false});}})()" % JSON.stringify(WEB_KEY + (".backup" if backup else ""))
	var envelope = Campaign.read_document(str(JavaScriptBridge.eval(js, true)))
	if not envelope is Dictionary or not envelope.get("ok", false):
		error = "Browser storage is unavailable. Scores last only in this session."
		return ""
	return envelope.data if envelope.get("data") is String else ""

func flush() -> bool:
	var payload := JSON.stringify({"version": 1, "tables": tables})
	var previous := read_raw(false)
	if browser_storage:
		var js := "(() => {try {"
		if not previous.is_empty():
			var suffix := ".backup" if valid_document(Campaign.read_document(previous)) else ".unreadable"
			js += "localStorage.setItem(%s,%s);" % [JSON.stringify(WEB_KEY + suffix), JSON.stringify(previous)]
		js += "localStorage.setItem(%s,%s);return true;}catch(_){return false;}})()" % [JSON.stringify(WEB_KEY), JSON.stringify(payload)]
		if not bool(JavaScriptBridge.eval(js, true)):
			error = "Scores could not be saved. They last only in this session."
			return false
	else:
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		if file == null:
			error = "Scores could not be saved. They last only in this session."
			return false
		file.store_string(payload)
		file.flush()
		var result := file.get_error()
		file.close()
		if result != OK:
			error = "Score save failed. Your previous scores are preserved."
			return false
		if not previous.is_empty():
			var suffix := ".bak" if valid_document(Campaign.read_document(previous)) else ".unreadable-" + str(Time.get_ticks_usec())
			if DirAccess.copy_absolute(path, path + suffix) != OK:
				error = "Score backup failed. Your previous scores are preserved."
				return false
		if DirAccess.rename_absolute(path + ".tmp", path) != OK:
			error = "Score save failed. Your previous scores are preserved."
			return false
	error = ""
	return true
