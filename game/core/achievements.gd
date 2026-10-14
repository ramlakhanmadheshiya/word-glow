class_name Achievements
extends RefCounted
## Achievement definitions. Each is unlocked once when `stat` reaches `goal`,
## and pays its reward exactly once (see Profile.check_achievements).

const LIST: Array[Dictionary] = [
	{"id": "first_light", "title": "First Light", "desc": "Clear your first level", "stat": "levels", "goal": 1, "reward": 20, "icon": "lantern"},
	{"id": "lamplighter", "title": "Lamplighter", "desc": "Clear 25 levels", "stat": "levels", "goal": 25, "reward": 60, "icon": "lantern"},
	{"id": "keeper", "title": "Keeper of Lanterns", "desc": "Clear 100 levels", "stat": "levels", "goal": 100, "reward": 150, "icon": "lantern"},
	{"id": "all_lit", "title": "Every Light Lit", "desc": "Clear all 160 levels", "stat": "levels", "goal": 160, "reward": 400, "icon": "trophy"},
	{"id": "word_100", "title": "Word Collector", "desc": "Find 100 words", "stat": "words", "goal": 100, "reward": 40, "icon": "book"},
	{"id": "word_500", "title": "Wordsmith", "desc": "Find 500 words", "stat": "words", "goal": 500, "reward": 120, "icon": "book"},
	{"id": "flawless_10", "title": "Steady Hand", "desc": "Clear 10 levels without hints", "stat": "flawless", "goal": 10, "reward": 50, "icon": "star"},
	{"id": "flawless_50", "title": "Bright Mind", "desc": "Clear 50 levels without hints", "stat": "flawless", "goal": 50, "reward": 150, "icon": "star"},
	{"id": "daily_1", "title": "Night Watch", "desc": "Finish a daily lantern", "stat": "dailies", "goal": 1, "reward": 20, "icon": "calendar"},
	{"id": "streak_3", "title": "Three Nights", "desc": "Keep a 3-day daily streak", "stat": "best_streak", "goal": 3, "reward": 40, "icon": "flame"},
	{"id": "streak_7", "title": "A Week of Light", "desc": "Keep a 7-day daily streak", "stat": "best_streak", "goal": 7, "reward": 100, "icon": "flame"},
	{"id": "beacon_10", "title": "Beacon Keeper", "desc": "Light 10 beacons", "stat": "beacons", "goal": 10, "reward": 50, "icon": "flame"},
	{"id": "worlds_4", "title": "Far Horizons", "desc": "Unlock 4 worlds", "stat": "worlds", "goal": 4, "reward": 80, "icon": "globe"},
]


static func by_id(id: String) -> Dictionary:
	for a: Dictionary in LIST:
		if a["id"] == id:
			return a
	return {}
