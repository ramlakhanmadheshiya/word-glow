extends Node
## The player's progress and wallet: unlocks, rewards, hints, daily streaks and
## achievements. Every reward is keyed by what earned it, so it can be paid only once.

signal coins_changed(total: int)
signal achievement_unlocked(achievement: Dictionary)
signal settings_changed

var _d: Dictionary:
	get:
		return Save.data


# --- Coins -------------------------------------------------------------------

func coins() -> int:
	return int(_d["coins"])


func add_coins(n: int) -> void:
	if n <= 0:
		return
	_d["coins"] = coins() + n
	Save.mark_dirty()
	coins_changed.emit(coins())


## Takes coins if the player has enough. Returns false (and changes nothing) otherwise.
func spend(n: int) -> bool:
	if n < 0 or coins() < n:
		return false
	_d["coins"] = coins() - n
	Save.mark_dirty()
	coins_changed.emit(coins())
	return true


## One Spark a day is free, so nobody is ever stuck without coins.
func free_spark_available() -> bool:
	return str(_d["free_spark_date"]) != Catalog.today_key()


func use_free_spark() -> bool:
	if not free_spark_available():
		return false
	_d["free_spark_date"] = Catalog.today_key()
	Save.mark_dirty()
	return true


# --- Levels and worlds -------------------------------------------------------

func is_cleared(id: String) -> bool:
	return (_d["cleared"] as Dictionary).has(id)


func is_flawless(id: String) -> bool:
	return bool((_d["cleared"] as Dictionary).get(id, {}).get("flawless", false))


func world_clears(world_idx: int) -> int:
	var w: Dictionary = Catalog.world(world_idx)
	if w.is_empty():
		return 0
	var n: int = 0
	for k: int in range(1, Catalog.LEVELS_PER_WORLD + 1):
		if is_cleared(Catalog.level_id(w["id"], k)):
			n += 1
	return n


func world_unlocked(world_idx: int) -> bool:
	if world_idx <= 0:
		return world_idx == 0
	if world_idx >= Catalog.world_count():
		return false
	return world_clears(world_idx - 1) >= Catalog.unlock_clears


func level_unlocked(world_idx: int, n: int) -> bool:
	if not world_unlocked(world_idx) or n < 1 or n > Catalog.LEVELS_PER_WORLD:
		return false
	return n == 1 or is_cleared(Catalog.level_id(Catalog.world(world_idx)["id"], n - 1))


func unlocked_world_count() -> int:
	var n: int = 0
	for i: int in Catalog.world_count():
		if world_unlocked(i):
			n += 1
	return n


## Where "Continue" should go: the last level played if it is still unfinished,
## otherwise the first open, uncleared level.
func next_level() -> Array[int]:
	var last: String = str(_d["last_level"])
	if not last.is_empty() and not is_cleared(last):
		var wn: Array[int] = Catalog.parse_level_id(last)
		if wn[0] >= 0 and level_unlocked(wn[0], wn[1]):
			return wn
	for w: int in Catalog.world_count():
		if not world_unlocked(w):
			continue
		for n: int in range(1, Catalog.LEVELS_PER_WORLD + 1):
			if level_unlocked(w, n) and not is_cleared(Catalog.level_id(Catalog.world(w)["id"], n)):
				return [w, n]
	return [maxi(0, Catalog.world_count() - 1), Catalog.LEVELS_PER_WORLD]


func set_last_level(id: String) -> void:
	if not id.begins_with("daily-"):
		_d["last_level"] = id
		Save.mark_dirty()


# --- In-level progress (survives restarts) -----------------------------------

func saved_progress(id: String) -> Dictionary:
	return (_d["progress"] as Dictionary).get(id, {})


func store_progress(id: String, state: LevelState) -> void:
	_d["progress"][id] = state.to_dict()
	Save.mark_dirty()


func clear_progress(id: String) -> void:
	(_d["progress"] as Dictionary).erase(id)
	Save.mark_dirty()


# --- Rewards -----------------------------------------------------------------

## Records a found word (and beacons it lit) for stats and achievements.
func record_word(beacons_lit: int) -> void:
	var s: Dictionary = _d["stats"]
	s["words"] = int(s["words"]) + 1
	s["beacons"] = int(s["beacons"]) + beacons_lit
	Save.mark_dirty()


func record_hint() -> void:
	_d["stats"]["hints"] = int(_d["stats"]["hints"]) + 1
	Save.mark_dirty()


