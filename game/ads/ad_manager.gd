extends Node
## All ad decisions live here so ads stay polite:
## - a small banner at the bottom of the home, chapter, level and game screens,
##   with layout space reserved so it never covers a button;
## - a rewarded video only when the player asks for one (a hint when coins run
##   out, free coins, a level key, or a pack trial);
## - a short video between levels after every LEVELS_PER_VIDEO cleared levels.
## The banner loads a fresh ad when the player moves between screens, at most
## once every BANNER_REFRESH_SECONDS (AdMob asks for at least 30 s between
## refreshes). Supporters see no banners and no videos between levels.
## Providers: AdMob on Android (plugin), a visible mock on debug desktop builds,
## and nothing at all elsewhere (web, release desktop).

signal banner_changed(height: float)
signal rewarded_finished(ok: bool)

## Loaded lazily: it references plugin classes that only exist on Android.
const ADMOB_PROVIDER_PATH: String = "res://game/ads/providers/admob_provider.gd"
const MockProvider: GDScript = preload("res://game/ads/providers/mock_ad_provider.gd")

const LEVELS_PER_VIDEO: int = 5
const BANNER_REFRESH_SECONDS: float = 30.0

var provider: Node = null
var _last_banner_load_msec: int = -1000000
## Banner height in viewport units (0 when no banner is showing).
var banner_height: float = 0.0
var _banner_on: bool = false


func _ready() -> void:
	if Engine.has_singleton("PoingGodotAdMob"):
		use_provider((load(ADMOB_PROVIDER_PATH) as GDScript).new())
	elif OS.is_debug_build() and not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		use_provider(MockProvider.new())
	Profile.supporter_changed.connect(func(_on: bool) -> void: refresh_banner())


## Swaps the ad provider (tests use the mock in headless runs).
func use_provider(p: Node) -> void:
	if provider != null:
		provider.queue_free()
	_banner_on = false
	provider = p
	if provider != null:
		provider.name = "AdProvider"
		add_child(provider)
		provider.banner_resized.connect(_on_banner_resized)


func ads_enabled() -> bool:
	return provider != null and not Profile.is_supporter()


## Shows the bottom banner unless the player is a Supporter.
func refresh_banner() -> void:
	var want: bool = ads_enabled()
	if want == _banner_on:
		return
	_banner_on = want
	if provider == null:
		return
	if want:
		_last_banner_load_msec = Time.get_ticks_msec()
		provider.show_banner()
	else:
		provider.hide_banner()
		_on_banner_resized(0.0)


func _on_banner_resized(height_px: float) -> void:
	# Convert device pixels to viewport units so layouts can reserve the space.
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var vp: Vector2 = get_viewport().get_visible_rect().size
	banner_height = height_px * (vp.y / maxf(1.0, win.y)) if height_px > 0.0 else 0.0
	banner_changed.emit(banner_height)


## Called on every screen change: shows a fresh banner ad if the last one has
## been up long enough.
func screen_changed() -> void:
	if not _banner_on or provider == null or not provider.has_method("reload_banner"):
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_banner_load_msec < int(BANNER_REFRESH_SECONDS * 1000.0):
		return
	_last_banner_load_msec = now
	provider.reload_banner()


## Counts a cleared level; every LEVELS_PER_VIDEO levels, plays a short video
## before `then` runs. Otherwise (or for Supporters, or with no ads) `then`
## runs straight away.
func after_level(then: Callable) -> void:
	var n: int = int(Save.data.get("levels_since_video", 0)) + 1
	Save.data["levels_since_video"] = n
	Save.mark_dirty()
	if n < LEVELS_PER_VIDEO or not ads_enabled() or not provider.has_method("show_interstitial") or not provider.interstitial_ready():
		then.call()
		return
	Save.data["levels_since_video"] = 0
	Audio.stop_music_briefly()
	provider.show_interstitial(func() -> void: then.call())


func rewarded_ready() -> bool:
	return provider != null and provider.rewarded_ready()


## Plays a rewarded video; callback(ok) is true if the reward was earned.
func show_rewarded(callback: Callable) -> void:
	if not rewarded_ready():
		callback.call(false)
		return
	provider.show_rewarded(func(ok: bool) -> void:
		rewarded_finished.emit(ok)
		callback.call(ok)
	)
