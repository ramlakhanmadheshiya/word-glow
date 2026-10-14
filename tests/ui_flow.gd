extends Node
## End-to-end flow through the real app with a throwaway save, the simulated
## store and the mock ad provider: home, chapters, levels, a locked level and a
## key, a full level with a wrong guess, stars and rewards, Restart, hints
## (free, paid, and by video when coins run out), the shop, settings, the daily,
## the ad banner's reserved space, and an app restart.
##
##   godot --headless --path . res://tests/ui_flow.tscn

const SAVE: String = "user://ui_flow_save.json"
const MockProvider: GDScript = preload("res://game/ads/providers/mock_ad_provider.gd")

var t: Check = Check.new("UI FLOW")
var app: App
var mock: Node


func _ready() -> void:
	_wipe()
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music_volume", 0.0)
	Profile.set_setting("sound_volume", 0.0)
	Store.simulate = true
	mock = MockProvider.new()
	mock.auto_finish = true
	AdManager.use_provider(mock)
	await _boot()
	await _banner_space()
	await _menus()
	await _first_level()
	await _locked_and_keys()
	await _hints_and_ads()
	await _restart_button()
	await _shop()
	await _settings()
	await _daily()
	await _restart_app()
	_wipe()
	get_tree().quit(t.report())


func _wipe() -> void:
	for s: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + s))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _boot() -> void:
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	await _wait(1.5)
	t.eq(app.screen_name, "home", "boots to the home screen")


func _find(root: Node, n: String) -> Node:
	return root.find_child(n, true, false) if root != null else null


func _press(root: Node, n: String) -> bool:
	var b: BaseButton = _find(root, n) as BaseButton
	if b == null:
		t.ok(false, "button %s exists" % n)
		return false
	b.pressed.emit()
	return true


func _play() -> Node:
	return app.screen


func _solve(play: Node) -> void:
	for i: int in LanternRules.solve_order(play.puzzle):
		if play.state.found[i] == 0:
			play.board.traced.emit(play.puzzle.words[i]["cells"])
			await _wait(0.05)


func _banner_space() -> void:
	t.ok(AdManager.banner_height > 0.0, "the banner is showing")
	var frame: MarginContainer = app.screen.get_child(0) as MarginContainer
	t.ok(frame.get_theme_constant("margin_bottom") >= int(AdManager.banner_height), "screens keep room for the banner")
	for n: String in ["Play", "Shop", "SettingsButton", "Chapters", "Daily"]:
		t.ok(_find(app.screen, n) != null, "home has %s" % n)


func _menus() -> void:
	_press(app.screen, "Chapters")
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "Chapters opens")
	var list: Node = _find(app.screen, "List")
	var cards: int = 0
	for c: Node in list.get_children():
		if c is ChapterCard:
			cards += 1
	t.eq(cards, 16, "16 chapter cards")
	_press(list, "Chapter_harbor")
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "a locked chapter does not open")
	_press(list, "Chapter_meadow")
	await _wait(0.6)
	t.eq(app.screen_name, "levels", "an open chapter shows its levels")
	var grid: Node = _find(app.screen, "Grid")
	t.eq(grid.get_child_count(), 40, "all 40 levels are shown, locked ones too")
	var locked: int = 0
	for tile: LevelTile in grid.get_children():
		if not tile.open:
			locked += 1
	t.eq(locked, 39, "39 locked levels are visible")
	t.ok((_find(app.screen, "Legend") as Label).text.contains("39 locked"), "the hero card counts locked levels")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "Back returns to chapters")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "home", "Back returns home")


