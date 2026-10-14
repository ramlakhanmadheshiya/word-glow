class_name Economy
extends RefCounted
## Every coin amount and hint price in one place.

const START_COINS: int = 150
const LEVEL_REWARD: int = 10
const FLAWLESS_BONUS: int = 5
const WORLD_BONUS: int = 50
const DAILY_REWARD: int = 30
const STREAK_BONUS_PER_DAY: int = 5
const STREAK_BONUS_CAP_DAYS: int = 6
const SPARK_COST: int = 25
const LANTERN_COST: int = 60


## Coins for clearing a daily on day `streak` of a streak (streak >= 1).
static func daily_reward(streak: int) -> int:
	return DAILY_REWARD + STREAK_BONUS_PER_DAY * clampi(streak - 1, 0, STREAK_BONUS_CAP_DAYS)
