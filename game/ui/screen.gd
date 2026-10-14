class_name Screen
extends Control
## Base for full-screen pages. Content goes in `body`, a column that is centred,
## capped at Style.MAX_WIDTH and kept clear of notches and system bars.

var app: App
var args: Dictionary = {}
var body: VBoxContainer
var _frame: MarginContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_frame = MarginContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	body = UIKit.vbox(16)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(body)
	resized.connect(_fit)
	build()
	_fit()


## Subclasses build their UI here.
func build() -> void:
	pass


## Sky colours for this screen (top, bottom).
func sky() -> Array[Color]:
	return [Style.DEFAULT_SKY_TOP, Style.DEFAULT_SKY_BOTTOM]


## Return true if the screen handled Back itself.
func on_back() -> bool:
	return false


## Called when an overlay above this screen closes, and when returning to it.
func refresh() -> void:
	pass


func _fit() -> void:
	var insets: Vector4 = App.safe_insets(self)
	var side: float = maxf(Style.GUTTER, (size.x - Style.MAX_WIDTH) / 2.0)
	_frame.add_theme_constant_override("margin_left", int(maxf(side, insets.x + Style.GUTTER)))
	_frame.add_theme_constant_override("margin_right", int(maxf(side, insets.z + Style.GUTTER)))
	_frame.add_theme_constant_override("margin_top", int(insets.y + 20))
	_frame.add_theme_constant_override("margin_bottom", int(insets.w + 24))


## A top bar: optional back button, centred title block, and a right-side widget.
func top_bar(title: String, subtitle: String = "", show_back: bool = true, right: Control = null) -> HBoxContainer:
	var bar: HBoxContainer = UIKit.hbox(12, BoxContainer.ALIGNMENT_BEGIN)
	bar.custom_minimum_size.y = 96
	var left: Control
	if show_back:
		var back: Button = UIKit.icon_button("chevron-left", 84)
		back.name = "Back"
		back.pressed.connect(func() -> void: app.back())
		left = back
	else:
		left = Control.new()
		left.custom_minimum_size = Vector2(84, 84)
	bar.add_child(left)
	var mid: VBoxContainer = UIKit.vbox(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	if not subtitle.is_empty():
		mid.add_child(UIKit.caption(subtitle))
	mid.add_child(UIKit.label(title, Style.SIZE_H2, Style.INK, 600))
	bar.add_child(mid)
	if right == null:
		right = Control.new()
		right.custom_minimum_size = Vector2(84, 84)
	bar.add_child(right)
	return bar
