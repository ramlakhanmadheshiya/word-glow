class_name Economy
extends RefCounted
## Every coin amount, hint price and star rule in one place.

const START_COINS: int = 150
## First clear of a level.
const LEVEL_REWARD: int = 5
## Paid for each star earned for the first time (so improving 1★ -> 3★ pays 10 more).
const STAR_REWARD: int = 5
## Clearing all 40 levels of a chapter.
const CHAPTER_BONUS: int = 100
const DAILY_REWARD: int = 30
const STREAK_BONUS_PER_DAY: int = 5
const STREAK_BONUS_CAP_DAYS: int = 6

const SPARK_COST: int = 25
const LANTERN_COST: int = 60
## Free Sparks each day (Supporters get more).
const FREE_SPARKS: int = 1
const SUPPORTER_FREE_SPARKS: int = 3
## "Free coins" videos in the shop.
const VIDEO_COINS: int = 25
const VIDEO_COINS_PER_DAY: int = 5
## Level keys from videos.
const VIDEO_KEYS_PER_DAY: int = 5
## Chapter keys (open a whole locked chapter) from videos.
const VIDEO_CHAPTER_KEYS_PER_DAY: int = 1
## Cosmetic pack trial from a video.
const TRIAL_SECONDS: int = 3600

## Extra moves (wrong words + hints) still worth two stars.
const TWO_STAR_EXTRA: int = 3


## ★★★ for a perfect solve (no wrong words, no hints), ★★ for up to
## TWO_STAR_EXTRA extra moves, ★ otherwise.
static func stars_for(extra_moves: int) -> int:
	if extra_moves <= 0:
		return 3
	if extra_moves <= TWO_STAR_EXTRA:
		return 2
	return 1


## Coins for clearing a daily on day `streak` of a streak (streak >= 1).
static func daily_reward(streak: int) -> int:
	return DAILY_REWARD + STREAK_BONUS_PER_DAY * clampi(streak - 1, 0, STREAK_BONUS_CAP_DAYS)
