extends SceneTree
## Validates every shipped level and the word database:
## - theme words are real-looking, unique, A-Z, 3+ letters;
## - each level is structurally valid (full coverage, adjacency, words from its theme,
##   no duplicate answers, each answer traceable in only one place, solvable with shadows);
## - every level can be played to completion through the real game logic;
## - difficulty follows the chapter curve: easy (1-5), easy-medium (6-10),
##   medium (11-20), medium-hard (21-30), hard (31-39), extreme (40).
##
##   godot --headless --path . -s res://tests/levels_test.gd


func _init() -> void:
	var t: Check = Check.new("LEVELS")
	var themes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/themes.json"))
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var vocab: Dictionary = {}
	var names: Dictionary = {}
	_check_themes(t, themes, vocab, names)
	var ids: Dictionary = {}
	var per: int = int(plan["levels_per_chapter"])
	var chapters: Array = plan["chapters"]
	t.eq(chapters.size(), 16, "16 chapters")
	t.eq(per, 40, "40 levels per chapter")
	var tiers: Array = plan["difficulty"]["tiers"]
	for ci: int in chapters.size():
		var ch: Dictionary = chapters[ci]
		var levels: Array = _load(t, ch["id"])
		t.eq(levels.size(), per, "%s has %d levels" % [ch["id"], per])
		var prev_area: int = 0
		var prev_theme: String = ""
		var scores: Array[float] = []
		for i: int in levels.size():
			var p: Puzzle = Puzzle.from_dict(levels[i], names)
			_check_puzzle(t, p, vocab, ids)
			t.eq(p.id, "%s-%02d" % [ch["id"], i + 1], "level id order")
			t.ok(p.cell_count() >= prev_area, "%s: grid never shrinks within a chapter" % p.id)
			t.ok(p.theme_id != prev_theme, "%s: theme differs from the previous level" % p.id)
			if ci + 1 < int(plan["difficulty"]["shadows_from_chapter"]):
				t.ok(p.shadows.is_empty(), "%s: no shadows before chapter %d" % [p.id, plan["difficulty"]["shadows_from_chapter"]])
			if ci + 1 < int(plan["difficulty"]["beacons_from_chapter"]):
				t.ok(p.beacons.is_empty(), "%s: no beacons before chapter %d" % [p.id, plan["difficulty"]["beacons_from_chapter"]])
			prev_area = p.cell_count()
			prev_theme = p.theme_id
			scores.append(difficulty(p))
		# The curve: every tier is harder on average than the one before, and
		# level 40 is the hardest level in its chapter.
		var prev_mean: float = -1.0
		for tier: Dictionary in tiers:
			var sum: float = 0.0
			var n: int = 0
			for lv: int in range(int(tier["from"]), int(tier["to"]) + 1):
				sum += scores[lv - 1]
				n += 1
			var mean: float = sum / n
			t.ok(mean > prev_mean, "%s: %s levels are harder than the tier before (%.1f > %.1f)" % [ch["id"], tier["name"], mean, prev_mean])
			prev_mean = mean
		var top: float = scores[per - 1]
		for k: int in per - 1:
			t.ok(scores[k] < top, "%s: level 40 is harder than level %d" % [ch["id"], k + 1])
	var daily: Array = _load(t, "daily")
	t.eq(daily.size(), int(plan["daily"]["count"]), "daily pool size")
	for d: Variant in daily:
		_check_puzzle(t, Puzzle.from_dict(d, names), vocab, ids)
	quit(t.report())


## A rough difficulty score: bigger grids, longer words, more shadows and more
## waves of light are all harder.
static func difficulty(p: Puzzle) -> float:
	var letters: int = 0
	for w: Dictionary in p.words:
		letters += str(w["word"]).length()
	var avg: float = float(letters) / float(maxi(1, p.words.size()))
	return p.cell_count() + 3.0 * avg + 1.5 * p.shadows.size() + 2.0 * maxi(0, LanternRules.light_depth(p) - 1)


func _load(t: Check, id: String) -> Array:
	var path: String = "res://data/levels/%s.json" % id
	t.ok(FileAccess.file_exists(path), "missing %s" % path)
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.ok(v is Dictionary, "%s parses" % path)
	return v.get("levels", []) if v is Dictionary else []


func _check_themes(t: Check, themes: Dictionary, vocab: Dictionary, names: Dictionary) -> void:
	var re: RegEx = RegEx.create_from_string("^[A-Z]{3,12}$")
	t.ok(themes.size() >= 60, "at least 60 themes")
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
