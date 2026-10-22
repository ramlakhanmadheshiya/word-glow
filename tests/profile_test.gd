extends Node
## Save, progression, star, reward, shop and ad-reward tests against the real
## autoloads, using a throwaway save file and the simulated store.
##
##   godot --headless --path . res://tests/profile_test.tscn

const TEST_SAVE: String = "user://test_profile_save.json"

var t: Check = Check.new("PROFILE")


func _ready() -> void:
	_use_fresh_save()
	Store.simulate = true
	_coins_and_free_sparks()
	_stars_and_rewards()
	_unlocks_keys_and_chapters()
	_chapter_keys()
	_daily_streaks()
	_achievements_pay_once()
	_video_rewards()
	_store_purchases()
	_trials_and_looks()
	_reset_keeps_purchases()
	_restart_keeps_progress()
	_corrupt_save_recovers()
	_migrates_v1_saves()
	_migrates_v2_saves()
	_migrates_diamond_keys()
	_streak_achievements()
	_glyphs()
	_cleanup()
	get_tree().quit(t.report())


func _use_fresh_save() -> void:
	_cleanup()
	Save.path = TEST_SAVE
	Save.load_data()


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE + suffix))


## A solved level with `extra` extra moves (wrong words).
func _state(id: String, extra: int = 0) -> LevelState:
	var p: Puzzle = Catalog.puzzle_by_id(id)
	var s: LevelState = LevelState.new(p)
	for i: int in LanternRules.solve_order(p):
		s.submit(p.words[i]["cells"])
	s.mistakes = extra
	return s


func _coins_and_free_sparks() -> void:
	t.eq(Profile.coins(), Economy.START_COINS, "new players start with coins")
	t.ok(not Profile.spend(Economy.START_COINS + 1), "cannot overspend")
	t.eq(Profile.coins(), Economy.START_COINS, "a failed spend changes nothing")
	t.ok(Profile.spend(Economy.SPARK_COST), "can pay for a spark")
	t.eq(Profile.coins(), Economy.START_COINS - Economy.SPARK_COST, "spark cost deducted")
	t.eq(Profile.free_sparks_left(), Economy.FREE_SPARKS, "one free spark a day")
	t.ok(Profile.use_free_spark(), "free spark used")
	t.ok(not Profile.use_free_spark(), "no second free spark today")
	Save.data["sparks"]["day"] = "2000-01-01"
	t.eq(Profile.free_sparks_left(), Economy.FREE_SPARKS, "free sparks refill on a new day")
	Profile.add_coins(-50)
	t.eq(Profile.coins(), Economy.START_COINS - Economy.SPARK_COST, "negative rewards are ignored")


func _stars_and_rewards() -> void:
	var before: int = Profile.coins()
	var r: Dictionary = Profile.complete_level("firstlight-01", _state("firstlight-01", 2))
	t.eq(r["stars"], 2, "two extra moves: 2 stars")
	t.eq(r["coins"], Economy.LEVEL_REWARD + 2 * Economy.STAR_REWARD, "first clear pays the level and each star")
	t.eq(Profile.coins(), before + r["coins"], "coins added")
	var better: Dictionary = Profile.complete_level("firstlight-01", _state("firstlight-01"))
	t.eq(better["stars"], 3, "perfect replay: 3 stars")
	t.eq(better["coins"], Economy.STAR_REWARD, "improving pays only the new star")
	var worse: Dictionary = Profile.complete_level("firstlight-01", _state("firstlight-01", 9))
	t.eq(worse["coins"], 0, "a worse replay pays nothing")
	t.eq(Profile.stars_for("firstlight-01"), 3, "the best stars are kept")
	t.eq(Profile.stat("stars"), 3, "star stat counts each star once")
	t.eq(Profile.stat("levels"), 1, "levels stat counted once")
	t.eq(Profile.stat("perfect"), 1, "perfect clears counted once")
	t.eq(Profile.total_stars(), 3, "total stars")


