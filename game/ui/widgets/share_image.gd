class_name ShareImage
extends Control
## The picture players share after a clear, like Single Shot's: the solved
## puzzle glowing on its board, the stars, the theme, and a QR code and link to
## the game. Rendered off-screen at 1080 x 1350 (4:5, the shape chat apps and
## feeds show best).

const SIZE: Vector2i = Vector2i(1080, 1350)
const SITE: String = "theramlakhan.com/word-glow"

var info: Dictionary = {}


## Renders the picture for `data` and calls back with an Image (null where
## nothing can be rendered, e.g. headless).
static func render(host: Node, data: Dictionary, done: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		done.call(null)
		return
	var vp: SubViewport = SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	var card: ShareImage = ShareImage.new()
	card.info = data
	card.size = Vector2(SIZE)
	vp.add_child(card)
	host.add_child(vp)
	# Let the board lay out and its glow settle before taking the picture.
	for i: int in 8:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(vp):
		return
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	done.call(img)


func _ready() -> void:
	var accent: Color = info.get("accent", Style.AMBER)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.position = Vector2(72, 60)
	icon.size = Vector2(104, 104)
	add_child(icon)
	_label("Word Glow", 56, Style.INK, 700, Vector2(196, 74), Vector2(520, 76))
	var daily: bool = not str(info.get("daily", "")).is_empty()
	_label("Daily puzzle" if daily else "Level %d" % int(info["number"]), 36, accent, 800, Vector2(560, 66), Vector2(448, 50), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(str(info["chapter"]) if not daily else str(info["daily"]), 30, Style.MUTED, 600, Vector2(560, 116), Vector2(448, 44), HORIZONTAL_ALIGNMENT_RIGHT)
	# The solved puzzle, lit.
	var puzzle: Puzzle = info["puzzle"]
	_label(puzzle.theme_name, 44, Style.INK, 700, Vector2(0, 196), Vector2(1080, 60))
	var board: BoardView = BoardView.new()
	board.input_enabled = false
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.position = Vector2(150, 276)
	board.size = Vector2(780, 720)
	add_child(board)
	board.setup(info["state"], accent)
	var stars: StarRow = StarRow.new()
	stars.position = Vector2(0, 1010)
	stars.size = Vector2(1080, 110)
	add_child(stars)
	stars.show_now(int(info["stars"]))
	_label(str(info["title"]), 64, Style.INK, 700, Vector2(0, 1110), Vector2(1080, 80))
	_label("%s  ·  %d words" % [str(info["verdict"]), puzzle.words.size()], 30, Style.MUTED, 500, Vector2(0, 1186), Vector2(1080, 44))
	_label("Can you light every word?", 34, Style.INK, 700, Vector2(72, 1240), Vector2(760, 48), HORIZONTAL_ALIGNMENT_LEFT)
	_label(SITE, 30, accent, 700, Vector2(72, 1284), Vector2(760, 44), HORIZONTAL_ALIGNMENT_LEFT)
	var qr: TextureRect = TextureRect.new()
	qr.texture = load("res://assets/share/qr.png")
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr.position = Vector2(880, 1214)
	qr.size = Vector2(128, 128)
	add_child(qr)


func _label(text: String, fs: int, col: Color, weight: int, pos: Vector2, sz: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var l: Label = UIKit.label(text, fs, col, weight, align)
	l.position = pos
	l.size = sz
	l.clip_text = true
	add_child(l)


func _draw() -> void:
	var sky: Array = info.get("sky", [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM])
	var top: Color = sky[0]
	var bottom: Color = sky[1]
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var dot: Color = Color("FFF4E3", 0.35) if Style.DARK else Color(1, 1, 1, 0.5)
	for i: int in 80:
		draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.8), rng.randf_range(1.5, 4.0), dot, true, -1.0, true)
	draw_line(Vector2(72, 1226), Vector2(840, 1226), Color(Style.INK, 0.14), 2.0, true)
