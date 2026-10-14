extends Node
## Save, progression and reward tests against the real autoloads, using a
## throwaway save file.
##
##   godot --headless --path . res://tests/profile_test.tscn

const TEST_SAVE: String = "user://test_profile_save.json"

var t: Check = Check.new("PROFILE")


func _ready() -> void:
	_use_fresh_save()
	_coins_and_hints()
	_level_rewards_are_paid_once()
	_unlocks()
	_daily_streaks()
	_achievements_pay_once()
	_restart_keeps_progress()
	_corrupt_save_recovers()
	_cleanup()
	get_tree().quit(t.report())


func _use_fresh_save() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + suffix))
	Save.path = TEST_SAVE
	Save.load_data()


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + suffix))


func _state(id: String, hints: int = 0) -> LevelState:
	var p: Puzzle = Catalog.puzzle_by_id(id)
	var s: LevelState = LevelState.new(p)
	for i: int in LanternRules.solve_order(p):
		s.submit(p.words[i]["cells"])
	s.hints_used = hints
	return s


func _coins_and_hints() -> void:
	t.eq(Profile.coins(), Economy.START_COINS, "new players start with coins")
	t.ok(not Profile.spend(Economy.START_COINS + 1), "cannot overspend")
	t.eq(Profile.coins(), Economy.START_COINS, "a failed spend changes nothing")
	t.ok(Profile.spend(Economy.SPARK_COST), "can pay for a spark")
	t.eq(Profile.coins(), Economy.START_COINS - Economy.SPARK_COST, "spark cost deducted")
	t.ok(Profile.free_spark_available(), "a free spark is available today")
	t.ok(Profile.use_free_spark(), "free spark used")
	t.ok(not Profile.use_free_spark(), "only one free spark per day")
	Profile.add_coins(-50)
	t.eq(Profile.coins(), Economy.START_COINS - Economy.SPARK_COST, "negative rewards are ignored")


func _level_rewards_are_paid_once() -> void:
	var before: int = Profile.coins()
	var r: Dictionary = Profile.complete_level("meadow-01", _state("meadow-01"))
	t.ok(r["first"], "first clear")
	t.eq(r["coins"], Economy.LEVEL_REWARD + Economy.FLAWLESS_BONUS, "flawless first clear pays reward + bonus")
	t.eq(Profile.coins(), before + r["coins"], "coins added")
	var again: Dictionary = Profile.complete_level("meadow-01", _state("meadow-01"))
	t.eq(again["coins"], 0, "replaying a cleared level pays nothing")
	t.eq(Profile.coins(), before + r["coins"], "coins unchanged on replay")
	t.eq(Profile.stat("levels"), 1, "levels stat counted once")
	var hinted: Dictionary = Profile.complete_level("meadow-02", _state("meadow-02", 2))
	t.eq(hinted["coins"], Economy.LEVEL_REWARD, "a hinted clear has no flawless bonus")
	t.ok(not Profile.is_flawless("meadow-02"), "hinted clear is not flawless")
	Profile.complete_level("meadow-02", _state("meadow-02"))
	t.ok(Profile.is_flawless("meadow-02"), "a later flawless replay upgrades the badge")
	t.eq(Profile.stat("flawless"), 2, "flawless upgrade counted once")


func _unlocks() -> void:
	t.ok(Profile.level_unlocked(0, 3), "level 3 opens after level 2")
	t.ok(not Profile.level_unlocked(0, 4), "level 4 stays locked")
	t.ok(not Profile.world_unlocked(1), "world 2 starts locked")
	t.eq(Profile.next_level(), [0, 3] as Array[int], "continue goes to the first open level")
	var before: int = Profile.coins()
	var unlocked_seen: bool = false
	for n: int in range(3, 21):
		var r: Dictionary = Profile.complete_level(Catalog.level_id("meadow", n), _state(Catalog.level_id("meadow", n), 1))
		if n == Catalog.unlock_clears:
			unlocked_seen = r["world_unlocked"]
		if n == 20:
			t.ok(r["world_done"], "clearing all 20 completes the world")
			t.eq(r["coins"], Economy.LEVEL_REWARD + Economy.WORLD_BONUS, "world bonus paid with the last level")
	t.ok(unlocked_seen, "world 2 unlocks at the 15th clear")
	t.ok(Profile.world_unlocked(1), "world 2 is open")
	t.eq(Profile.coins(), before + 18 * Economy.LEVEL_REWARD + Economy.WORLD_BONUS, "exact coins for the world")
	var replay: Dictionary = Profile.complete_level("meadow-20", _state("meadow-20"))
	t.ok(not replay["world_done"], "world bonus is never paid twice")
	t.eq(Profile.next_level(), [1, 1] as Array[int], "continue moves to the next world")


