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
		var n: int = {"coins_300": 0, "coins_1000": 1, "coins_2500": 2, "coins_6000": 3}.get(product, 0)
		_art("coin_stack", c + Vector2(0, s * 0.02), s * (0.62 + 0.06 * n))
		if n >= 2:
			_art("coin", c + Vector2(s * 0.24, s * 0.2), s * 0.3)
		if n >= 3:
			_art("coin", c + Vector2(-s * 0.26, s * 0.22), s * 0.26)
	elif product == "coins":
		_art("coin_stack", c, s * 0.66)
	elif product == "keys":
		_art("key", c, s * 0.66)
	elif product == "tips":
		_art("heart", c, s * 0.6)
	elif product == "theme_pack":
		_art("theme", c, s * 0.7)
	elif product == "style_pack":
		var ids: Array = ["neon", "candy", "jewel", "ember"]
		for i: int in 4:
			var col: Color = Look.lantern(int(_t * 1.5) + i, ids[i])
			var r: Rect2 = Rect2(o + Vector2(s * (0.16 + 0.36 * (i % 2)), s * (0.16 + 0.36 * (i / 2))), Vector2(s * 0.32, s * 0.32))
			draw_texture_rect(Style.glow_texture(), r.grow(s * 0.08), false, Color(col, 0.4))
			draw_style_box(UIKit.box(col, int(s * 0.32 * float(Look.STYLES[ids[i]]["radius"]))), r)
	elif product == "supporter_pack":
		_art("lantern", c + Vector2(-s * 0.06, -s * 0.02), s * 0.7)
		_art("heart", c + Vector2(s * 0.24, s * 0.24), s * 0.32)
	else:
		_art("lantern", c + Vector2(-s * 0.12, -s * 0.04), s * 0.66)
		_art("coin_stack", c + Vector2(s * 0.2, s * 0.2), s * 0.4)
		_art("star", c + Vector2(s * 0.24, -s * 0.24), s * 0.3)


func _art(name: String, c: Vector2, px: float) -> void:
	draw_texture_rect(UIKit.art(name), Rect2(c - Vector2(px, px) / 2.0, Vector2(px, px)), false)
