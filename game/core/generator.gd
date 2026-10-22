class_name PuzzleGenerator
extends RefCounted
## Builds puzzles from the curated theme word lists. Shared by the level tool
## (tools/generate_levels.gd, which writes the 320 chapter levels once) and the
## game itself, which builds each day's daily puzzle on the phone from the date.
##
## Deterministic: the same inputs give the same puzzle on every device. A puzzle
## is a random Hamiltonian path over the grid (so every tile is used once) cut
## into theme words, and is kept only if every answer can be traced in exactly
## one place, the shadows can all be lit, and beacons genuinely help.

## Grid sizes (rows, cols) from smallest to largest. Every chapter climbs its
## own stretch of this ladder ("sizes" in chapters.json) one step at a time.
const SIZES: Array = [[3, 3], [4, 3], [4, 4], [5, 4], [5, 5], [6, 5], [6, 6], [7, 6], [7, 7], [8, 7]]
## Each level must score at least this much more than the one before.
const MIN_STEP: float = 0.15
## Candidates tried per level (more only when none is harder than the last).
const CANDIDATES: int = 8
const MAX_CANDIDATES: int = 60
const RECENT_THEMES: int = 14

var themes: Dictionary = {}
var plan: Dictionary = {}
var recent: Array[String] = []
var _sorted_themes: Array = []


func _init(theme_data: Dictionary, plan_data: Dictionary) -> void:
	themes = theme_data
	plan = plan_data
	_sorted_themes = themes.keys()
	_sorted_themes.sort()


## How hard a puzzle is. Bigger grids, longer words, more shadows and more
## waves of light are harder, and so are twisty words (each turn makes a word
## harder to spot), words that read backwards (right-to-left or upwards) and
## words that run down the grid (harder to read than words running across), and
## look-alike starts (other tiles with a word's first letter are false leads).
## Levels are chosen so this rises a little every level.
static func difficulty(p: Puzzle) -> float:
	var letters: int = 0
	var turns: int = 0
	var bends: int = 0
	var back: int = 0
	var down: int = 0
	var steps: int = 0
	for w: Dictionary in p.words:
		var cells: PackedInt32Array = w["cells"]
		letters += cells.size()
		for k: int in range(1, cells.size()):
			var d: int = cells[k] - cells[k - 1]
			steps += 1
			if d < 0:
				back += 1
			if absi(d) == p.cols:
				down += 1
			if k >= 2:
				bends += 1
				if d != cells[k - 1] - cells[k - 2]:
					turns += 1
	var avg: float = float(letters) / float(maxi(1, p.words.size()))
	var twist: float = float(turns) / float(maxi(1, bends))
	var backwards: float = float(back) / float(maxi(1, steps))
	var vertical: float = float(down) / float(maxi(1, steps))
	var leads: int = 0
	for w: Dictionary in p.words:
		leads += p.letters.count(str(w["word"])[0]) - 1
	var decoys: float = float(leads) / float(maxi(1, p.words.size()))
	return p.cell_count() + 3.0 * avg + 1.5 * p.shadows.size() + 2.0 * maxi(0, LanternRules.light_depth(p) - 1) + 6.0 * twist + 3.0 * backwards + 2.0 * vertical + decoys


static func tier_for(plan_data: Dictionary, n: int) -> Dictionary:
	for t: Dictionary in plan_data["difficulty"]["tiers"]:
		if n >= int(t["from"]) and n <= int(t["to"]):
			return t
	return plan_data["difficulty"]["tiers"][0]


