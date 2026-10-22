class_name PickerCard
extends Overlay
## Pick a colour theme or a lantern style. Locked ones open their pack's card
## (buy, or try it free for an hour with a video).

## "themes" or "styles".
var mode: String = "themes"
var _clock: Label
var _product: String = ""


func _process(_delta: float) -> void:
	if _clock != null:
		var c: String = Profile.trial_clock(_product)
		_clock.text = "On trial · %s left" % c if not c.is_empty() else "Trial over"


func build() -> void:
	name = "Picker"
	add_title("Colours" if mode == "themes" else "Glow styles")
	_product = "theme_pack" if mode == "themes" else "style_pack"
	var owned: bool = Profile.owns(_product)
	var current: String = Look.theme_id() if mode == "themes" else Look.style_id()
	if Profile.trial_left(_product) > 0 and not Profile.bought(_product):
		_clock = UIKit.label("", Style.SIZE_SMALL, Style.AMBER, 600)
		_clock.name = "TrialClock"
		body.add_child(_clock)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	var ids: Array = Look.theme_ids() if mode == "themes" else Look.style_ids()
	for id: String in ids:
		var free: bool = id == "chapters" or id == "classic"
		var locked: bool = not free and not owned
		var tile: Button = _tile(id, id == current, locked)
		tile.pressed.connect(func() -> void:
			if locked:
				var o: ProductCard = ProductCard.new()
				o.product = _product
				open_child(o)
				return
			Profile.set_setting("theme" if mode == "themes" else "style", id)
			Audio.play("click", 1.2, -4.0)
			app.repaint_and_reopen(mode)
		)
		grid.add_child(tile)
	if not Profile.bought(_product):
		var get_btn: Button = UIKit.button("Get the %s" % Store.display_name(_product), "ghost", Style.AMBER, 80, 24)
		get_btn.name = "GetPack"
		get_btn.pressed.connect(func() -> void:
			var o: ProductCard = ProductCard.new()
			o.product = _product
			open_child(o)
		)
		body.add_child(get_btn)


func _tile(id: String, selected: bool, locked: bool) -> Button:
	var b: Button = Button.new()
	b.name = "Pick_" + id
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = UIKit.box(Color(Style.INK, 0.06), 28, Style.GOLD if selected else Color(Style.INK, 0.06), 4 if selected else 2)
	for st: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	UIKit.juice(b)
	var sw: Swatch = Swatch.new()
	sw.mode = mode
	sw.id = id
	sw.dim = locked
	sw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sw.offset_top = 12
	sw.offset_bottom = -46
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sw)
	var n: Label = UIKit.label(Look.theme_name(id) if mode == "themes" else Look.style_name(id), 22, Color(Style.INK, 0.5 if locked else 1.0), 600)
	n.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	n.offset_top = -46
	n.offset_bottom = -10
	b.add_child(n)
	if locked:
		var lock: TextureRect = UIKit.icon_rect("lock", 22, Color(Style.INK, 0.5))
		lock.position = Vector2(14, 12)
		b.add_child(lock)
	return b


## A theme's sky with a tile, or a style's lit tiles.
class Swatch:
	extends Control
	var mode: String
	var id: String
	var dim: bool

	func _draw() -> void:
		var a: float = 0.45 if dim else 1.0
		var c: Vector2 = size / 2.0
		var t: float = minf(size.y * 0.62, 56.0)
		if mode == "themes":
			var top: Color = Color("2E2A6B") if id == "chapters" else Color(Look.THEMES[id]["top"])
			var bottom: Color = Color("141235") if id == "chapters" else Color(Look.THEMES[id]["bottom"])
			var acc: Color = Color("FFB547") if id == "chapters" else Color(Look.THEMES[id]["accent"])
			var tile: Color = Look.DEFAULT_TILE if id == "chapters" else Color(Look.THEMES[id]["tile"])
			var r: Rect2 = Rect2(c - Vector2(size.x * 0.38, size.y * 0.5), Vector2(size.x * 0.76, size.y))
			draw_style_box(UIKit.box(Color(top.lerp(bottom, 0.4), a), 18, Color(acc, a), 2), r)
			draw_style_box(UIKit.box(Color(tile, a), 10), Rect2(c - Vector2(t * 0.9, t * 0.4), Vector2(t * 0.8, t * 0.8)))
			draw_style_box(UIKit.box(Color(acc, a), 10), Rect2(c + Vector2(t * 0.1, -t * 0.4), Vector2(t * 0.8, t * 0.8)))
		else:
			var rad: float = float(Look.STYLES[id]["radius"])
			for k: int in 3:
				var col: Color = Look.lantern(k, id)
				var r: Rect2 = Rect2(c + Vector2((float(k) - 1.5) * t * 0.95, -t * 0.42), Vector2(t * 0.85, t * 0.85))
				draw_texture_rect(Style.glow_texture(), r.grow(t * 0.25), false, Color(col, 0.3 * a * float(Look.STYLES[id]["glow"])))
				draw_style_box(UIKit.box(Color(col, a), int(t * 0.85 * rad)), r)