func _first_level() -> void:
	var coins0: int = Profile.coins()
	_press(app.screen, "Play")
	await _wait(1.2)
	t.eq(app.screen_name, "play", "Play opens the first level")
	t.ok(app.top_overlay() is HowToCard, "the first level explains the rules")
	app.top_overlay().close()
	await _wait(0.5)
	var play: Node = _play()
	t.eq(play.puzzle.id, "meadow-01", "it is Meadow 1")
	for n: String in ["LevelsButton", "Spark", "Lantern", "Restart", "SettingsButton", "Back"]:
		t.ok(_find(play, n) != null, "the game screen has %s" % n)
	var wrong: PackedInt32Array = _wrong_path(play.state)
	play.board.traced.emit(wrong)
	await _wait(0.1)
	t.eq(play.state.found_count(), 0, "a wrong guess finds nothing")
	t.eq(play.state.stars(), 2, "a wrong guess costs a star")
	t.eq(Profile.coins(), coins0, "a wrong guess costs no coins")
	await _solve(play)
	await _wait(2.6)
	var card: Overlay = app.top_overlay()
	t.ok(card is ResultCard, "the result card appears")
	t.eq((_find(card, "ResultTitle") as Label).text, "Nicely done", "2-star title")
	t.eq(Profile.stars_for("meadow-01"), 2, "2 stars recorded")
	t.ok(Profile.coins() >= coins0 + Economy.LEVEL_REWARD + 2 * Economy.STAR_REWARD, "clear reward paid")
	_press(card, "Again")
	await _wait(0.8)
	play = _play()
	t.eq(play.state.stars(), 3, "Again starts fresh with 3 stars on offer")
	await _solve(play)
	await _wait(2.6)
	t.eq(Profile.stars_for("meadow-01"), 3, "a perfect replay records 3 stars")
	t.eq((_find(app.top_overlay(), "ResultTitle") as Label).text, "Perfect!", "3-star title")
	_press(app.top_overlay(), "Next")
	await _wait(0.9)
	t.eq(_play().puzzle.id, "meadow-02", "Next opens level 2")


func _locked_and_keys() -> void:
	app.go("levels", {"chapter": 0})
	await _wait(0.7)
	_press(_find(app.screen, "Grid"), "Level9")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is LockedCard, "a locked level explains how it opens")
	t.ok((_find(card, "UseKey") as Button).disabled, "no keys: Use a key is disabled")
	card.close()
	await _wait(0.4)
	Profile.add_keys(1)
	_press(_find(app.screen, "Grid"), "Level9")
	await _wait(0.5)
	_press(app.top_overlay(), "UseKey")
	await _wait(0.9)
	t.eq(app.screen_name, "play", "a key opens the level and plays it")
	t.eq(_play().puzzle.id, "meadow-09", "it is level 9")
	t.eq(Profile.keys(), 0, "the key is spent")


func _hints_and_ads() -> void:
	var play: Node = _play()
	Save.data["sparks"]["day"] = ""
	var coins0: int = Profile.coins()
	_press(play, "Spark")
	await _wait(0.1)
	t.eq(Profile.coins(), coins0, "the first spark of the day is free")
	t.eq(play.state.stars(), 2, "a hint costs a star")
	_press(play, "Spark")
	await _wait(0.1)
	t.eq(Profile.coins(), coins0 - Economy.SPARK_COST, "the next spark costs coins")
	# Out of coins: the game offers a video for the hint.
	Save.data["coins"] = 5
	var hints: int = play.state.hints_used
	_press(play, "Lantern")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is MessageCard and card.name == "OutOfCoins", "out of coins: a video is offered")
	t.eq(play.state.hints_used, hints, "no hint before the video")
	_press(card, "Watchavideo")
	await _wait(0.5)
	t.eq(play.state.hints_used, hints + 1, "after the video, the hint is given")
	t.eq(Profile.coins(), 5, "and no coins are taken")
	mock.earn = false
	_press(play, "Lantern")
	await _wait(0.4)
	_press(app.top_overlay(), "Watchavideo")
	await _wait(0.5)
	t.eq(play.state.hints_used, hints + 1, "a skipped video gives no hint")
	mock.earn = true
	Save.data["coins"] = 500


func _restart_button() -> void:
	var play: Node = _play()
	t.ok(play.state.found_count() > 0 or play.state.extra_moves() > 0, "the level has progress")
	_press(play, "Restart")
	await _wait(0.4)
	t.ok(app.top_overlay() is MessageCard, "Restart asks first")
	_press(app.top_overlay(), "Restart")
	await _wait(0.9)
	t.eq(_play().state.found_count(), 0, "Restart clears found words")
	t.eq(_play().state.stars(), 3, "Restart puts 3 stars back on offer")
	t.ok(Profile.saved_progress("meadow-09").is_empty(), "Restart clears saved progress")