func _unlocks_keys_and_chapters() -> void:
	t.ok(Profile.level_unlocked(0, 2), "level 2 opens after level 1")
	t.ok(not Profile.level_unlocked(0, 3), "level 3 stays locked")
	t.ok(not Profile.use_key("firstlight-05"), "no keys, no key unlock")
	Profile.add_keys(2)
	t.ok(Profile.use_key("firstlight-05"), "a key opens a locked level")
	t.ok(Profile.level_unlocked(0, 5), "the keyed level is open")
	t.ok(not Profile.level_unlocked(0, 4), "levels before it stay locked")
	t.ok(not Profile.use_key("firstlight-05"), "a key is not spent twice on one level")
	t.eq(Profile.keys(), 1, "one key left")
	t.eq(Profile.next_level(), [0, 2] as Array[int], "Play continues at the first open level")
	t.ok(not Profile.chapter_unlocked(1), "chapter 2 starts locked")
	var before: int = Profile.coins()
	var paid: int = 0
	var opened: bool = false
	var done: bool = false
	for n: int in range(2, 41):
		var r: Dictionary = Profile.complete_level(Catalog.level_id("firstlight", n), _state(Catalog.level_id("firstlight", n)))
		paid += int(r["coins"])
		if n == Catalog.unlock_clears:
			opened = r["chapter_unlocked"]
		if n == 40:
			done = r["chapter_done"]
	t.ok(opened, "chapter 2 opens at the 15th clear")
	t.ok(done, "clearing all 40 completes the chapter")
	t.eq(paid, 39 * (Economy.LEVEL_REWARD + 3 * Economy.STAR_REWARD) + Economy.CHAPTER_BONUS, "exact coins for the chapter, bonus included")
	t.eq(Profile.coins(), before + paid, "coins match")
	t.eq(Profile.chapter_stars(0), 120, "120 stars in a perfect chapter")
	t.ok(not Profile.complete_level("firstlight-40", _state("firstlight-40"))["chapter_done"], "the chapter bonus is never paid twice")
	t.eq(Profile.stat("ch_firstlight"), 1, "chapter completion recorded")
	t.eq(Profile.next_level(), [1, 1] as Array[int], "Play moves to the next chapter")


## Chapter keys: earned once per chapter for level 40, open a locked chapter
## at level 1 only, limited free ones from videos, and sold in packs.
func _chapter_keys() -> void:
	# First Light was fully cleared above, so its level 40 has already paid a chapter key.
	t.eq(Profile.chapter_keys(), 1, "clearing level 40 earned a chapter key")
	Profile.complete_level("firstlight-40", _state("firstlight-40"))
	t.eq(Profile.chapter_keys(), 1, "replaying level 40 pays no second chapter key")
	t.ok(not Profile.chapter_unlocked(5), "chapter 6 is locked")
	t.ok(not Profile.use_chapter_key(1), "a chapter key is not spent on an open chapter")
	t.ok(Profile.use_chapter_key(5), "a chapter key opens a locked chapter")
	t.eq(Profile.chapter_keys(), 0, "the chapter key is spent")
	t.ok(Profile.chapter_unlocked(5), "chapter 6 is open")
	t.ok(Profile.level_unlocked(5, 1), "its level 1 is open")
	t.ok(not Profile.level_unlocked(5, 2), "but only level 1")
	t.ok(not Profile.use_chapter_key(6), "no chapter keys left")
	t.ok(Profile.add_video_chapter_key(), "one free chapter key from a video")
	t.ok(not Profile.add_video_chapter_key(), "only one a day")
	Store.buy("chapter_keys_3")
	t.eq(Profile.chapter_keys(), 4, "3 chapter keys bought")


func _daily_streaks() -> void:
	var p: Puzzle = Catalog.daily_puzzle("2026-03-01")
	t.ok(p != null, "daily puzzle loads")
	t.eq(p.id, "daily-2026-03-01", "daily id carries the date")
	t.eq(Catalog.date_key_from_day(Catalog.day_number("2026-10-15")), "2026-10-15", "day numbers round-trip")
	var s: LevelState = LevelState.new(p)
	var r1: Dictionary = Profile.complete_daily("2026-03-01", s)
	t.eq(r1["streak"], 1, "first daily starts a streak")
	t.eq(r1["coins"], Economy.daily_reward(1), "daily reward")
	t.eq(Profile.complete_daily("2026-03-01", s)["coins"], 0, "the same daily never pays twice")
	t.eq(Profile.complete_daily("2026-03-02", s)["streak"], 2, "next day extends the streak")
	t.eq(Profile.complete_daily("2026-03-04", s)["streak"], 1, "a missed day restarts the streak")
	t.eq(Profile.stat("best_streak"), 2, "best streak kept")


