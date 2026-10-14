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
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	for st: Vector4 in _stars:
		var a: float = 0.25 + 0.45 * (0.5 + 0.5 * sin(_t * 1.3 + st.w))
		draw_circle(Vector2(st.x * s.x, st.y * s.y), st.z, Color(Style.INK, a))
	var glow: Texture2D = Style.glow_texture()
	for l: Dictionary in _lanterns:
		var p: Vector2 = Vector2((float(l["x"]) + 0.02 * sin(_t * 0.6 + float(l["phase"]))) * s.x, float(l["y"]) * s.y)
		var r: float = l["size"]
		var c: Color = l["color"]
		var flicker: float = 0.85 + 0.15 * sin(_t * 3.0 + float(l["phase"]))
		draw_texture_rect(glow, Rect2(p - Vector2(r, r) * 3.0, Vector2(r, r) * 6.0), false, Color(c, 0.22 * flicker))
		draw_rect(Rect2(p - Vector2(r * 0.55, r * 0.7), Vector2(r * 1.1, r * 1.4)), Color(c, 0.75 * flicker))
		draw_rect(Rect2(p - Vector2(r * 0.4, r * 0.85), Vector2(r * 0.8, r * 0.18)), Color(0.1, 0.07, 0.2, 0.6))
