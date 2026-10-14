class_name ResultCard
extends Overlay
## Shown when a level or daily is cleared: the lantern lights, coins count up,
## badges for flawless clears, streaks and unlocks, then Next.

var play: Node
var reward: Dictionary = {}


func _init() -> void:
	super._init()
	dismissable = false


func build() -> void:
	name = "Result"
	body.add_theme_constant_override("separation", 14)
	var daily: bool = not play.daily_key.is_empty()
	var art: LanternArt = LanternArt.new(200)
	art.color = play.accent
	art.lit = 0.0
	art.letter = ""
	body.add_child(art)
	create_tween().tween_property(art, "lit", 1.0, 0.9).set_delay(0.15)
	var title: String = "Daily lantern lit!" if daily else "Lantern lit!"
	body.add_child(UIKit.label(title, Style.SIZE_H1, Style.INK, 600))
	var sub: String
	if daily:
		sub = "%s · %d words" % [play.puzzle.theme_name, play.puzzle.words.size()]
	else:
		sub = "%s · Level %d · %s" % [Catalog.world(play.world_idx)["name"], play.level_n, play.puzzle.theme_name]
	body.add_child(UIKit.caption(sub))
	body.add_child(UIKit.gap(4))

	var badges: HBoxContainer = UIKit.hbox(12)
	if bool(reward.get("flawless", false)):
		badges.add_child(_badge("star-filled", "No hints", Style.GOLD))
	if daily:
		badges.add_child(_badge("flame", "%d-day streak" % int(reward.get("streak", 1)), Color("FF8A3D")))
	if play.state.mistakes == 0:
		badges.add_child(_badge("check", "No misses", Style.SUCCESS))
	if badges.get_child_count() > 0:
		body.add_child(badges)

	var coins: int = int(reward.get("coins", 0))
	if coins > 0:
		var coin_row: HBoxContainer = UIKit.hbox(12)
		coin_row.add_child(UIKit.icon_rect("coin", 48, Style.GOLD))
		var amount: Label = UIKit.label("+0", 44, Style.GOLD, 700)
		amount.name = "Reward"
		coin_row.add_child(amount)
		body.add_child(coin_row)
		var tw: Tween = create_tween()
		tw.tween_interval(0.5)
		tw.tween_method(func(v: float) -> void: amount.text = "+%d" % int(v), 0.0, float(coins), 0.7)
		tw.tween_callback(func() -> void: Audio.play("coin"))
	elif not bool(reward.get("first", true)):
		body.add_child(UIKit.para("Already cleared before: rewards are paid once.", Style.SIZE_SMALL))

	if bool(reward.get("world_done", false)):
		body.add_child(_note("trophy", "World complete! +%d bonus" % Economy.WORLD_BONUS, Style.GOLD))
	if bool(reward.get("world_unlocked", false)):
		var nw: Dictionary = Catalog.world(play.world_idx + 1)
		if not nw.is_empty():
			body.add_child(_note("lock", "New world unlocked: %s" % nw["name"], nw["accent"]))
			get_tree().create_timer(0.9).timeout.connect(func() -> void: Audio.play("unlock"))
	if daily:
		body.add_child(UIKit.para("A new daily lantern arrives tomorrow.", Style.SIZE_SMALL))

	body.add_child(UIKit.gap(6))
	var next_text: String = "Home" if daily else ("Next level" if play.level_n < Catalog.LEVELS_PER_WORLD else "Continue")
	var next: Button = UIKit.button(next_text, "primary", play.accent, 100, 34, "arrow-right")
	next.name = "Next"
	next.pressed.connect(func() -> void:
		close()
		play.go_next()
	)
	body.add_child(next)
	if not daily:
		var levels: Button = UIKit.button("Level list", "soft", play.accent, 84, 28, "layout-grid")
		levels.name = "Levels"
		levels.pressed.connect(func() -> void:
			close()
			app.back()
		)
		body.add_child(levels)


func _badge(icon_name: String, text: String, tint: Color) -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(8)
	row.add_child(UIKit.icon_rect(icon_name, 28, tint))
	row.add_child(UIKit.label(text, Style.SIZE_CAPTION, Style.INK, 600))
	return UIKit.panel(row, Color(tint, 0.16), 24, Vector2(16, 8))


func _note(icon_name: String, text: String, tint: Color) -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(12)
	row.add_child(UIKit.icon_rect(icon_name, 36, tint))
	var l: Label = UIKit.label(text, Style.SIZE_SMALL, Style.INK, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return UIKit.panel(row, Color(tint, 0.14), 26, Vector2(20, 12))


func on_back() -> void:
	close()
	play.go_next()
