extends Node
## Screenshots of every screen at a given window size, for visual review.
## Runs the real app with a throwaway save. Needs a display (not --headless):
##
##   godot --path . res://tests/capture.tscn -- <out_dir> [width] [height]

const SAVE: String = "user://capture_save.json"

var out_dir: String = "/tmp/word_lantern_shots"
var app: App
var _n: int = 0


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() >= 1:
		out_dir = a[0]
	var win: Vector2i = Vector2i(450, 800)
	if a.size() >= 3:
		win = Vector2i(int(a[1]), int(a[2]))
	DisplayServer.window_set_size(win)
	DirAccess.make_dir_recursive_absolute(out_dir)
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music", false)
	Profile.set_setting("sfx", false)
	_seed_progress()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.6)
	await _shot("home")
	app.go("worlds")
	await _wait(0.7)
	await _shot("worlds")
	app.go("levels", {"world": 1})
	await _wait(0.7)
	await _shot("levels")
	# First level with its intro card, then the ghost-finger tutorial.
	Save.data["seen"] = {}
	app.go("play", {"world": 0, "level": 1})
	await _wait(1.4)
	await _shot("intro_basics")
	app.top_overlay().close()
	await _wait(0.8)
	await _shot("play_tutorial")
	# A shadows + beacons level mid-way, with a live trace.
	app.go("play", {"world": 4, "level": 12})
	await _wait(0.8)
	var play: Node = app.screen
	var p: Puzzle = play.puzzle
	var order: PackedInt32Array = LanternRules.solve_order(p)
	play.board.traced.emit(p.words[order[0]]["cells"])
	await _wait(1.4)
	play.use_spark()
	await _wait(0.4)
	var next: PackedInt32Array = p.words[order[1]]["cells"]
	play.board._begin(play.board.cell_center(next[0]))
	for k: int in range(1, next.size() - 1):
		play.board._drag(play.board.cell_center(next[k]))
	await _wait(0.3)
	await _shot("play_shadows")
	play.board._end()
	await _wait(0.3)
	play.board.traced.emit(PackedInt32Array([next[0], next[1], next[2]]))
	await _wait(0.15)
	await _shot("play_mistake")
	await _wait(1.2)
	play._open_pause()
	await _wait(0.6)
	await _shot("pause")
	app.top_overlay().close()
	await _wait(0.4)
	# Finish it for the result card.
	for i: int in LanternRules.solve_order(p):
		if play.state.found[i] == 0:
			play.board.traced.emit(p.words[i]["cells"])
			await _wait(0.15)
	await _wait(3.2)
	await _shot("result")
	app.top_overlay().close()
	await _wait(0.4)
	app.go("play", {"daily": Catalog.today_key()})
	await _wait(0.9)
	await _shot("daily")
	for o: Overlay in [SettingsCard.new(), AboutCard.new(), CreditsCard.new(), AchievementsCard.new()]:
		app.open(o)
		await _wait(0.7)
		await _shot(o.name.to_lower())
		o.close()
		await _wait(0.4)
	var how: HowToCard = HowToCard.new()
	app.open(how)
	for k: int in 4:
		await _wait(0.8)
		await _shot("howto_%d" % k)
		how._show(k + 1)
	how.close()
	await _wait(0.3)
	var msg: MessageCard = MessageCard.new()
	msg.title_text = "Not enough coins"
	msg.icon_name = "coin"
	msg.message = "This hint costs 60 coins and you have 12."
	msg.buttons = [["Keep playing", "primary", func() -> void: msg.close()]]
	app.open(msg)
	await _wait(0.6)
	await _shot("coins")
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	print("CAPTURE: %d screenshots in %s" % [_n, out_dir])
	get_tree().quit()


## A believable mid-game save: Meadow done, Harbor half way, some dailies.
func _seed_progress() -> void:
	for n: int in range(1, 21):
		Save.data["cleared"][Catalog.level_id("meadow", n)] = {"flawless": n % 3 != 0}
	for n: int in range(1, 9):
		Save.data["cleared"][Catalog.level_id("harbor", n)] = {"flawless": n % 2 == 0}
	Save.data["progress"][Catalog.level_id("harbor", 9)] = {"found": [0]}
	for w: String in ["orchard", "canyon", "glacier"]:
		for n: int in range(1, 16):
			Save.data["cleared"][Catalog.level_id(w, n)] = {"flawless": true}
	Save.data["stats"]["levels"] = 73
	Save.data["stats"]["words"] = 388
	Save.data["coins"] = 245
	Save.data["daily"]["streak"] = 3
	Save.data["daily"]["last_date"] = Catalog.date_key_from_day(Catalog.day_number(Catalog.today_key()) - 1)
	Save.data["seen"] = {"intro_basics": true, "intro_shadows": true, "intro_beacons": true}
	Profile.check_achievements()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, _n, name])
