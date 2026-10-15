class_name LevelTile
extends Button
## One level on the level grid. Every number is shown, so the whole chapter is
## visible at a glance: cleared levels are lit with their stars under the number,
## the next level glows, levels opened by a key carry a key badge, and locked
## ones are dimmed with a small lock badge.

var number: int = 1
var stars: int = 0
var open: bool = false
var current: bool = false
var keyed: bool = false
var in_progress: bool = false
var accent: Color = Style.AMBER
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(108, 118)
	focus_mode = Control.FOCUS_ALL
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.juice(self)


func _process(delta: float) -> void:
	_t += delta
	if current or has_focus():
		queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y - 10.0)
	var box: Rect2 = Rect2(Vector2((size.x - s) / 2.0, 4), Vector2(s, s) - Vector2(8, 8))
	var r: int = int(s * 0.24)
	var f: Font = UIKit.font(700)
	var fs: int = int(s * 0.32)
	if has_focus():
		draw_style_box(UIKit.box(Color.TRANSPARENT, r + 4, Color(Style.INK, 0.8), 3), box.grow(5))
	if not open:
		draw_style_box(UIKit.box(Color(Style.INK, 0.05), r, Color(Style.INK, 0.08), 2), box)
		_text(f, str(number), box.get_center() + Vector2(0, -3), fs, Color(Style.INK, 0.32))
		var c: Vector2 = box.end - Vector2(16, 16)
		draw_circle(c, 14.0, Style.LIP, true, -1.0, true)
		draw_texture_rect(UIKit.art("lock"), Rect2(c - Vector2(11, 11), Vector2(22, 22)), false, Color(Style.INK, 0.8))
		return
	if stars > 0:
		draw_texture_rect(Style.glow_texture(), box.grow(s * 0.15), false, Color(accent, 0.18))
		draw_style_box(UIKit.box(accent.darkened(0.25), r), Rect2(box.position + Vector2(0, 4), box.size))
		draw_style_box(UIKit.box(accent, r), box)
		_text(f, str(number), box.get_center() + Vector2(0, -s * 0.1), fs, Style.PAPER_INK)
		for k: int in 3:
			var p: Vector2 = box.get_center() + Vector2((float(k) - 1.0) * s * 0.17, s * 0.22)
			var ss: float = s * 0.15
			var col: Color = Color.WHITE if k < stars else Color(Style.PAPER_INK, 0.3)
			draw_texture_rect(UIKit.art("star"), Rect2(p - Vector2(ss, ss) * 0.5, Vector2(ss, ss) * 1.15), false, col)
	else:
		draw_style_box(UIKit.box(Color(accent, 0.16) if current else Color(Style.INK, 0.05), r, accent if current else Color(Style.INK, 0.4), 3), box)
		_text(f, str(number), box.get_center() + Vector2(0, -3), fs, Style.INK)
	if current:
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
		draw_style_box(UIKit.box(Color.TRANSPARENT, r + 4, Color(accent, 0.7 - 0.5 * pulse), 3), box.grow(4.0 + 4.0 * pulse))
	if in_progress and stars == 0:
		draw_circle(box.position + Vector2(16, 16), 6.0, accent, true, -1.0, true)
	if keyed and stars == 0:
		var kc: Vector2 = box.end - Vector2(16, 16)
		draw_circle(kc, 14.0, accent, true, -1.0, true)
		draw_texture_rect(UIKit.art("key"), Rect2(kc - Vector2(12, 12), Vector2(24, 24)), false)


func _text(f: Font, s: String, centre: Vector2, fs: int, col: Color) -> void:
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(centre.x - w * 0.5, centre.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
