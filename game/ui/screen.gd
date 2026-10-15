class_name Screen
extends Control
## Base for full-screen pages. Content goes in `body`, a column that is centred,
## capped at Style.MAX_WIDTH, kept clear of notches, and lifted above the ad
## banner so the banner never covers a button.

var app: App
var args: Dictionary = {}
var body: VBoxContainer
var _frame: MarginContainer


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_frame = MarginContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	body = UIKit.vbox(14)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(body)
	resized.connect(_fit)
	AdManager.banner_changed.connect(func(_h: float) -> void: _fit())
	build()
	_fit()


## Subclasses build their UI here.
func build() -> void:
	pass


## The chapter whose colours this screen uses ({} for the home colours).
func chapter_info() -> Dictionary:
	return {}


## Sky colours for this screen (top, bottom), honouring the chosen theme.
func sky() -> Array[Color]:
	return Look.sky(chapter_info())


func accent() -> Color:
	return Look.accent(chapter_info())


## True while a level is being played (Settings then hides Reset progress).
func in_game() -> bool:
	return false


## Return true if the screen handled Back itself.
func on_back() -> bool:
	return false


## Called when an overlay above this screen closes.
func refresh() -> void:
	pass


func _fit() -> void:
	if _frame == null:
		return
	var insets: Vector4 = App.safe_insets(self)
	var side: float = maxf(Style.GUTTER, (size.x - Style.MAX_WIDTH) / 2.0)
	_frame.add_theme_constant_override("margin_left", int(maxf(side, insets.x + Style.GUTTER)))
	_frame.add_theme_constant_override("margin_right", int(maxf(side, insets.z + Style.GUTTER)))
	_frame.add_theme_constant_override("margin_top", int(insets.y + 16))
	_frame.add_theme_constant_override("margin_bottom", int(insets.w + 16 + AdManager.banner_height))


## The standard header: Back on the left, the title in the middle (with an
## optional caption above it) and Settings on the right.
func header(title: String, caption: String = "", on_back_pressed: Callable = Callable()) -> HBoxContainer:
	var bar: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	bar.name = "Header"
	bar.custom_minimum_size.y = 92
	var back: Button = UIKit.icon_button("chevron-left", Style.TOP_BUTTON)
	back.name = "Back"
	back.pressed.connect(on_back_pressed if on_back_pressed.is_valid() else func() -> void: app.back())
	bar.add_child(back)
	var mid: VBoxContainer = UIKit.vbox(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	if not caption.is_empty():
		mid.add_child(UIKit.caption(caption, accent()))
	var t: Label = UIKit.label(title, Style.SIZE_H2, Style.INK, 600)
	t.name = "Title"
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(t)
	bar.add_child(mid)
	var settings: Button = UIKit.icon_button("settings", Style.TOP_BUTTON)
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings())
	bar.add_child(settings)
	return bar


## A right-aligned row of chips (keys, coins) under a header.
func chip_row(chips: Array) -> HBoxContainer:
	var row: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_END)
	row.name = "Chips"
	for c: Control in chips:
		row.add_child(c)
	return row
