class_name ChapterCard
extends Button
## A chapter on the chapter list, painted in its own colours: number, name,
## tagline, stars and progress, or what opens it when locked.

var chapter: Dictionary
var index: int = 0
var clears: int = 0
var stars: int = 0
var unlocked: bool = false
var lock_text: String = ""


func _init() -> void:
	custom_minimum_size = Vector2(0, 186)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for st: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.juice(self)


var _art: LanternArt


func _ready() -> void:
	# A lantern on the right, lit by how much of the chapter is done.
	_art = LanternArt.new(130)
	_art.color = Look.accent(chapter)
	_art.letter = str(index + 1)
	_art.lit = (0.3 + 0.7 * float(clears) / float(Catalog.levels_per_chapter)) if unlocked else 0.0
	_art.sway = 1.0 if unlocked else 0.0
	_art.modulate.a = 1.0 if unlocked else 0.45
	_art.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_art.position = Vector2(-150, -65)
	_art.size = Vector2(104, 130)
	add_child(_art)
	resized.connect(func() -> void: _art.position = Vector2(size.x - 124, (size.y - 130) / 2.0))


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var accent: Color = Look.accent(chapter)
	var sky: Array[Color] = Look.sky(chapter)
	var bg: Color = sky[0].lerp(sky[1], 0.3)
	if not unlocked:
		bg = bg.lerp(Style.LIP, 0.6)
	draw_style_box(UIKit.box(bg, 34, Color(accent, 0.55 if unlocked else 0.15), 2), r)
	if has_focus():
		draw_style_box(UIKit.box(Color.TRANSPARENT, 36, Color(Style.INK, 0.8), 3), r.grow(4))
	var pad: float = 28.0
	var ink: Color = Style.INK if unlocked else Color(Style.INK, 0.45)
	var cap: FontVariation = (UIKit.font(700) as FontVariation).duplicate()
	cap.spacing_glyph = 3
	draw_string(cap, Vector2(pad, 44), "CHAPTER %d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(accent, 0.95 if unlocked else 0.45))
	draw_string(UIKit.font(600), Vector2(pad, 92), str(chapter["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 200, 40, ink)
	var tag: String = str(chapter["tagline"]) if unlocked else lock_text
	draw_string(UIKit.font(400), Vector2(pad, 126), tag, HORIZONTAL_ALIGNMENT_LEFT, size.x - 200, 21, Color(Style.MUTED, 0.9 if unlocked else 0.65))
	var by: float = size.y - 34.0
	if unlocked:
		var bw: float = size.x - pad - 290.0
		draw_style_box(UIKit.box(Color(Style.INK, 0.12), 5, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(pad, by - 5, bw, 10))
		if clears > 0:
			draw_style_box(UIKit.box(accent, 5, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(pad, by - 5, maxf(10.0, bw * clears / float(Catalog.levels_per_chapter)), 10))
		var f: Font = UIKit.font(700)
		draw_string(f, Vector2(pad + bw + 16, by + 8), "%d/%d" % [clears, Catalog.levels_per_chapter], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Style.INK)
		draw_texture_rect(UIKit.art("star"), Rect2(pad + bw + 84, by - 13, 26, 26), false)
		draw_string(f, Vector2(pad + bw + 112, by + 8), str(stars), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Style.GOLD)
	else:
		draw_texture_rect(UIKit.art("lock"), Rect2(pad, by - 17, 32, 32), false, Color(Style.INK, 0.75))
		draw_string(UIKit.font(600), Vector2(pad + 42, by + 7), "%d levels" % Catalog.levels_per_chapter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Style.INK, 0.45))