func _achievements_pay_once() -> void:
	var before: int = Profile.coins()
	var got: Array[Dictionary] = Profile.check_achievements()
	var ids: Array = got.map(func(a: Dictionary) -> String: return a["id"])
	t.ok(ids.has("first_light"), "First Light unlocked")
	t.ok(ids.has("chapter_firstlight"), "the chapter achievement unlocked")
	t.ok(ids.has("stars_50"), "the star achievement unlocked")
	t.ok(not ids.has("chapter_meadow"), "other chapters not yet")
	var paid: int = 0
	for a: Dictionary in got:
		paid += int(a["reward"])
	t.eq(Profile.coins(), before + paid, "achievement rewards paid")
	t.eq(Profile.check_achievements().size(), 0, "achievements unlock only once")
	t.eq(Achievements.all().size(), Achievements.BASE.size() + 8, "one achievement per chapter")


func _video_rewards() -> void:
	var before: int = Profile.coins()
	for i: int in Economy.VIDEO_COINS_PER_DAY:
		t.ok(Profile.claim_video_coins(), "video coins %d" % (i + 1))
	t.ok(not Profile.claim_video_coins(), "video coins are limited per day")
	t.eq(Profile.coins(), before + Economy.VIDEO_COINS * Economy.VIDEO_COINS_PER_DAY, "exact video coins")
	var keys: int = Profile.keys()
	for i: int in Economy.VIDEO_KEYS_PER_DAY:
		Profile.add_video_key()
	t.ok(not Profile.add_video_key(), "video keys are limited per day")
	t.eq(Profile.keys(), keys + Economy.VIDEO_KEYS_PER_DAY, "exact video keys")


func _store_purchases() -> void:
	t.ok(Store.available(), "the simulated store is available in tests")
	t.ok(not Profile.is_supporter(), "not a supporter yet")
	Store.buy("supporter_pack")
	t.ok(Profile.is_supporter(), "Supporter pack bought")
	Save.data["sparks"]["day"] = ""
	t.eq(Profile.free_sparks_left(), Economy.SUPPORTER_FREE_SPARKS, "supporters get more free sparks")
	var coins: int = Profile.coins()
	var keys: int = Profile.keys()
	Store.buy("complete_pack")
	t.eq(Profile.coins(), coins + Store.COMPLETE_COINS, "the Complete pack adds its coins")
	t.eq(Profile.keys(), keys + Store.COMPLETE_KEYS, "and its keys")
	t.ok(Profile.bought("theme_pack") and Profile.bought("style_pack"), "and every pack")
	Store.buy("complete_pack")
	t.eq(Profile.coins(), coins + Store.COMPLETE_COINS, "buying it again adds nothing")
	Store.buy("coins_1000")
	t.eq(Profile.coins(), coins + Store.COMPLETE_COINS + 1000, "a coin bag adds its coins")
	Store.buy("keys_5")
	t.eq(Profile.keys(), keys + Store.COMPLETE_KEYS + 5, "keys bought")
	Store.buy("tip_50")
	t.eq(Profile.tips_given(), 1, "a tip is counted")
	t.eq(Store.all_ids().size(), 4 + 10 + 5 + 10 + 100, "product catalogue size")
	t.ok(Store.chapter_key_ids().size() == Store.CHAPTER_KEY_MAX and Store.CHAPTER_KEY_MAX == 5, "chapter keys are sold 1 to 5 at a time")
	var coin_ids: Array = Store.COIN_PACKS.keys()
	for want: String in ["coins_100", "coins_250", "coins_500", "coins_750", "coins_1000", "coins_1500", "coins_2000", "coins_300", "coins_2500", "coins_6000"]:
		t.ok(coin_ids.has(want), "the shop sells %s" % want)
	for k: int in range(1, coin_ids.size()):
		t.ok(int(Store.COIN_PACKS[coin_ids[k]][0]) > int(Store.COIN_PACKS[coin_ids[k - 1]][0]), "coin bags are listed smallest first")
		t.ok(float(Store.COIN_PACKS[coin_ids[k]][0]) / float(Store.COIN_PACKS[coin_ids[k]][2]) >= float(Store.COIN_PACKS[coin_ids[k - 1]][0]) / float(Store.COIN_PACKS[coin_ids[k - 1]][2]), "bigger bags give at least as many coins per rupee")
	t.ok(Store.complete_saving() > 0, "the Complete pack is cheaper than its parts")
	Store.simulate = false
	var msg: Array[String] = [""]
	var cb: Callable = func(_ok: bool, m: String, _id: String) -> void: msg[0] = m
	Store.purchase_finished.connect(cb)
	Store.buy("coins_300")
	t.ok(msg[0].contains("Android"), "outside Android, purchases explain where they work")
	Store.purchase_finished.disconnect(cb)
	Store.simulate = true


