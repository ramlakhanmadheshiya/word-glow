class_name BoardView
extends Control
## Draws the letter grid and turns drags into traced paths. Knows nothing about
## coins or saving: it reads a LevelState and emits `traced` when a drag ends.
##
## Found words are drawn as one connected ribbon of lantern colour; shadows are
## dark tiles; beacons carry a small flame. All animation is time-based in _draw.

signal traced(cells: PackedInt32Array)
signal trace_changed(text: String)

const MAX_TILE: float = 132.0
const GAP_RATIO: float = 0.12
## A drag only enters a tile when it comes this close to its centre (fraction of
## the tile), so cutting a corner never selects a diagonal by mistake.
const HIT_RADIUS: float = 0.42

var state: LevelState
var accent: Color = Style.AMBER
var input_enabled: bool = true

var _tile: float = 64.0
var _gap: float = 8.0
var _origin: Vector2 = Vector2.ZERO
var _path: PackedInt32Array = PackedInt32Array()
var _dragging: bool = false
var _colors: Dictionary = {}          # word index -> Color
var _fx: Dictionary = {}              # cell -> {kind: start_time}
var _beams: Array[Dictionary] = []    # {cell, t}
var _celebrate_t: float = -10.0
var _ghost: PackedInt32Array = PackedInt32Array()
var _ghost_t: float = 0.0
var _now: float = 0.0
var _busy_until: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = false


func setup(s: LevelState, accent_color: Color) -> void:
	state = s
	accent = accent_color
	_colors.clear()
	for k: int in s.found_order.size():
		_colors[s.found_order[k]] = Look.lantern(k)
	_layout()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if state == null:
		return
	var p: Puzzle = state.puzzle
	var tw: float = size.x / (p.cols + GAP_RATIO * (p.cols - 1))
	var th: float = size.y / (p.rows + GAP_RATIO * (p.rows - 1))
	_tile = floorf(minf(minf(tw, th), MAX_TILE))
	_gap = roundf(_tile * GAP_RATIO)
	var grid: Vector2 = Vector2(p.cols * _tile + (p.cols - 1) * _gap, p.rows * _tile + (p.rows - 1) * _gap)
	_origin = ((size - grid) / 2.0).round()


## Smallest size the board can be drawn at comfortably.
func _get_minimum_size() -> Vector2:
	return Vector2(200, 200)


func tile_size() -> float:
	return _tile


func cell_rect(c: int) -> Rect2:
	var p: Puzzle = state.puzzle
	return Rect2(_origin + Vector2(p.col_of(c), p.row_of(c)) * (_tile + _gap), Vector2(_tile, _tile))


func cell_center(c: int) -> Vector2:
	return cell_rect(c).get_center()


## The cell under a point; with `strict`, only near the tile's centre.
func cell_at(pos: Vector2, strict: bool) -> int:
	var p: Puzzle = state.puzzle
	var rel: Vector2 = (pos - _origin) / (_tile + _gap)
	var col: int = int(floor(rel.x))
	var row: int = int(floor(rel.y))
	if col < 0 or row < 0 or col >= p.cols or row >= p.rows:
		return -1
	var c: int = row * p.cols + col
	if strict and pos.distance_to(cell_center(c)) > _tile * HIT_RADIUS * 1.15:
		return -1
	return c


# --- Input -------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	if state == null or not input_enabled:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e
		if mb.pressed:
			_begin(mb.position)
		else:
			_end()
		accept_event()
	elif e is InputEventMouseMotion and _dragging:
		_drag((e as InputEventMouseMotion).position)
		accept_event()


func _begin(pos: Vector2) -> void:
	var c: int = cell_at(pos, false)
	if c < 0 or not state.can_select(c):
		return
	_dragging = true
	_path = PackedInt32Array([c])
	_ghost = PackedInt32Array()
	_on_path_changed()


func _drag(pos: Vector2) -> void:
	var c: int = cell_at(pos, true)
	if c < 0 or c == _path[_path.size() - 1]:
		return
	if _path.size() >= 2 and c == _path[_path.size() - 2]:
		_path.remove_at(_path.size() - 1)
		_on_path_changed()
		return
	if _path.has(c) or not state.can_select(c) or not state.puzzle.is_adjacent(_path[_path.size() - 1], c):
		return
	_path.append(c)
	_on_path_changed()


