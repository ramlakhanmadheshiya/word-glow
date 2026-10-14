class_name MovesHud
extends Control
## MOVES and STARS side by side over the board, like Single Shot's TRY / STARS.
## A perfect solve takes one move per word; every wrong word or hint is an extra
## move, and the stars still on offer drop (with a little pulse) as they add up.

var moves: int = 0
var par: int = 1
var stars: int = 3
var accent: Color = Style.AMBER
var _bump: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(m: int, p: int, s: int) -> void:
	if s < stars and is_inside_tree():
		_bump = 1.0
		Audio.play("error", 0.7, -10.0)
	moves = m
	par = p
	stars = s
	queue_redraw()


func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 2.5)
		queue_redraw()


func _draw() -> void:
	var cap_font: FontVariation = (UIKit.font(600) as FontVariation).duplicate()
	cap_font.spacing_glyph = 3
	var mid: float = size.x * 0.5
	var cols: Array[float] = [mid - 120.0, mid + 120.0]
	for i: int in 2:
		var cap: String = "MOVES" if i == 0 else "STARS"
		var w: float = cap_font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(cap_font, Vector2(cols[i] - w * 0.5, 22), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Style.MUTED)
	var nf: Font = UIKit.font(500)
	var num: String = "%d" % moves
	var tail: String = " / %d" % par
	var nw: float = nf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var tw: float = nf.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var x: float = cols[0] - (nw + tw) * 0.5
	draw_string(nf, Vector2(x, 70), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Style.INK if moves <= par else Style.AMBER)
	draw_string(nf, Vector2(x + nw, 70), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Style.MUTED)
	for k: int in 3:
		var s: float = 32.0 * (1.0 + (0.35 * _bump if k == stars else 0.0))
		var c: Vector2 = Vector2(cols[1] + (float(k) - 1.0) * 40.0, 55)
		var r: Rect2 = Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
		if k < stars:
			draw_texture_rect(UIKit.icon("star-filled"), r, false, Style.GOLD)
		else:
			draw_texture_rect(UIKit.icon("star"), r, false, Color(Style.INK, 0.22 + 0.5 * (_bump if k == stars else 0.0)))
