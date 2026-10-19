extends Node
## Stand-in ads for debug desktop builds and tests, so layouts and flows can be
## checked without a phone. No network, no SDK.

signal banner_resized(height_px: float)

const BANNER_PX: float = 60.0

## Tests set this so a rewarded "video" finishes on its own.
var auto_finish: bool = false
## Whether the next video counts as watched (tests can simulate skipping).
var earn: bool = true

var _layer: CanvasLayer
var _banner: Control


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)


## Mirrors AdMob: the banner's space is known before an ad loads.
func expected_banner_px() -> float:
	return BANNER_PX


## Counts banner reloads so tests can check navigation refreshes the ad.
var reloads: int = 0
var interstitials: int = 0


func reload_banner() -> void:
	reloads += 1
	if _banner != null:
		var l: Label = _banner.get_child(0)
		l.text = "Ad banner (test) · ad %d" % (reloads + 1)


func interstitial_ready() -> bool:
	return true


func show_interstitial(on_done: Callable) -> void:
	interstitials += 1
	if auto_finish:
		on_done.call_deferred()
		return
	_fullscreen("Video ad between levels (test)", func(_ok: bool) -> void: on_done.call())


func show_banner() -> void:
	if _banner != null:
		return
	var bar: ColorRect = ColorRect.new()
	bar.name = "MockBanner"
	bar.color = Color(0.06, 0.05, 0.12, 0.95)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	var win_h: float = float(maxi(1, DisplayServer.window_get_size().y))
	var vp_h: float = get_viewport().get_visible_rect().size.y
	bar.offset_top = -BANNER_PX * vp_h / win_h
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var l: Label = Label.new()
	l.text = "Ad banner (test)"
	l.add_theme_color_override("font_color", Color(Style.INK, 0.55))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	_banner = bar
	_layer.add_child(_banner)
	banner_resized.emit(BANNER_PX)


func hide_banner() -> void:
	if _banner != null:
		_banner.queue_free()
		_banner = null


func rewarded_ready() -> bool:
	return true


func show_rewarded(on_done: Callable) -> void:
	if auto_finish:
		on_done.call.call_deferred(earn)
		return
	_fullscreen("Rewarded video (test)", on_done)


func _fullscreen(text: String, on_done: Callable) -> void:
	var root: ColorRect = ColorRect.new()
	root.color = Color(0.03, 0.02, 0.08, 0.96)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(col)
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 32)
	col.add_child(l)
	var close: Button = Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 72)
	col.add_child(close)
	_layer.add_child(root)
	close.disabled = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void: close.disabled = false)
	close.pressed.connect(func() -> void:
		root.queue_free()
		on_done.call(earn)
	)
