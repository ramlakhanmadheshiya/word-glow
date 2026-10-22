extends Screen
## Playing one level (args {chapter, level}) or a daily (args {daily: "YYYY-MM-DD"}).
## Laid out like Single Shot's game screen: header, a MOVES / STARS strip that
## also carries messages, the answers and board, and a bottom bar with Levels,
## Spark, Lantern and Restart. Progress is saved after every move.

const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var puzzle: Puzzle
var state: LevelState
var board: BoardView
var words: WordList
var chapter_idx: int = -1
var level_n: int = 0
var daily_key: String = ""

var _hud: MovesHud
var _title: Label
var _toast: Label
var _toast_box: PanelContainer
var _toast_tween: Tween
var _spark_btn: Button
var _lantern_btn: Button
var _spark_badge: Label
var _lantern_badge: Label
var _done: bool = false


func chapter_info() -> Dictionary:
	if args.has("daily"):
		return {"sky_top": Color("3A2468"), "sky_bottom": Color("120B2B"), "accent": Color("C9A7FF")}
	return Catalog.chapter(int(args.get("chapter", 0)))


func in_game() -> bool:
	return true


func build() -> void:
	daily_key = str(args.get("daily", ""))
	if daily_key.is_empty():
		chapter_idx = int(args.get("chapter", 0))
		level_n = int(args.get("level", 1))
		puzzle = Catalog.puzzle(chapter_idx, level_n)
	else:
		puzzle = Catalog.daily_puzzle(daily_key)
	if puzzle == null:
		_build_error()
		return
	state = LevelState.new(puzzle)
	state.restore(Profile.saved_progress(puzzle.id))
	Profile.set_last_level(puzzle.id)
	Audio.music("play")
	_build_ui()
	_refresh()
	_intro_if_needed.call_deferred()


func _build_error() -> void:
	body.add_child(header("Level unavailable"))
	body.add_child(UIKit.gap(120))
	body.add_child(UIKit.icon_rect("info", 96, Style.MUTED))
	body.add_child(UIKit.para("This level could not be loaded. %s" % Catalog.last_error, Style.SIZE_BODY))
	var b: Button = UIKit.button("Back", "soft")
	b.pressed.connect(app.back)
	body.add_child(b)


func _title_caption() -> String:
	if not daily_key.is_empty():
		return "Daily · %s" % _pretty_date(daily_key)
	return "%s · Level %d · %s" % [Catalog.chapter(chapter_idx)["name"], level_n, Catalog.tier_name(level_n)]


func _build_ui() -> void:
	var head: HBoxContainer = header(puzzle.shown_theme(state.found), _title_caption())
	_title = head.find_child("Title", true, false)
	body.add_child(head)
	# The strip: MOVES / STARS and coins, always visible while playing.
	var strip: HBoxContainer = UIKit.hbox(8, BoxContainer.ALIGNMENT_BEGIN)
	strip.name = "Strip"
	_hud = MovesHud.new()
	_hud.name = "Hud"
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(_hud)
	var coins: CounterChip = UIKit.coin_chip()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(coins)
	var strip_panel: PanelContainer = PanelContainer.new()
	strip_panel.add_theme_stylebox_override("panel", UIKit.lip_box(Style.PANEL, 28, Style.LIP, 5, Vector2(14, 2)))
	strip_panel.add_child(strip)
	body.add_child(strip_panel)

	words = WordList.new()
	words.name = "Words"
	body.add_child(words)
	words.setup(state)

	# The word line: the letters being traced and short messages, on their own
	# line just above the board (it keeps its height so nothing jumps).
	var line: CenterContainer = CenterContainer.new()
	line.name = "WordLine"
	line.custom_minimum_size.y = 64
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box = PanelContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.32), 30, Color(Style.INK, 0.08), 2, Vector2(26, 6)))
	_toast = UIKit.label("", 30, Style.INK, 700)
	_toast.name = "Toast"
	_toast_box.add_child(_toast)
	_toast_box.modulate.a = 0.0
	line.add_child(_toast_box)
	body.add_child(line)

	board = BoardView.new()
	board.name = "Board"
	board.setup(state, accent())
	board.traced.connect(_on_traced)
	board.trace_changed.connect(_on_trace_changed)
	body.add_child(board)

	var bar: HBoxContainer = UIKit.hbox(26)
	bar.name = "Bar"
	bar.custom_minimum_size.y = 128
	bar.add_child(_action("layout-grid", "LEVELS" if daily_key.is_empty() else "HOME", "LevelsButton", 80, func() -> void: app.back()))
	var spark: Array = _hint_action("art:hint_letter", "LETTER", "LetterHint", use_spark)
	_spark_btn = spark[0]
	_spark_badge = spark[1]
	bar.add_child(spark[2])
	var lantern: Array = _hint_action("art:hint_word", "WORD", "WordHint", use_lantern)
	_lantern_btn = lantern[0]
	_lantern_badge = lantern[1]
	bar.add_child(lantern[2])
	bar.add_child(_action("rotate-ccw", "RESTART", "Restart", 80, ask_restart))
	body.add_child(bar)


