extends Node
## End-to-end flow through the real app with a throwaway save: menus, a full
## level (with a wrong guess and a hint), rewards, Next, Back, a daily, and an
## app restart that must keep everything.
##
##   godot --headless --path . res://tests/ui_flow.tscn

const SAVE: String = "user://ui_flow_save.json"

var t: Check = Check.new("UI FLOW")
var app: App


func _ready() -> void:
	_wipe()
	Save.path = SAVE
	Save.load_data()
	Profile.set_setting("music", false)
	Profile.set_setting("sfx", false)
	await _boot()
	await _menus()
	await _first_level()
	await _next_and_back()
	await _hints_and_coins()
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
	return root.find_child(n, true, false)


func _press(root: Node, n: String) -> bool:
	var b: BaseButton = _find(root, n) as BaseButton
	if b == null:
		t.ok(false, "button %s exists" % n)
		return false
	b.pressed.emit()
	return true


func _menus() -> void:
	t.ok(_find(app.screen, "Play") != null, "home has Play")
	t.ok(_find(app.screen, "Daily") != null, "home has the daily card")
	_press(app.screen, "Worlds")
	await _wait(0.6)
	t.eq(app.screen_name, "worlds", "Worlds opens")
	var grid: Node = _find(app.screen, "Grid")
	t.eq(grid.get_child_count(), Catalog.world_count(), "every world has a tile")
	_press(grid, "World_harbor")
	await _wait(0.6)
	t.eq(app.screen_name, "worlds", "a locked world does not open")
	_press(grid, "World_meadow")
	await _wait(0.6)
	t.eq(app.screen_name, "levels", "an open world shows its levels")
	var levels: Node = _find(app.screen, "Grid")
	t.eq(levels.get_child_count(), 20, "20 level tiles")
	_press(levels, "Level2")
	await _wait(0.6)
	t.eq(app.screen_name, "levels", "a locked level does not open")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "worlds", "Back returns to worlds")
	app.handle_back()
	await _wait(0.6)
	t.eq(app.screen_name, "home", "Back returns home")
	# Settings, about, credits open and close.
	_press(app.screen, "Settings")
	await _wait(0.5)
	t.ok(app.top_overlay() is SettingsCard, "settings opens")
	_press(app.top_overlay(), "About")
	await _wait(0.5)
	t.ok(app.top_overlay() is AboutCard, "about opens from settings")
	t.ok(_find(app.top_overlay(), "Author") != null, "about credits the author")
	app.handle_back()
	await _wait(0.5)
	t.ok(app.top_overlay() == null, "Back closes the card")


func _play() -> Node:
	return app.screen


func _first_level() -> void:
	var coins0: int = Profile.coins()
	_press(app.screen, "Play")
	await _wait(1.2)
	t.eq(app.screen_name, "play", "Play opens the first level")
	t.ok(app.top_overlay() is HowToCard, "the first level explains the rules")
	app.top_overlay().close()
	await _wait(0.5)
	var play: Node = _play()
	var p: Puzzle = play.puzzle
	t.eq(p.id, "meadow-01", "it is Meadow 1")
	# A wrong guess: tiles are adjacent but do not spell an answer.
	var wrong: PackedInt32Array = _wrong_path(play.state)
	play.board.traced.emit(wrong)
	await _wait(0.1)
	t.eq(play.state.found_count(), 0, "a wrong guess finds nothing")
	t.eq(play.state.mistakes, 1, "the mistake is counted")
	t.eq(Profile.coins(), coins0, "a wrong guess costs nothing")
	# Find every word by tracing it.
	for i: int in LanternRules.solve_order(p):
		play.board.traced.emit(p.words[i]["cells"])
		await _wait(0.1)
	t.ok(play.state.is_complete(), "all words found")
	await _wait(2.6)
	t.ok(app.top_overlay() is ResultCard, "the result card appears")
	t.ok(Profile.is_cleared("meadow-01"), "level marked cleared")
	t.ok(Profile.coins() >= coins0 + Economy.LEVEL_REWARD + Economy.FLAWLESS_BONUS, "clear reward paid (plus any achievement)")
	t.ok(Profile.achievement_done("first_light"), "First Light unlocked")
	t.ok(Profile.saved_progress("meadow-01").is_empty(), "finished level leaves no half-progress")


