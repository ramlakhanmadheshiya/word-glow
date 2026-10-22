class_name Achievements
extends RefCounted
## Achievement definitions. Each unlocks once when `stat` reaches `goal` and
## pays its reward exactly once (see Profile.check_achievements). Every chapter
## also has its own "chapter complete" achievement, built from the catalogue.

const BASE: Array[Dictionary] = [
	{"id": "first_light", "title": "First Light", "desc": "Clear your first level", "stat": "levels", "goal": 1, "reward": 20, "icon": "lantern"},
	{"id": "lamplighter", "title": "Lamplighter", "desc": "Clear 50 levels", "stat": "levels", "goal": 50, "reward": 60, "icon": "lantern"},
	{"id": "keeper", "title": "Keeper of Light", "desc": "Clear 200 levels", "stat": "levels", "goal": 200, "reward": 200, "icon": "lantern"},
	{"id": "all_lit", "title": "Every Light Lit", "desc": "Clear all 320 levels", "stat": "levels", "goal": 320, "reward": 1000, "icon": "trophy"},
	{"id": "stars_50", "title": "Starlit", "desc": "Earn 50 stars", "stat": "stars", "goal": 50, "reward": 40, "icon": "star"},
	{"id": "stars_300", "title": "Constellation", "desc": "Earn 300 stars", "stat": "stars", "goal": 300, "reward": 150, "icon": "star"},
	{"id": "stars_1000", "title": "Galaxy", "desc": "Earn 600 stars", "stat": "stars", "goal": 600, "reward": 400, "icon": "star"},
	{"id": "stars_all", "title": "Every Star", "desc": "Earn all 960 stars", "stat": "stars", "goal": 960, "reward": 1000, "icon": "star-filled"},
	{"id": "perfect_10", "title": "Steady Hand", "desc": "Clear 10 levels perfectly", "stat": "perfect", "goal": 10, "reward": 50, "icon": "star-filled"},
	{"id": "perfect_100", "title": "Bright Mind", "desc": "Clear 100 levels perfectly", "stat": "perfect", "goal": 100, "reward": 200, "icon": "star-filled"},
	{"id": "word_500", "title": "Wordsmith", "desc": "Find 500 words", "stat": "words", "goal": 500, "reward": 80, "icon": "book"},
	{"id": "word_2500", "title": "Lexicon", "desc": "Find 2,500 words", "stat": "words", "goal": 2500, "reward": 300, "icon": "book"},
	{"id": "daily_1", "title": "Night Watch", "desc": "Finish a daily puzzle", "stat": "dailies", "goal": 1, "reward": 20, "icon": "calendar"},
	# Daily streaks count days in a row: missing a day starts the count again.
	{"id": "streak_3", "title": "Three Nights", "desc": "Play the daily puzzle 3 days in a row", "stat": "best_streak", "goal": 3, "reward": 40, "icon": "flame"},
	{"id": "streak_7", "title": "A Week of Light", "desc": "Play the daily puzzle 7 days in a row", "stat": "best_streak", "goal": 7, "reward": 100, "icon": "flame"},
	{"id": "streak_10", "title": "Ten Bright Days", "desc": "Play the daily puzzle 10 days in a row", "stat": "best_streak", "goal": 10, "reward": 150, "icon": "flame"},
	{"id": "streak_14", "title": "Two Weeks Glowing", "desc": "Play the daily puzzle 14 days in a row", "stat": "best_streak", "goal": 14, "reward": 250, "icon": "flame"},
	{"id": "streak_21", "title": "Three Weeks Strong", "desc": "Play the daily puzzle 21 days in a row", "stat": "best_streak", "goal": 21, "reward": 400, "icon": "flame"},
	{"id": "streak_30", "title": "A Month of Glow", "desc": "Play the daily puzzle 30 days in a row", "stat": "best_streak", "goal": 30, "reward": 600, "icon": "flame"},
	{"id": "beacon_25", "title": "Beacon Keeper", "desc": "Light 25 beacons", "stat": "beacons", "goal": 25, "reward": 60, "icon": "flame"},
]

const CHAPTER_REWARD: int = 50


## Base achievements plus one per chapter ("Meadow complete").
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = BASE.duplicate()
	for i: int in Catalog.chapter_count():
		var ch: Dictionary = Catalog.chapter(i)
		out.append({
			"id": "chapter_" + str(ch["id"]), "title": "%s complete" % ch["name"],
			"desc": "Clear all %d levels of chapter %d" % [Catalog.levels_per_chapter, i + 1],
			"stat": "ch_" + str(ch["id"]), "goal": 1, "reward": CHAPTER_REWARD, "icon": "trophy",
		})
	return out


static func by_id(id: String) -> Dictionary:
	for a: Dictionary in all():
		if a["id"] == id:
			return a
	return {}