func _daily_streaks() -> void:
	var p: Puzzle = Catalog.daily_puzzle("2026-03-01")
	t.ok(p != null, "daily puzzle loads")
	t.eq(p.id, "daily-2026-03-01", "daily id carries the date")
	t.eq(Catalog.daily_puzzle("2026-03-01").words.size(), p.words.size(), "same date, same puzzle")
	t.eq(Catalog.day_number("2026-01-02") - Catalog.day_number("2026-01-01"), 1, "day numbers are consecutive")
	t.eq(Catalog.date_key_from_day(Catalog.day_number("2026-10-15")), "2026-10-15", "day numbers round-trip")
	var s: LevelState = LevelState.new(p)
	var r1: Dictionary = Profile.complete_daily("2026-03-01", s)
	t.eq(r1["streak"], 1, "first daily starts a streak")
	t.eq(r1["coins"], Economy.daily_reward(1), "daily reward")
	var r1b: Dictionary = Profile.complete_daily("2026-03-01", s)
	t.eq(r1b["coins"], 0, "the same daily never pays twice")
	var r2: Dictionary = Profile.complete_daily("2026-03-02", s)
	t.eq(r2["streak"], 2, "next day extends the streak")
	t.eq(r2["coins"], Economy.daily_reward(2), "streak bonus grows")
	var r4: Dictionary = Profile.complete_daily("2026-03-04", s)
	t.eq(r4["streak"], 1, "a missed day restarts the streak")
	t.eq(Profile.stat("best_streak"), 2, "best streak kept")
	t.eq(Profile.stat("dailies"), 3, "three dailies counted")
	t.ok(Profile.daily_done("2026-03-02"), "daily marked done")


func _achievements_pay_once() -> void:
	var before: int = Profile.coins()
	var got: Array[Dictionary] = Profile.check_achievements()
	var ids: Array = got.map(func(a: Dictionary) -> String: return a["id"])
	t.ok(ids.has("first_light"), "First Light unlocked")
	t.ok(ids.has("daily_1"), "Night Watch unlocked")
	t.ok(not ids.has("lamplighter"), "Lamplighter not yet")
	var paid: int = 0
	for a: Dictionary in got:
		paid += int(a["reward"])
	t.eq(Profile.coins(), before + paid, "achievement rewards paid")
	t.eq(Profile.check_achievements().size(), 0, "achievements unlock only once")
	t.eq(Profile.coins(), before + paid, "and pay only once")


func _restart_keeps_progress() -> void:
	var p: Puzzle = Catalog.puzzle_by_id("harbor-01")
	var s: LevelState = LevelState.new(p)
	s.submit(p.words[LanternRules.solve_order(p)[0]]["cells"])
	Profile.store_progress("harbor-01", s)
	Profile.set_setting("music", false)
	var coins: int = Profile.coins()
	Save.flush()
	Save.data = {}
	Save.load_data()
	t.eq(Profile.coins(), coins, "coins survive a restart")
	t.ok(Profile.is_cleared("meadow-20"), "cleared levels survive a restart")
	t.ok(not Profile.setting("music"), "settings survive a restart")
	var s2: LevelState = LevelState.new(p)
	s2.restore(Profile.saved_progress("harbor-01"))
	t.eq(s2.found_count(), 1, "a half-played level resumes")
	t.ok(Profile.daily_done("2026-03-04"), "daily status survives a restart")


func _corrupt_save_recovers() -> void:
	var coins: int = Profile.coins()
	Save.flush()
	Save.flush()  # the backup now matches the current save
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Save.load_data()
	t.eq(Save.recovered_from, "backup", "a corrupt save falls back to the backup")
	t.eq(Profile.coins(), coins, "no coins lost to corruption")
	f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("[1, 2, 3]")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + ".bak"))
	Save.load_data()
	t.eq(Save.recovered_from, "fresh", "an unreadable save without backup starts fresh")
	t.eq(Profile.coins(), Economy.START_COINS, "fresh save has starting coins")
	Save.data["coins"] = "lots"
	Save.data = Save._merge(Save.defaults(), Save.data)
	t.eq(Profile.coins(), Economy.START_COINS, "wrong-typed values fall back to defaults")
