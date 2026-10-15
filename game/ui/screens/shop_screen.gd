extends Screen
## The shop, like Single Shot's: every pack with a live preview, its price and
## whether it's yours (tap for its card), then Coins, Level keys and the Tip jar
## as rows that open their own cards, and Restore purchases.

var _rows: Dictionary = {}
var _status: Label


func build() -> void:
	body.add_child(header("Shop", "Coins · packs · keys"))
	body.add_child(chip_row([UIKit.key_chip(), UIKit.coin_chip()]))
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list: VBoxContainer = UIKit.vbox(16)
	list.name = "List"
	scroll.set_content(list)
	list.add_child(UIKit.para("Every level in Word Lantern opens by playing.\nThese are extras, and they help me make more.", Style.SIZE_SMALL, Style.MUTED))
	for id: String in Store.PRODUCTS:
		var row: Button = _product_row(id)
		list.add_child(row)
		_rows[id] = row

	list.add_child(UIKit.caption("Coins, keys and thanks", Style.AMBER, Style.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT))
	list.add_child(_link_row("coins", "Coins", "Bags of 300 to 6,000 · free coins from a video", "Product_coins", func() -> void: app.open(CoinsCard.new())))
	list.add_child(_link_row("keys", "Level keys", "Open any locked level · 10% off for 5+", "Product_keys", func() -> void: app.open(KeysCard.new())))
	var n: int = Profile.tips_given()
	list.add_child(_link_row("tips", "Tip jar", "Say thanks, as often as you like" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"], "TipJar", func() -> void: app.open(TipCard.new())))

	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	list.add_child(_status)
	var restore: Button = UIKit.button("Restore purchases", "ghost", Style.AMBER, 76, 24)
	restore.name = "Restore"
	restore.custom_minimum_size.x = 360
	restore.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore.pressed.connect(func() -> void:
		_status.text = "Checking your purchases…"
		Store.restore()
	)
	list.add_child(restore)
	list.add_child(UIKit.para("One-time purchases through Google Play. No subscriptions.", Style.SIZE_CAPTION))
	list.add_child(UIKit.gap(20))
	Store.restore_finished.connect(func(_ok: bool, msg: String) -> void: _show_status(msg))
	Store.purchase_finished.connect(func(ok: bool, msg: String, _id: String) -> void:
		_show_status(msg)
		if ok:
			Audio.play("unlock", 1.0, -3.0)
	)
	Store.price_updated.connect(func(_id: String, _p: String) -> void: refresh())
	Profile.purchases_changed.connect(refresh)
	refresh()


func _show_status(msg: String) -> void:
	if is_inside_tree():
		_status.text = msg
		refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	for id: String in _rows:
		var tag: Label = (_rows[id] as Node).find_child("Price", true, false)
		var sub: Label = (_rows[id] as Node).find_child("Trial", true, false)
		if Profile.bought(id):
			tag.text = "Owned ✓"
			tag.add_theme_color_override("font_color", Style.SUCCESS)
		else:
			tag.text = Store.price(id)
			tag.add_theme_color_override("font_color", Style.GOLD)
		var clock: String = Profile.trial_clock(id)
		sub.text = "" if clock.is_empty() or Profile.bought(id) else "trial · %s left" % clock


func _process(_delta: float) -> void:
	# Keeps trial countdowns live.
	if Engine.get_process_frames() % 30 == 0:
		for id: String in _rows:
			var sub: Label = (_rows[id] as Node).find_child("Trial", true, false)
			var clock: String = Profile.trial_clock(id)
			sub.text = "" if clock.is_empty() or Profile.bought(id) else "trial · %s left" % clock


## One pack row: preview, name and blurb, and price / owned.
func _product_row(id: String) -> Button:
	var info: Dictionary = Store.PRODUCTS[id]
	var featured: bool = id == "complete_pack"
	var b: Button = Button.new()
	b.name = "Product_" + id
	b.custom_minimum_size = Vector2(0, 150 if featured else 132)
	b.focus_mode = Control.FOCUS_ALL
	_style_row(b, Color("3A2A5E") if featured else Color("2E2870"), Style.AMBER if featured else Color.TRANSPARENT)
	UIKit.juice(b)
	b.pressed.connect(func() -> void: _open_product(id))
	var row: HBoxContainer = UIKit.hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pv: ProductPreview = ProductPreview.new(id, 96)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var text: VBoxContainer = UIKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	if featured:
		text.add_child(UIKit.caption("Best value · save %d%%" % Store.complete_saving(), Style.AMBER, 16, HORIZONTAL_ALIGNMENT_LEFT))
	text.add_child(UIKit.label(str(info["name"]), 30, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT))
	var blurb: Label = UIKit.label(str(info["blurb"]), 20, Style.MUTED, 400, HORIZONTAL_ALIGNMENT_LEFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(blurb)
	var right: VBoxContainer = UIKit.vbox(0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price: Label = UIKit.label("", 26, Style.GOLD, 700, HORIZONTAL_ALIGNMENT_RIGHT)
	price.name = "Price"
	right.add_child(price)
	var trial: Label = UIKit.label("", 15, Style.AMBER, 700, HORIZONTAL_ALIGNMENT_RIGHT)
	trial.name = "Trial"
	right.add_child(trial)
	row.add_child(right)
	row.add_child(UIKit.icon_rect("chevron-right", 26, Style.MUTED))
	return b


func _open_product(id: String) -> void:
	var o: ProductCard = ProductCard.new()
	o.product = id
	o.show_shop_link = false
	app.open(o)


func _link_row(preview: String, title: String, sub: String, node_name: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 124)
	_style_row(b, Color("2E2870"), Color.TRANSPARENT)
	UIKit.juice(b)
	b.pressed.connect(cb)
	var row: HBoxContainer = UIKit.hbox(18, BoxContainer.ALIGNMENT_BEGIN)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var pv: ProductPreview = ProductPreview.new(preview, 88)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var text: VBoxContainer = UIKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(UIKit.label(title, 28, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT))
	var s: Label = UIKit.label(sub, 20, Style.MUTED, 400, HORIZONTAL_ALIGNMENT_LEFT)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(s)
	row.add_child(text)
	row.add_child(UIKit.icon_rect("chevron-right", 26, Style.MUTED))
	return b


## Pressable card style for shop rows (an outline marks the featured pack).
static func _style_row(b: Button, fill: Color, outline: Color) -> void:
	var lip_c: Color = Color("140F36")
	b.add_theme_stylebox_override("normal", UIKit.lip_box(fill, 30, lip_c, 7, Vector2(8, 8), false, outline))
	b.add_theme_stylebox_override("hover", UIKit.lip_box(fill.lightened(0.05), 30, lip_c, 7, Vector2(8, 8), false, outline))
	b.add_theme_stylebox_override("pressed", UIKit.lip_box(fill.darkened(0.05), 30, lip_c, 7, Vector2(8, 8), true, outline))
	b.add_theme_stylebox_override("hover_pressed", UIKit.lip_box(fill.darkened(0.05), 30, lip_c, 7, Vector2(8, 8), true, outline))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