## Grid size, word lengths, shadows, beacons and the chapter's idea for level n
## (1-based) of chapter ci (0-based). The grid climbs the chapter's stretch of
## the size ladder smoothly; word lengths and shadows follow the tiers (1-5
## easy, 6-10 easy-medium, 11-20 medium, 21-30 medium-hard, 31-39 hard, 40
## extreme). Each chapter's idea (listed words, straight words, two themes, a
## mystery theme, shadows, beacons) comes from its entry in chapters.json.
static func spec_for(plan_data: Dictionary, ci: int, n: int, size_floor: int = 0) -> Dictionary:
	var tier: Dictionary = tier_for(plan_data, n)
	var per: int = int(plan_data["levels_per_chapter"])
	var count: int = (plan_data["chapters"] as Array).size()
	var ch: Dictionary = plan_data["chapters"][ci]
	var c: float = float(ci) / float(maxi(1, count - 1))
	var sizes: Array = ch.get("sizes", [0, SIZES.size() - 1])
	var start: int = int(sizes[0])
	var last: int = mini(int(sizes[1]), SIZES.size() - 1)
	var t: float = pow(float(n - 1) / float(maxi(1, per - 1)), 1.1)
	var idx: int = clampi(maxi(size_floor, start + int(floor((last - start) * t + 0.0001))), 0, SIZES.size() - 1)
	var size: Array = SIZES[idx]
	var span: int = int(tier["to"]) - int(tier["from"])
	var p: float = 0.0 if span == 0 else float(n - int(tier["from"])) / float(span)
	var lo: int = int(tier["len"][0])
	var hi: int = int(tier["len"][1])
	if c >= 0.6 and lo + 2 <= hi:
		lo += 1
	if n == per:
		lo = maxi(lo, 6)
	var rows: int = int(size[0])
	var cols: int = int(size[1])
	var straight: bool = bool(ch.get("straight", false))
	# Small grids can't hold long words, and a straight word fits in one row or column.
	hi = mini(hi, rows * cols - 3)
	if straight:
		hi = mini(hi, maxi(rows, cols))
		lo = mini(lo, hi)
	if rows * cols <= 12:
		lo = 3
		hi = mini(hi, 5)
	var shadows: int = 0
	var scale: float = float(ch.get("shadows", 0.0))
	if scale > 0.0:
		shadows = maxi(2, int(round(rows * cols * float(tier["shadows"]) * scale * (0.85 + 0.3 * p))))
	var beacons: int = 0
	if int(ch.get("beacons", 0)) > 0:
		beacons = clampi(int(tier["beacons"]), 1, int(ch["beacons"]))
		shadows = maxi(shadows, 4)
	return {"rows": rows, "cols": cols, "min": lo, "max": hi, "shadows": shadows, "beacons": beacons, "tier": str(tier["name"]), "size_index": idx,
		"listed": bool(ch.get("listed", false)), "straight": straight, "themes": int(ch.get("themes", 1)), "mystery": bool(ch.get("mystery", false))}


## All levels of chapter ci, each a little harder than the one before.
## Returns an empty array if any level cannot be built.
func chapter_levels(ci: int) -> Array[Puzzle]:
	var out: Array[Puzzle] = []
	var ch: Dictionary = plan["chapters"][ci]
	var prev: float = -1.0e9
	recent.clear()
	# The grid never shrinks; when a size has no harder option left, step up.
	var size_floor: int = 0
	for n: int in range(1, int(plan["levels_per_chapter"]) + 1):
		var id: String = "%s-%02d" % [ch["id"], n]
		var best: Puzzle = null
		var best_score: float = 0.0
		var spec: Dictionary = {}
		while best == null and size_floor < SIZES.size():
			spec = spec_for(plan, ci, n, size_floor)
			for k: int in MAX_CANDIDATES:
				var p: Puzzle = generate(spec, id, "%s#%d#%d" % [id, int(spec["size_index"]), k])
				if p != null:
					var sc: float = difficulty(p)
					if sc >= prev + MIN_STEP and (best == null or sc < best_score):
						best = p
						best_score = sc
				if best != null and k >= CANDIDATES - 1:
					break
			if best == null:
				size_floor = int(spec["size_index"]) + 1
		if best == null:
			push_error("No level %s harder than %.2f (%s)" % [id, prev, str(spec)])
			return []
		size_floor = int(spec["size_index"])
		_remember(best.theme_id)
		prev = best_score
		out.append(best)
	return out


## One puzzle for a spec. `seed_id` seeds the randomness; `only_theme` forces a theme.
func generate(spec: Dictionary, id: String, seed_id: String = "", only_theme: String = "") -> Puzzle:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(seed_id if not seed_id.is_empty() else id)
	for attempt: int in 4000:
		var theme_list: Array[String] = [only_theme if not only_theme.is_empty() else _pick_theme(spec, rng)]
		if int(spec.get("themes", 1)) >= 2:
			theme_list.append(_pick_theme(spec, rng, theme_list[0]))
		var p: Puzzle = _tile(spec, theme_list, rng)
		if p == null or not LanternRules.placements_unique(p):
			if not only_theme.is_empty() and attempt >= 300:
				return null
			continue
		p.id = id
		p.listed = bool(spec.get("listed", false))
		p.mystery = bool(spec.get("mystery", false))
		if _place_lights(p, spec, rng):
			return p
	return null


func _remember(theme_id: String) -> void:
	recent.append(theme_id)
	if recent.size() > RECENT_THEMES:
		recent.pop_front()


# --- Daily puzzles ---------------------------------------------------------------