## Marks a level cleared and pays for it. Paying is idempotent: replaying a
## cleared level returns coins = 0. Returns what happened for the result card.
func complete_level(id: String, state: LevelState) -> Dictionary:
	var flawless: bool = state.hints_used == 0
	var first: bool = not is_cleared(id)
	var wn: Array[int] = Catalog.parse_level_id(id)
	var worlds_before: int = unlocked_world_count()
	var clears_before: int = world_clears(wn[0])
	var reward: int = 0
	var cleared: Dictionary = _d["cleared"]
	if first:
		cleared[id] = {"flawless": flawless}
		reward = Economy.LEVEL_REWARD + (Economy.FLAWLESS_BONUS if flawless else 0)
		var s: Dictionary = _d["stats"]
		s["levels"] = int(s["levels"]) + 1
		if flawless:
			s["flawless"] = int(s["flawless"]) + 1
	elif flawless and not is_flawless(id):
		cleared[id]["flawless"] = true
		_d["stats"]["flawless"] = int(_d["stats"]["flawless"]) + 1
	var world_done: bool = first and clears_before == Catalog.LEVELS_PER_WORLD - 1 and world_clears(wn[0]) == Catalog.LEVELS_PER_WORLD
	if world_done:
		reward += Economy.WORLD_BONUS
	clear_progress(id)
	_d["stats"]["worlds"] = unlocked_world_count()
	add_coins(reward)
	Save.mark_dirty()
	return {
		"coins": reward, "first": first, "flawless": flawless, "world_done": world_done,
		"world_unlocked": unlocked_world_count() > worlds_before,
	}


func daily_done(date_key: String) -> bool:
	return (_d["daily"]["done"] as Dictionary).has(date_key)


## The streak as it stands today: it survives until a whole day is missed.
func current_streak() -> int:
	var daily: Dictionary = _d["daily"]
	var last: String = str(daily["last_date"])
	if last.is_empty():
		return 0
	var gap: int = Catalog.day_number(Catalog.today_key()) - Catalog.day_number(last)
	return int(daily["streak"]) if gap <= 1 else 0


## Pays for a daily once per date and extends the streak when days are consecutive.
func complete_daily(date_key: String, state: LevelState) -> Dictionary:
	var daily: Dictionary = _d["daily"]
	var date_id: String = "daily-" + date_key
	clear_progress(date_id)
	if daily_done(date_key):
		return {"coins": 0, "first": false, "streak": current_streak(), "flawless": state.hints_used == 0}
	daily["done"][date_key] = true
	var last: String = str(daily["last_date"])
	var streak: int = 1
	if not last.is_empty():
		var gap: int = Catalog.day_number(date_key) - Catalog.day_number(last)
		if gap == 1:
			streak = int(daily["streak"]) + 1
		elif gap <= 0:
			streak = maxi(1, int(daily["streak"]))
	if last.is_empty() or Catalog.day_number(date_key) >= Catalog.day_number(last):
		daily["last_date"] = date_key
		daily["streak"] = streak
	daily["best_streak"] = maxi(int(daily["best_streak"]), streak)
	var s: Dictionary = _d["stats"]
	s["dailies"] = int(s["dailies"]) + 1
	s["best_streak"] = int(daily["best_streak"])
	var reward: int = Economy.daily_reward(streak)
	add_coins(reward)
	Save.mark_dirty()
	return {"coins": reward, "first": true, "streak": streak, "flawless": state.hints_used == 0}


# --- Achievements ------------------------------------------------------------

func stat(key: String) -> int:
	return int(_d["stats"].get(key, 0))


func achievement_done(id: String) -> bool:
	return (_d["achievements"] as Dictionary).has(id)


## Unlocks (and pays, once) every achievement whose goal is met.
func check_achievements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in Achievements.LIST:
		if achievement_done(a["id"]) or stat(a["stat"]) < int(a["goal"]):
			continue
		_d["achievements"][a["id"]] = Catalog.today_key()
		add_coins(int(a["reward"]))
		out.append(a)
		achievement_unlocked.emit(a)
	if not out.is_empty():
		Save.mark_dirty()
	return out


# --- Settings and one-time flags ---------------------------------------------

func setting(key: String) -> bool:
	return bool(_d["settings"].get(key, true))


func set_setting(key: String, value: bool) -> void:
	_d["settings"][key] = value
	Save.mark_dirty()
	settings_changed.emit()


func seen(key: String) -> bool:
	return (_d["seen"] as Dictionary).has(key)


func mark_seen(key: String) -> void:
	_d["seen"][key] = true
	Save.mark_dirty()


func reset_all() -> void:
	Save.reset()
	coins_changed.emit(coins())
	settings_changed.emit()
