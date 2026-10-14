class_name DemoBoard
extends PanelContainer
## The home screen's attract mode: a small board on a soft card that plays
## itself. A ghost finger traces each word, it lights up, and when the board is
## full it celebrates and starts again.

const DEMO: Dictionary = {
	"id": "demo", "theme": "light",
	"grid": ["GLOW", "LBEA", "ARAM", "MPTS"],
	"words": [{"w": "GLOW", "p": [0, 1, 2, 3]}, {"w": "LAMP", "p": [4, 8, 12, 13]}, {"w": "BEAM", "p": [5, 6, 7, 11]}, {"w": "STAR", "p": [15, 14, 10, 9]}],
}

var board: BoardView
var _state: LevelState
var _step: int = 0
var _timer: Timer


func _init() -> void:
	name = "DemoCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(300, 260)
	var sb: StyleBoxFlat = UIKit.box(Color(1, 1, 1, 0.05), 44, Color(1, 1, 1, 0.07), 2, Vector2(18, 18))
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	add_theme_stylebox_override("panel", sb)
	board = BoardView.new()
	board.input_enabled = false
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	resized.connect(func() -> void:
		var want: float = clampf(size.y, 260.0, 420.0)
		if absf(custom_minimum_size.x - want) > 2.0:
			custom_minimum_size.x = want
	)


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 2.2
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_restart()
	_timer.start()


func _restart() -> void:
	_state = LevelState.new(Puzzle.from_dict(DEMO))
	_step = 0
	board.setup(_state, Style.AMBER)
	board.show_ghost(_state.puzzle.words[0]["cells"])


## One beat of the loop: find the word being traced, then show the next one.
func _tick() -> void:
	if _step >= _state.puzzle.words.size():
		_restart()
		return
	var r: Dictionary = _state.submit(_state.puzzle.words[_step]["cells"])
	if r.get("result", -1) == LevelState.Result.FOUND:
		board.show_found(_step, r["revealed"], r["beacons"])
	_step += 1
	if _step < _state.puzzle.words.size():
		board.show_ghost(_state.puzzle.words[_step]["cells"])
	else:
		board.show_ghost(PackedInt32Array())
		board.celebrate()
