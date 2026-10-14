extends SceneTree
## Builds every level from the curated theme word lists and the plan in
## data/worlds.json, then writes data/levels/<world>.json and daily.json.
##
##   godot --headless --path . -s res://tools/generate_levels.gd
##   godot --headless --path . -s res://tools/generate_levels.gd -- harbor
##
## Deterministic: the same inputs always give the same levels. Each puzzle is a
## random Hamiltonian path over the grid (so every tile is used once) cut into
## theme words. It is kept only if every answer can be traced in exactly one place,
## the shadows can all be lit, and beacons genuinely help.

const LEVELS_PER_WORLD: int = 20
const OUT_DIR: String = "res://data/levels/"

var _themes: Dictionary = {}
var _recent_themes: Array[String] = []


func _init() -> void:
	_themes = JSON.parse_string(FileAccess.get_file_as_string("res://data/themes.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/worlds.json"))
	var only: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var t0: int = Time.get_ticks_msec()
	for w: Dictionary in catalog["worlds"]:
		if not only.is_empty() and not only.has(w["id"]):
			continue
		var levels: Array = []
		_recent_themes.clear()
		for n: int in range(1, LEVELS_PER_WORLD + 1):
			var spec: Dictionary = _spec(w["gen"], n, LEVELS_PER_WORLD, false, 0)
			var p: Puzzle = _generate(spec, "%s-%02d" % [w["id"], n])
			if p == null:
				push_error("FAILED %s level %d" % [w["id"], n])
				quit(1)
				return
			levels.append(p.to_dict())
			print("%s-%02d  %dx%d  %-12s words=%d shadows=%d beacons=%d depth=%d" % [w["id"], n, p.rows, p.cols, p.theme_id, p.words.size(), p.shadows.size(), p.beacons.size(), LanternRules.light_depth(p)])
		_write(OUT_DIR + w["id"] + ".json", {"world": w["id"], "levels": levels})
	if only.is_empty() or only.has("daily"):
		var daily: Dictionary = catalog["daily"]
		var levels: Array = []
		_recent_themes.clear()
		for n: int in range(1, int(daily["count"]) + 1):
			var spec: Dictionary = _spec(daily["gen"], n, int(daily["count"]), true, hash("daily-%d" % n))
			var p: Puzzle = _generate(spec, "daily-%03d" % n)
			if p == null:
				push_error("FAILED daily %d" % n)
				quit(1)
				return
			levels.append(p.to_dict())
		_write(OUT_DIR + "daily.json", {"world": "daily", "levels": levels})
		print("daily: %d puzzles" % levels.size())
	print("GENERATED in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


## The size, word lengths, shadow and beacon counts for level n of a plan.
## Stages are [from_level, rows, cols, min_len, max_len]; shadows and beacons are
## [first_count, last_count, from_level], ramping linearly (or random per day for the daily pool).
func _spec(gen: Dictionary, n: int, total: int, randomized: bool, seed_v: int) -> Dictionary:
	var stage: Array = gen["stages"][0]
	for s: Array in gen["stages"]:
		if n >= int(s[0]):
			stage = s
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var counts: Array[int] = []
	for key: String in ["shadows", "beacons"]:
		var r: Array = gen[key]
		var from: int = int(r[2])
		var k: int = 0
		if n >= from:
			if randomized:
				k = rng.randi_range(int(r[0]), int(r[1]))
			else:
				var t: float = 0.0 if total == from else float(n - from) / float(total - from)
				k = int(round(lerpf(float(r[0]), float(r[1]), t)))
		counts.append(k)
	return {"rows": int(stage[1]), "cols": int(stage[2]), "min": int(stage[3]), "max": int(stage[4]), "shadows": counts[0], "beacons": counts[1]}


func _generate(spec: Dictionary, id: String) -> Puzzle:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id)
	var themes: Array = _themes.keys()
	themes.sort()
	for attempt: int in 4000:
		var theme_id: String = _pick_theme(themes, spec, rng)
		var p: Puzzle = _tile(spec, theme_id, rng)
		if p == null or not LanternRules.placements_unique(p):
			continue
		p.id = id
		if _place_lights(p, spec, rng):
			_recent_themes.append(theme_id)
			if _recent_themes.size() > 8:
				_recent_themes.pop_front()
			return p
	return null


func _pick_theme(themes: Array, spec: Dictionary, rng: RandomNumberGenerator) -> String:
	var fresh: Array = themes.filter(func(t: String) -> bool: return not _recent_themes.has(t) and _usable_words(t, spec).size() >= 6)
	if fresh.is_empty():
		fresh = themes
	return fresh[rng.randi_range(0, fresh.size() - 1)]


func _usable_words(theme_id: String, spec: Dictionary) -> Array:
	return (_themes[theme_id]["words"] as Array).filter(func(w: String) -> bool: return w.length() >= spec["min"] and w.length() <= spec["max"])


## Cuts a random Hamiltonian path into theme words and writes them onto the grid.
func _tile(spec: Dictionary, theme_id: String, rng: RandomNumberGenerator) -> Puzzle:
	var rows: int = spec["rows"]
	var cols: int = spec["cols"]
	var pool: Dictionary = {}
	for w: String in _usable_words(theme_id, spec):
		if not pool.has(w.length()):
			pool[w.length()] = []
		pool[w.length()].append(w)
	var lengths: Array[int] = _split(rows * cols, spec["min"], spec["max"], pool, rng)
	if lengths.is_empty():
		return null
	var path: PackedInt32Array = _hamiltonian(rows, cols, rng)
	var p: Puzzle = Puzzle.new()
	p.theme_id = theme_id
	p.theme_name = _themes[theme_id]["name"]
	p.rows = rows
	p.cols = cols
	p.letters.resize(rows * cols)
	var used: Dictionary = {}
	var at: int = 0
	for L: int in lengths:
		var choices: Array = (pool[L] as Array).filter(func(w: String) -> bool: return not used.has(w))
		var word: String = choices[rng.randi_range(0, choices.size() - 1)]
		used[word] = true
		var cells: PackedInt32Array = path.slice(at, at + L)
		if rng.randf() < 0.5:
			cells.reverse()
		for k: int in L:
			p.letters[cells[k]] = word[k]
		p.words.append({"word": word, "cells": cells})
		at += L
	# Present answers in a stable, grid-ordered way rather than path order.
	p.words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["cells"] as PackedInt32Array)[0] < (b["cells"] as PackedInt32Array)[0])
	return p


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
	# Shuffle with the seeded RNG so results stay deterministic.
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
		# Reverse path[i+1 .. n-1].
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


## Places shadows and beacons so the level is solvable, needs light to spread, and
## each beacon is worth finding.
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
	if LanternRules.light_depth(p) > 0:
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


func _write(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false))
	f.close()
