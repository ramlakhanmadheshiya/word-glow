class_name CoinChip
extends PanelContainer
## The coin balance. Counts up/down smoothly and pulses when it changes.

var _label: Label
var _shown: float = 0.0
var _tween: Tween


func _init() -> void:
	name = "Coins"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.28), 34, Color(1, 1, 1, 0.08), 2, Vector2(18, 10)))
	var row: HBoxContainer = UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(UIKit.icon_rect("coin", 36, Style.GOLD))
	_label = UIKit.label("0", 28, Style.INK, 700)
	_label.custom_minimum_size.x = 56
	row.add_child(_label)


func _ready() -> void:
	_shown = Profile.coins()
	_label.text = str(Profile.coins())
	Profile.coins_changed.connect(_on_changed)


func _on_changed(total: int) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(func(v: float) -> void:
		_shown = v
		_label.text = str(int(round(v)))
	, _shown, float(total), 0.6)
	pivot_offset = size / 2
	scale = Vector2(1.12, 1.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
