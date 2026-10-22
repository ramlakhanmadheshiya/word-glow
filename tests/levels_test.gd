extends SceneTree
## Validates every shipped level and the word database:
## - theme words are real-looking, unique, A-Z, 3+ letters;
## - each level is structurally valid (full coverage, adjacency, words from its theme,
##   no duplicate answers, each answer traceable in only one place, solvable with shadows);
## - each level uses its chapter's idea and no idea from a later chapter (listed
##   words, straight words, two themes, a mystery theme, shadows, beacons);
## - every level can be played to completion through the real game logic;
## - difficulty follows the chapter curve: easy (1-5), easy-medium (6-10),
##   medium (11-20), medium-hard (21-30), hard (31-39), extreme (40).
##
##   godot --headless --path . -s res://tests/levels_test.gd


## The letters of the 2026-10-15 daily, as built by this version of the generator.
const PINNED_DAILY: String = "ORELECNYSPIPICGANUOHLRAMNAIHCPDRCNIK"


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
	t.eq(chapters.size(), 8, "8 chapters")
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
			_check_idea(t, p, ch)
			prev_area = p.cell_count()
			prev_theme = p.theme_id
			scores.append(PuzzleGenerator.difficulty(p))
		# Every level is a little harder than the one before it, and each tier
		# is harder on average than the tier before.
		for k: int in range(1, scores.size()):
			t.ok(scores[k] > scores[k - 1], "%s: level %d is harder than level %d (%.2f > %.2f)" % [ch["id"], k + 1, k, scores[k], scores[k - 1]])
		var prev_mean: float = -1.0
		for tier: Dictionary in tiers:
			var sum: float = 0.0
			var n: int = 0
			for lv: int in range(int(tier["from"]), int(tier["to"]) + 1):
				sum += scores[lv - 1]
				n += 1
			t.ok(sum / n > prev_mean, "%s: %s levels are harder than the tier before" % [ch["id"], tier["name"]])
			prev_mean = sum / n
	_check_daily(t, themes, plan, vocab, names)
	quit(t.report())


## Every level shows its chapter's idea, and only the ideas that chapter allows.
func _check_idea(t: Check, p: Puzzle, ch: Dictionary) -> void:
	t.eq(p.listed, bool(ch.get("listed", false)), "%s: words listed only in listed chapters" % p.id)
	t.eq(p.mystery, bool(ch.get("mystery", false)), "%s: mystery theme only in mystery chapters" % p.id)
	t.eq(p.theme_ids.size(), int(ch.get("themes", 1)), "%s: number of themes" % p.id)
	t.eq(not p.shadows.is_empty(), float(ch.get("shadows", 0.0)) > 0.0, "%s: shadows exactly in shadow chapters" % p.id)
	t.eq(not p.beacons.is_empty(), int(ch.get("beacons", 0)) > 0, "%s: beacons exactly in beacon chapters" % p.id)
	if bool(ch.get("straight", false)):
		for w: Dictionary in p.words:
			var cells: PackedInt32Array = w["cells"]
			var step: int = cells[1] - cells[0]
			var ok: bool = step == 1 or step == p.cols
			for k: int in range(2, cells.size()):
				ok = ok and cells[k] - cells[k - 1] == step
			t.ok(ok, "%s: %s runs straight, left to right or top to bottom" % [p.id, w["word"]])


## Daily puzzles are built on the phone from the date. Check a full year: every
## day valid and solvable, a new theme each day, the same puzzle every time for
## the same date, Sunday harder than Monday, and a pinned puzzle so an accidental
## change to the generator (which would change everyone's daily) is caught.
func _check_daily(t: Check, themes: Dictionary, plan: Dictionary, vocab: Dictionary, names: Dictionary) -> void:
	var gen: PuzzleGenerator = PuzzleGenerator.new(themes, plan)
	var prev_theme: String = ""
	var ids: Dictionary = {}
	var by_weekday: Array[float] = [0, 0, 0, 0, 0, 0, 0]
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 1, "hour": 12})
	for d: int in 365:
		var key: String = Time.get_date_string_from_unix_time(t0 + d * 86400)
		var p: Puzzle = gen.daily(key)
		t.ok(p != null, "daily %s builds" % key)
		if p == null:
			continue
		p.theme_name = names.get(p.theme_id, "")
		_check_puzzle(t, p, vocab, ids)
		t.ok(p.theme_id != prev_theme, "daily %s: a different theme from the day before" % key)
		prev_theme = p.theme_id
		by_weekday[PuzzleGenerator.weekday_of(key)] += PuzzleGenerator.difficulty(p)
	t.ok(by_weekday[0] > by_weekday[1], "Sunday dailies are harder than Monday dailies")
	var a: Puzzle = gen.daily("2027-02-14")
	var b: Puzzle = PuzzleGenerator.new(themes, plan).daily("2027-02-14")
	t.eq(str(a.to_dict()), str(b.to_dict()), "the same date always gives the same daily")
	var pinned: Puzzle = gen.daily("2026-10-15")
	t.eq("".join(pinned.letters), PINNED_DAILY, "the 2026-10-15 daily is unchanged (changing the generator changes every player's daily)")


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
