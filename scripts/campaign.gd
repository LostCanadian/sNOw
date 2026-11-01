extends RefCounted
## Three local named campaign slots. Only level boundaries/workshop edits are durable.

const StoragePaths = preload("res://scripts/storage_paths.gd")
const Loop = preload("res://scripts/loop.gd")
const VERSION := 1
const WEB_KEY := "snow.campaigns.v1"
var path: String
var browser_storage := false
var slots: Array = [null, null, null]
var error := ""


func _init(file_path := "user://campaigns.json") -> void:
	path = file_path
	browser_storage = OS.has_feature("web") and file_path == "user://campaigns.json"
	load_slots()


func load_slots() -> void:
	for candidate in [path, path + ".bak"]:
		var raw := read_raw(candidate != path)
		if raw.is_empty(): continue
		var data = read_document(raw)
		if not data is Dictionary or not whole(data.get("version"), VERSION, VERSION) or not data.get("slots") is Array or data.slots.size() != 3:
			error = "Save data could not be read. Existing files were preserved."
			continue
		for i in range(3):
			var record = data.slots[i]
			if record == null: continue
			if record is Dictionary and record.get("name") is String and valid_checkpoint(record.get("checkpoint")):
				if slots[i] == null: slots[i] = {"name": clean_name(record.name, i), "checkpoint": record.checkpoint}
			else:
				error = "One save slot could not be read; other saves are available."
		if valid_document(data):
			if candidate != path: error = "Recovered the last good local checkpoint."
			return


func read_raw(backup: bool) -> String:
	if not browser_storage:
		var candidate := path + (".bak" if backup else "")
		if FileAccess.file_exists(candidate): return FileAccess.get_file_as_string(candidate)
		return StoragePaths.legacy_raw("campaigns.json", backup) if path == "user://campaigns.json" else ""
	var key := WEB_KEY + (".backup" if backup else "")
	var js := "(() => { try { return JSON.stringify({ok:true,data:localStorage.getItem(%s)}); } catch (_) { return JSON.stringify({ok:false}); } })()" % JSON.stringify(key)
	var envelope = read_document(str(JavaScriptBridge.eval(js, true)))
	if not envelope is Dictionary or not envelope.get("ok", false):
		error = "Browser storage is unavailable. Progress will last only in this session."
		return ""
	return envelope.data if envelope.get("data") is String else ""


static func valid_document(data) -> bool:
	if not data is Dictionary or not whole(data.get("version"), VERSION, VERSION) or not data.get("slots") is Array or data.slots.size() != 3: return false
	for record in data.slots:
		if record != null and (not record is Dictionary or not record.get("name") is String or not valid_checkpoint(record.get("checkpoint"))): return false
	return true


static func clean_name(value: String, index: int) -> String:
	var name := value.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 18)
	if name == "Garden %d" % (index + 1): name = "Save %d" % (index + 1)
	return "Save %d" % (index + 1) if name.is_empty() else name


static func read_document(text: String):
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null


static func snapshot(game) -> Dictionary:
	if game.status == "playing" and game.week_time > 0.0: return {}
	var ids: Array = []
	for slot in game.slots: ids.append(slot.leaf_id)
	return {"rules": Loop.RULES, "regrown": game.regrown, "week_regrown": game.week_regrown, "difficulty": game.difficulty, "run_id": game.run_id, "week": game.week, "phase": game.status, "score": game.score,
		"combo": game.combo, "week_rescued": game.week_rescued, "week_missed": game.week_missed,
		"rescued": game.rescued, "missed": game.missed, "points": game.points,
		"earned_points": game.earned_points, "tiers": game.tiers.duplicate(),
		"leaf_ids": ids, "order": game.shedding_order.duplicate(),
		"rng_state": str(game.rng.state), "rng_seed": str(game.rng.seed)}