func _shop() -> void:
	app.go("shop")
	await _wait(0.7)
	t.eq(app.screen_name, "shop", "the shop opens")
	for id: String in Store.PRODUCTS:
		t.ok(_find(app.screen, "Product_" + id) != null, "the shop lists %s" % id)
	var coins: int = Profile.coins()
	_press(app.screen, "Buy_coins_300")
	await _wait(0.2)
	t.eq(Profile.coins(), coins + 300, "buying a coin bag adds coins")
	_press(app.screen, "FreeCoins")
	await _wait(0.3)
	t.eq(Profile.coins(), coins + 300 + Economy.VIDEO_COINS, "a free-coins video pays")
	_press(app.screen, "Product_theme_pack")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is ProductCard, "a pack opens its card")
	_press(card, "Trial")
	await _wait(0.6)
	t.ok(Profile.owns("theme_pack") and not Profile.bought("theme_pack"), "the video starts a trial")
	t.ok(app.top_overlay() is PickerCard, "and opens the theme picker")
	_press(app.top_overlay(), "Pick_ocean")
	await _wait(0.8)
	t.eq(Look.theme_id(), "ocean", "a theme can be picked during the trial")
	app.top_overlay().close()
	await _wait(0.3)
	_press(app.screen, "Product_supporter_pack")
	await _wait(0.4)
	_press(app.top_overlay(), "Buy")
	await _wait(0.3)
	t.ok(Profile.is_supporter(), "the Supporter pack can be bought")
	t.eq(AdManager.banner_height, 0.0, "supporters see no banner")
	app.top_overlay().close()
	await _wait(0.3)


func _settings() -> void:
	app.go("home")
	await _wait(0.6)
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is SettingsCard, "settings opens")
	var music: HSlider = _find(card, "MusicSlider") as HSlider
	t.ok(music != null, "music is a slider")
	t.ok(_find(card, "SoundSlider") is HSlider, "sound is a slider")
	music.value = 0.4
	t.eq(float(Profile.setting("music_volume")), 0.4, "moving the slider sets the volume")
	t.ok(_find(card, "Reset") != null, "Reset progress is offered from home")
	_press(card, "PickLanterns")
	await _wait(0.5)
	t.ok(app.top_overlay() is PickerCard, "the lantern style picker opens")
	app.top_overlay().close()
	await _wait(0.3)
	app.go("play", {"chapter": 0, "level": 2})
	await _wait(0.8)
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	t.ok(_find(app.top_overlay(), "Reset") == null, "Reset progress is hidden in a level")
	app.top_overlay().close()
	await _wait(0.3)


func _daily() -> void:
	app.go("home")
	await _wait(0.6)
	var coins0: int = Profile.coins()
	_press(app.screen, "Daily")
	await _wait(0.9)
	var play: Node = _play()
	t.ok(play.puzzle != null and play.puzzle.id == "daily-" + Catalog.today_key(), "the daily opens today's puzzle")
	await _solve(play)
	await _wait(2.8)
	t.ok(Profile.daily_done(Catalog.today_key()), "daily marked done")
	t.ok(Profile.coins() >= coins0 + Economy.daily_reward(1), "daily reward paid")
	_press(app.top_overlay(), "Next")
	await _wait(0.8)
	t.eq(app.screen_name, "home", "after the daily, Home")
	t.ok((_find(app.screen, "DailyStatus") as Label).text.begins_with("Done"), "home shows the daily as done")


func _restart_app() -> void:
	var coins: int = Profile.coins()
	Save.flush()
	app.queue_free()
	await _wait(0.2)
	Save.data = {}
	Save.load_data()
	await _boot()
	t.eq(Profile.coins(), coins, "coins survive a restart")
	t.eq(Profile.stars_for("meadow-01"), 3, "stars survive a restart")
	t.ok(Profile.is_supporter(), "purchases survive a restart")
	t.eq(float(Profile.setting("music_volume")), 0.4, "settings survive a restart")


## A path of adjacent visible tiles that spells nothing in the puzzle.
func _wrong_path(live: LevelState) -> PackedInt32Array:
	var p: Puzzle = live.puzzle
	for a: int in p.cell_count():
		for b: int in p.neighbors(a):
			for c: int in p.neighbors(b):
				if c == a:
					continue
				var path: PackedInt32Array = PackedInt32Array([a, b, c])
				if LevelState.new(p).submit(path)["result"] == LevelState.Result.NOT_A_WORD:
					return path
	return PackedInt32Array()
