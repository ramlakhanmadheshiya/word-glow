class_name LanternArt
extends Control
## A paper lantern drawn in code: glowing, gently swaying. Used for the logo,
## the loading screen and the result card. `lit` fades the light in.

@export var color: Color = Style.AMBER
@export var lit: float = 1.0
@export var sway: float = 1.0
var letter: String = "W"

var _t: float = 0.0


func _init(art_size: float = 220.0) -> void:
	custom_minimum_size = Vector2(art_size * 0.8, art_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var top: Vector2 = Vector2(w / 2, 0)
	var angle: float = sin(_t * 1.1) * 0.05 * sway
	draw_set_transform(top, angle, Vector2.ONE)
	var body_h: float = h * 0.66
	var body_w: float = w * 0.82
	var cy: float = h * 0.52
	var flicker: float = 0.92 + 0.08 * sin(_t * 7.0) * sin(_t * 3.1)
	var glow: Texture2D = Style.glow_texture()
	var gr: float = body_h * 1.25
	draw_texture_rect(glow, Rect2(Vector2(-gr, cy - gr), Vector2(gr, gr) * 2), false, Color(color, 0.45 * lit * flicker))
	draw_line(Vector2(0, 0), Vector2(0, h * 0.12), Color(Style.INK, 0.6), 3.0, true)
	var cap: Color = Color("2A2350")
	draw_rect(Rect2(Vector2(-body_w * 0.26, h * 0.12), Vector2(body_w * 0.52, h * 0.06)), cap)
	draw_rect(Rect2(Vector2(-body_w * 0.26, h * 0.84), Vector2(body_w * 0.52, h * 0.06)), cap)
	# Body: an ellipse-ish barrel, darker paper when unlit.
	var dark: Color = Color("6B4A3A")
	var paper: Color = dark.lerp(color, lit)
	var core: Color = dark.lerp(color.lerp(Color.WHITE, 0.45), lit * flicker)
	var pts: PackedVector2Array = PackedVector2Array()
	var cols: PackedColorArray = PackedColorArray()
	var n: int = 40
	for i: int in n:
		var a: float = TAU * i / n
		var x: float = cos(a) * body_w / 2
		pts.append(Vector2(x, cy + sin(a) * body_h / 2))
		cols.append(core.lerp(paper, absf(x) / (body_w / 2)))
	draw_polygon(pts, cols)
	# Ribs.
	for k: int in [-2, -1, 1, 2]:
		var rib: PackedVector2Array = PackedVector2Array()
		for i: int in 21:
			var a: float = -PI / 2 + PI * i / 20.0
			rib.append(Vector2(sin(PI * k / 6.0) * cos(a) * body_w / 2, cy + sin(a) * body_h / 2))
		draw_polyline(rib, Color(paper.darkened(0.25), 0.55), 2.0, true)
	if not letter.is_empty():
		var f: Font = UIKit.font(700)
		var fs: int = int(body_h * 0.42)
		var sz: Vector2 = f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(-sz.x / 2, cy + (f.get_ascent(fs) - f.get_descent(fs)) / 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Style.PAPER_INK, 0.85))
	draw_line(Vector2(0, h * 0.9), Vector2(0, h * 0.97), Color(Style.INK, 0.5), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
