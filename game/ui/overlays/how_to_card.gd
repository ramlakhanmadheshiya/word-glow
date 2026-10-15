class_name HowToCard
extends Overlay
## How to play, one page per idea, each with a small live demo board (the real
## BoardView with a ghost finger tracing the word). `pages` picks which ideas to show.

const ALL_PAGES: Array[String] = ["basics", "stars", "shadows", "beacons", "hints"]

const PAGES: Dictionary = {
	"basics": {
		"title": "Light every word",
		"text": "Every tile belongs to exactly one hidden word on the theme. Drag through neighbouring tiles (up, down, left or right) to spell a word. When every tile glows, the level is clear.",
		"grid": ["BEA", "HSM", "INE"], "words": [["BEAM", [0, 1, 2, 5]], ["SHINE", [4, 3, 6, 7, 8]]],
		"found": [0], "ghost": 1, "shadows": [], "beacons": [],
	},
	"shadows": {
		"title": "Shadow tiles",
		"text": "Dark tiles hide their letters. Find a word next to them and the light spreads, revealing them. Choose which word to find first!",
		"grid": ["BEA", "HSM", "INE"], "words": [["BEAM", [0, 1, 2, 5]], ["SHINE", [4, 3, 6, 7, 8]]],
		"found": [], "ghost": 0, "shadows": [3, 4, 8], "beacons": [],
	},
	"beacons": {
		"title": "Beacons",
		"text": "A tile with a flame is a beacon. When its word is found, beams of light shoot along its whole row and column, lighting every shadow in their path.",
		"grid": ["OWL", "BEE", "SUN", "CAT"], "words": [["OWL", [0, 1, 2]], ["BEE", [3, 4, 5]], ["SUN", [6, 7, 8]], ["CAT", [9, 10, 11]]],
		"found": [], "ghost": 0, "shadows": [3, 4, 6, 7, 8, 9, 10, 11], "beacons": [2],
	},
	"stars": {
		"title": "Three stars",
		"text": "Solve a level with no wrong words and no hints for three stars. Up to %d extra moves (a wrong word or a hint is one each) still earns two. Each new star pays %d coins, and Restart puts all three back on offer." % [Economy.TWO_STAR_EXTRA, Economy.STAR_REWARD],
		"grid": ["BEA", "HSM", "INE"], "words": [["BEAM", [0, 1, 2, 5]], ["SHINE", [4, 3, 6, 7, 8]]],
		"found": [0, 1], "ghost": -1, "shadows": [], "beacons": [],
	},
	"hints": {
		"title": "Hints and coins",
		"text": "Stuck? A Spark (%d coins) reveals the next letter of a word, and your first Spark each day is free. A Lantern (%d coins) lights a whole word. Out of coins? Watch a short video for the hint, or earn coins from levels, chapters, daily lanterns and achievements." % [Economy.SPARK_COST, Economy.LANTERN_COST],
		"grid": ["BEA", "HSM", "INE"], "words": [["BEAM", [0, 1, 2, 5]], ["SHINE", [4, 3, 6, 7, 8]]],
		"found": [0], "ghost": -1, "shadows": [], "beacons": [], "sparks": {1: 2},
	},
}

var pages: Array = ALL_PAGES
var _index: int = 0
var _holder: VBoxContainer
var _prev: Button
var _next: Button
var _dots: HBoxContainer


func build() -> void:
	name = "HowTo"
	add_title("How to play" if pages.size() > 1 or pages == ["basics"] else "New idea")
	_holder = UIKit.vbox(14)
	body.add_child(_holder)
	var nav: HBoxContainer = UIKit.hbox(16)
	_prev = UIKit.icon_button("chevron-left", 80)
	_prev.pressed.connect(func() -> void: _show(_index - 1))
	nav.add_child(_prev)
	_dots = UIKit.hbox(10)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_dots)
	_next = UIKit.button("Next", "primary", Style.AMBER, 80, 28)
	_next.name = "Next"
	_next.custom_minimum_size.x = 200
	_next.pressed.connect(func() -> void:
		if _index >= pages.size() - 1:
			close()
		else:
			_show(_index + 1)
	)
	nav.add_child(_next)
	body.add_child(nav)
	_show(0)


func _show(i: int) -> void:
	_index = clampi(i, 0, pages.size() - 1)
	for c: Node in _holder.get_children():
		c.queue_free()
	var page: Dictionary = PAGES[pages[_index]]
	var demo: BoardView = _demo(page)
	_holder.add_child(demo)
	_holder.add_child(UIKit.label(page["title"], Style.SIZE_H2, Style.AMBER, 600))
	_holder.add_child(UIKit.para(page["text"], Style.SIZE_BODY - 2, Style.INK))
	_prev.visible = pages.size() > 1
	_prev.disabled = _index == 0
	_next.text = "Got it" if _index == pages.size() - 1 else "Next"
	for c: Node in _dots.get_children():
		c.queue_free()
	if pages.size() > 1:
		for k: int in pages.size():
			var dot: ColorRect = ColorRect.new()
			dot.custom_minimum_size = Vector2(14, 14) if k != _index else Vector2(34, 14)
			dot.color = Style.AMBER if k == _index else Color(Style.INK, 0.25)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_dots.add_child(dot)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	refit()


## A non-interactive board showing the page's idea.
func _demo(page: Dictionary) -> BoardView:
	var words: Array = []
	for w: Array in page["words"]:
		words.append({"w": w[0], "p": w[1]})
	var p: Puzzle = Puzzle.from_dict({"id": "demo", "theme": "demo", "grid": page["grid"], "words": words, "shadows": page["shadows"], "beacons": page["beacons"]})
	var s: LevelState = LevelState.new(p)
	for i: int in page["found"]:
		s.submit(p.words[i]["cells"])
	var sp: Dictionary = page.get("sparks", {})
	for k: Variant in sp:
		s.sparks[int(k)] = int(sp[k])
	var b: BoardView = BoardView.new()
	b.input_enabled = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.custom_minimum_size = Vector2(0, 260 if p.rows <= 3 else 330)
	b.setup(s, Style.AMBER)
	if int(page["ghost"]) >= 0:
		b.show_ghost(p.words[int(page["ghost"])]["cells"])
	return b
