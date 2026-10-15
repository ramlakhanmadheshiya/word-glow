class_name SettingsCard
extends Overlay
## Settings, laid out like Single Shot's: volume sliders, vibration, the look
## (colour theme and lantern style), help and info, and Reset progress, which is
## hidden while a level is being played so stars can't be wiped by accident.


var _confirm_reset: bool = false


func build() -> void:
	name = "Settings"
	add_title("Settings")
	body.add_child(UIKit.slider_row("Music", "music", float(Profile.setting("music_volume", 0.6)), func(v: float) -> void: Profile.set_setting("music_volume", v)))
	body.add_child(UIKit.slider_row("Sound", "volume-2", float(Profile.setting("sound_volume", 0.8)), func(v: float) -> void: Profile.set_setting("sound_volume", v)))
	body.add_child(UIKit.toggle_row("Vibration", "sparkles", bool(Profile.setting("haptics", true)), func(on: bool) -> void: Profile.set_setting("haptics", on)))
	body.add_child(UIKit.gap(6))
	var looks: HBoxContainer = UIKit.hbox(14)
	looks.add_child(_look_button("Colours", Look.theme_name(Look.theme_id()), "palette", "themes"))
	looks.add_child(_look_button("Lanterns", Look.style_name(Look.style_id()), "lantern", "styles"))
	body.add_child(looks)
	body.add_child(UIKit.gap(6))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	# Info cards open on top of Settings and return to it when closed;
	# Shop leaves Settings for the shop screen.
	var items: Array = [
		["How to play", "HowToPlay", "circle-help", func() -> void: open_child(HowToCard.new())],
		["Shop", "ShopButton", "shopping-bag", func() -> void:
			close()
			app.go("shop")],
		["Awards", "Achievements", "trophy", func() -> void: open_child(AchievementsCard.new())],
		["About", "About", "info", func() -> void: open_child(AboutCard.new())],
		["Credits", "Credits", "users", func() -> void: open_child(CreditsCard.new())],
	]
	var provider: Node = AdManager.provider
	if provider != null and provider.has_method("privacy_options_required") and provider.privacy_options_required():
		items.append(["Ad privacy", "Privacy", "shield", func() -> void: provider.show_privacy_options()])
	for item: Array in items:
		var b: Button = UIKit.button(str(item[0]), "soft", Style.AMBER, 76, 23, str(item[2]))
		b.name = str(item[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(item[3])
		grid.add_child(b)
	if app.screen == null or not app.screen.in_game():
		var reset: Button = UIKit.button("Reset progress", "ghost", Style.AMBER, 72, 23)
		reset.name = "Reset"
		reset.add_theme_color_override("font_color", Style.ERROR)
		reset.add_theme_color_override("font_hover_color", Style.ERROR)
		# Like Single Shot: the first tap asks, the second tap erases.
		reset.pressed.connect(func() -> void:
			if not _confirm_reset:
				_confirm_reset = true
				reset.text = "Tap again to erase all progress"
				Haptics.error()
				return
			close()
			app.reset_progress()
		)
		body.add_child(reset)
	var version: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	body.add_child(UIKit.caption("Word Lantern %s · made with Godot" % version, Style.MUTED, 16))
	if _confirm_reset == false and app.screen != null and not app.screen.in_game():
		body.add_child(UIKit.para("Reset keeps your settings, packs, keys and bought coins.", Style.SIZE_CAPTION))


## A card showing the current colour theme or lantern style; opens its picker.
func _look_button(title: String, current: String, icon_name: String, mode: String) -> Button:
	var b: Button = UIKit.button("", "ghost", Style.AMBER, 100, 22)
	b.name = "Pick" + title
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		var p: PickerCard = PickerCard.new()
		p.mode = mode
		open_child(p)
	)
	var row: HBoxContainer = UIKit.hbox(14, BoxContainer.ALIGNMENT_BEGIN)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var dot: PanelContainer = UIKit.panel(UIKit.icon_rect(icon_name, 26, Style.AMBER), Color(Style.AMBER, 0.16), 26, Vector2(13, 13))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	var text: VBoxContainer = UIKit.vbox(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(UIKit.label(title, 25, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT))
	var cur: Label = UIKit.label(current, 18, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	cur.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(cur)
	row.add_child(text)
	return b