func _next_and_back() -> void:
	_press(app.top_overlay(), "Next")
	await _wait(0.9)
	t.eq(_play().puzzle.id, "meadow-02", "Next opens level 2")
	var play: Node = _play()
	var first: int = LanternRules.solve_order(play.puzzle)[0]
	play.board.traced.emit(play.puzzle.words[first]["cells"])
	await _wait(0.2)
	t.eq(Profile.saved_progress("meadow-02").get("found", []).size(), 1, "progress saved mid-level")
	app.handle_back()
	await _wait(0.5)
	t.ok(app.top_overlay() is PauseCard, "Back in a level opens Pause")
	_press(app.top_overlay(), "Levels")
	await _wait(0.8)
	t.eq(app.screen_name, "levels", "Pause > Levels returns to the level list")
	_press(_find(app.screen, "Grid"), "Level2")
	await _wait(0.8)
	t.eq(_play().state.found_count(), 1, "re-opening the level resumes it")


func _hints_and_coins() -> void:
	var play: Node = _play()
	Save.data["free_spark_date"] = ""
	var coins0: int = Profile.coins()
	play.use_spark()
	await _wait(0.1)
	t.eq(Profile.coins(), coins0, "the first spark of the day is free")
	t.eq(play.state.hints_used, 1, "spark counted")
	play.use_spark()
	await _wait(0.1)
	t.eq(Profile.coins(), coins0 - Economy.SPARK_COST, "the second spark costs coins")
	Save.data["coins"] = 5
	Profile.coins_changed.emit(5)
	var hints: int = play.state.hints_used
	play.use_lantern()
	await _wait(0.5)
	t.eq(Profile.coins(), 5, "no coins taken when you cannot afford a hint")
	t.eq(play.state.hints_used, hints, "and no hint given")
	t.ok(app.top_overlay() is MessageCard, "the not-enough-coins card explains how to earn")
	app.top_overlay().close()
	await _wait(0.4)
	Save.data["coins"] = 500
	var before: int = play.state.found_count()
	play.use_lantern()
	await _wait(0.2)
	t.eq(play.state.found_count(), before + 1, "a lantern finds a word")
	t.eq(Profile.coins(), 500 - Economy.LANTERN_COST, "lantern cost deducted once")
	for i: int in LanternRules.solve_order(play.puzzle):
		if play.state.found[i] == 0:
			play.board.traced.emit(play.puzzle.words[i]["cells"])
			await _wait(0.05)
	await _wait(2.6)
	t.ok(not Profile.is_flawless("meadow-02"), "a hinted clear is not flawless")
	var coins_after: int = Profile.coins()
	app.top_overlay().close()
	await _wait(0.4)
	play.restart()
	await _wait(0.8)
	for i: int in LanternRules.solve_order(_play().puzzle):
		_play().board.traced.emit(_play().puzzle.words[i]["cells"])
		await _wait(0.05)
	await _wait(2.6)
	t.eq(Profile.coins(), coins_after, "replaying a cleared level pays nothing")
	app.top_overlay().close()
	await _wait(0.3)


func _daily() -> void:
	app.go("home")
	await _wait(0.6)
	var coins0: int = Profile.coins()
	_press(app.screen, "Daily")
	await _wait(0.8)
	var play: Node = _play()
	t.ok(play.puzzle != null and play.puzzle.id == "daily-" + Catalog.today_key(), "the daily opens today's puzzle")
	for i: int in LanternRules.solve_order(play.puzzle):
		play.board.traced.emit(play.puzzle.words[i]["cells"])
		await _wait(0.05)
	await _wait(2.6)
	t.ok(Profile.daily_done(Catalog.today_key()), "daily marked done")
	t.ok(Profile.coins() >= coins0 + Economy.daily_reward(1), "daily reward paid")
	t.eq(Profile.current_streak(), 1, "streak started")
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
	t.ok(Profile.is_cleared("meadow-02"), "cleared levels survive a restart")
	t.ok(Profile.daily_done(Catalog.today_key()), "the daily stays done after a restart")
	t.ok(not Profile.setting("sfx"), "settings survive a restart")
	t.eq(Profile.next_level(), [0, 3] as Array[int], "Continue points at level 3")


## A path of adjacent visible tiles that spells nothing in the puzzle.
func _wrong_path(live: LevelState) -> PackedInt32Array:
	var p: Puzzle = live.puzzle
	for a: int in p.cell_count():
		for b: int in p.neighbors(a):
			for c: int in p.neighbors(b):
				if c == a:
					continue
				var path: PackedInt32Array = PackedInt32Array([a, b, c])
				# Probe on a scratch copy so the live level is untouched.
				if LevelState.new(p).submit(path)["result"] == LevelState.Result.NOT_A_WORD:
					return path
	return PackedInt32Array()