## A round icon button with a small caption under it.
func _action(icon_name: String, caption: String, node_name: String, size_px: float, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(6)
	var b: Button = UIKit.icon_button(icon_name, size_px)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 16))
	return box


## A hint button with a price badge. Returns [button, badge, box].
func _hint_action(icon_name: String, caption: String, node_name: String, cb: Callable) -> Array:
	var box: VBoxContainer = _action(icon_name, caption, node_name, 96, cb)
	var b: Button = box.get_child(0)
	var badge: Label = UIKit.label("", 17, Style.PAPER_INK, 800)
	badge.name = "Badge"
	badge.add_theme_stylebox_override("normal", UIKit.box(Style.GOLD, 14, Color.TRANSPARENT, 0, Vector2(8, 1)))
	badge.position = Vector2(58, -6)
	b.add_child(badge)
	return [b, badge, box]


func _pretty_date(key: String) -> String:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != 3:
		return key
	return "%s %d" % [MONTHS[clampi(int(parts[1]) - 1, 0, 11)], int(parts[2])]


func _refresh() -> void:
	_title.text = puzzle.shown_theme(state.found)
	_hud.accent = accent()
	_hud.set_state(state.moves(), state.par(), state.stars())
	_spark_badge.text = "FREE" if Profile.free_sparks_left() > 0 else str(Economy.SPARK_COST)
	_lantern_badge.text = str(Economy.LANTERN_COST)
	_spark_badge.reset_size()
	_lantern_badge.reset_size()
	var can_hint: bool = not _done and state.hint_target() >= 0
	_spark_btn.disabled = not can_hint
	_lantern_btn.disabled = not can_hint


# --- Tracing -------------------------------------------------------------------

func _on_trace_changed(text: String) -> void:
	if not text.is_empty():
		show_toast(text, 0.0, Style.INK)


func _on_traced(cells: PackedInt32Array) -> void:
	if _done or cells.size() < 2:
		hide_toast()
		return
	var r: Dictionary = state.submit(cells)
	match r["result"]:
		LevelState.Result.FOUND:
			_on_found(r)
		LevelState.Result.TOO_SHORT:
			board.show_error(cells)
			show_toast("Words have 3 or more letters", 1.6, Style.MUTED)
		LevelState.Result.ALREADY_FOUND:
			board.show_error(cells)
			show_toast("Already found", 1.4, Style.MUTED)
		LevelState.Result.NOT_A_WORD:
			board.show_error(cells)
			Audio.play("error", 1.0, -2.0)
			Haptics.error()
			var tip: String = "%s isn't hidden here" % r["word"]
			if state.mistakes == 3:
				tip = "Stuck? A letter hint shows the next letter"
			show_toast(tip, 2.2, Style.ERROR)
			Profile.store_progress(puzzle.id, state)
			_refresh()
		_:
			hide_toast()


