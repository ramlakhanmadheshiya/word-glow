class_name Backdrop
extends Control
## The night sky behind every screen: a vertical gradient that eases between
## world colours, twinkling stars and a few paper lanterns drifting upward.

const STAR_COUNT: int = 70
const LANTERN_COUNT: int = 9

var top: Color = Style.DEFAULT_SKY_TOP
var bottom: Color = Style.DEFAULT_SKY_BOTTOM
var _stars: Array[Vector4] = []    # x, y (0..1), radius, phase
var _lanterns: Array[Dictionary] = []
var _t: float = 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Offsets too: anchors alone keep the empty rect it was added with.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in STAR_COUNT:
		_stars.append(Vector4(rng.randf(), rng.randf() * 0.8, rng.randf_range(1.0, 2.6), rng.randf() * TAU))
	for i: int in LANTERN_COUNT:
		_lanterns.append({
			"x": rng.randf(), "y": rng.randf(), "speed": rng.randf_range(0.006, 0.016),
			"size": rng.randf_range(10.0, 22.0), "phase": rng.randf() * TAU,
			"color": Look.lantern(rng.randi_range(0, 9), "classic").lerp(Style.AMBER, 0.55),
		})


## Eases the sky to a world's colours.
func set_sky(new_top: Color, new_bottom: Color, seconds: float = 0.8) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "top", new_top, seconds)
	_tween.tween_property(self, "bottom", new_bottom, seconds)


func _process(delta: float) -> void:
	_t += delta
	for l: Dictionary in _lanterns:
		l["y"] = float(l["y"]) - float(l["speed"]) * delta
		if float(l["y"]) < -0.08:
			l["y"] = 1.08
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var glow: Texture2D = Style.glow_texture()
	var moon: Vector2 = Vector2(s.x * 0.84, s.y * 0.1)
	var mr: float = minf(s.x, s.y) * 0.055
	if Style.DARK:
		for st: Vector4 in _stars:
			var a: float = 0.25 + 0.45 * (0.5 + 0.5 * sin(_t * 1.3 + st.w))
			draw_circle(Vector2(st.x * s.x, st.y * s.y * 0.7), st.z, Color("FFF4E3", a))
		# A crescent moon.
		draw_texture_rect(glow, Rect2(moon - Vector2(mr, mr) * 5.0, Vector2(mr, mr) * 10.0), false, Color("FFF1C9", 0.16))
		draw_circle(moon, mr, Color("FFF4DA", 0.92), true, -1.0, true)
		draw_circle(moon + Vector2(mr * 0.35, -mr * 0.2), mr * 0.82, top.lerp(Color("FFF4DA"), 0.1), true, -1.0, true)
	else:
		# Light themes get a soft sun instead of stars.
		draw_texture_rect(glow, Rect2(moon - Vector2(mr, mr) * 6.0, Vector2(mr, mr) * 12.0), false, Color("FFE7A3", 0.55))
		draw_circle(moon, mr * 1.1, Color("FFE7A3"), true, -1.0, true)
	# Far hills, then the lanterns rising from behind the near hills.
	_hills(s, s.y * 0.8, s.y * 0.05, 1.7, 0.3, bottom.lerp(top, 0.35).darkened(0.25 if Style.DARK else 0.08))
	for l: Dictionary in _lanterns:
		var p: Vector2 = Vector2((float(l["x"]) + 0.02 * sin(_t * 0.6 + float(l["phase"]))) * s.x, float(l["y"]) * s.y)
		var r: float = l["size"]
		var c: Color = l["color"]
		var flicker: float = 0.85 + 0.15 * sin(_t * 3.0 + float(l["phase"]))
		draw_texture_rect(glow, Rect2(p - Vector2(r, r) * 3.0, Vector2(r, r) * 6.0), false, Color(c, 0.22 * flicker))
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 16:
			var ang: float = TAU * i / 16.0
			pts.append(p + Vector2(cos(ang) * r * 0.55, sin(ang) * r * 0.7))
		draw_colored_polygon(pts, Color(c, 0.8 * flicker))
		draw_rect(Rect2(p - Vector2(r * 0.3, r * 0.82), Vector2(r * 0.6, r * 0.16)), Color(0.1, 0.07, 0.2, 0.7))
	_hills(s, s.y * 0.88, s.y * 0.04, 2.6, 1.9, bottom.darkened(0.45 if Style.DARK else 0.15))


## A soft ridge of hills across the bottom of the screen.
func _hills(s: Vector2, base_y: float, amp: float, freq: float, phase: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([Vector2(0, s.y)])
	var n: int = 32
	for i: int in n + 1:
		var x: float = s.x * i / n
		var y: float = base_y - amp * (sin(i * freq / n * TAU * 0.5 + phase) * 0.6 + sin(i * freq * 2.3 / n * TAU * 0.5 + phase * 2.0) * 0.4)
		pts.append(Vector2(x, y))
	pts.append(Vector2(s.x, s.y))
	draw_colored_polygon(pts, col)
