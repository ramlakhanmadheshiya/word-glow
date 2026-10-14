class_name SettingsCard
extends Overlay
## Sound, music and vibration switches, help and info pages, and progress reset.


func build() -> void:
	name = "Settings"
	add_title("Settings")
	body.add_child(UIKit.toggle_row("Music", "music", Profile.setting("music"), func(on: bool) -> void: Profile.set_setting("music", on)))
	body.add_child(UIKit.toggle_row("Sounds", "volume-2", Profile.setting("sfx"), func(on: bool) -> void: Profile.set_setting("sfx", on)))
	body.add_child(UIKit.toggle_row("Vibration", "sparkles", Profile.setting("haptics"), func(on: bool) -> void: Profile.set_setting("haptics", on)))
	body.add_child(UIKit.gap(8))
	for item: Array in [["How to play", "circle-help", func() -> Overlay: return HowToCard.new()],
			["Achievements", "trophy", func() -> Overlay: return AchievementsCard.new()],
			["About", "info", func() -> Overlay: return AboutCard.new()],
			["Credits", "heart", func() -> Overlay: return CreditsCard.new()]]:
		var b: Button = UIKit.button(str(item[0]), "soft", Style.AMBER, 84, 28, str(item[1]))
		b.name = str(item[0]).replace(" ", "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var make: Callable = item[2]
		b.pressed.connect(func() -> void:
			close()
			app.open(make.call())
		)
		body.add_child(b)
	body.add_child(UIKit.gap(8))
	var in_level: bool = app.screen_name == "play"
	if not in_level:
		var reset: Button = UIKit.button("Reset progress", "ghost", Style.AMBER, 76, 24)
		reset.name = "Reset"
		reset.add_theme_color_override("font_color", Style.ERROR)
		reset.pressed.connect(func() -> void:
			close()
			MessageCard.confirm(app, "Reset all progress?", "Every cleared level, coin, streak and achievement will be erased. Settings are kept. This cannot be undone.", "Erase progress", func() -> void:
				Profile.reset_all()
				app.toast("Progress reset", "rotate-ccw")
				app.go("home")
			, true)
		)
		body.add_child(reset)
	var version: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	body.add_child(UIKit.para("Word Lantern %s · Progress is saved on this device." % version, Style.SIZE_CAPTION))