func _on_found(r: Dictionary) -> void:
	var i: int = r["word_index"]
	var title_before: String = _title.text
	board.show_found(i, r["revealed"], r["beacons"])
	words.mark_found(i)
	show_toast(str(r["word"]), 1.1, Look.lantern(state.found_count() - 1))
	if puzzle.mystery and puzzle.shown_theme(state.found) != title_before:
		var theme: String = puzzle.theme_names[int(puzzle.words[i].get("theme", 0))]
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_inside_tree():
				show_toast("The theme is %s" % theme, 1.6, Style.GOLD))
	Audio.play("found", 1.0 + 0.04 * mini(state.found_count(), 6))
	Haptics.success()
	var beacons: int = (r["beacons"] as PackedInt32Array).size()
	if beacons > 0:
		get_tree().create_timer(0.3).timeout.connect(func() -> void: Audio.play("beam"))
	elif not (r["revealed"] as PackedInt32Array).is_empty():
		get_tree().create_timer(0.35).timeout.connect(func() -> void: Audio.play("reveal", 1.0, -4.0))
	Profile.record_word(beacons)
	if state.is_complete():
		_complete()
	else:
		Profile.store_progress(puzzle.id, state)
		Profile.check_achievements()
	_refresh()


## Shows the traced letters or a short message on the word line above the
## board (0 s = until hidden). MOVES / STARS are never covered.
func show_toast(text: String, seconds: float, color: Color = Style.INK) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast_box.reset_size()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_box, "modulate:a", 1.0, 0.1)
	if seconds > 0.0:
		_toast_tween.tween_interval(seconds)
		_toast_tween.tween_property(_toast_box, "modulate:a", 0.0, 0.3)


func hide_toast() -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_box, "modulate:a", 0.0, 0.2)


# --- Hints ---------------------------------------------------------------------

## Spark: one letter of a word. Free Sparks first, then coins; with too few
## coins, the player is offered a video instead. Nothing is charged unless there
## is something to reveal.
func use_spark() -> void:
	if _done or state.hint_target() < 0:
		return
	if Profile.use_free_spark() or Profile.spend(Economy.SPARK_COST):
		_give_spark()
	else:
		_out_of_coins("spark")


func use_lantern() -> void:
	if _done or state.hint_target() < 0:
		return
	if Profile.spend(Economy.LANTERN_COST):
		_give_lantern()
	else:
		_out_of_coins("lantern")


func _give(kind: String) -> void:
	if kind == "spark":
		_give_spark()
	else:
		_give_lantern()


func _give_spark() -> void:
	var r: Dictionary = state.apply_spark()
	if r.is_empty():
		return
	Profile.record_hint()
	Audio.play("spark")
	board.show_spark(int(r["spark_cell"]))
	if r.get("result", -1) == LevelState.Result.FOUND:
		_on_found(r)
	else:
		words.queue_redraw()
		Profile.store_progress(puzzle.id, state)
		show_toast("Letter %d of %d" % [int(r["spark_count"]), str(puzzle.words[int(r["word_index"])]["word"]).length()], 1.4, Style.GOLD)
	_refresh()


func _give_lantern() -> void:
	var r: Dictionary = state.apply_lantern()
	if r.is_empty():
		return
	Profile.record_hint()
	Audio.play("lantern")
	_on_found(r)


## Not enough coins: watch a video for this hint, get coins, or carry on.
## Where no video can be shown at all (e.g. the web), the hint is free.
func _out_of_coins(kind: String) -> void:
	var cost: int = Economy.SPARK_COST if kind == "spark" else Economy.LANTERN_COST
	var hint_name: String = "letter hint" if kind == "spark" else "word hint"
	if AdManager.provider == null:
		show_toast("Here's a free %s" % hint_name, 1.8, Style.GOLD)
		_give(kind)
		return
	var o: MessageCard = MessageCard.new()
	o.name = "OutOfCoins"
	o.title_text = "Out of coins"
	o.icon_name = "coin"
	o.icon_color = Style.GOLD
	o.message = "A %s costs %d coins and you have %d.\nWatch a short video to get this one free?" % [hint_name, cost, Profile.coins()]
	o.buttons = [
		["Watch a video", "primary", func() -> void:
			o.close()
			if not AdManager.rewarded_ready():
				show_toast("No video available right now. Try again soon.", 2.4, Style.MUTED)
				return
			AdManager.show_rewarded(func(ok: bool) -> void:
				if not is_inside_tree():
					return
				if ok:
					Audio.play("unlock", 1.2, -4.0)
					_give(kind)
				else:
					show_toast("The video was closed early, so no hint this time.", 2.4, Style.MUTED)
			)],
		["Get coins", "soft", func() -> void:
			o.close()
			app.go("shop")],
		["Not now", "ghost", func() -> void: o.close()],
	]
	app.open(o)


