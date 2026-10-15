extends Node
## Persistent player data as one JSON document in user://.
## Writes go to a temp file first and the previous save is kept as a backup,
## so a crash mid-write or a corrupt file never loses progress.

signal saved

const VERSION: int = 2
const DEFAULT_PATH: String = "user://word_lantern_save.json"

var path: String = DEFAULT_PATH
var data: Dictionary = {}
## Set when the save could not be read and a backup or fresh save was used.
var recovered_from: String = ""

var _dirty: bool = false


func _ready() -> void:
	load_data()


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"coins": Economy.START_COINS,
		# level id -> {"stars": 1..3}
		"cleared": {},
		# level id -> LevelState.to_dict() for half-played levels
		"progress": {},
		# level ids opened early with a level key
		"unlocked": {},
		"keys": 0,
		# diamond keys open a whole locked chapter (from level 1)
		"diamonds": 0,
		# chapter ids opened early with a diamond key
		"chapters_opened": {},
		# coins bought with real money (kept on a progress reset)
		"coins_bought": 0,
		"owned": {},
		"trials": {},
		"tips": 0,
		"video": {"day": "", "coins": 0, "keys": 0, "diamonds": 0},
		"sparks": {"day": "", "used": 0},
		"daily": {"done": {}, "streak": 0, "best_streak": 0, "last_date": ""},
		"achievements": {},
		"stats": {"levels": 0, "stars": 0, "perfect": 0, "words": 0, "dailies": 0, "best_streak": 0, "beacons": 0, "hints": 0},
		"settings": {"music_volume": 0.6, "sound_volume": 0.8, "haptics": true, "theme": "chapters", "style": "classic"},
		"seen": {},
		"last_level": "",
	}


func load_data() -> void:
	recovered_from = ""
	var loaded: Variant = _read(path)
	if loaded == null and FileAccess.file_exists(path):
		loaded = _read(path + ".bak")
		recovered_from = "backup" if loaded != null else "fresh"
	var d: Dictionary = loaded if loaded is Dictionary else {}
	if not d.is_empty() and int(d.get("version", 1)) < 2:
		_migrate_v1(d)
	data = _merge(defaults(), d)
	data["version"] = VERSION


## Version 1 had 8 worlds of 20 different levels: keep coins, settings, dailies,
## achievements and word stats, but level progress no longer applies.
static func _migrate_v1(d: Dictionary) -> void:
	for k: String in ["cleared", "progress", "last_level", "free_spark_date"]:
		d.erase(k)
	var st: Variant = d.get("stats", {})
	if st is Dictionary:
		for k: String in ["levels", "flawless", "worlds"]:
			(st as Dictionary).erase(k)
	var old: Variant = d.get("settings", {})
	if old is Dictionary:
		var o: Dictionary = old
		o["music_volume"] = 0.6 if bool(o.get("music", true)) else 0.0
		o["sound_volume"] = 0.8 if bool(o.get("sfx", true)) else 0.0
		o.erase("music")
		o.erase("sfx")


func _read(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var text: String = FileAccess.get_file_as_string(p)
	if text.is_empty():
		return null
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	return json.data


## Fills in any keys a saved document lacks (older versions, partial files)
## and drops values of the wrong type.
static func _merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for k: Variant in over:
		if not out.has(k):
			out[k] = over[k]
		elif out[k] is Dictionary and over[k] is Dictionary:
			out[k] = _merge(out[k], over[k])
		elif typeof(out[k]) == typeof(over[k]) or (out[k] is float and over[k] is int) or (out[k] is int and over[k] is float):
			out[k] = over[k]
	return out


## Saves soon (once per frame at most).
func mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		flush.call_deferred()


func flush() -> void:
	_dirty = false
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return
	if FileAccess.file_exists(path):
		dir.copy(path, path + ".bak")
	dir.rename(tmp, path)
	saved.emit()


## Erases progress (levels, stars, streaks, achievements, earned coins) but keeps
## settings and everything paid for: packs, trials, keys and bought coins.
func reset() -> void:
	var keep: Dictionary = {}
	for k: String in ["settings", "owned", "trials", "tips", "keys", "diamonds", "chapters_opened", "coins_bought"]:
		keep[k] = data.get(k)
	data = defaults()
	for k: String in keep:
		if keep[k] != null:
			data[k] = keep[k]
	data["coins"] = Economy.START_COINS + int(data["coins_bought"])
	flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			flush()
