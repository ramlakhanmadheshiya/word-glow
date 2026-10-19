class_name Look
extends RefCounted
## The player's chosen look: a colour theme (sky, accent and tiles; Theme pack)
## and a lantern style (lit-word colours and tile shape; Lantern styles pack).
## "chapters" and "classic" are free and keep each chapter's own colours.

const THEMES: Dictionary = {
	"midnight": {"name": "Midnight", "top": "#1B1D2B", "bottom": "#0B0C12", "accent": "#7AA2F7", "tile": "#E6E9F5", "ink": "#1B1D2B"},
	"nord": {"name": "Nord", "top": "#3B4252", "bottom": "#242933", "accent": "#88C0D0", "tile": "#ECEFF4", "ink": "#2E3440"},
	"dracula": {"name": "Dracula", "top": "#343746", "bottom": "#1B1C24", "accent": "#BD93F9", "tile": "#F8F8F2", "ink": "#282A36"},
	"ocean": {"name": "Ocean", "top": "#14405A", "bottom": "#06121C", "accent": "#4FC3F7", "tile": "#E6F4FB", "ink": "#0E2233"},
	"forest": {"name": "Forest", "top": "#23402C", "bottom": "#0A140E", "accent": "#7BC67E", "tile": "#EEF3EA", "ink": "#1C2E22"},
	"sunset": {"name": "Sunset", "top": "#7A3B57", "bottom": "#2B1B3D", "accent": "#FF8C61", "tile": "#FFF0E6", "ink": "#3A1E33"},
	"sakura": {"name": "Sakura", "top": "#5A2E4C", "bottom": "#1A0E18", "accent": "#FF9EC4", "tile": "#FFF1F5", "ink": "#4A2030"},
	"ember": {"name": "Ember", "top": "#4A1E0C", "bottom": "#120704", "accent": "#FF7A3D", "tile": "#FFE9D6", "ink": "#3A1A0C"},
	"royal": {"name": "Royal", "top": "#3A1F73", "bottom": "#0C0620", "accent": "#FFD45C", "tile": "#FFF6DC", "ink": "#23124A"},
	"paper": {"name": "Paper", "top": "#FBF6EC", "bottom": "#EADBC2", "accent": "#E8603F", "tile": "#FFFFFF", "ink": "#2D2A4A", "light": true},
	"daylight": {"name": "Daylight", "top": "#E8F4FF", "bottom": "#B9D9F5", "accent": "#2F80D9", "tile": "#FFFFFF", "ink": "#1E3A55", "light": true},
}

const STYLES: Dictionary = {
	"classic": {"name": "Classic", "radius": 0.22, "glow": 1.0, "colors": ["#FF9F43", "#FF6B81", "#A47CFF", "#4FB3FF", "#2ECDB4", "#8CD64B", "#FFC93C", "#FF7AC6", "#6C8CFF", "#FF8456"]},
	"neon": {"name": "Neon", "radius": 0.3, "glow": 1.8, "colors": ["#FF2E88", "#00E5FF", "#B6FF00", "#FFEA00", "#7C4DFF", "#FF6D00", "#00FFA3", "#FF00E5"]},
	"glass": {"name": "Glass", "radius": 0.26, "glow": 0.6, "colors": ["#9AD0F5", "#B8E3D6", "#D6C8F5", "#F5C8D9", "#F5E3B8", "#C8F0F5", "#E0F5C8"]},
	"ember": {"name": "Ember", "radius": 0.18, "glow": 1.4, "colors": ["#FF6A2B", "#FF9F1C", "#E63946", "#FFC145", "#D9480F", "#FF7F50"]},
	"candy": {"name": "Candy", "radius": 0.45, "glow": 0.9, "colors": ["#FF8FB1", "#7FD8FF", "#B9F18C", "#FFD36E", "#C79BFF", "#FF9E7A", "#7FFFD4"]},
	"ink": {"name": "Ink", "radius": 0.12, "glow": 0.4, "colors": ["#3E4C7A", "#5A3E7A", "#2F6B6B", "#7A3E52", "#4A5A2F", "#2F4A7A"]},
	"jewel": {"name": "Jewel", "radius": 0.24, "glow": 1.2, "colors": ["#0F9D58", "#C2185B", "#1E63D6", "#7B1FA2", "#E0A800", "#00897B", "#D84315"]},
}

const DEFAULT_TILE: Color = Color("FBF1DE")
const DEFAULT_INK: Color = Color("2A2350")


static func theme_id() -> String:
	var id: String = str(Profile.setting("theme", "chapters"))
	return id if THEMES.has(id) and Profile.owns("theme_pack") else "chapters"


static func style_id() -> String:
	var id: String = str(Profile.setting("style", "classic"))
	return id if STYLES.has(id) and (id == "classic" or Profile.owns("style_pack")) else "classic"


