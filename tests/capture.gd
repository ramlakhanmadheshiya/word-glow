extends Node
## Screenshots of every screen and card at a given window size, for visual
## review. Runs the real app with a throwaway save and the mock ad banner.
## Needs a display (not --headless):
##
##   godot --path . res://tests/capture.tscn -- <out_dir> [width] [height] [clean]
##
## "clean" hides the test ad banner (for store and website screenshots).

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
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Store.simulate = true
	if a.size() >= 4 and a[3] == "clean":
		AdManager.use_provider(null)
	_seed_progress()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.8)
	await _shot("home")
	app.go("chapters")
	await _wait(0.9)
	await _shot("chapters")
	app.go("levels", {"chapter": 4})
	await _wait(0.9)
	await _shot("levels")
	app.open(_locked(4, 30))
	await _wait(0.6)
	await _shot("locked")
	_close_intro()
	await _wait(0.3)
	# A mid-chapter level with shadows and a beacon, mid-way, with a live trace.
	app.go("play", {"chapter": 4, "level": 22})
	await _wait(1.0)
	_close_intro()
	await _wait(0.5)
	var play: Node = app.screen
	var p: Puzzle = play.puzzle
	var order: PackedInt32Array = LanternRules.solve_order(p)
	play.board.traced.emit(p.words[order[0]]["cells"])
	await _wait(1.3)
	play.use_spark()
	await _wait(1.6)
	var next: PackedInt32Array = p.words[order[1]]["cells"]
	play.board._begin(play.board.cell_center(next[0]))
	for k: int in range(1, next.size() - 1):
		play.board._drag(play.board.cell_center(next[k]))
	await _wait(0.3)
	await _shot("play")
	play.board._end()
	await _wait(0.2)
	for i: int in order:
		if play.state.found[i] == 0:
			play.board.traced.emit(p.words[i]["cells"])
			await _wait(0.15)
	await _wait(3.4)
	await _shot("result")
	_close_intro()
	await _wait(0.3)
	# Out of coins in a level.
	app.go("play", {"chapter": 0, "level": 3})
	await _wait(0.9)
	Save.data["coins"] = 10
	app.screen.use_lantern()
	await _wait(0.7)
	await _shot("out_of_coins")
	_close_intro()
	Save.data["coins"] = 1240
	await _wait(0.3)
	app.go("shop")
	await _wait(1.0)
	await _shot("shop")
	var scroll: TouchScroll = app.screen.find_child("Scroll", true, false)
	scroll.scroll_to(900)
	await _wait(0.4)
	await _shot("shop_more")
	for o: Overlay in [_product("complete_pack"), _product("theme_pack"), KeysCard.new(), TipCard.new(), _picker("themes"), _picker("styles"), SettingsCard.new(), AchievementsCard.new(), AboutCard.new(), CreditsCard.new()]:
		app.open(o)
		await _wait(0.8)
		await _shot(o.name.to_lower() + ("_" + str(o.get("mode")) if o is PickerCard else ("_" + str(o.get("product")) if o is ProductCard else "")))
		o.close()
		await _wait(0.35)
	var how: HowToCard = HowToCard.new()
	how.pages = ["stars"]
	app.open(how)
	await _wait(0.8)
	await _shot("howto_stars")
	how.close()
	await _wait(0.3)
	# The same level in a bought theme and lantern style.
	Save.data["owned"]["theme_pack"] = true
	Save.data["owned"]["style_pack"] = true
	Profile.set_setting("theme", "sakura")
	Profile.set_setting("style", "neon")
	app.go("play", {"chapter": 7, "level": 15})
	await _wait(1.0)
	_close_intro()
	await _wait(0.4)
	var p2: Node = app.screen
	var o2: PackedInt32Array = LanternRules.solve_order(p2.puzzle)
	for k: int in mini(3, o2.size()):
		p2.board.traced.emit(p2.puzzle.words[o2[k]]["cells"])
		await _wait(0.3)
	await _wait(1.2)
	await _shot("play_themed")
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))
	print("CAPTURE: %d screenshots in %s" % [_n, out_dir])
	get_tree().quit()


func _close_intro() -> void:
	var o: Overlay = app.top_overlay()
	if o != null:
		o.close()


func _locked(ci: int, n: int) -> LockedCard:
	var o: LockedCard = LockedCard.new()
	o.chapter_idx = ci
	o.level = n
	return o


func _product(id: String) -> ProductCard:
	var o: ProductCard = ProductCard.new()
	o.product = id
	return o


func _picker(mode: String) -> PickerCard:
	var o: PickerCard = PickerCard.new()
	o.mode = mode
	return o


## A believable mid-game save: four chapters done with mixed stars, the fifth
## half way, some keys and coins.
func _seed_progress() -> void:
	for ci: int in 5:
		var id: String = Catalog.chapter(ci)["id"]
		var upto: int = 40 if ci < 4 else 21
		for n: int in range(1, upto + 1):
			Save.data["cleared"][Catalog.level_id(id, n)] = {"stars": 3 if n % 4 != 0 else (2 if n % 3 != 0 else 1)}
	Save.data["progress"][Catalog.level_id("canyon", 22)] = {"found": []}
	Save.data["coins"] = 1240
	Save.data["keys"] = 3
	Save.data["stats"]["levels"] = 181
	Save.data["stats"]["stars"] = Profile.total_stars()
	Save.data["stats"]["words"] = 1104
	Save.data["daily"]["streak"] = 3
	Save.data["daily"]["last_date"] = Catalog.date_key_from_day(Catalog.day_number(Catalog.today_key()) - 1)
	Save.data["seen"] = {"intro_basics": true, "intro_shadows": true, "intro_beacons": true}
	Save.data["last_level"] = "canyon-22"
	Profile.check_achievements()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	_n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, _n, name])
