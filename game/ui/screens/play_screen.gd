extends Screen
## Playing one level (args {world, level}) or a daily puzzle (args {daily: "YYYY-MM-DD"}).
## Connects the LevelState rules to the board, the word list, hints, coins and saving.

const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var puzzle: Puzzle
var state: LevelState
var board: BoardView
var words: WordList
var world_idx: int = -1
var level_n: int = 0
var daily_key: String = ""
var accent: Color = Style.AMBER

var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_tween: Tween
var _progress: ProgressBar
var _count_label: Label
var _spark_btn: Button
var _lantern_btn: Button
var _spark_cost: Label
var _lantern_cost: Label
var _done: bool = false


func sky() -> Array[Color]:
	if args.has("daily"):
		return [Color("3A2468"), Color("120B2B")]
	var w: Dictionary = Catalog.world(int(args.get("world", 0)))
	if w.is_empty():
		return super.sky()
	return [w["sky_top"], w["sky_bottom"]]


func build() -> void:
	daily_key = str(args.get("daily", ""))
	if daily_key.is_empty():
		world_idx = int(args.get("world", 0))
		level_n = int(args.get("level", 1))
		puzzle = Catalog.puzzle(world_idx, level_n)
		var w: Dictionary = Catalog.world(world_idx)
		if not w.is_empty():
			accent = w["accent"]
	else:
		puzzle = Catalog.daily_puzzle(daily_key)
		accent = Color("C9A7FF")
	if puzzle == null:
		_build_error()
		return
	state = LevelState.new(puzzle)
	state.restore(Profile.saved_progress(puzzle.id))
	Profile.set_last_level(puzzle.id)
	Audio.music("play")
	_build_ui()
	_refresh_hud()
	_intro_if_needed.call_deferred()


func _build_error() -> void:
	body.add_child(top_bar("Level unavailable"))
	body.add_child(UIKit.gap(120))
	body.add_child(UIKit.icon_rect("info", 96, Style.MUTED))
	body.add_child(UIKit.para("This level could not be loaded. %s" % Catalog.last_error, Style.SIZE_BODY))
	var b: Button = UIKit.button("Back", "soft")
	b.pressed.connect(app.back)
	body.add_child(b)


func _build_ui() -> void:
	var pause: Button = UIKit.icon_button("pause", 84)
	pause.name = "Pause"
	pause.pressed.connect(_open_pause)
	var bar: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	bar.add_child(pause)
	var mid: VBoxContainer = UIKit.vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var where: String
	if daily_key.is_empty():
		where = "%s · Level %d" % [Catalog.world(world_idx)["name"], level_n]
	else:
		where = "Daily · %s" % _pretty_date(daily_key)
	mid.add_child(UIKit.caption(where, accent))
	var theme: Label = UIKit.label(puzzle.theme_name, Style.SIZE_H2, Style.INK, 600)
	theme.name = "Theme"
	theme.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(theme)
	bar.add_child(mid)
	bar.add_child(UIKit.coin_chip())
	body.add_child(bar)

	var prog_row: HBoxContainer = UIKit.hbox(14)
	_progress = UIKit.progress_bar(0.0, accent, 10)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog_row.add_child(_progress)
	_count_label = UIKit.label("", Style.SIZE_SMALL, Style.MUTED, 600)
	_count_label.name = "Count"
	prog_row.add_child(_count_label)
	body.add_child(prog_row)

	words = WordList.new()
	words.name = "Words"
	body.add_child(words)
	words.setup(state)

	_bubble = PanelContainer.new()
	_bubble.custom_minimum_size = Vector2(0, 64)
	_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.3), 32, Color.TRANSPARENT, 0, Vector2(30, 6)))
	_bubble_label = UIKit.label(" ", 32, Style.INK, 700)
	_bubble.add_child(_bubble_label)
	_bubble.modulate.a = 0.0
	body.add_child(_bubble)

	board = BoardView.new()
	board.name = "Board"
	board.setup(state, accent)
	board.traced.connect(_on_traced)
	board.trace_changed.connect(_on_trace_changed)
	body.add_child(board)

	var hints: HBoxContainer = UIKit.hbox(16)
	var spark: Array = _hint_button("Spark", "sparkles")
	_spark_btn = spark[0]
	_spark_cost = spark[1]
	_spark_btn.name = "Spark"
	_spark_btn.pressed.connect(use_spark)
	hints.add_child(_spark_btn)
	var lantern: Array = _hint_button("Lantern", "lantern")
	_lantern_btn = lantern[0]
	_lantern_cost = lantern[1]
	_lantern_btn.name = "Lantern"
	_lantern_btn.pressed.connect(use_lantern)
	hints.add_child(_lantern_btn)
	body.add_child(hints)


