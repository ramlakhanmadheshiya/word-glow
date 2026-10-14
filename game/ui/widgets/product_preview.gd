class_name ProductPreview
extends Control
## A small live picture of what a shop item gives: themes as sky swatches,
## lantern styles as lit tiles, coins as a stack, keys, the Supporter lantern,
## the tip jar, and the Complete pack as a little of everything.

var product: String = ""
var _t: float = 0.0


func _init(id: String = "", px: float = 96.0) -> void:
	product = id
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) / 2.0
	var box: Rect2 = Rect2(o, Vector2(s, s))
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.28), int(s * 0.26)), box)
	var c: Vector2 = box.get_center()
	if product.begins_with("coins") or product == "free_coins":
		_coins(c, s, 3 if product == "coins_300" or product == "free_coins" else (4 if product == "coins_1000" else (5 if product == "coins_2500" else 6)))
	elif product == "keys":
		_icon("key-round", c, s * 0.5, Style.AMBER)
	elif product == "tips":
		_icon("coffee", c, s * 0.5, Color("FF9E7A"))
	elif product == "theme_pack":
		var ids: Array = ["sunset", "ocean", "sakura", "royal"]
		for i: int in 4:
			var th: Dictionary = Look.THEMES[ids[i]]
			var r: Rect2 = Rect2(o + Vector2(s * (0.16 + 0.36 * (i % 2)), s * (0.16 + 0.36 * (i / 2))), Vector2(s * 0.32, s * 0.32))
			draw_style_box(UIKit.box(Color(th["top"]), int(s * 0.08), Color(th["accent"]), 2), r)
	elif product == "style_pack":
		var ids: Array = ["neon", "candy", "jewel", "ember"]
		for i: int in 4:
			var col: Color = Look.lantern(int(_t * 1.5) + i, ids[i])
			var r: Rect2 = Rect2(o + Vector2(s * (0.16 + 0.36 * (i % 2)), s * (0.16 + 0.36 * (i / 2))), Vector2(s * 0.32, s * 0.32))
			draw_texture_rect(Style.glow_texture(), r.grow(s * 0.08), false, Color(col, 0.4))
			draw_style_box(UIKit.box(col, int(s * 0.32 * float(Look.STYLES[ids[i]]["radius"]))), r)
	elif product == "supporter_pack":
		_lantern(c, s, Style.AMBER)
		_icon("heart", c + Vector2(s * 0.24, s * 0.24), s * 0.26, Color("FF6B81"))
	else:
		_lantern(c + Vector2(-s * 0.12, 0), s * 0.9, Color("FF9F43"))
		_coins(c + Vector2(s * 0.2, s * 0.18), s * 0.55, 3)
		_icon("star-filled", c + Vector2(s * 0.24, -s * 0.24), s * 0.24, Style.GOLD)


func _icon(name: String, c: Vector2, px: float, col: Color) -> void:
	draw_texture_rect(Style.glow_texture(), Rect2(c - Vector2(px, px), Vector2(px, px) * 2.0), false, Color(col, 0.25))
	draw_texture_rect(UIKit.icon(name), Rect2(c - Vector2(px, px) / 2.0, Vector2(px, px)), false, col)


func _coins(c: Vector2, s: float, n: int) -> void:
	for i: int in n:
		var p: Vector2 = c + Vector2((float(i % 2) - 0.5) * s * 0.18, s * 0.22 - float(i) * s * 0.09)
		draw_circle(p + Vector2(0, 3), s * 0.17, Color("B8860B"), true, -1.0, true)
		draw_circle(p, s * 0.17, Style.GOLD, true, -1.0, true)
		draw_circle(p, s * 0.11, Color("FFE89A"), false, 2.0, true)


func _lantern(c: Vector2, s: float, col: Color) -> void:
	var flicker: float = 0.85 + 0.15 * sin(_t * 4.0)
	draw_texture_rect(Style.glow_texture(), Rect2(c - Vector2(s, s) * 0.45, Vector2(s, s) * 0.9), false, Color(col, 0.45 * flicker))
	draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.3), Vector2(s * 0.2, s * 0.06)), Color("2A2350"))
	draw_rect(Rect2(c + Vector2(-s * 0.1, s * 0.24), Vector2(s * 0.2, s * 0.06)), Color("2A2350"))
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 28:
		var a: float = TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * s * 0.2, sin(a) * s * 0.26))
	draw_colored_polygon(pts, col)
	# Paper ribs and a soft highlight.
	for k: int in [-1, 1]:
		var rib: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var a: float = -PI / 2 + PI * i / 12.0
			rib.append(c + Vector2(k * 0.5 * cos(a) * s * 0.2, sin(a) * s * 0.26))
		draw_polyline(rib, Color(col.darkened(0.3), 0.6), 2.0, true)
	draw_circle(c + Vector2(-s * 0.06, -s * 0.08), s * 0.07, Color(1, 1, 1, 0.25), true, -1.0, true)
