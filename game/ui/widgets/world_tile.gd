class_name WorldTile
extends Button
## A world on the world map: its sky colours, name, progress, or what unlocks it.

var world: Dictionary
var clears: int = 0
var unlocked: bool = false
var lock_text: String = ""
var _t: float = 0.0


func _init(w: Dictionary, n_clears: int, is_unlocked: bool, locked_hint: String) -> void:
	world = w
	clears = n_clears
	unlocked = is_unlocked
	lock_text = locked_hint
	name = "World_" + str(w["id"])
	custom_minimum_size = Vector2(0, 230)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.juice(self)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var accent: Color = world["accent"]
	var top: Color = world["sky_top"]
	var bottom: Color = world["sky_bottom"]
	var bg: Color = top.lerp(bottom, 0.25)
	if not unlocked:
		bg = bg.lerp(Color("15122E"), 0.6)
	draw_style_box(UIKit.box(bg, 32, Color(accent, 0.55 if unlocked else 0.15), 2), r)
	# Lantern glow in the corner.
	if unlocked:
		var flicker: float = 0.85 + 0.15 * sin(_t * 2.0 + float(world["id"].length()))
		var g: float = size.y * 0.9
		draw_texture_rect(Style.glow_texture(), Rect2(Vector2(size.x - g * 0.75, -g * 0.3), Vector2(g, g)), false, Color(accent, 0.45 * flicker))
		draw_circle(Vector2(size.x - g * 0.25, g * 0.2), 14.0, Color(accent.lerp(Color.WHITE, 0.4), 0.95))
	if has_focus():
		draw_style_box(UIKit.box(Color.TRANSPARENT, 34, Color(Style.INK, 0.7), 3), r.grow(4))
	var f: Font = UIKit.font(600)
	var pad: float = 26.0
	var ink: Color = Style.INK if unlocked else Color(Style.INK, 0.45)
	var index: int = Catalog.world_index(world["id"]) + 1
	draw_string(UIKit.font(700), Vector2(pad, 46), "WORLD %d" % index, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.SIZE_CAPTION, Color(accent, 0.95 if unlocked else 0.4))
	draw_string(f, Vector2(pad, 98), str(world["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - pad * 2, 40, ink)
	var tag_font: Font = UIKit.font(400)
	var lines: PackedStringArray = _wrap(str(world["tagline"]) if unlocked else lock_text, tag_font, 20, size.x - pad * 2)
	for i: int in mini(lines.size(), 2):
		draw_string(tag_font, Vector2(pad, 134 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Style.MUTED, 0.9 if unlocked else 0.6))
	var by: float = size.y - 34
	if unlocked:
		var bw: float = size.x - pad * 2 - 80
		draw_style_box(UIKit.box(Color(1, 1, 1, 0.12), 5, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(pad, by - 5, bw, 10))
		if clears > 0:
			draw_style_box(UIKit.box(accent, 5, Color.TRANSPARENT, 0, Vector2.ZERO), Rect2(pad, by - 5, maxf(10.0, bw * clears / float(Catalog.LEVELS_PER_WORLD)), 10))
		draw_string(UIKit.font(700), Vector2(size.x - pad - 66, by + 8), "%d/%d" % [clears, Catalog.LEVELS_PER_WORLD], HORIZONTAL_ALIGNMENT_RIGHT, 66, 22, Style.INK)
	else:
		draw_texture_rect(UIKit.icon("lock"), Rect2(pad, by - 18, 32, 32), false, Color(Style.INK, 0.5))


static func _wrap(text: String, f: Font, fs: int, width: float) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in text.split(" "):
		var trial: String = word if line.is_empty() else line + " " + word
		if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		out.append(line)
	return out