static func whole(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high


static func valid_checkpoint(data) -> bool:
	if not data is Dictionary: return false
	if not whole(data.get("rules", 1), 1, Loop.RULES): return false
	var legacy: bool = data.get("rules", 1) == 1
	if not whole(data.get("difficulty", 1), 0, 2): return false
	if data.has("run_id") and (not data.run_id is String or data.run_id.length() < 16 or data.run_id.length() > 80): return false
	var count: int = Loop.Canopy.LEGACY_COUNT if legacy else Loop.Canopy.SLOT_COUNT
	for field in ["week", "phase", "score", "rescued", "missed", "points", "earned_points", "tiers", "leaf_ids", "order", "rng_state", "rng_seed"]:
		if not data.has(field): return false
	if not whole(data.week, 1, Loop.BOSS_STAGE) or not data.phase is String or data.phase not in ["playing", "workshop", "won"]: return false
	if data.phase == "workshop" and data.week > Loop.MAIN_WEEKS: return false
	if data.phase == "won" and data.week != Loop.BOSS_STAGE: return false
	if not whole(data.score, 0, 1000000000) or not whole(data.rescued, 0, 10000) or not whole(data.missed, 0, 10000): return false
	if legacy and data.missed >= [34, 28, 22][int(data.get("difficulty", 1))]: return false
	if not whole(data.get("regrown", 0), 0, int(data.missed)) or not whole(data.get("week_regrown", 0), 0, Loop.RECOVERY_FLOOR): return false
	if not whole(data.get("combo", 0), 0, int(data.rescued)): return false
	if not whole(data.get("week_rescued", 0), 0, count) or not whole(data.get("week_missed", 0), 0, mini(count, int(data.missed))): return false
	if data.phase == "playing" and (data.get("week_missed", 0) != 0 or data.get("week_rescued", 0) != 0): return false
	if not whole(data.earned_points, 0, Loop.MAIN_WEEKS) or not whole(data.points, 0, Loop.MAIN_WEEKS): return false
	var expected: int = int(data.week) if data.phase == "workshop" else mini(int(data.week) - 1, Loop.MAIN_WEEKS)
	if data.earned_points != expected: return false
	if not data.tiers is Array or data.tiers.size() != 3: return false
	var spent := 0
	for tier in data.tiers:
		if not whole(tier, 0, 2 if legacy else Loop.Upgrades.MAX_RANK): return false
		spent += (0 if tier == 0 else (1 if tier == 1 else 4)) if legacy else int(tier)
	if data.points + spent != data.earned_points: return false
	if not data.leaf_ids is Array or data.leaf_ids.size() != count: return false
	var seen := {}
	var missing := 0
	for id in data.leaf_ids:
		if not whole(id, -1, count - 1): return false
		if id == -1: missing += 1
		elif seen.has(int(id)): return false
		else: seen[int(id)] = true
	if missing != data.missed - data.get("regrown", 0): return false
	if not legacy and data.phase == "playing" and count - missing < Loop.RECOVERY_FLOOR: return false
	if not data.order is Array or data.order.size() > count: return false
	var ordered := {}
	for id in data.order:
		if not whole(id, 0, count - 1) or ordered.has(int(id)): return false
		ordered[int(id)] = true
		if data.phase == "playing" and not seen.has(int(id)): return false
	if data.phase == "playing" and data.order.is_empty(): return false
	for field in ["rng_state", "rng_seed"]:
		if not data[field] is String or not data[field].is_valid_int(): return false
		if str(data[field].to_int()) != data[field]: return false
	return true


static func restore(data):
	if not valid_checkpoint(data): return null
	var game = Loop.new(641023, int(data.get("difficulty", 1)))
	# Stable identity for legacy checkpoints: reloading/retrying never makes another score row.
	game.run_id = data.get("run_id", "legacy-" + JSON.stringify(data).sha256_text().substr(0, 32))
	game.week = int(data.week)
	game.status = data.phase
	game.score = int(data.score)
	game.combo = int(data.get("combo", 0))
	game.week_rescued = int(data.get("week_rescued", 0))
	game.week_missed = int(data.get("week_missed", 0))
	game.rescued = int(data.rescued)
	game.missed = int(data.missed)
	game.regrown = int(data.get("regrown", 0))
	game.week_regrown = int(data.get("week_regrown", 0))
	game.points = int(data.points)
	game.earned_points = int(data.earned_points)
	var legacy: bool = data.get("rules", 1) == 1
	game.tiers = data.tiers.map(func(t): return (4 if t == 2 else int(t)) if legacy else int(t))
	for i in range(data.leaf_ids.size()): game.slots[i].leaf_id = int(data.leaf_ids[i])
	game.shedding_order.assign(data.order.map(func(id): return int(id)))
	game.rng.seed = data.rng_seed.to_int()
	game.rng.state = data.rng_state.to_int()
	return game


func store(index: int, name: String, checkpoint: Dictionary) -> bool:
	if index < 0 or index > 2 or not valid_checkpoint(checkpoint):
		error = "This checkpoint could not be saved. Your previous save is unchanged."
		return false
	slots[index] = {"name": clean_name(name, index), "checkpoint": checkpoint.duplicate(true)}
	return flush()


func rename_slot(index: int, name: String) -> bool:
	if index < 0 or index > 2 or slots[index] == null: return false
	slots[index].name = clean_name(name, index)
	return flush()


func flush() -> bool:
	if browser_storage:
		# WebStorage setItem is an atomic, synchronous value replacement. Keep a
		# validated previous value separately; never depend on virtual-FS flush timing.
		var previous := read_raw(false)
		var payload := JSON.stringify({"version": VERSION, "slots": slots})
		var js := "(() => { try { "
		if valid_document(read_document(previous)):
			js += "localStorage.setItem(%s,%s);" % [JSON.stringify(WEB_KEY + ".backup"), JSON.stringify(previous)]
		elif not previous.is_empty():
			js += "localStorage.setItem(%s,%s);" % [JSON.stringify(WEB_KEY + ".unreadable"), JSON.stringify(previous)]
		js += "localStorage.setItem(%s,%s);return true;} catch (_) { return false; } })()" % [JSON.stringify(WEB_KEY), JSON.stringify(payload)]
		if not bool(JavaScriptBridge.eval(js, true)):
			error = "Browser save failed. Your previous checkpoint is preserved."
			return false
		error = ""
		return true
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Local saving is unavailable. Keep this session open to retain progress."
		return false
	file.store_string(JSON.stringify({"version": VERSION, "slots": slots}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		error = "Local save failed; your previous checkpoint is preserved."
		return false
	if FileAccess.file_exists(path):
		# Never replace a good recovery copy with malformed data.
		var old = read_document(FileAccess.get_file_as_string(path))
		if valid_document(old):
			if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(path + ".bak")
			if DirAccess.rename_absolute(path, path + ".bak") != OK:
				error = "Could not replace the save file. Your previous checkpoint is preserved."
				return false
		else:
			var recovery := path + ".unreadable-" + str(Time.get_ticks_usec())
			if DirAccess.rename_absolute(path, recovery) != OK:
				error = "Could not preserve the unreadable save. Your previous files are unchanged."
				return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if FileAccess.file_exists(path + ".bak"): DirAccess.copy_absolute(path + ".bak", path)
		error = "Could not finish saving. Your previous checkpoint is preserved."
		return false
	error = ""
	return true