## Sets every Style colour from the chosen theme ("Original" keeps the night
## palette). Called at start-up, on every screen change (so an ended trial
## reverts) and whenever the player picks a theme.
static func apply() -> void:
	var t: String = theme_id()
	if t == "chapters" and original_is_light():
		# Original colours in daylight: warm cream sky, dark text.
		_set_palette(Color("FFF4E6"), Color("F4D8C4"), Color("E8703A"), false, Color("2D2547"))
		return
	if t == "chapters":
		_set_palette(Color("2E2A6B"), Color("141235"), Color("FFB547"), true, Color("FFF4E3"))
		Style.CARD = Color("272161")
		Style.SURFACE = Color("2E2870")
		Style.PANEL = Color("231D5C")
		Style.LIP = Color("140F36")
		Style.SHADOW_TILE = Color("1A1540")
		Style.MUTED = Color("C6BFEA")
		Style.DIM = Color(0.03, 0.02, 0.10, 0.62)
		return
	var th: Dictionary = THEMES[t]
	var light: bool = bool(th.get("light", false))
	_set_palette(Color(th["top"]), Color(th["bottom"]), Color(th["accent"]), not light, Color(th["ink"]) if light else Color("F4F1FF"))


static func _set_palette(top: Color, bottom: Color, accent: Color, dark: bool, ink: Color) -> void:
	Style.DARK = dark
	Style.DEFAULT_SKY_TOP = top
	Style.DEFAULT_SKY_BOTTOM = bottom
	Style.AMBER = accent
	Style.INK = ink
	if dark:
		var mid: Color = top.lerp(bottom, 0.4)
		Style.MUTED = ink.lerp(top, 0.3)
		Style.CARD = mid.lightened(0.07)
		Style.SURFACE = mid.lightened(0.14)
		Style.PANEL = mid.lightened(0.04)
		Style.LIP = bottom.darkened(0.5)
		Style.SHADOW_TILE = bottom.lightened(0.04)
		Style.FIELD = Color(ink, 0.07)
		Style.CARD_EDGE = Color(1, 1, 1, 0.10)
		Style.DIM = Color(bottom.darkened(0.6), 0.62)
	else:
		Style.MUTED = ink.lerp(top, 0.42)
		Style.CARD = top.lerp(Color.WHITE, 0.55)
		Style.SURFACE = Color.WHITE
		Style.PANEL = top.lerp(Color.WHITE, 0.4)
		Style.LIP = bottom.darkened(0.22)
		Style.SHADOW_TILE = bottom.darkened(0.25)
		Style.FIELD = Color(ink, 0.07)
		Style.CARD_EDGE = Color(ink, 0.12)
		Style.DIM = Color(ink, 0.45)


## Settings › Appearance for the Original colours: "auto" follows the phone's
## dark mode, "dark" is the night look, "light" the daytime look.
static func appearance() -> String:
	var a: String = str(Profile.setting("appearance", "auto"))
	return a if a in ["auto", "dark", "light"] else "auto"


static func original_is_light() -> bool:
	match appearance():
		"light":
			return true
		"dark":
			return false
	return DisplayServer.is_dark_mode_supported() and not DisplayServer.is_dark_mode()


static func theme_ids() -> Array:
	return ["chapters"] + THEMES.keys()


static func style_ids() -> Array:
	return STYLES.keys()


static func theme_name(id: String) -> String:
	return "Original" if id == "chapters" else str(THEMES.get(id, {}).get("name", id))


static func style_name(id: String) -> String:
	return str(STYLES.get(id, {}).get("name", id))


## Sky colours for a chapter (or the home screen when chapter is empty).
static func sky(chapter: Dictionary) -> Array[Color]:
	var t: String = theme_id()
	if t != "chapters":
		return [Color(THEMES[t]["top"]), Color(THEMES[t]["bottom"])]
	if chapter.is_empty() or not chapter.has("sky_top"):
		return [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM]
	if original_is_light():
		# Each chapter keeps its hue, as a daytime sky.
		var hue: Color = chapter.get("accent", Style.AMBER)
		return [hue.lerp(Color.WHITE, 0.85), hue.lerp(Color.WHITE, 0.62)]
	return [chapter["sky_top"], chapter["sky_bottom"]]


static func accent(chapter: Dictionary) -> Color:
	var t: String = theme_id()
	if t != "chapters":
		return Color(THEMES[t]["accent"])
	var a: Color = chapter.get("accent", Style.AMBER)
	# Deeper on daytime skies so captions and bars keep their contrast.
	return a.darkened(0.3) if original_is_light() else a


static func tile() -> Color:
	var t: String = theme_id()
	if t == "chapters":
		return Color.WHITE if original_is_light() else DEFAULT_TILE
	return Color(THEMES[t]["tile"])


static func tile_ink() -> Color:
	var t: String = theme_id()
	return Color(THEMES[t]["ink"]) if t != "chapters" else DEFAULT_INK


static func tile_edge() -> Color:
	return tile().darkened(0.16)


## Lit-word colour for the i-th word found.
static func lantern(i: int, style: String = "") -> Color:
	var s: Dictionary = STYLES[style if STYLES.has(style) else style_id()]
	var cols: Array = s["colors"]
	return Color(str(cols[posmod(i, cols.size())]))


## Tile corner radius as a fraction of the tile size.
static func radius() -> float:
	return float(STYLES[style_id()]["radius"])


static func glow() -> float:
	return float(STYLES[style_id()]["glow"])