func _end() -> void:
	if not _dragging:
		return
	_dragging = false
	var p: PackedInt32Array = _path
	_path = PackedInt32Array()
	trace_changed.emit("")
	queue_redraw()
	if p.size() >= 1:
		traced.emit(p)


func _on_path_changed() -> void:
	var last: int = _path[_path.size() - 1]
	_fx_start(last, "pop")
	Audio.tap(_path.size() - 1)
	Haptics.tick()
	trace_changed.emit(state.puzzle.word_text(_path))
	queue_redraw()


## Cancels a drag in progress (e.g. when a menu opens).
func cancel_trace() -> void:
	_dragging = false
	_path = PackedInt32Array()
	trace_changed.emit("")
	queue_redraw()


# --- Feedback the play screen triggers ----------------------------------------

func show_found(word_idx: int, revealed: PackedInt32Array, beacons: PackedInt32Array) -> void:
	_colors[word_idx] = Look.lantern(state.found_order.size() - 1)
	var cells: PackedInt32Array = state.puzzle.words[word_idx]["cells"]
	for k: int in cells.size():
		_fx_start(cells[k], "lit", k * 0.05)
	var delay: float = cells.size() * 0.05 + 0.1
	for b: int in beacons:
		_beams.append({"cell": b, "t": _now + delay})
	for c: int in revealed:
		var d: float = 0.0
		for b: int in beacons:
			if state.puzzle.row_of(b) == state.puzzle.row_of(c) or state.puzzle.col_of(b) == state.puzzle.col_of(c):
				d = maxf(d, 0.12 + 0.07 * absi(state.puzzle.row_of(b) - state.puzzle.row_of(c) + state.puzzle.col_of(b) - state.puzzle.col_of(c)))
		_fx_start(c, "reveal", delay + d)
	_busy_until = _now + delay + 0.6
	queue_redraw()


func show_error(cells: PackedInt32Array) -> void:
	for c: int in cells:
		_fx_start(c, "shake")
	queue_redraw()


func show_spark(cell: int) -> void:
	_fx_start(cell, "spark")
	queue_redraw()


## A wave of light across the finished board.
func celebrate() -> void:
	_celebrate_t = _now
	queue_redraw()


## Tutorial: animate a ghost finger along this path until the player starts tracing.
func show_ghost(path: PackedInt32Array) -> void:
	_ghost = path
	_ghost_t = _now
	queue_redraw()


func _fx_start(c: int, kind: String, delay: float = 0.0) -> void:
	if not _fx.has(c):
		_fx[c] = {}
	_fx[c][kind] = _now + delay


## 0..1 progress of an effect on a cell, or -1 when not running.
func _fx_k(c: int, kind: String, dur: float) -> float:
	if not _fx.has(c) or not _fx[c].has(kind):
		return -1.0
	var k: float = (_now - float(_fx[c][kind])) / dur
	if k < 0.0:
		return 0.0 if kind == "reveal" else -1.0
	if k > 1.0:
		_fx[c].erase(kind)
		return -1.0
	return k


