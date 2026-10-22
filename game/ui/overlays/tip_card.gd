class_name TipCard
extends Overlay
## The tip jar, like Single Shot's: four quick amounts, or pick your own with
## − / + and a slider. Every amount is shown as Google Play's price in the
## player's own currency (rupees in India, dollars in the USA, and so on), so
## nobody has to think in rupees. Each amount is its own product, ₹10 to ₹10,000.

var _status: Label
var _price: Label
var _slider: HSlider
var _custom: Button
var _presets: Dictionary = {}     # rupees -> Button
var _amounts: Array = Store.tip_amounts()
var _index: int = 0


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
		_presets[rupees] = b
	body.add_child(UIKit.caption("Or choose your own amount"))
	var row: HBoxContainer = UIKit.hbox(14)
	var minus: Button = UIKit.icon_button("minus", 68)
	minus.name = "TipMinus"
	minus.pressed.connect(func() -> void: _select(_index - 1))
	row.add_child(minus)
	_price = UIKit.label("", 34, Style.INK, 600)
	_price.name = "TipPrice"
	_price.custom_minimum_size = Vector2(220, 76)
	_price.add_theme_stylebox_override("normal", UIKit.box(Style.FIELD, 36, Color(Style.INK, 0.15), 2, Vector2(18, 6)))
	row.add_child(_price)
	var plus: Button = UIKit.icon_button("plus", 68)
	plus.name = "TipPlus"
	plus.pressed.connect(func() -> void: _select(_index + 1))
	row.add_child(plus)
	body.add_child(row)
	_slider = _make_slider()
	body.add_child(_slider)
	_custom = UIKit.button("", "primary", Style.AMBER, 88, 28, "art:heart")
	_custom.name = "TipCustom"
	_custom.pressed.connect(func() -> void: _tip(amount()))
	body.add_child(_custom)
	_status = UIKit.para(_thanks(), Style.SIZE_SMALL, Style.AMBER)
	_status.name = "Status"
	body.add_child(_status)
	body.add_child(UIKit.no_refunds())
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if is_inside_tree() and (Store.is_tip(id) or id.is_empty()):
			_status.text = msg if not ok else _thanks()
			if ok:
				Audio.play("unlock", 1.0, -3.0)
	)
	# Google Play's real prices replace the fallbacks as they arrive.
	Store.price_updated.connect(func(id: String, _p: String) -> void:
		if is_inside_tree() and Store.is_tip(id):
			_refresh_prices()
	)
	_select(_amounts.find(500))


## The selected amount in rupees (the product id; never shown to the player).
func amount() -> int:
	return int(_amounts[_index])


func _make_slider() -> HSlider:
	var s: HSlider = HSlider.new()
	s.name = "TipSlider"
	s.min_value = 0
	s.max_value = _amounts.size() - 1
	s.step = 1
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 56)
	s.focus_mode = Control.FOCUS_ALL
	s.add_theme_stylebox_override("slider", UIKit.box(Color(Style.INK, 0.14), 6, Color.TRANSPARENT, 0, Vector2(0, 6)))
	var fill: StyleBoxFlat = UIKit.box(Style.AMBER, 6, Color.TRANSPARENT, 0, Vector2(0, 6))
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", UIKit._knob(false, Style.AMBER))
	s.add_theme_icon_override("grabber_highlight", UIKit._knob(true, Style.AMBER))
	s.value_changed.connect(func(v: float) -> void:
		if int(v) != _index:
			_select(int(v))
			Audio.play("tap", 1.0 + v / float(_amounts.size()) * 0.5, -8.0)
	)
	return s


func _select(i: int) -> void:
	_index = clampi(i, 0, _amounts.size() - 1)
	if _slider != null and int(_slider.value) != _index:
		_slider.set_value_no_signal(_index)
	_refresh_prices()


func _refresh_prices() -> void:
	var p: String = Store.price("tip_%d" % amount())
	_price.text = p
	_custom.text = "Tip %s" % p
	for rupees: int in _presets:
		(_presets[rupees] as Button).text = Store.price("tip_%d" % rupees)


func _tip(rupees: int) -> void:
	_status.text = "Opening Google Play…"
	Store.buy("tip_%d" % rupees)


func _thanks() -> String:
	var n: int = Profile.tips_given()
	return "" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"]