## A hint button: icon, name, and a price tag. Returns [button, price label].
func _hint_button(title: String, icon_name: String) -> Array:
	var b: Button = UIKit.button("", "soft", accent, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = UIKit.hbox(12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UIKit.icon_rect(icon_name, 40, accent))
	row.add_child(UIKit.label(title, 30, Style.INK, 600))
	var tag: PanelContainer = PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.3), 20, Color.TRANSPARENT, 0, Vector2(12, 2)))
	var tag_row: HBoxContainer = UIKit.hbox(4)
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_row.add_child(UIKit.icon_rect("coin", 24, Style.GOLD))
	var cost: Label = UIKit.label("", 22, Style.GOLD, 700)
	tag_row.add_child(cost)
	tag.add_child(tag_row)
	row.add_child(tag)
	b.add_child(row)
	return [b, cost]


func _pretty_date(key: String) -> String:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != 3:
		return key
	return "%s %d" % [MONTHS[clampi(int(parts[1]) - 1, 0, 11)], int(parts[2])]


func _refresh_hud() -> void:
	var total: int = puzzle.words.size()
	_count_label.text = "%d / %d" % [state.found_count(), total]
	create_tween().tween_property(_progress, "value", float(state.found_count()) / total, 0.35)
	_spark_cost.text = "FREE" if Profile.free_spark_available() else str(Economy.SPARK_COST)
	_lantern_cost.text = str(Economy.LANTERN_COST)
	var can_hint: bool = not _done and state.hint_target() >= 0
	_spark_btn.disabled = not can_hint
	_lantern_btn.disabled = not can_hint


# --- Tracing -------------------------------------------------------------------

func _on_trace_changed(text: String) -> void:
	if text.is_empty():
		return
	_say(text, Style.INK, false)


func _on_traced(cells: PackedInt32Array) -> void:
	if _done or cells.size() < 2:
		_hide_bubble()
		return
	var r: Dictionary = state.submit(cells)
	match r["result"]:
		LevelState.Result.FOUND:
			_on_found(r)
		LevelState.Result.TOO_SHORT:
			board.show_error(cells)
			_say("Words have 3+ letters", Style.MUTED)
		LevelState.Result.ALREADY_FOUND:
			board.show_error(cells)
			_say("Already found", Style.MUTED)
		LevelState.Result.NOT_A_WORD:
			state.record_mistake()
			board.show_error(cells)
			Audio.play("error", 1.0, -2.0)
			Haptics.error()
			_say("%s isn't hidden here" % r["word"], Style.ERROR)
			Profile.store_progress(puzzle.id, state)
		_:
			_hide_bubble()


func _on_found(r: Dictionary) -> void:
	var i: int = r["word_index"]
	board.show_found(i, r["revealed"], r["beacons"])
	words.mark_found(i)
	var col: Color = Style.lantern_color(state.found_count() - 1)
	_say(str(r["word"]), col)
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
	_refresh_hud()


func _say(text: String, color: Color, fade: bool = true) -> void:
	_bubble_label.text = text
	_bubble_label.add_theme_color_override("font_color", color)
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.08)
	if fade:
		_bubble_tween.tween_interval(1.1)
		_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.35)


func _hide_bubble() -> void:
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.2)


# --- Hints ---------------------------------------------------------------------

