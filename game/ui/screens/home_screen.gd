extends Screen
## Title screen: Shop, keys, coins and Settings along the top; the name; a live
## demo board; and one centred column with Play (and where it continues),
## Chapters and Awards, and today's daily lantern.

var _daily_status: Label
var _daily_btn: Button


func build() -> void:
	Audio.music("menu")
	body.add_theme_constant_override("separation", 16)
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	top.custom_minimum_size.y = 92
	var shop: Button = UIKit.icon_button("art:bag", Style.TOP_BUTTON)
	shop.name = "Shop"
	shop.pressed.connect(func() -> void: app.go("shop"))
	top.add_child(shop)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var keys: CounterChip = UIKit.key_chip()
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(keys)
	var coins: CounterChip = UIKit.coin_chip()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coins)
	var settings: Button = UIKit.icon_button("settings", Style.TOP_BUTTON)
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings())
	top.add_child(settings)
	body.add_child(top)

	var title_box: VBoxContainer = UIKit.vbox(2)
	var title: Label = UIKit.label("Word Lantern", 78, Style.INK, 700)
	title.name = "Title"
	title.add_theme_color_override("font_shadow_color", Color(Style.AMBER, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 18)
	title_box.add_child(title)
	title_box.add_child(UIKit.caption("Trace the words · light the night", Style.AMBER))
	body.add_child(title_box)

	body.add_child(DemoBoard.new())

	# One centred column for every action, all the same width.
	var column: VBoxContainer = UIKit.vbox(16)
	column.custom_minimum_size.x = 560
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var next: Array[int] = Profile.next_level()
	var ch: Dictionary = Catalog.chapter(next[0])
	var all_done: bool = Profile.stat("levels") >= Catalog.total_levels()
	var play: Button = UIKit.button("Play", "primary", Style.AMBER, 112, 40, "play")
	play.name = "Play"
	play.pressed.connect(func() -> void:
		if all_done:
			app.go("chapters")
		else:
			app.go("play", {"chapter": next[0], "level": next[1]})
	)
	column.add_child(play)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play.resized.connect(func() -> void: play.pivot_offset = play.size / 2)
	play.button_down.connect(func() -> void: pulse.kill())
	# Where Play continues: just the chapter and the level.
	var where: Label = UIKit.label("Every lantern is lit" if all_done else "%s · Level %d" % [ch.get("name", ""), next[1]], Style.SIZE_SMALL + 1, Style.MUTED, 600)
	where.name = "NextLevel"
	column.add_child(where)
	var row: HBoxContainer = UIKit.hbox(16)
	var chapters: Button = UIKit.button("Chapters", "soft", Style.AMBER, 84, 26, "layout-grid")
	chapters.name = "Chapters"
	chapters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapters.pressed.connect(func() -> void: app.go("chapters"))
	row.add_child(chapters)
	var awards: Button = UIKit.button("Awards", "soft", Style.AMBER, 84, 26, "art:trophy")
	awards.name = "Awards"
	awards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	awards.pressed.connect(func() -> void: app.open(AchievementsCard.new()))
	row.add_child(awards)
	column.add_child(row)
	column.add_child(_daily_card())
	body.add_child(column)

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_daily)
	add_child(timer)
	_update_daily()


func _daily_card() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	row.add_child(UIKit.art_rect("calendar", 60))
	var mid: VBoxContainer = UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label("Daily lantern", Style.SIZE_BODY, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT))
	_daily_status = UIKit.label("", Style.SIZE_CAPTION + 1, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	_daily_status.name = "DailyStatus"
	_daily_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_daily_status)
	row.add_child(mid)
	_daily_btn = UIKit.button("Play", "primary", Color("B9A4FF"), 72, 26)
	_daily_btn.name = "Daily"
	_daily_btn.custom_minimum_size.x = 140
	_daily_btn.pressed.connect(func() -> void: app.go("play", {"daily": Catalog.today_key()}))
	row.add_child(_daily_btn)
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.lip_box(Style.PANEL, 30, Style.LIP, 6, Vector2(20, 14)))
	p.add_child(row)
	return p


func _update_daily() -> void:
	var today: String = Catalog.today_key()
	var streak: int = Profile.current_streak()
	var streak_text: String = "%d-day streak" % streak if streak > 0 else "Start a streak"
	if Profile.daily_done(today):
		var now: Dictionary = Time.get_time_dict_from_system()
		var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_daily_status.text = "Done · %s · next in %dh %02dm" % [streak_text, left / 3600, (left % 3600) / 60]
		_daily_btn.text = "Replay"
	else:
		_daily_status.text = "%s · +%d coins" % [streak_text, Economy.daily_reward(streak + 1)]
		_daily_btn.text = "Play"


func refresh() -> void:
	_update_daily()

