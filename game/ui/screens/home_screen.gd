extends Screen
## Main menu: the lantern logo, Continue, today's daily lantern, and the way to
## worlds, achievements, help and settings.

var _daily_status: Label
var _daily_btn: Button


func build() -> void:
	Audio.music("menu")
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	var settings: Button = UIKit.icon_button("settings", 84)
	settings.name = "Settings"
	settings.pressed.connect(func() -> void: app.open(SettingsCard.new()))
	top.add_child(settings)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(UIKit.coin_chip())
	body.add_child(top)

	var hero_space: Control = Control.new()
	hero_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(hero_space)
	var art: LanternArt = LanternArt.new(250)
	body.add_child(art)
	body.add_child(UIKit.label("Word Lantern", Style.SIZE_HERO, Style.INK, 600))
	body.add_child(UIKit.para("Trace the words. Light the night.", Style.SIZE_BODY, Style.MUTED))
	var low_space: Control = Control.new()
	low_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(low_space)

	var next: Array[int] = Profile.next_level()
	var w: Dictionary = Catalog.world(next[0])
	var all_done: bool = Profile.stat("levels") >= Catalog.world_count() * Catalog.LEVELS_PER_WORLD
	var play: Button = UIKit.button("Play" if not all_done else "Replay levels", "primary", Style.AMBER, 112, 38, "play")
	play.name = "Play"
	play.pressed.connect(func() -> void:
		if all_done:
			app.go("worlds")
		else:
			app.go("play", {"world": next[0], "level": next[1]}, true, {"name": "levels", "args": {"world": next[0]}})
	)
	body.add_child(play)
	var where: String = "Every lantern is lit. Thank you for playing!" if all_done else "%s · Level %d" % [w.get("name", ""), next[1]]
	var where_label: Label = UIKit.caption(where, Style.MUTED)
	where_label.name = "NextLevel"
	body.add_child(where_label)
	body.add_child(UIKit.gap(10))
	body.add_child(_daily_card())
	body.add_child(UIKit.gap(6))

	var row: HBoxContainer = UIKit.hbox(14)
	for item: Array in [["Worlds", "layout-grid"], ["Awards", "trophy"], ["Help", "circle-help"]]:
		var b: Button = UIKit.button(str(item[0]), "soft", Style.AMBER, 88, 26, str(item[1]))
		b.name = str(item[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		match item[0]:
			"Worlds":
				b.pressed.connect(func() -> void: app.go("worlds"))
			"Awards":
				b.pressed.connect(func() -> void: app.open(AchievementsCard.new()))
			"Help":
				b.pressed.connect(func() -> void: app.open(HowToCard.new()))
	body.add_child(row)
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_daily)
	add_child(timer)
	_update_daily()


func _daily_card() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	row.add_child(UIKit.icon_rect("calendar", 56, Color("C9A7FF")))
	var mid: VBoxContainer = UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label("Daily lantern", Style.SIZE_BODY, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT))
	_daily_status = UIKit.label("", Style.SIZE_CAPTION + 1, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	_daily_status.name = "DailyStatus"
	mid.add_child(_daily_status)
	row.add_child(mid)
	_daily_btn = UIKit.button("Play", "primary", Color("C9A7FF"), 76, 26)
	_daily_btn.name = "Daily"
	_daily_btn.custom_minimum_size.x = 150
	_daily_btn.pressed.connect(func() -> void: app.go("play", {"daily": Catalog.today_key()}))
	row.add_child(_daily_btn)
	var card: PanelContainer = UIKit.panel(row, Color(0, 0, 0, 0.25), 34, Vector2(24, 18))
	card.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.25), 34, Color("C9A7FF", 0.35), 2, Vector2(24, 18)))
	return card


func _update_daily() -> void:
	var today: String = Catalog.today_key()
	var streak: int = Profile.current_streak()
	var streak_text: String = "%d-day streak" % streak if streak > 0 else "Start a streak today"
	if Profile.daily_done(today):
		var now: Dictionary = Time.get_time_dict_from_system()
		var left: int = 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))
		_daily_status.text = "Done · %s · next in %dh %02dm" % [streak_text, left / 3600, (left % 3600) / 60]
		_daily_btn.text = "Replay"
		_daily_btn.icon = UIKit.icon("check")
	else:
		var reward: int = Economy.daily_reward(streak + 1)
		_daily_status.text = "%s · +%d coins" % [streak_text, reward]
		_daily_btn.text = "Play"
		_daily_btn.icon = null


func refresh() -> void:
	_update_daily()
