extends Node
## Persistent player data as one JSON document in user://.
## Writes go to a temp file first and the previous save is kept as a backup,
## so a crash mid-write or a corrupt file never loses progress.

signal saved

const VERSION: int = 1
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
		"cleared": {},
		"progress": {},
		"daily": {"done": {}, "streak": 0, "best_streak": 0, "last_date": ""},
		"achievements": {},
		"stats": {"levels": 0, "words": 0, "flawless": 0, "dailies": 0, "best_streak": 0, "beacons": 0, "worlds": 1, "hints": 0},
		"settings": {"music": true, "sfx": true, "haptics": true},
		"seen": {},
		"free_spark_date": "",
		"last_level": "",
	}


func load_data() -> void:
	recovered_from = ""
	var loaded: Variant = _read(path)
	if loaded == null and FileAccess.file_exists(path):
		loaded = _read(path + ".bak")
		recovered_from = "backup" if loaded != null else "fresh"
	data = _merge(defaults(), loaded if loaded is Dictionary else {})
	data["version"] = VERSION


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


func reset() -> void:
	var keep: Dictionary = (data.get("settings", {}) as Dictionary).duplicate()
	data = defaults()
	data["settings"] = _merge(data["settings"], keep)
	flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			flush()
