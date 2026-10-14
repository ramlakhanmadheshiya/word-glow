extends Screen
## Title screen, laid out like Single Shot's: Shop and Settings at the top, the
## name, a live demo board, one obvious pulsing Play button with a chip saying
## where it continues, Chapters, and today's daily lantern.

var _daily_status: Label
var _daily_btn: Button


func build() -> void:
	Audio.music("menu")
	var top: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	top.custom_minimum_size.y = 92
	var shop: Button = UIKit.icon_button("shopping-bag", 80)
	shop.name = "Shop"
	shop.pressed.connect(func() -> void: app.go("shop"))
	top.add_child(shop)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var coins: CounterChip = UIKit.coin_chip()
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coins)
	var settings: Button = UIKit.icon_button("settings", 80)
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings())
	top.add_child(settings)
	body.add_child(top)

	var title_box: VBoxContainer = UIKit.vbox(0)
	var icon: TextureRect = TextureRect.new()
	icon.name = "Logo"
	icon.texture = load("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(92, 92)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_box.add_child(icon)
	var title: Label = UIKit.label("Word Lantern", 72, Style.INK, 600)
	title.name = "Title"
	title_box.add_child(title)
	title_box.add_child(UIKit.caption("Trace the words · light the night", Style.AMBER))
	body.add_child(title_box)

	var demo: DemoBoard = DemoBoard.new()
	body.add_child(demo)

	var bottom: VBoxContainer = UIKit.vbox(14)
	var next: Array[int] = Profile.next_level()
	var ch: Dictionary = Catalog.chapter(next[0])
	var all_done: bool = Profile.stat("levels") >= Catalog.total_levels()
	var play: Button = UIKit.button("Play", "primary", Style.AMBER, 104, 38, "play")
	play.name = "Play"
	play.custom_minimum_size.x = 340
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func() -> void:
		if all_done:
			app.go("chapters")
		else:
			app.go("play", {"chapter": next[0], "level": next[1]})
	)
	bottom.add_child(play)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	play.resized.connect(func() -> void: play.pivot_offset = play.size / 2)
	play.button_down.connect(func() -> void: pulse.kill())
	var chip: ContinueChip = ContinueChip.new()
	chip.name = "Continue"
	chip.dot = Look.accent(ch)
	chip.text = "Every lantern is lit" if all_done else "%s · LEVEL %d" % [str(ch.get("name", "")).to_upper(), next[1]]
	chip.stars = Profile.total_stars()
	bottom.add_child(chip)
	var row: HBoxContainer = UIKit.hbox(14)
	var chapters: Button = UIKit.button("Chapters", "ghost", Style.AMBER, 80, 26, "layout-grid")
	chapters.name = "Chapters"
	chapters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapters.pressed.connect(func() -> void: app.go("chapters"))
	row.add_child(chapters)
	var awards: Button = UIKit.button("Awards", "ghost", Style.AMBER, 80, 26, "trophy")
	awards.name = "Awards"
	awards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	awards.pressed.connect(func() -> void: app.open(AchievementsCard.new()))
	row.add_child(awards)
	bottom.add_child(row)
	bottom.add_child(_daily_card())
	body.add_child(bottom)

	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_update_daily)
	add_child(timer)
	_update_daily()


func _daily_card() -> PanelContainer:
	var row: HBoxContainer = UIKit.hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	row.add_child(UIKit.icon_rect("calendar", 52, Color("C9A7FF")))
	var mid: VBoxContainer = UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label("Daily lantern", Style.SIZE_BODY, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT))
	_daily_status = UIKit.label("", Style.SIZE_CAPTION + 1, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	_daily_status.name = "DailyStatus"
	mid.add_child(_daily_status)
	row.add_child(mid)
	_daily_btn = UIKit.button("Play", "primary", Color("C9A7FF"), 72, 26)
	_daily_btn.name = "Daily"
	_daily_btn.custom_minimum_size.x = 140
	_daily_btn.pressed.connect(func() -> void: app.go("play", {"daily": Catalog.today_key()}))
	row.add_child(_daily_btn)
	return UIKit.panel(row, Color(0, 0, 0, 0.25), 34, Vector2(22, 14))


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


## "● MEADOW · LEVEL 13   ★ 34": where Play continues, and the stars so far.
class ContinueChip:
	extends Control
	var dot: Color = Style.AMBER
	var text: String = ""
	var stars: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 42)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f: Font = UIKit.font(700)
		var fs: int = 19
		var star_text: String = "★ %d" % stars
		var w1: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w2: float = f.get_string_size(star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pad: float = 20.0
		var total: float = 24.0 + w1 + 26.0 + w2 + pad * 2.0
		var r: Rect2 = Rect2(Vector2((size.x - total) * 0.5, 0), Vector2(total, size.y))
		draw_style_box(UIKit.box(Color(1, 1, 1, 0.07), int(size.y * 0.5)), r)
		var y: float = r.get_center().y
		var x: float = r.position.x + pad
		draw_circle(Vector2(x + 7.0, y), 7.0, dot, true, -1.0, true)
		x += 24.0
		var base: float = y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Style.INK, 0.75))
		x += w1 + 26.0
		draw_string(f, Vector2(x, base), star_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.GOLD)