func _unhandled_key_input(e: InputEvent) -> void:
	if app.top_overlay() != null or not e.is_pressed():
		return
	if e.is_action_pressed("hint"):
		use_spark()
	elif e is InputEventKey and (e as InputEventKey).keycode == KEY_R:
		ask_restart()


# --- Restart and completion ------------------------------------------------------

## A fresh start with all three stars on offer (asks first if words are found).
func ask_restart() -> void:
	if _done or puzzle == null:
		return
	board.cancel_trace()
	if state.found_count() == 0 and state.extra_moves() == 0:
		show_toast("Fresh start", 1.2, Style.MUTED)
		return
	MessageCard.confirm(app, "Restart this level?", "Found words are cleared and all three stars are on offer again. Coins spent on hints are not refunded.", "Restart", restart)


func restart() -> void:
	Profile.clear_progress(puzzle.id)
	app.reload_screen()


func _complete() -> void:
	_done = true
	board.input_enabled = false
	var reward: Dictionary
	if daily_key.is_empty():
		reward = Profile.complete_level(puzzle.id, state)
	else:
		reward = Profile.complete_daily(daily_key, state)
	reward["achievements"] = Profile.check_achievements()
	await get_tree().create_timer(0.6).timeout
	board.celebrate()
	Audio.play("complete", 1.0, -3.0)
	await get_tree().create_timer(1.3).timeout
	if not is_inside_tree():
		return
	var card: ResultCard = ResultCard.new()
	card.play = self
	card.reward = reward
	app.open(card)


## Where "Next" goes after a clear: the next level, the next chapter, or home.
func go_next() -> void:
	if not daily_key.is_empty():
		app.go("home")
	elif level_n < Catalog.levels_per_chapter and Profile.level_unlocked(chapter_idx, level_n + 1):
		app.go("play", {"chapter": chapter_idx, "level": level_n + 1})
	elif level_n >= Catalog.levels_per_chapter and Profile.chapter_unlocked(chapter_idx + 1):
		app.go("levels", {"chapter": chapter_idx + 1})
	else:
		app.go("levels", {"chapter": chapter_idx})


func on_back() -> bool:
	if puzzle != null and not _done:
		board.cancel_trace()
	return false


# --- Intros ------------------------------------------------------------------------

## Like Single Shot, every chapter has one new idea: the first time a chapter is
## played, a card explains it with a live demo. A daily shows the shadow or
## beacon card if the player has not met those yet.
func _intro_if_needed() -> void:
	var key: String = ""
	var heading: String = ""
	if daily_key.is_empty():
		var ch: Dictionary = Catalog.chapter(chapter_idx)
		key = str(ch.get("lesson", ""))
		heading = "New in %s" % ch["name"] if chapter_idx > 0 else "How to play"
	elif not puzzle.beacons.is_empty():
		key = "beacons"
	elif not puzzle.shadows.is_empty():
		key = "shadows"
	if not key.is_empty() and not Profile.seen("intro_" + key):
		Profile.mark_seen("intro_" + key)
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return
		var o: HowToCard = HowToCard.new()
		o.pages = [key]
		o.heading = heading
		o.closed.connect(_show_ghost_if_tutorial)
		app.open(o)
		return
	_show_ghost_if_tutorial()


## On the very first level, a ghost finger shows how to trace the first word.
func _show_ghost_if_tutorial() -> void:
	if chapter_idx == 0 and level_n == 1 and daily_key.is_empty() and state.found_count() == 0 and is_inside_tree():
		var target: int = state.hint_target()
		if target >= 0:
			board.show_ghost(puzzle.words[target]["cells"])
