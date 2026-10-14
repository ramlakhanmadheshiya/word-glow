extends Node
## Read-only game content: chapters, difficulty tiers, theme names and the level
## files in data/. Missing or broken files are reported through `last_error`.

const DAILY_EPOCH: Dictionary = {"year": 2026, "month": 1, "day": 1}

var chapters: Array[Dictionary] = []
var tiers: Array = []
var levels_per_chapter: int = 40
var unlock_clears: int = 15
var theme_names: Dictionary = {}
var last_error: String = ""

var _level_cache: Dictionary = {}


func _ready() -> void:
	_load_meta()


## Drops cached content and reads it again (used by the error card's Retry).
func reload() -> void:
	chapters.clear()
	theme_names.clear()
	_level_cache.clear()
	last_error = ""
	_load_meta()


func _load_meta() -> void:
	var catalog: Variant = _json("res://data/chapters.json")
	if catalog is Dictionary:
		levels_per_chapter = int(catalog.get("levels_per_chapter", 40))
		unlock_clears = int(catalog.get("unlock_clears", 15))
		tiers = catalog.get("difficulty", {}).get("tiers", [])
		for c: Variant in catalog.get("chapters", []):
			var d: Dictionary = c
			d["sky_top"] = Color(str(d.get("sky_top", "#2E2A6B")))
			d["sky_bottom"] = Color(str(d.get("sky_bottom", "#141235")))
			d["accent"] = Color(str(d.get("accent", "#FFB547")))
			chapters.append(d)
	var themes: Variant = _json("res://data/themes.json")
	if themes is Dictionary:
		for k: Variant in themes:
			theme_names[k] = str(themes[k].get("name", str(k).capitalize()))


func _json(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		last_error = "Missing game data: %s" % p.get_file()
		return null
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if v == null:
		last_error = "Damaged game data: %s" % p.get_file()
	return v


func chapter_count() -> int:
	return chapters.size()


func chapter(index: int) -> Dictionary:
	return chapters[index] if index >= 0 and index < chapters.size() else {}


func chapter_index(id: String) -> int:
	for i: int in chapters.size():
		if chapters[i]["id"] == id:
			return i
	return -1


func total_levels() -> int:
	return chapters.size() * levels_per_chapter


## "Easy", "Medium"... for level n of any chapter.
func tier_name(n: int) -> String:
	for t: Variant in tiers:
		if n >= int(t["from"]) and n <= int(t["to"]):
			return str(t["name"])
	return ""


static func level_id(chapter_id: String, n: int) -> String:
	return "%s-%02d" % [chapter_id, n]


## Splits "harbor-07" into [chapter index, 7]; [-1, 0] if unknown.
func parse_level_id(id: String) -> Array[int]:
	var dash: int = id.rfind("-")
	if dash <= 0:
		return [-1, 0]
	return [chapter_index(id.substr(0, dash)), int(id.substr(dash + 1))]


func _levels(file_id: String) -> Array:
	if not _level_cache.has(file_id):
		var v: Variant = _json("res://data/levels/%s.json" % file_id)
		_level_cache[file_id] = v.get("levels", []) if v is Dictionary else []
	return _level_cache[file_id]


## The puzzle for level n (1-based) of a chapter, or null if it cannot be loaded.
func puzzle(chapter_idx: int, n: int) -> Puzzle:
	var c: Dictionary = chapter(chapter_idx)
	if c.is_empty():
		last_error = "Unknown chapter"
		return null
	var levels: Array = _levels(c["id"])
	if n < 1 or n > levels.size():
		if last_error.is_empty():
			last_error = "Level %d of %s is missing" % [n, c["name"]]
		return null
	return Puzzle.from_dict(levels[n - 1], theme_names)


func puzzle_by_id(id: String) -> Puzzle:
	if id.begins_with("daily-"):
		return daily_puzzle(id.substr(6))
	var cn: Array[int] = parse_level_id(id)
	return puzzle(cn[0], cn[1])


## Days since the daily epoch for a "YYYY-MM-DD" key.
static func day_number(date_key: String) -> int:
	var parts: PackedStringArray = date_key.split("-")
	if parts.size() != 3:
		return 0
	var t: int = Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12})
	var t0: int = Time.get_unix_time_from_datetime_dict(DAILY_EPOCH.merged({"hour": 12}))
	return int(round(float(t - t0) / 86400.0))


static func date_key_from_day(day: int) -> String:
	var t0: int = Time.get_unix_time_from_datetime_dict(DAILY_EPOCH.merged({"hour": 12}))
	return Time.get_date_string_from_unix_time(t0 + day * 86400)


static func today_key() -> String:
	return Time.get_date_string_from_system()


## The daily puzzle for a date: the pool repeats once every pool-size days.
func daily_puzzle(date_key: String) -> Puzzle:
	var levels: Array = _levels("daily")
	if levels.is_empty():
		return null
	var idx: int = posmod(day_number(date_key), levels.size())
	var p: Puzzle = Puzzle.from_dict(levels[idx], theme_names)
	p.id = "daily-" + date_key
	return p
