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
	await _ads_between_levels()
	await _shop()
	await _settings()
	await _daily()
	await _restart_app()
	await _chapter_key_unlock()
	await _chapter_ideas()
	await _extras()
	await _reset_progress()
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
	for n: String in ["Play", "Shop", "SettingsButton", "Chapters", "Daily", "Keys", "Coins"]:
		t.ok(_find(app.screen, n) != null, "home has %s" % n)
	t.ok(_find(app.screen, "Logo") == null, "home has no logo image")
	var where: Label = _find(app.screen, "NextLevel") as Label
	t.eq(where.text, "First Light · Level 1", "home shows only the chapter and level")


func _menus() -> void:
	_press(app.screen, "Chapters")
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "Chapters opens")
	var list: Node = _find(app.screen, "List")
	var cards: int = 0
	for c: Node in list.get_children():
		if c is ChapterCard:
			cards += 1
	t.eq(cards, 8, "8 chapter cards")
	for c: Node in list.get_children():
		if c is ChapterCard:
			t.ok(not str((c as ChapterCard).chapter.get("concept", "")).is_empty(), "%s names its idea" % c.name)
	_press(list, "Chapter_meadow")
	await _wait(0.6)
	t.eq(app.screen_name, "chapters", "a locked chapter does not open")
	_press(list, "Chapter_firstlight")
	await _wait(0.6)
	t.eq(app.screen_name, "levels", "an open chapter shows its levels")
	var grid: Node = _find(app.screen, "Grid")
	t.eq(grid.get_child_count(), 40, "all 40 levels are shown, locked ones too")
	var locked: int = 0
	for tile: LevelTile in grid.get_children():
		if not tile.open:
			locked += 1
	t.eq(locked, 39, "39 locked levels are visible")
	_press(app.screen, "HowItWorks")
	await _wait(0.5)
	t.ok(app.top_overlay() is HowToCard, "How it works explains the chapter's idea")
	app.top_overlay().close()
	await _wait(0.4)
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
	t.eq(play.puzzle.id, "firstlight-01", "it is First Light 1")
	for n: String in ["LevelsButton", "LetterHint", "WordHint", "Restart", "SettingsButton", "Back"]:
		t.ok(_find(play, n) != null, "the game screen has %s" % n)
	var wrong: PackedInt32Array = _wrong_path(play.state)
	play.board._begin(play.board.cell_center(wrong[0]))
	play.board._drag(play.board.cell_center(wrong[1]))
	await _wait(0.2)
	t.eq(play._toast.text, play.puzzle.word_text(PackedInt32Array([wrong[0], wrong[1]])), "the traced letters show on the word line")
	t.ok(play._hud.modulate.a > 0.99 and play._hud.is_visible_in_tree(), "MOVES / STARS stay visible while tracing")
	play.board.cancel_trace()
	play.board.traced.emit(wrong)
	await _wait(0.1)
	t.eq(play.state.found_count(), 0, "a wrong guess finds nothing")
	t.eq(play.state.stars(), 2, "a wrong guess costs a star")
	t.ok(play._hud.modulate.a > 0.99, "MOVES / STARS stay visible with a message showing")
	t.eq(Profile.coins(), coins0, "a wrong guess costs no coins")
	await _solve(play)
	await _wait(2.6)
	var card: Overlay = app.top_overlay()
	t.ok(card is ResultCard, "the result card appears")
	t.eq((_find(card, "ResultTitle") as Label).text, "Nicely done", "2-star title")
	t.eq(Profile.stars_for("firstlight-01"), 2, "2 stars recorded")
	t.ok(Profile.coins() >= coins0 + Economy.LEVEL_REWARD + 2 * Economy.STAR_REWARD, "clear reward paid")
	_press(card, "Again")
	await _wait(0.8)
	play = _play()
	t.eq(play.state.stars(), 3, "Again starts fresh with 3 stars on offer")
	await _solve(play)
	await _wait(2.6)
	t.eq(Profile.stars_for("firstlight-01"), 3, "a perfect replay records 3 stars")
	t.eq((_find(app.top_overlay(), "ResultTitle") as Label).text, "Perfect!", "3-star title")
	_press(app.top_overlay(), "Next")
	await _wait(0.9)
	t.eq(_play().puzzle.id, "firstlight-02", "Next opens level 2")


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
	t.eq(_play().puzzle.id, "firstlight-09", "it is level 9")
	t.eq(Profile.keys(), 0, "the key is spent")