## Spark: one letter of a word. Free once a day, otherwise it costs coins.
## Coins are only taken when there is something to reveal.
func use_spark() -> void:
	if _done or state.hint_target() < 0:
		return
	if not Profile.use_free_spark() and not Profile.spend(Economy.SPARK_COST):
		_need_coins(Economy.SPARK_COST)
		return
	var r: Dictionary = state.apply_spark()
	Profile.record_hint()
	Audio.play("spark")
	board.show_spark(int(r["spark_cell"]))
	if r.get("result", -1) == LevelState.Result.FOUND:
		_on_found(r)
	else:
		words.queue_redraw()
		Profile.store_progress(puzzle.id, state)
		_say("Letter %d of %d" % [int(r["spark_count"]), str(puzzle.words[int(r["word_index"])]["word"]).length()], Style.GOLD)
	_refresh_hud()


## Lantern: lights a whole word.
func use_lantern() -> void:
	if _done or state.hint_target() < 0:
		return
	if not Profile.spend(Economy.LANTERN_COST):
		_need_coins(Economy.LANTERN_COST)
		return
	var r: Dictionary = state.apply_lantern()
	Profile.record_hint()
	Audio.play("lantern")
	_on_found(r)


func _need_coins(cost: int) -> void:
	var o: MessageCard = MessageCard.new()
	o.title_text = "Not enough coins"
	o.icon_name = "coin"
	o.icon_color = Style.GOLD
	o.message = "This hint costs %d coins and you have %d.\n\nEarn coins by clearing new levels (+%d), playing the daily lantern (+%d or more) and unlocking achievements. Your first Spark each day is free." % [cost, Profile.coins(), Economy.LEVEL_REWARD, Economy.DAILY_REWARD]
	o.buttons = [["Keep playing", "primary", func() -> void: o.close()]]
	app.open(o)


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_action_pressed("hint") and app.top_overlay() == null:
		use_spark()


# --- Completion ------------------------------------------------------------------

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
	Audio.play("complete")
	await get_tree().create_timer(1.3).timeout
	if not is_inside_tree():
		return
	var card: ResultCard = ResultCard.new()
	card.play = self
	card.reward = reward
	app.open(card)


## Where "Next" goes after a clear.
func go_next() -> void:
	if not daily_key.is_empty():
		app.go("home")
	elif level_n < Catalog.LEVELS_PER_WORLD:
		app.go("play", {"world": world_idx, "level": level_n + 1}, false)
	elif world_idx + 1 < Catalog.world_count() and Profile.world_unlocked(world_idx + 1):
		app.go("levels", {"world": world_idx + 1}, false)
	else:
		app.go("worlds", {}, false)


func restart() -> void:
	Profile.clear_progress(puzzle.id)
	app.go("play", args, false)


# --- Pause, intros and Back ------------------------------------------------------

func _open_pause() -> void:
	if _done:
		return
	board.cancel_trace()
	var o: PauseCard = PauseCard.new()
	o.play = self
	app.open(o)


func on_back() -> bool:
	if puzzle == null:
		return false
	if not _done:
		_open_pause()
	return true


## First-time explanations: the basics on level 1, shadows and beacons when they appear.
func _intro_if_needed() -> void:
	if daily_key.is_empty() and puzzle != null:
		var intros: Dictionary = Catalog.world(world_idx).get("intros", {})
		var key: String = str(intros.get(str(level_n), ""))
		if not key.is_empty() and not Profile.seen("intro_" + key):
			Profile.mark_seen("intro_" + key)
			await get_tree().create_timer(0.45).timeout
			var o: HowToCard = HowToCard.new()
			o.pages = [key]
			o.closed.connect(_show_ghost_if_tutorial)
			app.open(o)
			return
	_show_ghost_if_tutorial()


## On the very first level, a ghost finger shows how to trace the first word.
func _show_ghost_if_tutorial() -> void:
	if world_idx == 0 and level_n == 1 and state.found_count() == 0 and is_inside_tree():
		var target: int = state.hint_target()
		if target >= 0:
			board.show_ghost(puzzle.words[target]["cells"])
