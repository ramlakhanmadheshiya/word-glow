class_name CounterChip
extends PanelContainer
## A balance pill (coins or level keys). Counts smoothly to new values, pulses
## when they change, and can be tapped (coins open the shop, keys the key shop).

signal pressed

var _label: Label
var _shown: float = 0.0
var _tween: Tween
var _kind: String


## kind: "coins" or "keys".
func _init(kind: String = "coins") -> void:
	_kind = kind
	name = "Coins" if kind == "coins" else "Keys"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.28), 34, Color(1, 1, 1, 0.08), 2, Vector2(18, 10)))
	var row: HBoxContainer = UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(UIKit.icon_rect("coin" if kind == "coins" else "key-round", 34, Style.GOLD if kind == "coins" else Style.AMBER))
	_label = UIKit.label("0", 28, Style.INK, 700)
	_label.custom_minimum_size.x = 40 if kind == "keys" else 56
	row.add_child(_label)
	row.add_child(UIKit.icon_rect("plus", 22, Color(Style.INK, 0.5)))


func _value() -> int:
	return Profile.coins() if _kind == "coins" else Profile.keys()


func _ready() -> void:
	_shown = _value()
	_label.text = str(_value())
	if _kind == "coins":
		Profile.coins_changed.connect(_on_changed)
	else:
		Profile.keys_changed.connect(_on_changed)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		Audio.play("click", 1.0, -6.0)
		pressed.emit()
		accept_event()


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