## The daily puzzle for a "YYYY-MM-DD" date, built from the date alone, so every
## player gets the same puzzle on the same day with no server and no updates.
## Difficulty follows the week (Monday gentlest, Sunday hardest) and the theme
## rotates through every theme before repeating, never twice in a row.
func daily(date_key: String) -> Puzzle:
	var day: int = day_number(date_key)
	var cfg: Dictionary = plan["daily"]
	var weekday: int = weekday_of(date_key)
	var spec: Dictionary = spec_for(plan, int(cfg["chapter"]), int(cfg["weekday_levels"][weekday]))
	var id: String = "daily-" + date_key
	var theme_id: String = daily_theme(day, spec)
	var p: Puzzle = generate(spec, id, id, theme_id)
	if p == null:
		p = generate(spec, id, id + "#any")
	return p


## The theme for a day: a shuffled pass through every usable theme, a new
## shuffle each pass, and never the same theme two days running.
func daily_theme(day: int, spec: Dictionary) -> String:
	var usable: Array = _sorted_themes.filter(func(t: String) -> bool: return _usable_words(t, spec).size() >= 6)
	var n: int = usable.size()
	var today: String = _theme_at(usable, day)
	if today == _theme_at(usable, day - 1):
		var cycle: Array = _cycle(usable, int(floor(float(day) / n)))
		today = cycle[(posmod(day, n) + 1) % n]
	return today


func _theme_at(usable: Array, day: int) -> String:
	var n: int = usable.size()
	return _cycle(usable, int(floor(float(day) / n)))[posmod(day, n)]


func _cycle(usable: Array, k: int) -> Array:
	var order: Array = usable.duplicate()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("daily-cycle-%d" % k)
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


## Days since the daily epoch (1 Oct 2026) for a "YYYY-MM-DD" key.
static func day_number(date_key: String) -> int:
	var t: int = _unix_noon(date_key)
	var t0: int = _unix_noon("2026-10-01")
	return int(round(float(t - t0) / 86400.0))


## 0 = Sunday ... 6 = Saturday.
static func weekday_of(date_key: String) -> int:
	return int(Time.get_datetime_dict_from_unix_time(_unix_noon(date_key))["weekday"])


static func _unix_noon(date_key: String) -> int:
	var parts: PackedStringArray = date_key.split("-")
	if parts.size() != 3:
		return 0
	return Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12})


# --- Building one puzzle -----------------------------------------------------------

## A theme not used lately with enough words of the right lengths (`other`, the
## first theme of a two-theme grid, is never picked again).
func _pick_theme(spec: Dictionary, rng: RandomNumberGenerator, other: String = "") -> String:
	var need: int = 6 if other.is_empty() else 4
	var fresh: Array = _sorted_themes.filter(func(t: String) -> bool: return t != other and not recent.has(t) and _usable_words(t, spec).size() >= need)
	if fresh.is_empty():
		fresh = _sorted_themes.filter(func(t: String) -> bool: return t != other)
	return fresh[rng.randi_range(0, fresh.size() - 1)]


func _usable_words(theme_id: String, spec: Dictionary) -> Array:
	return (themes[theme_id]["words"] as Array).filter(func(w: String) -> bool: return w.length() >= spec["min"] and w.length() <= spec["max"])


