extends SceneTree
## Unit tests for the rules and the live level state, including deliberately
## broken puzzles that the validator must reject.
##
##   godot --headless --path . -s res://tests/logic_test.gd

var t: Check = Check.new("LOGIC")
var vocab: Dictionary = {"test": ["CAT", "DOG", "SUN", "TOP", "POT", "ANT", "BEE", "OWL"]}


func _init() -> void:
	_validator_rejects_broken_puzzles()
	_submit_rules()
	_shadows_and_beacons()
	_hints()
	_save_and_restore()
	_stars()
	quit(t.report())


## Stars: 3 for a perfect solve, 2 for up to TWO_STAR_EXTRA extra moves, else 1.
func _stars() -> void:
	t.eq(Economy.stars_for(0), 3, "perfect is 3 stars")
	t.eq(Economy.stars_for(1), 2, "one extra move is 2 stars")
	t.eq(Economy.stars_for(Economy.TWO_STAR_EXTRA), 2, "the last 2-star extra move")
	t.eq(Economy.stars_for(Economy.TWO_STAR_EXTRA + 1), 1, "then 1 star")
	var s: LevelState = LevelState.new(_simple())
	t.eq(s.stars(), 3, "a fresh level offers 3 stars")
	t.eq(s.par(), 2, "par is one move per word")
	s.submit(PackedInt32Array([0, 1, 4]))
	t.eq(s.mistakes, 1, "a wrong word counts as a mistake")
	t.eq(s.stars(), 2, "a wrong word costs a star")
	s.submit(PackedInt32Array([0, 1]))
	t.eq(s.mistakes, 1, "a too-short trace is not a move")
	s.submit(PackedInt32Array([0, 1, 2]))
	s.apply_spark()
	t.eq(s.extra_moves(), 2, "hints are extra moves")
	t.eq(s.moves(), 3, "moves = words found + extra")
	var p: LevelState = LevelState.new(_simple())
	p.submit(PackedInt32Array([0, 1, 2]))
	p.submit(PackedInt32Array([5, 4, 3]))
	t.ok(p.is_complete() and p.stars() == 3 and p.moves() == p.par(), "a perfect solve: 3 stars in par moves")


## 2x3 grid:  C A T
##            G O D   -> words CAT (0,1,2) and DOG (5,4,3)
func _simple() -> Puzzle:
	return Puzzle.from_dict({"id": "t-1", "theme": "test", "grid": ["CAT", "GOD"], "words": [{"w": "CAT", "p": [0, 1, 2]}, {"w": "DOG", "p": [5, 4, 3]}]})


func _validator_rejects_broken_puzzles() -> void:
	t.eq(LanternRules.problems(_simple(), vocab).size(), 0, "a valid puzzle has no problems")
	var gap: Puzzle = _simple()
	gap.words.pop_back()
	t.ok(LanternRules.problems(gap, vocab).size() > 0, "uncovered cells are reported")
	var jump: Puzzle = Puzzle.from_dict({"id": "t", "theme": "test", "grid": ["CAT", "GOD"], "words": [{"w": "CAT", "p": [0, 1, 2]}, {"w": "DOG", "p": [5, 3, 4]}]})
	t.ok(str(LanternRules.problems(jump, vocab)).contains("jumps") or str(LanternRules.problems(jump, vocab)).contains("does not match"), "non-adjacent paths are reported")
	var unknown: Puzzle = Puzzle.from_dict({"id": "t", "theme": "test", "grid": ["CAX", "GOD"], "words": [{"w": "CAX", "p": [0, 1, 2]}, {"w": "DOG", "p": [5, 4, 3]}]})
	t.ok(str(LanternRules.problems(unknown, vocab)).contains("not in theme"), "words outside the theme are reported")
	var dup: Puzzle = Puzzle.from_dict({"id": "t", "theme": "test", "grid": ["CAT", "TAC"], "words": [{"w": "CAT", "p": [0, 1, 2]}, {"w": "CAT", "p": [5, 4, 3]}]})
	t.ok(str(LanternRules.problems(dup, vocab)).contains("duplicate"), "duplicate answers are reported")
	# TOP / POT: "TOP" can also be traced backwards along POT's tiles.
	var ambiguous: Puzzle = Puzzle.from_dict({"id": "t", "theme": "test", "grid": ["TOP", "TOP"], "words": [{"w": "TOP", "p": [0, 1, 2]}, {"w": "POT", "p": [5, 4, 3]}]})
	t.ok(str(LanternRules.problems(ambiguous, vocab)).contains("more than one place"), "ambiguous placements are reported")
	var stuck: Puzzle = _simple()
	stuck.shadows = PackedInt32Array([0, 5])
	t.ok(str(LanternRules.problems(stuck, vocab)).contains("unsolvable"), "puzzles whose shadows never light are reported")
	var bad_beacon: Puzzle = _simple()
	bad_beacon.shadows = PackedInt32Array([1])
	bad_beacon.beacons = PackedInt32Array([1])
	t.ok(str(LanternRules.problems(bad_beacon, vocab)).contains("beacon"), "beacons starting in shadow are reported")


