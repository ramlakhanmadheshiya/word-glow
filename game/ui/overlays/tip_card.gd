class_name TipCard
extends Overlay
## The tip jar, like Single Shot's: four quick amounts, or type your own.
## − / + step by 10, and a typed amount rounds to the nearest 10 (Google Play
## sells fixed prices, so each amount is its own product).

var _status: Label
var _amount: LineEdit
var _custom: Button


func build() -> void:
	name = "Tips"
	add_title("Tip jar")
	body.add_child(UIKit.para("Say thanks, as often as you like. A tip opens nothing new: it all goes into making the next chapter.", Style.SIZE_SMALL))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for rupees: int in Store.TIP_PRESETS:
		var b: Button = UIKit.button(Store.price("tip_%d" % rupees), "soft", Style.AMBER, 84, 28)
		b.name = "Tip_%d" % rupees
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _tip(rupees))
		grid.add_child(b)
	body.add_child(UIKit.caption("Or your own amount"))
	var row: HBoxContainer = UIKit.hbox(14)
	var minus: Button = UIKit.icon_button("minus", 68)
	minus.name = "TipMinus"
	minus.pressed.connect(func() -> void: _nudge(-Store.TIP_STEP))
	row.add_child(minus)
	_amount = LineEdit.new()
	_amount.name = "TipAmount"
	_amount.text = "500"
	_amount.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount.custom_minimum_size = Vector2(220, 76)
	_amount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_amount.max_length = 4
	_amount.add_theme_font_override("font", UIKit.font(600))
	_amount.add_theme_font_size_override("font_size", 34)
	_amount.add_theme_color_override("font_color", Style.INK)
	_amount.add_theme_color_override("caret_color", Style.AMBER)
	var box: StyleBoxFlat = UIKit.box(Style.FIELD, 36, Color(Style.INK, 0.15), 2, Vector2(18, 6))
	_amount.add_theme_stylebox_override("normal", box)
	var focus: StyleBoxFlat = box.duplicate()
	focus.border_color = Style.AMBER
	_amount.add_theme_stylebox_override("focus", focus)
	_amount.text_changed.connect(func(t: String) -> void:
		# Digits only.
		var digits: String = ""
		for ch: String in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != t:
			_amount.text = digits
			_amount.caret_column = digits.length()
		_refresh_custom()
	)
	_amount.text_submitted.connect(func(_t: String) -> void:
		_amount.text = str(_value())
		_refresh_custom()
	)
	row.add_child(_amount)
	var plus: Button = UIKit.icon_button("plus", 68)
	plus.name = "TipPlus"
	plus.pressed.connect(func() -> void: _nudge(Store.TIP_STEP))
	row.add_child(plus)
	body.add_child(row)
	_custom = UIKit.button("", "primary", Style.AMBER, 88, 28, "art:heart")
	_custom.name = "TipCustom"
	_custom.pressed.connect(func() -> void:
		_amount.text = str(_value())
		_tip(_value())
	)
	body.add_child(_custom)
	_status = UIKit.para(_thanks(), Style.SIZE_SMALL, Style.AMBER)
	_status.name = "Status"
	body.add_child(_status)
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if is_inside_tree() and (Store.is_tip(id) or id.is_empty()):
			_status.text = msg if not ok else _thanks()
			if ok:
				Audio.play("unlock", 1.0, -3.0)
	)
	_refresh_custom()


## The typed amount, rounded to the nearest 10 and kept in range.
func _value() -> int:
	var raw: int = _amount.text.to_int()
	var r: int = int(round(float(raw) / float(Store.TIP_STEP))) * Store.TIP_STEP
	return clampi(r, Store.TIP_MIN, Store.TIP_MAX)


func _nudge(by: int) -> void:
	_amount.text = str(clampi(_value() + by, Store.TIP_MIN, Store.TIP_MAX))
	_refresh_custom()


func _refresh_custom() -> void:
	var v: int = _value()
	_custom.text = "Tip %s" % Store.price("tip_%d" % v)
	var typed: int = _amount.text.to_int()
	if typed > 0 and typed != v:
		_status.text = "Google Play takes amounts in steps of %d, so that's %s" % [Store.TIP_STEP, Store.price("tip_%d" % v)]
	elif _status != null and _status.text.begins_with("Google Play takes"):
		_status.text = _thanks()


func _tip(rupees: int) -> void:
	_status.text = "Opening Google Play…"
	Store.buy("tip_%d" % rupees)


func _thanks() -> String:
	var n: int = Profile.tips_given()
	return "" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"]
