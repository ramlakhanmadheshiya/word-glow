class_name Style
extends RefCounted
## Design tokens: colours, sizes and shared textures. Night sky, paper tiles,
## warm lantern light.

## Theme-driven colours. They start as the "Original" night palette and are
## replaced as a set by Look.apply() when the player picks a colour theme, so
## the whole app changes, not just the text: sky, cards, buttons, panels and tiles.
static var INK: Color = Color("FFF4E3")
static var MUTED: Color = Color("C6BFEA")
static var CARD: Color = Color("272161")
static var CARD_EDGE: Color = Color(1, 1, 1, 0.10)
static var FIELD: Color = Color(1, 1, 1, 0.07)
## Raised surfaces: soft buttons, shop rows, chips.
static var SURFACE: Color = Color("2E2870")
## The darker edge under raised surfaces.
static var LIP: Color = Color("140F36")
## Flat panels: the MOVES strip, the daily card.
static var PANEL: Color = Color("231D5C")
static var SHADOW_TILE: Color = Color("1A1540")
static var AMBER: Color = Color("FFB547")
static var DIM: Color = Color(0.03, 0.02, 0.10, 0.62)
static var DEFAULT_SKY_TOP: Color = Color("2E2A6B")
static var DEFAULT_SKY_BOTTOM: Color = Color("141235")
## False for light themes (dark text, no stars in the sky).
static var DARK: bool = true

## Fixed colours that read on any theme.
const PAPER: Color = Color("FBF1DE")
const PAPER_EDGE: Color = Color("D9C9AE")
const PAPER_INK: Color = Color("2A2350")
const GOLD: Color = Color("FFD45C")
const ERROR: Color = Color("FF5D6C")
const SUCCESS: Color = Color("4FD18B")

## Every round icon button in a top bar (Back, Settings, Shop) is this size on
## every screen, so they never change size between pages.
const TOP_BUTTON: float = 84.0
## Every card's close (X) button is this size.
const CLOSE_BUTTON: float = 72.0

const GUTTER: int = 24
const MAX_WIDTH: int = 720
const RADIUS: int = 28

const SIZE_HERO: int = 76
const SIZE_H1: int = 48
const SIZE_H2: int = 36
const SIZE_BODY: int = 28
const SIZE_SMALL: int = 23
const SIZE_CAPTION: int = 19


static var _glow: Texture2D


static func clear_caches() -> void:
	_glow = null


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