func _trials_and_looks() -> void:
	# Undo the Complete pack to test trials on their own.
	Save.data["owned"] = {}
	Profile.set_setting("theme", "ocean")
	t.eq(Look.theme_id(), "chapters", "a locked theme falls back to chapter colours")
	Profile.start_trial("theme_pack")
	t.ok(Profile.owns("theme_pack") and not Profile.bought("theme_pack"), "a video trial grants the pack, not a purchase")
	t.eq(Look.theme_id(), "ocean", "the trial theme applies")
	t.ok(Profile.trial_clock("theme_pack").begins_with("59:") or Profile.trial_clock("theme_pack").begins_with("60:"), "an hour on the clock")
	Save.data["trials"]["theme_pack"] = 1
	t.eq(Look.theme_id(), "chapters", "when the trial ends the theme reverts")
	Profile.set_setting("style", "neon")
	t.eq(Look.style_id(), "classic", "locked style falls back to classic")


func _reset_keeps_purchases() -> void:
	Store.buy("supporter_pack")
	Save.data["coins_bought"] = 2000
	var keys: int = Profile.keys()
	var chapter_keys: int = Profile.chapter_keys()
	Profile.reset_all()
	t.ok(Profile.is_supporter(), "a reset keeps packs")
	t.eq(Profile.chapter_keys(), chapter_keys, "a reset keeps chapter keys")
	t.eq(Profile.keys(), keys, "a reset keeps keys")
	t.eq(Profile.coins(), Economy.START_COINS + 2000, "a reset keeps bought coins, not earned ones")
	t.eq(Profile.stat("levels"), 0, "a reset clears progress")
	t.ok(not Profile.achievement_done("first_light"), "a reset clears achievements")


func _restart_keeps_progress() -> void:
	Profile.complete_level("firstlight-01", _state("firstlight-01", 1))
	var p: Puzzle = Catalog.puzzle_by_id("firstlight-02")
	var s: LevelState = LevelState.new(p)
	s.submit(p.words[LanternRules.solve_order(p)[0]]["cells"])
	Profile.store_progress("firstlight-02", s)
	Profile.set_setting("music_volume", 0.25)
	var coins: int = Profile.coins()
	Save.flush()
	Save.data = {}
	Save.load_data()
	t.eq(Profile.coins(), coins, "coins survive a restart")
	t.eq(Profile.stars_for("firstlight-01"), 2, "stars survive a restart")
	t.eq(float(Profile.setting("music_volume")), 0.25, "volume survives a restart")
	t.ok(Profile.is_supporter(), "purchases survive a restart")
	var s2: LevelState = LevelState.new(p)
	s2.restore(Profile.saved_progress("firstlight-02"))
	t.eq(s2.found_count(), 1, "a half-played level resumes")


func _corrupt_save_recovers() -> void:
	var coins: int = Profile.coins()
	Save.flush()
	Save.flush()
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


func _migrates_v1_saves() -> void:
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "coins": 777, "cleared": {"firstlight-01": {"flawless": true}},
		"settings": {"music": false, "sfx": true, "haptics": false}, "stats": {"levels": 9, "words": 50, "worlds": 2}}))
	f.close()
	Save.load_data()
	t.eq(Profile.coins(), 777, "v1 coins kept")
	t.ok(not Profile.is_cleared("firstlight-01"), "v1 level progress dropped (the levels changed)")
	t.eq(float(Profile.setting("music_volume")), 0.0, "v1 music off becomes volume 0")
	t.ok(float(Profile.setting("sound_volume")) > 0.0, "v1 sound on keeps a volume")
	t.ok(not bool(Profile.setting("haptics")), "v1 vibration setting kept")
	t.eq(Profile.stat("words"), 50, "v1 word stats kept")
	t.eq(Profile.stat("levels"), 0, "v1 level stats reset")
	t.eq(int(Save.data["version"]), 3, "saved as version 3")


