class_name LevelState
extends RefCounted
## Live state of one level being played: which words are found, which tiles are
## lit or still in shadow, and which letters hints have revealed. No UI, no coins.

enum Result { FOUND, NOT_A_WORD, ALREADY_FOUND, TOO_SHORT, INVALID_PATH }

const MIN_WORD: int = 3

var puzzle: Puzzle
var found: PackedByteArray = PackedByteArray()
var visible: PackedByteArray = PackedByteArray()
## word index -> how many of its letters a Spark hint has revealed (from the start).
var sparks: Dictionary = {}
var hints_used: int = 0
var mistakes: int = 0
## Order words were found in (used to colour them consistently after a reload).
var found_order: PackedInt32Array = PackedInt32Array()

var _owners: PackedInt32Array


func _init(p: Puzzle) -> void:
	puzzle = p
	found.resize(p.words.size())
	visible = LanternRules.initial_visible(p)
	_owners = p.owner_map()


func owner_of(cell: int) -> int:
	return _owners[cell]


func is_lit(cell: int) -> bool:
	return found[_owners[cell]] != 0


## A tile can be traced when it is visible and not already part of a found word.
func can_select(cell: int) -> bool:
	return cell >= 0 and cell < puzzle.cell_count() and visible[cell] != 0 and not is_lit(cell)


func found_count() -> int:
	return found_order.size()


func is_complete() -> bool:
	return found_order.size() == puzzle.words.size()


## Checks a traced path. On success the word is marked found and the result
## lists the cells that newly came out of shadow.
func submit(cells: PackedInt32Array) -> Dictionary:
	if cells.size() < MIN_WORD:
		return {"result": Result.TOO_SHORT}
	for i: int in cells.size():
		if not can_select(cells[i]) or cells.find(cells[i]) != i:
			return {"result": Result.INVALID_PATH}
		if i > 0 and not puzzle.is_adjacent(cells[i - 1], cells[i]):
			return {"result": Result.INVALID_PATH}
	var text: String = puzzle.word_text(cells)
	for i: int in puzzle.words.size():
		var w: Dictionary = puzzle.words[i]
		if w["word"] != text:
			continue
		if found[i] != 0:
			return {"result": Result.ALREADY_FOUND, "word": text}
		if LanternRules.same_cells(cells, w["cells"]):
			return _mark_found(i)
	return {"result": Result.NOT_A_WORD, "word": text}


func _mark_found(i: int) -> Dictionary:
	var revealed: PackedInt32Array = LanternRules.reveals_for(puzzle, i, visible)
	var beams: PackedInt32Array = PackedInt32Array()
	for c: int in puzzle.words[i]["cells"]:
		if puzzle.beacons.has(c):
			beams.append(c)
	found[i] = 1
	found_order.append(i)
	for c: int in revealed:
		visible[c] = 1
	sparks.erase(i)
	return {"result": Result.FOUND, "word_index": i, "word": puzzle.words[i]["word"], "revealed": revealed, "beacons": beams}


func record_mistake() -> void:
	mistakes += 1


## Unfound words that can be traced right now (all tiles visible).
func playable_words() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in puzzle.words.size():
		if found[i] == 0 and LanternRules.all_visible(puzzle.words[i]["cells"], visible):
			out.append(i)
	return out


## The word a hint should help with: continue a partly sparked word first, then
## the shortest playable word (ties broken by grid position, so it is stable).
func hint_target() -> int:
	var playable: PackedInt32Array = playable_words()
	if playable.is_empty():
		return -1
	for i: int in playable:
		if sparks.has(i):
			return i
	var best: int = playable[0]
	for i: int in playable:
		var wl: int = str(puzzle.words[i]["word"]).length()
		var bl: int = str(puzzle.words[best]["word"]).length()
		if wl < bl or (wl == bl and puzzle.words[i]["cells"][0] < puzzle.words[best]["cells"][0]):
			best = i
	return best


## Spark: reveals the next letter of the hint target. When that was the word's
## last hidden letter the word is found for the player. Returns {} if no target.
func apply_spark() -> Dictionary:
	var i: int = hint_target()
	if i < 0:
		return {}
	hints_used += 1
	var n: int = int(sparks.get(i, 0)) + 1
	var cells: PackedInt32Array = puzzle.words[i]["cells"]
	if n >= cells.size():
		var res: Dictionary = _mark_found(i)
		res["spark_cell"] = cells[cells.size() - 1]
		return res
	sparks[i] = n
	return {"word_index": i, "spark_cell": cells[n - 1], "spark_count": n}


## Lantern: finds a whole playable word for the player.
func apply_lantern() -> Dictionary:
	var i: int = hint_target()
	if i < 0:
		return {}
	hints_used += 1
	return _mark_found(i)


## Cells whose letter a Spark has revealed, mapped to their position in the word (0-based).
func sparked_cells() -> Dictionary:
	var out: Dictionary = {}
	for i: Variant in sparks:
		var cells: PackedInt32Array = puzzle.words[int(i)]["cells"]
		for k: int in mini(int(sparks[i]), cells.size()):
			out[cells[k]] = k
	return out


## Progress that survives an app restart.
func to_dict() -> Dictionary:
	var sp: Dictionary = {}
	for k: Variant in sparks:
		sp[str(k)] = int(sparks[k])
	return {"found": Array(found_order), "sparks": sp, "hints": hints_used, "mistakes": mistakes}


## Replays saved progress. Unknown or inconsistent entries are ignored, so a
## stale save can never put the level into an impossible state.
func restore(d: Dictionary) -> void:
	var found_list: Variant = d.get("found", [])
	for v: Variant in (found_list if found_list is Array else []):
		if not (v is int or v is float):
			continue
		var i: int = int(v)
		if i >= 0 and i < puzzle.words.size() and found[i] == 0 and LanternRules.all_visible(puzzle.words[i]["cells"], visible):
			_mark_found(i)
	var sp: Variant = d.get("sparks", {})
	if sp is Dictionary:
		for k: Variant in sp:
			if not str(k).is_valid_int():
				continue
			var i: int = int(str(k))
			if i >= 0 and i < puzzle.words.size() and found[i] == 0:
				sparks[i] = clampi(int(sp[k]), 1, str(puzzle.words[i]["word"]).length() - 1)
	hints_used = maxi(0, int(d.get("hints", 0)))
	mistakes = maxi(0, int(d.get("mistakes", 0)))