## Lays theme words over the whole grid: a random Hamiltonian path cut into
## words (they bend and may read backwards), or for straight chapters, rows and
## columns cut into words read left to right and top to bottom. With two themes,
## each word comes from whichever theme has fewer words so far.
func _tile(spec: Dictionary, theme_list: Array[String], rng: RandomNumberGenerator) -> Puzzle:
	var rows: int = spec["rows"]
	var cols: int = spec["cols"]
	# length -> [[word, theme index], ...]; a word in both themes counts once.
	var pool: Dictionary = {}
	var seen: Dictionary = {}
	for t: int in theme_list.size():
		for w: String in _usable_words(theme_list[t], spec):
			if seen.has(w):
				continue
			seen[w] = true
			if not pool.has(w.length()):
				pool[w.length()] = []
			pool[w.length()].append([w, t])
	var segments: Array[PackedInt32Array] = []
	if bool(spec.get("straight", false)):
		segments = _straight_segments(rows, cols, spec["min"], spec["max"], pool, rng)
	else:
		var lengths: Array[int] = _split(rows * cols, spec["min"], spec["max"], pool, rng)
		var path: PackedInt32Array = _hamiltonian(rows, cols, rng)
		var at: int = 0
		for L: int in lengths:
			var cells: PackedInt32Array = path.slice(at, at + L)
			if rng.randf() < 0.5:
				cells.reverse()
			segments.append(cells)
			at += L
	if segments.is_empty():
		return null
	var p: Puzzle = Puzzle.new()
	p.theme_id = theme_list[0]
	for t: String in theme_list:
		p.theme_ids.append(t)
		p.theme_names.append(str(themes[t]["name"]))
	p.theme_name = " & ".join(p.theme_names)
	p.rows = rows
	p.cols = cols
	p.letters.resize(rows * cols)
	var used: Dictionary = {}
	var per_theme: Array[int] = []
	per_theme.resize(theme_list.size())
	for cells: PackedInt32Array in segments:
		var L: int = cells.size()
		var choices: Array = (pool[L] as Array).filter(func(e: Array) -> bool: return not used.has(e[0]))
		if choices.is_empty():
			return null
		if theme_list.size() > 1:
			var want: int = 0 if per_theme[0] <= per_theme[1] else 1
			var mine: Array = choices.filter(func(e: Array) -> bool: return int(e[1]) == want)
			if not mine.is_empty():
				choices = mine
		var pick: Array = choices[rng.randi_range(0, choices.size() - 1)]
		var word: String = pick[0]
		used[word] = true
		per_theme[int(pick[1])] += 1
		for k: int in L:
			p.letters[cells[k]] = word[k]
		p.words.append({"word": word, "cells": cells, "theme": int(pick[1])})
	for n: int in per_theme:
		if n < 2:
			return null
	# Present answers in a stable, grid-ordered way rather than path order
	# (grouped by theme when there are two).
	p.words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["theme"]) != int(b["theme"]):
			return int(a["theme"]) < int(b["theme"])
		return (a["cells"] as PackedInt32Array)[0] < (b["cells"] as PackedInt32Array)[0])
	return p


## Covers the grid with straight runs (left to right, or top to bottom) whose
## lengths the pool can fill. Returns the runs, or an empty array.
func _straight_segments(rows: int, cols: int, lo: int, hi: int, pool: Dictionary, rng: RandomNumberGenerator) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var covered: PackedByteArray = PackedByteArray()
	covered.resize(rows * cols)
	var budget: Array[int] = [4000]
	if _straight_rec(rows, cols, lo, hi, pool, rng, covered, out, {}, budget):
		return out
	return []


