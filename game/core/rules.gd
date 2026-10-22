class_name LanternRules
extends RefCounted
## The rules shared by gameplay, the level generator and the tests:
## how light spreads, where a word can be traced, and whether a puzzle is solvable.


## Cells visible when a level opens (everything but shadows).
static func initial_visible(p: Puzzle) -> PackedByteArray:
	var vis: PackedByteArray = PackedByteArray()
	vis.resize(p.cell_count())
	vis.fill(1)
	for c: int in p.shadows:
		vis[c] = 0
	return vis


## Cells a found word lights up: shadows next to any of its tiles, plus the
## whole row and column of each beacon tile in it. Only currently dark cells are returned.
static func reveals_for(p: Puzzle, word_idx: int, vis: PackedByteArray) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var cells: PackedInt32Array = p.words[word_idx]["cells"]
	for c: int in cells:
		for n: int in p.neighbors(c):
			if vis[n] == 0 and not out.has(n):
				out.append(n)
	for c: int in cells:
		if p.beacons.has(c):
			for n: int in beam_cells(p, c):
				if vis[n] == 0 and not out.has(n):
					out.append(n)
	return out


## Every cell in the beacon's row and column (excluding itself), nearest first.
static func beam_cells(p: Puzzle, beacon: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var r: int = p.row_of(beacon)
	var c: int = p.col_of(beacon)
	for d: int in range(1, maxi(p.rows, p.cols)):
		for cell: Vector2i in [Vector2i(r, c - d), Vector2i(r, c + d), Vector2i(r - d, c), Vector2i(r + d, c)]:
			if cell.x >= 0 and cell.x < p.rows and cell.y >= 0 and cell.y < p.cols:
				out.append(cell.x * p.cols + cell.y)
	return out


static func all_visible(cells: PackedInt32Array, vis: PackedByteArray) -> bool:
	for c: int in cells:
		if vis[c] == 0:
			return false
	return true


## Finds every word in turn (any word whose tiles are all visible). Light only ever
## grows, so this greedy order succeeds exactly when some order does.
## Returns the order of word indices, or an empty array when the puzzle is stuck.
static func solve_order(p: Puzzle) -> PackedInt32Array:
	var vis: PackedByteArray = initial_visible(p)
	var found: PackedByteArray = PackedByteArray()
	found.resize(p.words.size())
	var order: PackedInt32Array = PackedInt32Array()
	var progress: bool = true
	while progress and order.size() < p.words.size():
		progress = false
		for i: int in p.words.size():
			if found[i] == 0 and all_visible(p.words[i]["cells"], vis):
				found[i] = 1
				order.append(i)
				for n: int in reveals_for(p, i, vis):
					vis[n] = 1
				progress = true
	if order.size() < p.words.size():
		return PackedInt32Array()
	return order


## Number of "waves" needed: how many rounds of finding-all-visible-words it takes.
## 1 means nothing is hidden behind anything else.
static func light_depth(p: Puzzle) -> int:
	var vis: PackedByteArray = initial_visible(p)
	var found: PackedByteArray = PackedByteArray()
	found.resize(p.words.size())
	var left: int = p.words.size()
	var depth: int = 0
	while left > 0:
		var wave: Array[int] = []
		for i: int in p.words.size():
			if found[i] == 0 and all_visible(p.words[i]["cells"], vis):
				wave.append(i)
		if wave.is_empty():
			return -1
		depth += 1
		for i: int in wave:
			found[i] = 1
			left -= 1
			for n: int in reveals_for(p, i, vis):
				vis[n] = 1
	return depth


## Every path of orthogonally adjacent, distinct cells spelling `word`.
## `blocked` cells (if given) are skipped. Capped at `limit` paths.
static func paths_spelling(p: Puzzle, word: String, blocked: PackedByteArray = PackedByteArray(), limit: int = 64) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	if word.is_empty():
		return out
	for start: int in p.cell_count():
		if p.letters[start] != word[0] or (not blocked.is_empty() and blocked[start] != 0):
			continue
		var path: PackedInt32Array = PackedInt32Array([start])
		_extend(p, word, blocked, path, out, limit)
		if out.size() >= limit:
			break
	return out


static func _extend(p: Puzzle, word: String, blocked: PackedByteArray, path: PackedInt32Array, out: Array[PackedInt32Array], limit: int) -> void:
	if out.size() >= limit:
		return
	if path.size() == word.length():
		out.append(path.duplicate())
		return
	var want: String = word[path.size()]
	for n: int in p.neighbors(path[path.size() - 1]):
		if p.letters[n] != want or path.has(n):
			continue
		if not blocked.is_empty() and blocked[n] != 0:
			continue
		path.append(n)
		_extend(p, word, blocked, path, out, limit)
		path.remove_at(path.size() - 1)


static func same_cells(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() != b.size():
		return false
	var sa: PackedInt32Array = a.duplicate()
	var sb: PackedInt32Array = b.duplicate()
	sa.sort()
	sb.sort()
	return sa == sb


## True when every way of tracing each answer uses exactly its own tiles, so a
## correctly spelled answer can never land in the "wrong" place.
static func placements_unique(p: Puzzle) -> bool:
	for w: Dictionary in p.words:
		for path: PackedInt32Array in paths_spelling(p, w["word"]):
			if not same_cells(path, w["cells"]):
				return false
	return true


## Structural problems with a puzzle, as human-readable strings (empty = valid).
## `vocabulary` maps theme id -> Array of allowed words.
static func problems(p: Puzzle, vocabulary: Dictionary) -> PackedStringArray:
	var errs: PackedStringArray = PackedStringArray()
	if p.rows < 2 or p.cols < 2:
		errs.append("grid too small")
		return errs
	if p.letters.size() != p.cell_count():
		errs.append("ragged grid")
		return errs
	for l: String in p.letters:
		if l.length() != 1 or l < "A" or l > "Z":
			errs.append("bad letter '%s'" % l)
	var seen_words: Dictionary = {}
	var covered: PackedInt32Array = PackedInt32Array()
	covered.resize(p.cell_count())
	var ids: PackedStringArray = p.theme_ids if not p.theme_ids.is_empty() else PackedStringArray([p.theme_id])
	for t: String in ids:
		if (vocabulary.get(t, []) as Array).is_empty():
			errs.append("unknown theme '%s'" % t)
	var per_theme: Dictionary = {}
	for w: Dictionary in p.words:
		var word: String = w["word"]
		var cells: PackedInt32Array = w["cells"]
		if seen_words.has(word):
			errs.append("duplicate answer %s" % word)
		seen_words[word] = true
		var t: int = int(w.get("theme", 0))
		var tid: String = ids[t] if t >= 0 and t < ids.size() else ""
		if not (vocabulary.get(tid, []) as Array).has(word):
			errs.append("%s is not in theme %s" % [word, tid])
		per_theme[t] = int(per_theme.get(t, 0)) + 1
		if cells.size() != word.length():
			errs.append("%s has %d cells" % [word, cells.size()])
			continue
		if word.length() < 3:
			errs.append("%s is shorter than 3 letters" % word)
		for i: int in cells.size():
			var c: int = cells[i]
			if c < 0 or c >= p.cell_count():
				errs.append("%s leaves the grid" % word)
				break
			covered[c] += 1
			if p.letters[c] != word[i]:
				errs.append("%s does not match the grid at cell %d" % [word, c])
			if i > 0 and not p.is_adjacent(cells[i - 1], c):
				errs.append("%s jumps between cells %d and %d" % [word, cells[i - 1], c])
	for c: int in p.cell_count():
		if covered[c] != 1:
			errs.append("cell %d is covered %d times" % [c, covered[c]])
	for t: int in ids.size():
		if int(per_theme.get(t, 0)) < 2:
			errs.append("theme %s has fewer than two words" % ids[t])
	for c: int in p.beacons:
		if p.shadows.has(c):
			errs.append("beacon %d starts in shadow" % c)
	if errs.is_empty():
		if not placements_unique(p):
			errs.append("an answer can be traced in more than one place")
		if solve_order(p).is_empty():
			errs.append("unsolvable: shadows never all light up")
	return errs
