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
	"deepsea": {"name": "Deep sea", "top": "#0B3D44", "bottom": "#021216", "accent": "#3DE0C8", "tile": "#E2FBF7", "ink": "#06302C"},
	"royal": {"name": "Royal", "top": "#3A1F73", "bottom": "#0C0620", "accent": "#FFD45C", "tile": "#FFF6DC", "ink": "#23124A"},
	"mono": {"name": "Mono", "top": "#262626", "bottom": "#050505", "accent": "#E0E0E0", "tile": "#F2F2F2", "ink": "#111111"},
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
	if chapter.is_empty():
		return [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM]
	return [chapter["sky_top"], chapter["sky_bottom"]]


static func accent(chapter: Dictionary) -> Color:
	var t: String = theme_id()
	if t != "chapters":
		return Color(THEMES[t]["accent"])
	return chapter.get("accent", Style.AMBER)


static func tile() -> Color:
	var t: String = theme_id()
	return Color(THEMES[t]["tile"]) if t != "chapters" else DEFAULT_TILE


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