## Every character the UI can show (including every fallback price) must be in
## Outfit or one of its bundled fallbacks, or the web build shows boxes.
func _glyphs() -> void:
	var base: FontFile = (UIKit.font(600) as FontVariation).base_font as FontFile
	var fonts: Array[Font] = [base]
	fonts.append_array(base.fallbacks)
	var text: String = "★☆♥✓…→–—×·%"
	for region: Variant in Store.REGIONAL_TIERS:
		for price: Variant in Store.REGIONAL_TIERS[region]:
			text += str(price)
	for region: Variant in Store.KEY_UNIT:
		text += str(Store.KEY_UNIT[region][0])
	for i: int in text.length():
		var code: int = text.unicode_at(i)
		var ok: bool = false
		for f: Font in fonts:
			if f.has_char(code):
				ok = true
				break
		t.ok(ok, "the fonts can draw '%s' (U+%04X)" % [text[i], code])


## Version 2 saves had 16 chapters: level progress starts over on the new
## chapters, keys spent on old levels and chapters come back, the rest is kept.
func _migrates_v2_saves() -> void:
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "coins": 420, "keys": 1, "chapter_keys": 0,
		"cleared": {"meadow-01": {"stars": 3}}, "progress": {"bamboo-03": {"found": [0]}}, "unlocked": {"meadow-07": true, "comet-02": true},
		"chapters_opened": {"glacier": true}, "last_level": "bamboo-03", "owned": {"supporter": true},
		"stats": {"levels": 30, "stars": 80, "perfect": 12, "words": 300}, "seen": {"intro_shadows": true, "rate_prompt": true}}))
	f.close()
	Save.load_data()
	t.eq(Profile.coins(), 420, "v2 coins kept")
	t.ok(not Profile.is_cleared("meadow-01"), "v2 level progress starts over (the chapters changed)")
	t.ok(Profile.saved_progress("bamboo-03").is_empty(), "v2 half-played levels dropped")
	t.eq(Profile.keys(), 3, "level keys spent on old levels come back")
	t.eq(Profile.chapter_keys(), 1, "chapter keys spent on old chapters come back")
	t.ok(not Profile.chapter_unlocked(1), "only chapter 1 is open")
	t.eq(Profile.stat("levels"), 0, "v2 level stats reset")
	t.eq(Profile.stat("words"), 300, "v2 word stats kept")
	t.ok(not Profile.seen("intro_shadows"), "the chapter idea cards show again")
	t.ok(Profile.seen("rate_prompt"), "other seen flags kept")
	t.eq(int(Save.data["version"]), 3, "saved as version 3")


## Saves from builds that called chapter keys "diamond keys" keep them.
func _migrates_diamond_keys() -> void:
	var f: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "coins": 50, "diamonds": 3}))
	f.close()
	Save.load_data()
	t.eq(Profile.chapter_keys(), 3, "old diamond keys become chapter keys")


## Streak achievements need that many days in a row; a missed day starts over.
func _streak_achievements() -> void:
	Save.data = Save.defaults()
	var t0: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 1, "day": 1, "hour": 12})
	var s: LevelState = LevelState.new(Catalog.daily_puzzle("2026-01-01"))
	for d: int in 9:
		Profile.complete_daily(Time.get_date_string_from_unix_time(t0 + d * 86400), s)
	# Day 10 is missed; then 5 more days.
	for d: int in range(10, 15):
		Profile.complete_daily(Time.get_date_string_from_unix_time(t0 + d * 86400), s)
	Profile.check_achievements()
	t.ok(Profile.achievement_done("streak_7"), "7 days in a row earns A Week of Light")
	t.ok(not Profile.achievement_done("streak_10"), "9 days, a miss, then 5 more is not 10 in a row")
	for d: int in range(15, 20):
		Profile.complete_daily(Time.get_date_string_from_unix_time(t0 + d * 86400), s)
	Profile.check_achievements()
	t.ok(Profile.achievement_done("streak_10"), "10 days in a row after the miss earns Ten Bright Days")
	t.ok(not Profile.achievement_done("streak_14"), "two weeks needs 14 days in a row")
	for id: String in ["streak_3", "streak_7", "streak_10", "streak_14", "streak_21", "streak_30"]:
		t.ok(not Achievements.by_id(id).is_empty(), "%s exists" % id)