func _straight_rec(rows: int, cols: int, lo: int, hi: int, pool: Dictionary, rng: RandomNumberGenerator, covered: PackedByteArray, out: Array[PackedInt32Array], used: Dictionary, budget: Array[int]) -> bool:
	budget[0] -= 1
	if budget[0] < 0:
		return false
	var c: int = covered.find(0)
	if c < 0:
		return true
	var r: int = c / cols
	var col: int = c % cols
	var opts: Array[PackedInt32Array] = []
	for L: int in range(lo, hi + 1):
		if not pool.has(L) or int(used.get(L, 0)) >= (pool[L] as Array).size():
			continue
		if col + L <= cols:
			var run: PackedInt32Array = PackedInt32Array()
			for k: int in L:
				if covered[c + k] == 0:
					run.append(c + k)
			if run.size() == L:
				opts.append(run)
		if r + L <= rows:
			var run: PackedInt32Array = PackedInt32Array()
			for k: int in L:
				if covered[c + k * cols] == 0:
					run.append(c + k * cols)
			if run.size() == L:
				opts.append(run)
	for i: int in range(opts.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: PackedInt32Array = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp
	for run: PackedInt32Array in opts:
		for k: int in run:
			covered[k] = 1
		out.append(run)
		used[run.size()] = int(used.get(run.size(), 0)) + 1
		if _straight_rec(rows, cols, lo, hi, pool, rng, covered, out, used, budget):
			return true
		used[run.size()] = int(used[run.size()]) - 1
		out.pop_back()
		for k: int in run:
			covered[k] = 0
	return false


## Random word lengths summing to n, using no more words of a length than the pool has.
func _split(n: int, lo: int, hi: int, pool: Dictionary, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	var used: Dictionary = {}
	if _split_rec(n, lo, hi, pool, rng, out, used, 0):
		return out
	return []


func _split_rec(n: int, lo: int, hi: int, pool: Dictionary, rng: RandomNumberGenerator, out: Array[int], used: Dictionary, depth: int) -> bool:
	if n == 0:
		return true
	if depth > 40:
		return false
	var opts: Array[int] = []
	for L: int in range(lo, hi + 1):
		if L <= n and pool.has(L) and int(used.get(L, 0)) < (pool[L] as Array).size():
			opts.append(L)
	for i: int in range(opts.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = opts[i]
		opts[i] = opts[j]
		opts[j] = tmp
	for L: int in opts:
		var rest: int = n - L
		if rest != 0 and rest < lo:
			continue
		out.append(L)
		used[L] = int(used.get(L, 0)) + 1
		if _split_rec(rest, lo, hi, pool, rng, out, used, depth + 1):
			return true
		out.pop_back()
		used[L] = int(used[L]) - 1
	return false


## Random Hamiltonian path on the grid by "backbite" moves from a serpentine.
func _hamiltonian(rows: int, cols: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var path: Array[int] = []
	for r: int in rows:
		for k: int in cols:
			var c: int = k if r % 2 == 0 else cols - 1 - k
			path.append(r * cols + c)
	var n: int = rows * cols
	var pos: PackedInt32Array = PackedInt32Array()
	pos.resize(n)
	for i: int in n:
		pos[path[i]] = i
	for step: int in n * 40:
		if rng.randf() < 0.5:
			path.reverse()
			for i: int in n:
				pos[path[i]] = i
		var end: int = path[n - 1]
		var r: int = end / cols
		var c: int = end % cols
		var nbs: Array[int] = []
		if r > 0: nbs.append(end - cols)
		if r < rows - 1: nbs.append(end + cols)
		if c > 0: nbs.append(end - 1)
		if c < cols - 1: nbs.append(end + 1)
		var nb: int = nbs[rng.randi_range(0, nbs.size() - 1)]
		var i: int = pos[nb]
		if i == n - 2:
			continue
		var a: int = i + 1
		var b: int = n - 1
		while a < b:
			var t: int = path[a]
			path[a] = path[b]
			path[b] = t
			pos[path[a]] = a
			pos[path[b]] = b
			a += 1
			b -= 1
	return PackedInt32Array(path)


## Places shadows and beacons so the level is solvable, needs light to spread,
## and each beacon is worth finding.
func _place_lights(p: Puzzle, spec: Dictionary, rng: RandomNumberGenerator) -> bool:
	var k_sh: int = spec["shadows"]
	var k_bc: int = spec["beacons"]
	if k_sh == 0 and k_bc == 0:
		return true
	var n: int = p.cell_count()
	for attempt: int in 200:
		var cells: Array[int] = []
		for i: int in n:
			cells.append(i)
		_shuffle(cells, rng)
		p.beacons = PackedInt32Array(cells.slice(0, k_bc))
		var rest: Array[int] = cells.slice(k_bc)
		# Half the shadows sit on beacon lines, so beams have something to light.
		var on_beam: Array[int] = []
		for b: int in p.beacons:
			for c: int in LanternRules.beam_cells(p, b):
				if rest.has(c) and not on_beam.has(c):
					on_beam.append(c)
		_shuffle(on_beam, rng)
		var shadows: Array[int] = []
		if k_bc > 0:
			shadows.assign(on_beam.slice(0, k_sh / 2))
		for c: int in rest:
			if shadows.size() >= k_sh:
				break
			if not shadows.has(c):
				shadows.append(c)
		p.shadows = PackedInt32Array(shadows)
		if _lights_ok(p, k_sh):
			return true
	return false


func _lights_ok(p: Puzzle, k_sh: int) -> bool:
	var depth: int = LanternRules.light_depth(p)
	if depth < 0:
		return false
	var need: int = 1
	if k_sh >= 2:
		need = 2
	if k_sh >= 10:
		need = 3
	if depth < need:
		return false
	# At least two words must be playable at the start, so there is a choice.
	var start_playable: int = 0
	var vis: PackedByteArray = LanternRules.initial_visible(p)
	for w: Dictionary in p.words:
		if LanternRules.all_visible(w["cells"], vis):
			start_playable += 1
	if start_playable < 2:
		return false
	if p.beacons.is_empty():
		return true
	# Each beacon must light at least two shadows its own word would not reach.
	var owners: PackedInt32Array = p.owner_map()
	for b: int in p.beacons:
		var near: Dictionary = {}
		for c: int in p.words[owners[b]]["cells"]:
			near[c] = true
			for nb: int in p.neighbors(c):
				near[nb] = true
		var extra: int = 0
		for c: int in LanternRules.beam_cells(p, b):
			if p.shadows.has(c) and not near.has(c):
				extra += 1
		if extra < 2:
			return false
	# And together they must matter: without beams the level is harder or impossible.
	var saved: PackedInt32Array = p.beacons
	p.beacons = PackedInt32Array()
	var plain: int = LanternRules.light_depth(p)
	p.beacons = saved
	return plain < 0 or plain > depth


func _shuffle(a: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = a[i]
		a[i] = a[j]
		a[j] = t