func _hints_and_ads() -> void:
	var play: Node = _play()
	Save.data["sparks"]["day"] = ""
	var coins0: int = Profile.coins()
	_press(play, "LetterHint")
	await _wait(0.1)
	t.eq(Profile.coins(), coins0, "the first spark of the day is free")
	t.eq(play.state.stars(), 2, "a hint costs a star")
	_press(play, "LetterHint")
	await _wait(0.1)
	t.eq(Profile.coins(), coins0 - Economy.SPARK_COST, "the next spark costs coins")
	# Out of coins: the game offers a video for the hint.
	Save.data["coins"] = 5
	var hints: int = play.state.hints_used
	_press(play, "WordHint")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is MessageCard and card.name == "OutOfCoins", "out of coins: a video is offered")
	t.eq(play.state.hints_used, hints, "no hint before the video")
	_press(card, "Watchavideo")
	await _wait(0.5)
	t.eq(play.state.hints_used, hints + 1, "after the video, the hint is given")
	t.eq(Profile.coins(), 5, "and no coins are taken")
	mock.earn = false
	_press(play, "WordHint")
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
	t.ok(Profile.saved_progress("firstlight-09").is_empty(), "Restart clears saved progress")


func _shop() -> void:
	app.go("shop")
	await _wait(0.7)
	t.eq(app.screen_name, "shop", "the shop opens")
	for id: String in Store.PRODUCTS:
		t.ok(_find(app.screen, "Product_" + id) != null, "the shop lists %s" % id)
	t.ok(_find(app.screen, "Buy_coins_300") == null, "coin bags are not listed on the shop page itself")
	_press(app.screen, "Product_coins")
	await _wait(0.5)
	var coin_card: Overlay = app.top_overlay()
	t.ok(coin_card is CoinsCard, "the Coins row opens its card, like the tip jar")
	var coins: int = Profile.coins()
	_press(coin_card, "Buy_coins_300")
	await _wait(0.2)
	t.eq(Profile.coins(), coins + 300, "buying a coin bag adds coins")
	_press(coin_card, "FreeCoins")
	await _wait(0.3)
	t.eq(Profile.coins(), coins + 300 + Economy.VIDEO_COINS, "a free-coins video pays")
	coin_card.close()
	await _wait(0.3)
	_press(app.screen, "Product_theme_pack")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is ProductCard, "a pack opens its card")
	_press(card, "Trial")
	await _wait(0.6)
	t.ok(Profile.owns("theme_pack") and not Profile.bought("theme_pack"), "the video starts a trial")
	t.ok(app.top_overlay() is PickerCard, "and opens the theme picker")
	var surface_before: Color = Style.SURFACE
	_press(app.top_overlay(), "Pick_ocean")
	await _wait(1.0)
	t.eq(Look.theme_id(), "ocean", "a theme can be picked during the trial")
	t.ok(Style.SURFACE != surface_before, "the theme recolours buttons and cards, not just text")
	t.eq(Style.DEFAULT_SKY_TOP, Color(Look.THEMES["ocean"]["top"]), "the theme recolours the sky")
	var restyled: Button = _find(app.screen, "SettingsButton") as Button
	t.eq((restyled.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Style.SURFACE, "the screen was rebuilt in the new colours")
	t.ok(app.top_overlay() is PickerCard, "the picker is shown again after repainting")
	app.top_overlay().close()
	await _wait(0.4)
	t.ok(app.top_overlay() is SettingsCard and app.top_overlay().visible, "closing the picker returns to Settings")
	app.top_overlay().close()
	await _wait(0.3)
	# Light theme: dark text on a light sky.
	Save.data["owned"]["theme_pack"] = true
	Profile.set_setting("theme", "paper")
	app.repaint_and_reopen("themes")
	await _wait(1.0)
	t.ok(not Style.DARK and Style.INK.get_luminance() < 0.4, "a light theme switches to dark text")
	app.close_overlays()
	Profile.set_setting("theme", "chapters")
	Save.data["owned"].erase("theme_pack")
	app.reload_screen()
	await _wait(0.8)
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
	_press(card, "PickGlow")
	await _wait(0.5)
	t.ok(app.top_overlay() is PickerCard, "the glow style picker opens")
	app.top_overlay().close()
	await _wait(0.4)
	# Settings > Credits > close: back on Settings, not closed.
	_press(card, "Credits")
	await _wait(0.5)
	t.ok(app.top_overlay() is CreditsCard, "Credits opens from Settings")
	t.ok(not card.visible, "Settings steps aside while Credits is open")
	app.top_overlay().close()
	await _wait(0.4)
	t.ok(app.top_overlay() == card and card.visible, "closing Credits returns to Settings")
	_press(card, "About")
	await _wait(0.5)
	app.handle_back()
	await _wait(0.4)
	t.ok(app.top_overlay() == card and card.visible, "Back from About returns to Settings")
	card.close()
	await _wait(0.3)
	# Top-bar buttons are the same size on every screen.
	var sizes: Array[Vector2] = []
	for route: Array in [["home", {}], ["chapters", {}], ["levels", {"chapter": 0}], ["shop", {}], ["play", {"chapter": 0, "level": 1}]]:
		app.go(route[0], route[1])
		await _wait(0.7)
		app.close_overlays()
		var sb: Button = _find(app.screen, "SettingsButton") as Button
		sizes.append(sb.size)
	for k: int in sizes.size():
		t.eq(sizes[k], Vector2(Style.TOP_BUTTON, Style.TOP_BUTTON), "the Settings button is %dpx on screen %d" % [int(Style.TOP_BUTTON), k])
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
	t.eq(Profile.stars_for("firstlight-01"), 3, "stars survive a restart")
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


## Reset, like Single Shot: the first tap asks, the second erases. Progress goes;
## settings, packs, keys and bought coins stay.
func _reset_progress() -> void:
	app.go("home")
	await _wait(0.6)
	Profile.add_keys(2)
	var keys: int = Profile.keys()
	t.ok(Profile.stat("levels") > 0, "there is progress to reset")
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	var reset: Button = _find(card, "Reset") as Button
	reset.pressed.emit()
	await _wait(0.2)
	t.ok(Profile.stat("levels") > 0, "the first tap only asks")
	t.ok(reset.text.begins_with("Tap again"), "the button asks for a second tap")
	reset.pressed.emit()
	await _wait(1.0)
	t.eq(Profile.stat("levels"), 0, "the second tap erases progress")
	t.eq(Profile.stars_for("firstlight-01"), 0, "stars are erased")
	t.ok(not Profile.daily_done(Catalog.today_key()), "the daily is reset")
	t.ok(Profile.is_supporter(), "packs are kept")
	t.eq(Profile.keys(), keys, "keys are kept")
	t.eq(float(Profile.setting("music_volume")), 0.4, "settings are kept")
	t.eq(app.screen_name, "home", "after a reset, home")
	t.eq((_find(app.screen, "NextLevel") as Label).text, "First Light · Level 1", "Play starts again from First Light 1")
	t.ok(app.top_overlay() == null, "no card is left open")


## Each chapter's idea in play: the first level of a chapter opens its idea
## card, listed levels write the words out, and a mystery theme shows once a
## word is found.
func _chapter_ideas() -> void:
	Profile.mark_seen("intro_listed")
	app.go("play", {"chapter": 6, "level": 1})
	await _wait(1.2)
	var card: Overlay = app.top_overlay()
	t.ok(card is HowToCard, "a new chapter opens with its idea card")
	if card is HowToCard:
		t.eq((card as HowToCard).pages, ["mystery"], "Moonwell explains the mystery theme")
		card.close()
	await _wait(0.5)
	var play: Node = _play()
	t.ok(play.puzzle.mystery, "Moonwell levels have a mystery theme")
	var title: Label = _find(play, "Title") as Label
	t.eq(title.text, "Mystery theme", "the theme starts hidden")
	var order: PackedInt32Array = LanternRules.solve_order(play.puzzle)
	play.board.traced.emit(play.puzzle.words[order[0]]["cells"])
	await _wait(0.3)
	t.eq(title.text, play.puzzle.theme_name, "finding a word reveals the theme")
	app.go("play", {"chapter": 0, "level": 2})
	await _wait(1.0)
	t.ok(app.top_overlay() == null, "an idea card shows only once")
	t.ok(_play().puzzle.listed, "First Light writes the words out")
	app.go("home")
	await _wait(0.6)


## A locked chapter opened with a chapter key starts at its level 1.
func _chapter_key_unlock() -> void:
	app.go("chapters")
	await _wait(0.7)
	_press(_find(app.screen, "List"), "Chapter_bazaar")
	await _wait(0.5)
	var card: Overlay = app.top_overlay()
	t.ok(card is LockedChapterCard, "a locked chapter offers a chapter key")
	t.ok((_find(card, "UseChapterKey") as Button).disabled, "no chapter keys: the button is disabled")
	card.close()
	await _wait(0.3)
	Profile.add_chapter_keys(1)
	_press(_find(app.screen, "List"), "Chapter_bazaar")
	await _wait(0.5)
	_press(app.top_overlay(), "UseChapterKey")
	await _wait(0.9)
	t.eq(app.screen_name, "levels", "the opened chapter shows its levels")
	var grid: Node = _find(app.screen, "Grid")
	t.ok((grid.get_child(0) as LevelTile).open and not (grid.get_child(1) as LevelTile).open, "only its level 1 is open")
	t.eq(Profile.chapter_keys(), 0, "the chapter key is spent")


## A short video after every 5th cleared level (not for daily puzzles), and a
## fresh banner ad when moving between screens (at most every 30 seconds).
func _ads_between_levels() -> void:
	Save.data["levels_since_video"] = 3
	var before: int = mock.interstitials
	for k: int in 2:
		app.go("play", {"chapter": 0, "level": 1})
		await _wait(0.8)
		await _solve(_play())
		await _wait(2.6)
		_press(app.top_overlay(), "Next")
		await _wait(0.9)
	t.eq(mock.interstitials, before + 1, "the 5th cleared level plays one video")
	t.eq(int(Save.data["levels_since_video"]), 0, "and the count starts again")
	t.eq(app.screen_name, "play", "after the video the game carries on")
	# Banner refresh on navigation, rate-limited.
	AdManager._last_banner_load_msec = -1000000
	var reloads: int = mock.reloads
	app.go("home")
	await _wait(0.7)
	t.eq(mock.reloads, reloads + 1, "moving to another screen loads a fresh banner ad")
	app.go("chapters")
	await _wait(0.7)
	t.eq(mock.reloads, reloads + 1, "but not again within 30 seconds")
	var frame: MarginContainer = app.screen.get_child(0) as MarginContainer
	t.ok(frame.get_theme_constant("margin_bottom") >= int(AdManager.banner_height), "the banner space stays reserved")


func _extras() -> void:
	# Appearance: Auto / Dark / Light.
	app.go("home")
	await _wait(0.7)
	_press(app.screen, "SettingsButton")
	await _wait(0.5)
	var slider: SegmentedSlider = _find(app.top_overlay(), "Appearance") as SegmentedSlider
	t.ok(slider != null, "Settings has the Auto / Dark / Light slider")
	slider.select(2)
	await _wait(1.0)
	t.eq(str(Profile.setting("appearance")), "light", "Light is saved")
	t.ok(not Style.DARK, "Light makes the Original colours light")
	t.ok(app.top_overlay() is SettingsCard, "Settings is shown again after repainting")
	(_find(app.top_overlay(), "Appearance") as SegmentedSlider).select(1)
	await _wait(1.0)
	t.ok(Style.DARK, "Dark brings the night look back")
	app.close_overlays()
	# Tip jar: ₹10 to ₹10,000, always shown as the player's own price.
	app.go("shop")
	await _wait(0.7)
	t.ok(_find(app.screen, "NoRefunds") != null, "the shop says purchases can't be refunded")
	_press(app.screen, "TipJar")
	await _wait(0.5)
	var tip: TipCard = app.top_overlay() as TipCard
	var price: Label = _find(tip, "TipPrice") as Label
	t.eq(tip.amount(), 500, "the picker starts on the ₹500 tip")
	t.eq(price.text, Store.price("tip_500"), "it shows the local price, not rupees")
	t.eq((_find(tip, "TipCustom") as Button).text, "Tip %s" % Store.price("tip_500"), "the button names the local price")
	_press(tip, "TipPlus")
	t.eq(tip.amount(), 510, "+ goes to the next amount")
	_press(tip, "TipMinus")
	_press(tip, "TipMinus")
	t.eq(tip.amount(), 490, "− goes to the amount before")
	var tip_slider: HSlider = _find(tip, "TipSlider") as HSlider
	tip_slider.value = tip_slider.max_value
	t.eq(tip.amount(), 10000, "the slider reaches ₹10,000")
	t.eq(price.text, Store.price("tip_10000"), "the label follows the slider")
	tip_slider.value = 0
	t.eq(tip.amount(), 10, "and goes down to ₹10")
	t.ok(_find(tip, "NoRefunds") != null, "the tip jar says purchases can't be refunded")
	Store.prices["tip_10"] = "CA$0.19"
	Store.price_updated.emit("tip_10", "CA$0.19")
	t.eq(price.text, "CA$0.19", "Google Play's price replaces the fallback")
	Store.prices["tip_10"] = Store.tip_price(10)
	tip.close()
	await _wait(0.3)
	# Chapter keys: 1 to 5 at a time.
	_press(app.screen, "Product_chapter_keys")
	await _wait(0.5)
	var ck: Overlay = app.top_overlay()
	for k: int in 8:
		_press(ck, "Plus")
	t.ok((_find(ck, "BuyChapterKeys") as Button).text.begins_with("Get 5 "), "no more than 5 chapter keys at once")
	ck.close()
	await _wait(0.3)
	# Share after a clear.
	app.go("play", {"chapter": 0, "level": 1})
	await _wait(0.8)
	await _solve(_play())
	await _wait(2.6)
	_press(app.top_overlay(), "Share")
	await _wait(0.6)
	var share: Overlay = app.top_overlay()
	t.ok(share is ShareCardOverlay, "the result card can share the puzzle")
	for n: String in ["ShareNow", "Save", "CopyLink"]:
		t.ok(_find(share, n) != null, "sharing offers %s" % n)
	t.ok(ShareService.message_for(share.info).contains("theramlakhan.com/word-glow"), "the share message links to the game")
	share.close()
	await _wait(0.4)
	t.ok(app.top_overlay() is ResultCard, "closing Share returns to the result")
