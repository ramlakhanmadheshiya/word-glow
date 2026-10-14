class_name PauseCard
extends Overlay
## In-level menu: resume, restart, quick sound toggles, and ways out.

var play: Node


func build() -> void:
	name = "Pause"
	add_title("Paused")
	var where: String = play.puzzle.theme_name
	body.add_child(UIKit.caption("%s · %d of %d words found" % [where, play.state.found_count(), play.puzzle.words.size()]))
	body.add_child(UIKit.gap(6))
	var resume: Button = UIKit.button("Resume", "primary", play.accent, 96, 32, "play")
	resume.name = "Resume"
	resume.pressed.connect(close)
	body.add_child(resume)
	var restart: Button = UIKit.button("Restart level", "soft", play.accent, 88, 28, "restart")
	restart.name = "Restart"
	restart.pressed.connect(func() -> void:
		close()
		MessageCard.confirm(app, "Restart this level?", "Found words will be cleared. Coins spent on hints are not refunded.", "Restart", play.restart)
	)
	body.add_child(restart)
	var row: HBoxContainer = UIKit.hbox(14)
	var levels: Button = UIKit.button("Levels" if play.daily_key.is_empty() else "Home", "soft", play.accent, 88, 28, "layout-grid" if play.daily_key.is_empty() else "house")
	levels.name = "Levels"
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.pressed.connect(func() -> void:
		close()
		app.back()
	)
	row.add_child(levels)
	var settings: Button = UIKit.button("Settings", "soft", play.accent, 88, 28, "settings")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(func() -> void:
		close()
		app.open(SettingsCard.new())
	)
	row.add_child(settings)
	body.add_child(row)
	body.add_child(UIKit.gap(4))
	body.add_child(UIKit.toggle_row("Music", "music", Profile.setting("music"), func(on: bool) -> void: Profile.set_setting("music", on)))
	body.add_child(UIKit.toggle_row("Sounds", "volume-2", Profile.setting("sfx"), func(on: bool) -> void: Profile.set_setting("sfx", on)))
	body.add_child(UIKit.para("Your progress in this level is saved automatically.", Style.SIZE_CAPTION))
