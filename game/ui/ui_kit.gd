class_name UIKit
extends RefCounted
## Builders for the game's controls, all styled from Style. Every button gets
## the same press feedback: a quick squash, a soft click and a haptic tick.

const FONT_PATH: String = "res://assets/fonts/Outfit-Variable.ttf"
const ICON_DIR: String = "res://assets/icons/"

static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}


## Drops cached fonts and textures (called on exit so nothing is reported as leaked).
static func clear_caches() -> void:
	_fonts.clear()
	_icons.clear()
	_switches.clear()
	_knobs.clear()


## Small Noto subsets (SIL OFL) for glyphs Outfit lacks: ★ ♥, currency signs such
## as ₹ in Google Play prices, and ৳. Without them the web build shows boxes.
const FALLBACK_FONTS: Array[String] = [
	"res://assets/fonts/NotoSans-Currency.ttf",
	"res://assets/fonts/NotoSansSymbols2-Subset.ttf",
	"res://assets/fonts/NotoSansBengali-Taka.ttf",
]


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv: FontVariation = FontVariation.new()
		var base: FontFile = load(FONT_PATH) as FontFile
		if base.fallbacks.is_empty():
			var chain: Array[Font] = []
			for path: String in FALLBACK_FONTS:
				chain.append(load(path) as Font)
			base.fallbacks = chain
		fv.base_font = base
		var ts: TextServer = TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path: String = ICON_DIR + name + ".svg"
		_icons[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[name]


static func label(text: String, size: int = Style.SIZE_BODY, color: Color = Style.INK, weight: int = 400, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Wrapping paragraph text.
static func para(text: String, size: int = Style.SIZE_SMALL, color: Color = Style.MUTED, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l: Label = label(text, size, color, 400, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 10
	return l


## Small spaced capitals, e.g. "WORLD 2".
static func caption(text: String, color: Color = Style.MUTED, size: int = Style.SIZE_CAPTION, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l: Label = label(text.to_upper(), size, color, 600, align)
	var fv: FontVariation = (font(600) as FontVariation).duplicate()
	fv.spacing_glyph = 3
	l.add_theme_font_override("font", fv)
	return l


static func box(fill: Color, radius: int = Style.RADIUS, border: Color = Color.TRANSPARENT, border_w: int = 0, pad: Vector2 = Vector2(28, 12)) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s


static func card_style(radius: int = 40, pad: int = 36) -> StyleBoxFlat:
	var s: StyleBoxFlat = box(Style.CARD, radius, Style.CARD_EDGE, 2, Vector2(pad, pad))
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 28
	s.shadow_offset = Vector2(0, 10)
	return s


static func icon_rect(name: String, size: float, color: Color = Style.INK) -> TextureRect:
	var ic: TextureRect = TextureRect.new()
	ic.texture = icon(name)
	ic.custom_minimum_size = Vector2(size, size)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.modulate = color
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


## Rounded pill button. style: "primary" (accent fill), "soft" (translucent), "ghost" (outline), "danger".
static func button(text: String, style: String = "primary", accent: Color = Style.AMBER, height: int = 92, font_size: int = 30, icon_name: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font(600))
	b.add_theme_font_size_override("font_size", font_size)
	var fill: Color
	var text_c: Color
	var border: Color = Color.TRANSPARENT
	var bw: int = 0
	match style:
		"primary":
			fill = accent
			text_c = Style.PAPER_INK
		"danger":
			fill = Style.ERROR
			text_c = Color.WHITE
		"soft":
			fill = Style.FIELD
			text_c = Style.INK
		_:
			fill = Color(0, 0, 0, 0)
			text_c = Style.INK
			border = Color(1, 1, 1, 0.22)
			bw = 3
	var r: int = height / 2
	b.add_theme_stylebox_override("normal", box(fill, r, border, bw))
	b.add_theme_stylebox_override("hover", box(fill.lightened(0.08) if style in ["primary", "danger"] else Color(1, 1, 1, fill.a + 0.05), r, border, bw))
	b.add_theme_stylebox_override("pressed", box(fill.darkened(0.1) if style in ["primary", "danger"] else Color(1, 1, 1, fill.a + 0.1), r, border, bw))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.06), r))
	var focus: StyleBoxFlat = box(Color.TRANSPARENT, r, Color(Style.INK, 0.7), 3)
	focus.set_expand_margin_all(5)
	b.add_theme_stylebox_override("focus", focus)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, text_c)
	b.add_theme_color_override("font_disabled_color", Color(Style.INK, 0.35))
	if not icon_name.is_empty():
		b.icon = icon(icon_name)
		b.add_theme_constant_override("icon_max_width", int(font_size * 1.1))
		b.add_theme_constant_override("h_separation", 12)
		for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(key, text_c)
	juice(b)
	return b


## Round icon-only button (44pt+ touch target).
static func icon_button(icon_name: String, size: float = 84.0, fill: Color = Style.FIELD, tint: Color = Style.INK) -> Button:
	var b: Button = Button.new()
	b.icon = icon(icon_name)
	b.custom_minimum_size = Vector2(size, size)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_ALL
	var r: int = int(size / 2)
	var pad: Vector2 = Vector2(size * 0.27, size * 0.27)
	b.add_theme_stylebox_override("normal", box(fill, r, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("hover", box(Color(fill, fill.a + 0.06), r, Color.TRANSPARENT, 0, pad))
	b.add_theme_stylebox_override("pressed", box(Color(fill, fill.a + 0.12), r, Color.TRANSPARENT, 0, pad))
	var focus: StyleBoxFlat = box(Color.TRANSPARENT, r, Color(Style.INK, 0.7), 3, pad)
	focus.set_expand_margin_all(4)
	b.add_theme_stylebox_override("focus", focus)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(key, tint)
	juice(b)
	return b


## Press feedback shared by every button.
static func juice(b: BaseButton) -> void:
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2
		b.create_tween().tween_property(b, "scale", Vector2(0.95, 0.95), 0.06)
		Haptics.tick()
	)
	b.button_up.connect(func() -> void:
		b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(b, "scale", Vector2.ONE, 0.18)
	)
	b.pressed.connect(func() -> void: Audio.play("click", 1.0, -6.0))


## A vertical gap.
static func gap(h: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hbox(sep: int = 12, align: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.alignment = align
	return h


static func vbox(sep: int = 12) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


## A rounded translucent panel holding one child.
static func panel(child: Control, fill: Color = Style.FIELD, radius: int = 30, pad: Vector2 = Vector2(28, 22)) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(fill, radius, Color.TRANSPARENT, 0, pad))
	p.add_child(child)
	return p


## A thin rounded progress bar.
static func progress_bar(ratio: float, color: Color, height: int = 10) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", box(Color(1, 1, 1, 0.1), height / 2, Color.TRANSPARENT, 0, Vector2.ZERO))
	bar.add_theme_stylebox_override("fill", box(color, height / 2, Color.TRANSPARENT, 0, Vector2.ZERO))
	return bar


## An on/off switch row: label on the left, toggle on the right.
static func toggle_row(text: String, icon_name: String, value: bool, on_change: Callable) -> HBoxContainer:
	var row: HBoxContainer = hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	row.add_child(icon_rect(icon_name, 40, Style.MUTED))
	var l: Label = label(text, Style.SIZE_BODY, Style.INK, 500, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var c: CheckButton = CheckButton.new()
	c.name = text.replace(" ", "")
	c.button_pressed = value
	c.custom_minimum_size = Vector2(96, 72)
	c.focus_mode = Control.FOCUS_ALL
	c.add_theme_icon_override("checked", _switch_icon(true))
	c.add_theme_icon_override("unchecked", _switch_icon(false))
	c.add_theme_icon_override("checked_mirrored", _switch_icon(true))
	c.add_theme_icon_override("unchecked_mirrored", _switch_icon(false))
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		c.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	c.toggled.connect(func(on: bool) -> void:
		Audio.play("click", 1.1 if on else 0.9, -4.0)
		Haptics.tick()
		on_change.call(on)
	)
	row.add_child(c)
	return row


## A labelled 0..1 volume slider (Music, Sound). Plays a tick while dragging
## so you hear the level.
static func slider_row(text: String, icon_name: String, value: float, on_change: Callable, accent: Color = Style.AMBER) -> HBoxContainer:
	var row: HBoxContainer = hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	row.custom_minimum_size = Vector2(0, 76)
	row.add_child(icon_rect(icon_name, 40, Style.MUTED))
	var l: Label = label(text, Style.SIZE_BODY, Style.INK, 500, HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var s: HSlider = HSlider.new()
	s.name = text.replace(" ", "") + "Slider"
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 48)
	s.focus_mode = Control.FOCUS_ALL
	var track: StyleBoxFlat = box(Color(1, 1, 1, 0.14), 6, Color.TRANSPARENT, 0, Vector2(0, 6))
	var fill: StyleBoxFlat = box(accent, 6, Color.TRANSPARENT, 0, Vector2(0, 6))
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _knob(false, accent))
	s.add_theme_icon_override("grabber_highlight", _knob(true, accent))
	s.add_theme_icon_override("grabber_disabled", _knob(false, accent))
	var pct: Label = label("%d%%" % int(round(value * 100)), Style.SIZE_SMALL, Style.MUTED, 600, HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v * 100))
		on_change.call(v)
		Audio.play("tap", 1.0 + v * 0.5, -8.0)
	)
	row.add_child(s)
	row.add_child(pct)
	return row


static var _knobs: Dictionary = {}


static func _knob(focused: bool, accent: Color) -> Texture2D:
	var key: String = "%s%s" % [focused, accent.to_html()]
	if _knobs.has(key):
		return _knobs[key]
	var d: int = 44
	var img: Image = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(d, d) * 0.5
	for y: int in d:
		for x: int in d:
			var dist: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			var ring: float = clampf(d * 0.5 - dist + 0.5, 0.0, 1.0)
			var inner: float = clampf(d * 0.5 - 5.0 - dist + 0.5, 0.0, 1.0)
			var edge: Color = accent if focused else Color(accent, 0.75)
			img.set_pixel(x, y, Color(edge, edge.a * ring).blend(Color(1, 1, 1, inner)))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_knobs[key] = tex
	return tex


static var _switches: Dictionary = {}


## A pill switch drawn into an image (no extra asset files).
static func _switch_icon(on: bool) -> Texture2D:
	if _switches.has(on):
		return _switches[on]
	var w: int = 84
	var h: int = 48
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track: Color = Style.AMBER if on else Color(1, 1, 1, 0.18)
	var knob: Color = Color.WHITE
	var r: float = h / 2.0
	var kx: float = w - r if on else r
	for y: int in h:
		for x: int in w:
			var px: Vector2 = Vector2(x + 0.5, y + 0.5)
			var cx: float = clampf(px.x, r, w - r)
			var d: float = px.distance_to(Vector2(cx, r))
			var a: float = clampf(r - d, 0.0, 1.0)
			var col: Color = Color(track, track.a * a)
			var dk: float = px.distance_to(Vector2(kx, r))
			var ka: float = clampf(r - 5.0 - dk, 0.0, 1.0)
			col = col.blend(Color(knob, ka))
			img.set_pixel(x, y, col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_switches[on] = tex
	return tex


## Coin balance pill; tapping it opens the shop.
static func coin_chip() -> CounterChip:
	var c: CounterChip = CounterChip.new("coins")
	c.pressed.connect(func() -> void: App.instance.go("shop"))
	return c


## Level-key balance pill; tapping it opens the key shop.
static func key_chip() -> CounterChip:
	var c: CounterChip = CounterChip.new("keys")
	c.pressed.connect(func() -> void: App.instance.open(KeysCard.new()))
	return c
