class_name LevelTile
extends Button
## One level on the level grid: lit (cleared), glowing (next to play), in
## progress, or locked. A star marks levels cleared without hints.

enum Kind { LOCKED, OPEN, CLEARED }

var number: int
var kind: Kind
var flawless: bool
var in_progress: bool
var accent: Color
var _t: float = 0.0


func _init(n: int, k: Kind, is_flawless: bool, started: bool, accent_color: Color) -> void:
	number = n
	kind = k
	flawless = is_flawless
	in_progress = started
	accent = accent_color
	name = "Level%d" % n
	custom_minimum_size = Vector2(0, 132)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.juice(self)


func _process(delta: float) -> void:
	_t += delta
	if kind == Kind.OPEN:
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var r: Rect2 = Rect2((size - Vector2(s, s)) / 2.0, Vector2(s, s))
	var f: Font = UIKit.font(700)
	var fs: int = int(s * 0.36)
	var text_col: Color
	match kind:
		Kind.CLEARED:
			draw_texture_rect(Style.glow_texture(), r.grow(s * 0.18), false, Color(accent, 0.25))
			draw_style_box(UIKit.box(accent.darkened(0.25), 28), Rect2(r.position + Vector2(0, 5), r.size))
			draw_style_box(UIKit.box(accent, 28), r)
			text_col = Style.PAPER_INK
		Kind.OPEN:
			var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
			draw_texture_rect(Style.glow_texture(), r.grow(s * 0.25), false, Color(accent, 0.2 + 0.25 * pulse))
			draw_style_box(UIKit.box(Style.PAPER, 28, accent, 4), r)
			text_col = Style.PAPER_INK
		_:
			draw_style_box(UIKit.box(Color(1, 1, 1, 0.06), 28, Color(1, 1, 1, 0.08), 2), r)
			text_col = Color(Style.INK, 0.3)
	if has_focus():
		draw_style_box(UIKit.box(Color.TRANSPARENT, 30, Color(Style.INK, 0.8), 3), r.grow(5))
	if kind == Kind.LOCKED:
		var ic: float = s * 0.3
		draw_texture_rect(UIKit.icon("lock"), Rect2(r.get_center() - Vector2(ic, ic) / 2.0, Vector2(ic, ic)), false, Color(Style.INK, 0.3))
		return
	var label: String = str(number)
	var w: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(r.get_center().x - w / 2.0, r.get_center().y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)
	if kind == Kind.CLEARED and flawless:
		var st: float = s * 0.24
		draw_texture_rect(UIKit.icon("star-filled"), Rect2(r.end - Vector2(st + 8, st + 8), Vector2(st, st)), false, Color(Style.PAPER_INK, 0.75))
	if in_progress and kind == Kind.OPEN:
		draw_circle(r.position + Vector2(s * 0.18, s * 0.18), s * 0.06, accent)
