extends SceneTree
## Validates every shipped level and the word database:
## - theme words are real-looking, unique, A-Z, 3+ letters;
## - each level is structurally valid (full coverage, adjacency, words from its theme,
##   no duplicate answers, each answer traceable in only one place, solvable with shadows);
## - every level can be played to completion through the real game logic;
## - difficulty never steps backwards within a world.
##
##   godot --headless --path . -s res://tests/levels_test.gd


func _init() -> void:
	var t: Check = Check.new("LEVELS")
	var themes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/themes.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/worlds.json"))
	var vocab: Dictionary = {}
	var names: Dictionary = {}
	_check_themes(t, themes, vocab, names)
	var ids: Dictionary = {}
	var prev_world_area: int = 0
	for w: Dictionary in catalog["worlds"]:
		var levels: Array = _load(t, w["id"])
		t.eq(levels.size(), 20, "%s has 20 levels" % w["id"])
		var prev_area: int = 0
		var prev_theme: String = ""
		var prev_shadows: int = 0
		var first_area: int = 0
		for i: int in levels.size():
			var p: Puzzle = Puzzle.from_dict(levels[i], names)
			_check_puzzle(t, p, vocab, ids)
			t.eq(p.id, "%s-%02d" % [w["id"], i + 1], "level id order")
			var area: int = p.cell_count()
			t.ok(area >= prev_area, "%s: grid never shrinks within a world" % p.id)
			t.ok(p.shadows.size() >= prev_shadows - 1, "%s: shadows do not drop sharply" % p.id)
			t.ok(p.theme_id != prev_theme, "%s: theme differs from the previous level" % p.id)
			if i == 0:
				first_area = area
			prev_area = area
			prev_theme = p.theme_id
			prev_shadows = p.shadows.size()
		t.ok(first_area >= prev_world_area, "%s starts at least as big as the previous world began" % w["id"])
		prev_world_area = first_area
	var daily: Array = _load(t, "daily")
	t.eq(daily.size(), int(catalog["daily"]["count"]), "daily pool size")
	for d: Variant in daily:
		_check_puzzle(t, Puzzle.from_dict(d, names), vocab, ids)
	quit(t.report())


func _load(t: Check, id: String) -> Array:
	var path: String = "res://data/levels/%s.json" % id
	t.ok(FileAccess.file_exists(path), "missing %s" % path)
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.ok(v is Dictionary, "%s parses" % path)
	return v.get("levels", []) if v is Dictionary else []


func _check_themes(t: Check, themes: Dictionary, vocab: Dictionary, names: Dictionary) -> void:
	var re: RegEx = RegEx.create_from_string("^[A-Z]{3,12}$")
	t.ok(themes.size() >= 40, "at least 40 themes")
	for k: Variant in themes:
		var words: Array = themes[k]["words"]
		names[k] = themes[k]["name"]
		vocab[k] = words
		t.ok(words.size() >= 18, "theme %s has at least 18 words" % k)
		var seen: Dictionary = {}
		for w: Variant in words:
			t.ok(re.search(str(w)) != null, "theme %s: '%s' must be 3-12 letters A-Z" % [k, w])
			t.ok(not seen.has(w), "theme %s lists %s twice" % [k, w])
			seen[w] = true


func _check_puzzle(t: Check, p: Puzzle, vocab: Dictionary, ids: Dictionary) -> void:
	t.ok(not ids.has(p.id), "duplicate level id %s" % p.id)
	ids[p.id] = true
	for e: String in LanternRules.problems(p, vocab):
		t.ok(false, "%s: %s" % [p.id, e])
	t.ok(p.cols <= 7 and p.rows <= 8, "%s fits a phone screen" % p.id)
	t.ok(p.words.size() >= 2, "%s has at least two words" % p.id)
	_play_through(t, p)


## Plays the level with the real LevelState: wrong guesses are refused, a reversed
## trace is refused, and finding the words in solve order completes the level.
func _play_through(t: Check, p: Puzzle) -> void:
	var s: LevelState = LevelState.new(p)
	var order: PackedInt32Array = LanternRules.solve_order(p)
	t.ok(order.size() == p.words.size(), "%s solvable" % p.id)
	for i: int in order:
		var cells: PackedInt32Array = p.words[i]["cells"]
		var rev: PackedInt32Array = cells.duplicate()
		rev.reverse()
		var word: String = p.words[i]["word"]
		if word != word.reverse():
			t.ok(s.submit(rev)["result"] != LevelState.Result.FOUND, "%s: reversed %s refused" % [p.id, word])
		var r: Dictionary = s.submit(cells)
		t.eq(r["result"], LevelState.Result.FOUND, "%s: %s accepted" % [p.id, word])
		t.eq(s.submit(cells)["result"], LevelState.Result.INVALID_PATH, "%s: %s cannot be found twice" % [p.id, word])
	t.ok(s.is_complete(), "%s completes" % p.id)
	for c: int in p.cell_count():
		t.ok(s.visible[c] == 1, "%s: cell %d lit at the end" % [p.id, c])
