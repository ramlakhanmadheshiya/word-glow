class_name Style
extends RefCounted
## Design tokens: colours, sizes and shared textures. Night sky, paper tiles,
## warm lantern light.

const INK: Color = Color("FFF4E3")
const MUTED: Color = Color("C6BFEA")
const CARD: Color = Color("272161")
const CARD_EDGE: Color = Color(1, 1, 1, 0.10)
const FIELD: Color = Color(1, 1, 1, 0.07)
const PAPER: Color = Color("FBF1DE")
const PAPER_EDGE: Color = Color("D9C9AE")
const PAPER_INK: Color = Color("2A2350")
const SHADOW_TILE: Color = Color("1A1540")
const AMBER: Color = Color("FFB547")
const GOLD: Color = Color("FFD45C")
const ERROR: Color = Color("FF5D6C")
const SUCCESS: Color = Color("7DE2A6")
const DIM: Color = Color(0.03, 0.02, 0.10, 0.62)

## Found words cycle through these lantern colours.
const LANTERNS: Array[Color] = [
	Color("FF9F43"), Color("FF6B81"), Color("A47CFF"), Color("4FB3FF"),
	Color("2ECDB4"), Color("8CD64B"), Color("FFC93C"), Color("FF7AC6"),
	Color("6C8CFF"), Color("FF8456"),
]

const GUTTER: int = 24
const MAX_WIDTH: int = 720
const RADIUS: int = 28

const SIZE_HERO: int = 76
const SIZE_H1: int = 48
const SIZE_H2: int = 36
const SIZE_BODY: int = 28
const SIZE_SMALL: int = 23
const SIZE_CAPTION: int = 19

const DEFAULT_SKY_TOP: Color = Color("2E2A6B")
const DEFAULT_SKY_BOTTOM: Color = Color("141235")

static var _glow: Texture2D


static func clear_caches() -> void:
	_glow = null


static func lantern_color(i: int) -> Color:
	return LANTERNS[posmod(i, LANTERNS.size())]


## Soft round light, white in the middle fading to nothing, tinted by modulate.
static func glow_texture() -> Texture2D:
	if _glow == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_glow = tex
	return _glow
