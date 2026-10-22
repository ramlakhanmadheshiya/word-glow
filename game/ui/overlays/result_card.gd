class_name ResultCard
extends Overlay
## Shown when a level or daily is cleared: the stars pop in, coins count up,
## and notes for a new best, a finished chapter or a newly opened one.
## Next goes on; Again, Levels and Home sit underneath, like Single Shot.

const TITLES: Array[String] = ["", "Cleared", "Nicely done", "Perfect!"]

var play: Node
var reward: Dictionary = {}


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Result"
	body.add_theme_constant_override("separation", 12)
	var daily: bool = not play.daily_key.is_empty()
	var stars: int = int(reward.get("stars", play.state.stars()))
	var acc: Color = play.accent()
	var where: String = "Daily puzzle" if daily else "%s · Level %d" % [Catalog.chapter(play.chapter_idx)["name"], play.level_n]
	body.add_child(UIKit.caption(where, acc))
	var title: Label = UIKit.label(TITLES[clampi(stars, 1, 3)], Style.SIZE_H1 + 6, Style.INK, 600)
	title.name = "ResultTitle"
	body.add_child(title)
	var row: StarRow = StarRow.new()
	row.name = "Stars"
	body.add_child(row)
	row.play(stars)
	body.add_child(UIKit.label(_verdict(), Style.SIZE_BODY - 2, Style.INK, 500))
	body.add_child(UIKit.label("%s · %d words · %d moves" % [play.puzzle.theme_name, play.puzzle.words.size(), play.state.moves()], Style.SIZE_SMALL, Style.MUTED, 500))

	var coins: int = int(reward.get("coins", 0))
	if coins > 0:
		var coin_row: HBoxContainer = UIKit.hbox(12)
		coin_row.add_child(UIKit.art_rect("coin", 52))
		var amount: Label = UIKit.label("+0", 40, Style.GOLD, 700)
		amount.name = "Reward"
		coin_row.add_child(amount)
		body.add_child(coin_row)
		var tw: Tween = create_tween()
		tw.tween_interval(1.1)
		tw.tween_method(func(v: float) -> void: amount.text = "+%d" % int(v), 0.0, float(coins), 0.6)
		tw.tween_callback(func() -> void: Audio.play("coin"))
	elif not bool(reward.get("first", true)):
		body.add_child(UIKit.para("Rewards are paid once per level, and for each new star.", Style.SIZE_CAPTION))
	if not daily and not bool(reward.get("first", true)) and int(reward.get("new_stars", 0)) > 0:
		body.add_child(_note("star-filled", "New best: %d stars" % int(reward["best"]), Style.GOLD))
	if daily:
		body.add_child(_note("flame", "%d-day streak · a new daily arrives tomorrow" % int(reward.get("streak", 1)), Color("FF8A3D")))
	if bool(reward.get("chapter_key", false)):
		body.add_child(_note("star", "+1 chapter key: open any locked chapter", Color("5FC8FF")))
	if bool(reward.get("chapter_done", false)):
		body.add_child(_note("trophy", "Chapter complete! +%d bonus coins" % Economy.CHAPTER_BONUS, Style.GOLD))
	if bool(reward.get("chapter_unlocked", false)):
		var nc: Dictionary = Catalog.chapter(play.chapter_idx + 1)
		if not nc.is_empty():
			body.add_child(_note("lock", "New chapter open: %s" % nc["name"], nc["accent"]))
			get_tree().create_timer(1.0).timeout.connect(func() -> void: Audio.play("unlock"))

	body.add_child(UIKit.gap(4))
	var next_text: String = "Home"
	if not daily:
		next_text = "Next level" if play.level_n < Catalog.levels_per_chapter else "Next chapter"
	var next: Button = UIKit.button(next_text, "primary", acc, 100, 34, "arrow-right")
	next.name = "Next"
	next.pressed.connect(func() -> void: _leave(Callable(play, "go_next")))
	body.add_child(next)
	var actions: HBoxContainer = UIKit.hbox(24)
	actions.add_child(_action("rotate-ccw", "AGAIN", "Again", func() -> void: _leave(Callable(play, "restart"))))
	if not daily:
		actions.add_child(_action("layout-grid", "LEVELS", "Levels", func() -> void: _leave(app.go.bind("levels", {"chapter": play.chapter_idx}))))
	actions.add_child(_action("share-2", "SHARE", "Share", func() -> void: open_child(_share_card())))
	actions.add_child(_action("house", "HOME", "Home", func() -> void: _leave(app.go.bind("home"))))
	body.add_child(actions)


## Leaves the result. After every few cleared levels a short video plays first
## (see AdManager.after_level). `then` belongs to the game screen or the App, so
## it still runs after this card has gone.
func _leave(then: Callable) -> void:
	close()
	if play.daily_key.is_empty():
		AdManager.after_level(then)
	else:
		then.call()


func _share_card() -> ShareCardOverlay:
	var o: ShareCardOverlay = ShareCardOverlay.new()
	o.info = {
		"puzzle": play.puzzle, "state": play.state, "stars": int(reward.get("stars", play.state.stars())),
		"title": TITLES[clampi(int(reward.get("stars", 1)), 1, 3)], "verdict": _verdict(),
		"chapter": "Daily puzzle" if not play.daily_key.is_empty() else str(Catalog.chapter(play.chapter_idx)["name"]),
		"number": play.level_n, "daily": play.daily_key, "accent": play.accent(), "sky": play.sky(),
	}
	return o


## How the solve went, in a few words.
func _verdict() -> String:
	var m: int = play.state.mistakes
	var h: int = play.state.hints_used
	if m == 0 and h == 0:
		return "No wrong words, no hints."
	var parts: PackedStringArray = PackedStringArray()
	if m > 0:
		parts.append("%d wrong %s" % [m, "word" if m == 1 else "words"])
	if h > 0:
		parts.append("%d %s" % [h, "hint" if h == 1 else "hints"])
	return " · ".join(parts)


func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(6)
	var b: Button = UIKit.icon_button(icon_name, 76)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 15))
	return box


func _note(icon_name: String, text: String, tint: Color) -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(12)
	row.add_child(UIKit.icon_rect(icon_name, 34, tint))
	var l: Label = UIKit.label(text, Style.SIZE_SMALL, Style.INK, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return UIKit.panel(row, Color(tint, 0.14), 26, Vector2(20, 10))


func on_back() -> void:
	_leave(Callable(play, "go_next"))
