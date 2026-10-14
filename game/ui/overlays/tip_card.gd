class_name TipCard
extends Overlay
## The tip jar: say thanks, as often as you like. A tip opens nothing new.
## Four quick amounts, or your own (Google Play sells fixed prices, so a custom
## tip rounds to the nearest 10).

var _status: Label
var _amount: int = 500
var _amount_label: Label
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
	minus.pressed.connect(func() -> void: _nudge(-Store.TIP_STEP * 5))
	row.add_child(minus)
	_amount_label = UIKit.label("", 40, Style.INK, 600)
	_amount_label.custom_minimum_size.x = 180
	row.add_child(_amount_label)
	var plus: Button = UIKit.icon_button("plus", 68)
	plus.name = "TipPlus"
	plus.pressed.connect(func() -> void: _nudge(Store.TIP_STEP * 5))
	row.add_child(plus)
	body.add_child(row)
	_custom = UIKit.button("", "primary", Style.AMBER, 88, 28, "heart")
	_custom.name = "TipCustom"
	_custom.pressed.connect(func() -> void: _tip(_amount))
	body.add_child(_custom)
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	body.add_child(_status)
	Store.purchase_finished.connect(func(ok: bool, msg: String, _id: String) -> void:
		if is_inside_tree():
			_status.text = msg
			if ok:
				Audio.play("unlock", 1.0, -3.0)
	)
	_nudge(0)


func _nudge(d: int) -> void:
	_amount = clampi(_amount + d, Store.TIP_MIN, Store.TIP_MAX)
	_amount_label.text = Store.price("tip_%d" % _amount)
	_custom.text = "Tip %s" % Store.price("tip_%d" % _amount)


func _tip(rupees: int) -> void:
	_status.text = "Opening Google Play…"
	Store.buy("tip_%d" % (int(round(rupees / float(Store.TIP_STEP))) * Store.TIP_STEP))