func _submit_rules() -> void:
	var s: LevelState = LevelState.new(_simple())
	t.eq(s.submit(PackedInt32Array([0, 1]))["result"], LevelState.Result.TOO_SHORT, "two letters are too short")
	t.eq(s.submit(PackedInt32Array([0, 1, 4]))["result"], LevelState.Result.NOT_A_WORD, "CAO is not an answer")
	t.eq(s.submit(PackedInt32Array([2, 1, 0]))["result"], LevelState.Result.NOT_A_WORD, "TAC (CAT reversed) is not an answer")
	t.eq(s.submit(PackedInt32Array([0, 2, 1]))["result"], LevelState.Result.INVALID_PATH, "non-adjacent steps are refused")
	t.eq(s.submit(PackedInt32Array([0, 1, 0]))["result"], LevelState.Result.INVALID_PATH, "revisiting a tile is refused")
	var r: Dictionary = s.submit(PackedInt32Array([0, 1, 2]))
	t.eq(r["result"], LevelState.Result.FOUND, "CAT is found")
	t.eq(r["word_index"], 0, "CAT is word 0")
	t.ok(not s.can_select(0), "a lit tile cannot be traced again")
	t.eq(s.submit(PackedInt32Array([0, 1, 2]))["result"], LevelState.Result.INVALID_PATH, "re-tracing a found word is refused")
	t.ok(not s.is_complete(), "not complete after one word")
	s.submit(PackedInt32Array([5, 4, 3]))
	t.ok(s.is_complete(), "complete after both words")
	t.eq(s.found_count(), 2, "two words found")


## 4x3 grid, OWL / BEE / SUN / CAT in rows; only OWL starts visible and its
## beacon (the L) shines down column 2.
func _shadows_and_beacons() -> void:
	var p: Puzzle = Puzzle.from_dict({"id": "t-2", "theme": "test", "grid": ["OWL", "BEE", "SUN", "CAT"],
		"words": [{"w": "OWL", "p": [0, 1, 2]}, {"w": "BEE", "p": [3, 4, 5]}, {"w": "SUN", "p": [6, 7, 8]}, {"w": "CAT", "p": [9, 10, 11]}],
		"shadows": [3, 4, 6, 7, 8, 9, 10, 11], "beacons": [2]})
	t.eq(LanternRules.problems(p, vocab).size(), 0, "shadow test puzzle is valid")
	var s: LevelState = LevelState.new(p)
	t.ok(not s.can_select(4), "a shadow tile cannot be traced")
	t.eq(s.submit(PackedInt32Array([3, 4, 5]))["result"], LevelState.Result.INVALID_PATH, "a word through shadows is refused")
	t.eq(Array(s.playable_words()), [0], "only OWL is playable at first")
	var r: Dictionary = s.submit(PackedInt32Array([0, 1, 2]))
	var rev: Array = Array(r["revealed"])
	t.ok(rev.has(3) and rev.has(4), "OWL lights the tiles below it")
	t.ok(rev.has(8) and rev.has(11), "the beacon lights its whole column")
	t.ok(not rev.has(6) and not rev.has(9), "light does not jump elsewhere")
	t.eq(Array(r["beacons"]), [2], "OWL contains the beacon")
	t.eq(s.submit(PackedInt32Array([3, 4, 5]))["result"], LevelState.Result.FOUND, "BEE can be found once lit")
	t.eq(LanternRules.light_depth(p), 4, "four waves of light")
	p.beacons = PackedInt32Array()
	t.eq(LanternRules.light_depth(p), 4, "without the beacon it still solves here, row by row")


func _hints() -> void:
	var s: LevelState = LevelState.new(_simple())
	var target: int = s.hint_target()
	t.ok(target >= 0, "there is a hint target")
	var r: Dictionary = s.apply_spark()
	t.eq(r["spark_count"], 1, "first spark reveals one letter")
	t.eq(s.hint_target(), target, "sparks keep helping the same word")
	s.apply_spark()
	r = s.apply_spark()
	t.eq(r.get("result", -1), LevelState.Result.FOUND, "the last spark finds the word")
	t.eq(s.hints_used, 3, "three hints counted")
	r = s.apply_lantern()
	t.eq(r["result"], LevelState.Result.FOUND, "a lantern finds a word")
	t.ok(s.is_complete(), "hints can finish a level")
	t.ok(s.apply_spark().is_empty(), "no hint when everything is found")


func _save_and_restore() -> void:
	var p: Puzzle = _simple()
	var s: LevelState = LevelState.new(p)
	s.submit(PackedInt32Array([0, 1, 2]))
	s.apply_spark()
	s.submit(PackedInt32Array([3, 4, 5]))
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2: LevelState = LevelState.new(p)
	s2.restore(d)
	t.eq(s2.found_count(), 1, "restored found words")
	t.ok(s2.is_lit(0), "restored lit tiles")
	t.eq(s2.sparks.size(), 1, "restored sparks")
	t.eq(s2.hints_used, 1, "restored hint count")
	t.eq(s2.mistakes, 1, "restored mistakes")
	var s3: LevelState = LevelState.new(p)
	s3.restore({"found": [7, -1, "x"], "sparks": {"9": 3}, "hints": -5})
	t.eq(s3.found_count(), 0, "garbage progress is ignored")
	t.eq(s3.hints_used, 0, "negative hints are clamped")