func _process(delta: float) -> void:
	_now += delta
	queue_redraw()


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	if state == null:
		return
	var p: Puzzle = state.puzzle
	var font: Font = UIKit.font(700)
	var fs: int = int(_tile * 0.5)
	var small_fs: int = maxi(12, int(_tile * 0.2))
	var radius: float = _tile * Look.radius()
	var glow: Texture2D = Style.glow_texture()
	var sparked: Dictionary = state.sparked_cells()
	var in_path: Dictionary = {}
	for k: int in _path.size():
		in_path[_path[k]] = k

	# Board tray.
	var grid_size: Vector2 = Vector2(p.cols * _tile + (p.cols - 1) * _gap, p.rows * _tile + (p.rows - 1) * _gap)
	var tray: Rect2 = Rect2(_origin, grid_size).grow(_gap * 1.6)
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.22), int(radius * 1.6), Color(1, 1, 1, 0.06), 2), tray)

	# Glow under lit words, then their ribbons.
	for i: int in p.words.size():
		if state.found[i] == 0:
			continue
		var col: Color = _colors.get(i, accent)
		for c: int in p.words[i]["cells"]:
			var lk: float = _fx_k(c, "lit", 0.5)
			var a: float = (0.28 if lk < 0.0 else 0.28 + 0.5 * (1.0 - lk)) * Look.glow()
			var r: Rect2 = cell_rect(c).grow(_tile * 0.45)
			draw_texture_rect(glow, r, false, Color(col, a))
	for i: int in p.words.size():
		if state.found[i] != 0:
			_draw_ribbon(p.words[i]["cells"], _colors.get(i, accent), radius, 1.0)
	if _path.size() >= 1:
		_draw_ribbon(_path, accent, radius, 0.95)
		# A white rim tells the live trace apart from words already lit.
		for c: int in _path:
			draw_style_box(UIKit.box(Color.TRANSPARENT, int(radius + 2), Color(1, 1, 1, 0.9), maxi(3, int(_tile * 0.05))), cell_rect(c).grow(1))

	# Tiles.
	for c: int in p.cell_count():
		var rect: Rect2 = cell_rect(c)
		var scale_k: float = 1.0
		var offset: Vector2 = Vector2.ZERO
		var pop: float = _fx_k(c, "pop", 0.22)
		if pop >= 0.0:
			scale_k += 0.12 * sin(PI * pop)
		var lit_k: float = _fx_k(c, "lit", 0.4)
		if lit_k >= 0.0:
			scale_k += 0.16 * sin(PI * lit_k)
		var shake: float = _fx_k(c, "shake", 0.4)
		if shake >= 0.0:
			offset.x = sin(shake * 40.0) * _tile * 0.08 * (1.0 - shake)
		if _now - _celebrate_t < 2.0:
			var wave: float = (_now - _celebrate_t) * 3.2 - (p.row_of(c) + p.col_of(c)) * 0.35
			if wave > 0.0 and wave < 1.0:
				scale_k += 0.14 * sin(PI * wave)
		rect = Rect2(rect.get_center() - rect.size * scale_k / 2.0 + offset, rect.size * scale_k)
		var lit: bool = state.is_lit(c)
		var letter: String = p.letters[c]
		var reveal: float = _fx_k(c, "reveal", 0.45)
		if state.visible[c] == 0 or reveal == 0.0:
			_draw_shadow_tile(rect, radius, c)
			continue
		if lit:
			var col: Color = _colors.get(state.owner_of(c), accent)
			_draw_letter(font, fs, letter, rect, Color.WHITE)
			if p.beacons.has(c):
				_draw_flame(rect, Color(1, 1, 1, 0.9), small_fs)
			continue
		if in_path.has(c):
			_draw_letter(font, fs, letter, rect, Look.tile_ink())
			continue
		var tile_col: Color = Look.tile()
		if shake >= 0.0:
			tile_col = Look.tile().lerp(Style.ERROR, 0.55 * (1.0 - shake))
		var a: float = 1.0
		if reveal > 0.0:
			a = reveal
			_draw_shadow_tile(rect, radius, c, 1.0 - reveal)
		draw_style_box(UIKit.box(Color(Look.tile_edge(), a), int(radius)), Rect2(rect.position + Vector2(0, _tile * 0.05), rect.size))
		draw_style_box(UIKit.box(Color(tile_col, a), int(radius)), rect)
		_draw_letter(font, fs, letter, rect, Color(Look.tile_ink(), a))
		if p.beacons.has(c):
			_draw_flame(rect, Color(Color("FF8A3D"), a), small_fs)
		if sparked.has(c):
			var sk: float = _fx_k(c, "spark", 0.6)
			var ring: Color = Style.GOLD
			var grow: float = 0.0 if sk < 0.0 else (1.0 - sk) * _tile * 0.15
			var rs: StyleBoxFlat = UIKit.box(Color.TRANSPARENT, int(radius + 3), ring, maxi(3, int(_tile * 0.06)))
			draw_style_box(rs, rect.grow(2.0 + grow))
			draw_string(font, rect.position + Vector2(_tile * 0.1, _tile * 0.3), str(int(sparked[c]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, small_fs, Color("B87A00"))

	# Beacon beams.
	for b: Dictionary in _beams.duplicate():
		var k: float = (_now - float(b["t"])) / 0.9
		if k > 1.0:
			_beams.erase(b)
			continue
		if k < 0.0:
			continue
		var from: Vector2 = cell_center(int(b["cell"]))
		var reach: float = maxf(p.rows, p.cols) * (_tile + _gap) * minf(1.0, k * 1.6)
		var a2: float = 1.0 - k
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var to: Vector2 = from + dir * reach
			to = to.clamp(_origin, _origin + grid_size)
			draw_line(from, to, Color(Style.GOLD, 0.35 * a2), _tile * 0.5, true)
			draw_line(from, to, Color(Color.WHITE, 0.7 * a2), _tile * 0.08, true)

	# Tutorial ghost finger.
	if _ghost.size() >= 2:
		var period: float = 0.45 * _ghost.size() + 0.9
		var gk: float = fmod(_now - _ghost_t, period) / (0.45 * (_ghost.size() - 1))
		if gk <= 1.0:
			var seg: float = gk * (_ghost.size() - 1)
			var i0: int = mini(int(seg), _ghost.size() - 2)
			var at: Vector2 = cell_center(_ghost[i0]).lerp(cell_center(_ghost[i0 + 1]), seg - i0)
			var trail: PackedVector2Array = PackedVector2Array()
			for j: int in i0 + 1:
				trail.append(cell_center(_ghost[j]))
			trail.append(at)
			if trail.size() >= 2:
				draw_polyline(trail, Color(accent, 0.55), _tile * 0.18, true)
			draw_circle(at + Vector2(_tile * 0.18, _tile * 0.22), _tile * 0.2, Color(1, 1, 1, 0.85))
			draw_circle(at + Vector2(_tile * 0.18, _tile * 0.22), _tile * 0.13, Color(accent, 0.9))


## One colour band joining a word's tiles, so it reads as a single lantern string.
func _draw_ribbon(cells: PackedInt32Array, col: Color, radius: float, alpha: float) -> void:
	var band: float = _tile * 0.62
	var c0: Color = Color(col, alpha)
	for k: int in cells.size():
		draw_style_box(UIKit.box(c0.darkened(0.25), int(radius)), Rect2(cell_rect(cells[k]).position + Vector2(0, _tile * 0.05), Vector2(_tile, _tile)))
	for k: int in range(1, cells.size()):
		var a: Vector2 = cell_center(cells[k - 1])
		var b: Vector2 = cell_center(cells[k])
		var r: Rect2 = Rect2(a.min(b) - Vector2(band, band) / 2.0, (b - a).abs() + Vector2(band, band))
		draw_rect(r, c0)
	for k: int in cells.size():
		draw_style_box(UIKit.box(c0, int(radius)), cell_rect(cells[k]))
		# A soft highlight band on the upper half for a paper-lantern feel.
		var hr: Rect2 = cell_rect(cells[k]).grow(-_tile * 0.12)
		hr.size.y *= 0.4
		draw_style_box(UIKit.box(Color(1, 1, 1, 0.13 * alpha), int(radius * 0.7)), hr)


func _draw_shadow_tile(rect: Rect2, radius: float, c: int, alpha: float = 1.0) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_now * 1.6 + c * 0.7)
	draw_style_box(UIKit.box(Color(Style.SHADOW_TILE, alpha), int(radius), Color(1, 1, 1, 0.07 * alpha), 2), rect)
	var ctr: Vector2 = rect.get_center()
	var s: float = _tile * (0.07 + 0.02 * pulse)
	var col: Color = Color(Style.MUTED, (0.25 + 0.2 * pulse) * alpha)
	draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -s * 2), ctr + Vector2(s * 0.5, -s * 0.5), ctr + Vector2(s * 2, 0), ctr + Vector2(s * 0.5, s * 0.5), ctr + Vector2(0, s * 2), ctr + Vector2(-s * 0.5, s * 0.5), ctr + Vector2(-s * 2, 0), ctr + Vector2(-s * 0.5, -s * 0.5)]), col)


func _draw_letter(font: Font, fs: int, letter: String, rect: Rect2, col: Color) -> void:
	var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base: float = rect.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0 - fs * 0.02
	draw_string(font, Vector2(rect.get_center().x - w / 2.0, base), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_flame(rect: Rect2, col: Color, px: int) -> void:
	var tex: Texture2D = UIKit.icon("flame")
	var s: float = maxf(16.0, px * 1.25)
	draw_texture_rect(tex, Rect2(rect.end - Vector2(s + _tile * 0.06, s + _tile * 0.06), Vector2(s, s)), false, col)


## True while found/reveal animations are still playing.
func is_animating() -> bool:
	return _now < _busy_until
