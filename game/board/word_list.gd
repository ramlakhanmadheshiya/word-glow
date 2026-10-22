class_name WordList
extends Control
## The answers as rows of letter slots: empty boxes show each word's length (or,
## in listed levels, the word itself), letter hints fill in letters, and found
## words light up in their lantern colour. Two-theme levels put each theme's
## words on their own rows under a small theme label.

var state: LevelState
var _colors: Dictionary = {}
var _rects: Array[Rect2] = []     # one per word
var _labels: Array = []           # [theme index, baseline y] per theme group
var _box: float = 30.0
var _pop: Dictionary = {}         # word index -> start time
var _now: float = 0.0
var _last_width: float = -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(s: LevelState) -> void:
	state = s
	_colors.clear()
	for k: int in s.found_order.size():
		_colors[s.found_order[k]] = Look.lantern(k)
	_last_width = -1.0
	_relayout()


func mark_found(word_idx: int) -> void:
	_colors[word_idx] = Look.lantern(state.found_order.size() - 1)
	_pop[word_idx] = _now
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and absf(size.x - _last_width) > 0.5:
		_relayout()


## Flows words into centred rows, shrinking the boxes until they fit in 3 rows
## (one more when two themes each start their own row).
func _relayout() -> void:
	if state == null or size.x <= 0:
		return
	_last_width = size.x
	var words: Array[Dictionary] = state.puzzle.words
	var best: Array[Rect2] = []
	var box: float = 40.0
	var max_rows: int = 3 + state.puzzle.theme_ids.size() - 1
	while box >= 20.0:
		var rows: Array = _flow(words, box)
		best = rows[0]
		_labels = rows[2]
		if int(rows[1]) <= max_rows:
			break
		box -= 2.0
	_box = box
	_rects = best
	var h: float = 0.0
	for r: Rect2 in _rects:
		h = maxf(h, r.end.y)
	custom_minimum_size.y = h + 4.0
	queue_redraw()


func _flow(words: Array[Dictionary], box: float) -> Array:
	var gap: float = box * 0.12
	var chip_gap: float = box * 0.7
	var row_gap: float = box * 0.38
	var rects: Array[Rect2] = []
	var rows: Array = [[]]
	var starts: Dictionary = {}       # row index -> theme that starts on it
	var labelled: bool = state.puzzle.theme_ids.size() > 1
	if labelled:
		starts[0] = int(words[0].get("theme", 0)) if not words.is_empty() else 0
	var x: float = 0.0
	for i: int in words.size():
		var n: int = str(words[i]["word"]).length()
		var w: float = n * box + (n - 1) * gap
		var new_theme: bool = i > 0 and int(words[i].get("theme", 0)) != int(words[i - 1].get("theme", 0))
		if x > 0.0 and (x + w > size.x or new_theme):
			rows.append([])
			x = 0.0
			if new_theme:
				starts[rows.size() - 1] = int(words[i].get("theme", 0))
		rows[rows.size() - 1].append([i, w])
		x += w + chip_gap
	rects.resize(words.size())
	var y: float = 2.0
	var labels: Array = []
	var label_h: float = 28.0
	for ri: int in rows.size():
		var row: Array = rows[ri]
		if starts.has(ri):
			labels.append([int(starts[ri]), y + label_h - 6.0])
			y += label_h
		var total: float = -chip_gap
		for item: Array in row:
			total += float(item[1]) + chip_gap
		var rx: float = (size.x - total) / 2.0
		for item: Array in row:
			rects[int(item[0])] = Rect2(rx, y, float(item[1]), box)
			rx += float(item[1]) + chip_gap
		y += box + row_gap
	return [rects, rows.size(), labels]


func _process(delta: float) -> void:
	_now += delta
	if not _pop.is_empty():
		queue_redraw()


func _draw() -> void:
	if state == null or _rects.is_empty():
		return
	var font: Font = UIKit.font(700)
	var fs: int = int(_box * 0.62)
	var gap: float = _box * 0.12
	var sparks: Dictionary = state.sparks
	var small: Font = UIKit.font(700)
	for lab: Array in _labels:
		var text: String = state.puzzle.shown_theme_part(int(lab[0]), state.found).to_upper()
		var tw: float = small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(small, Vector2((size.x - tw) / 2.0, float(lab[1])), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Style.MUTED)
	for i: int in state.puzzle.words.size():
		var word: String = state.puzzle.words[i]["word"]
		var r: Rect2 = _rects[i]
		var found: bool = state.found[i] != 0
		var col: Color = _colors.get(i, Style.AMBER)
		var s: float = 1.0
		if _pop.has(i):
			var k: float = (_now - float(_pop[i])) / 0.45
			if k >= 1.0:
				_pop.erase(i)
			else:
				s = 1.0 + 0.18 * sin(PI * k)
		var shown: int = int(sparks.get(i, 0))
		for k: int in word.length():
			var br: Rect2 = Rect2(r.position + Vector2(k * (_box + gap), 0), Vector2(_box, _box))
			br = Rect2(br.get_center() - br.size * s / 2.0, br.size * s)
			var fill: Color = col if found else Color(Style.INK, 0.09)
			draw_style_box(UIKit.box(fill, int(_box * 0.24)), br)
			var text: String = ""
			var tc: Color = Color.WHITE
			if found:
				text = word[k]
			elif k < shown:
				text = word[k]
				tc = Style.GOLD
			elif state.puzzle.listed:
				text = word[k]
				tc = Color(Style.INK, 0.85)
			if not text.is_empty():
				var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var base: float = br.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
				draw_string(font, Vector2(br.get_center().x - w / 2.0, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
