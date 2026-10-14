class_name ProductCard
extends Overlay
## One pack on a floating card: a live preview, what you get, the price, and for
## the Theme and Lantern-style packs a one-hour trial from a short video.

var product: String = "supporter_pack"
## Show a "See the shop" link (when opened from outside the shop).
var show_shop_link: bool = true
var _buy: Button
var _status: Label
var _trial: Button
var _tick: float = 0.0


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0 or _trial == null:
		return
	_tick = 0.25
	var clock: String = Profile.trial_clock(product)
	_trial.text = "On trial · %s left · choose one" % clock if not clock.is_empty() else "Try it free for 1 hour with a video"


func build() -> void:
	name = "Product"
	var info: Dictionary = Store.PRODUCTS[product]
	var head: HBoxContainer = UIKit.hbox(0, BoxContainer.ALIGNMENT_END)
	var x: Button = UIKit.icon_button("x", 72)
	x.name = "Close"
	x.pressed.connect(close)
	head.add_child(x)
	body.add_child(head)
	var hero: ProductPreview = ProductPreview.new(product, 170)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(hero)
	if product == "complete_pack":
		body.add_child(UIKit.caption("Best value · save %d%%" % Store.complete_saving(), Style.AMBER))
	body.add_child(UIKit.label(str(info["name"]), Style.SIZE_H1, Style.INK, 600))
	if product == "supporter_pack":
		body.add_child(UIKit.para("Word Lantern is made by one person. One purchase helps make the next chapter.", Style.SIZE_SMALL))
	var perks: VBoxContainer = UIKit.vbox(12)
	perks.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(perks)
	for perk: String in info["perks"]:
		var row: HBoxContainer = UIKit.hbox(14, BoxContainer.ALIGNMENT_BEGIN)
		var dot: PanelContainer = UIKit.panel(UIKit.icon_rect("check", 22, Style.SUCCESS), Color(Style.SUCCESS, 0.16), 20, Vector2(9, 9))
		row.add_child(dot)
		row.add_child(UIKit.label(perk, 25, Style.INK, 500, HORIZONTAL_ALIGNMENT_LEFT))
		perks.add_child(row)
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	body.add_child(_status)
	_buy = UIKit.button("", "primary", Style.AMBER, 92, 30)
	_buy.name = "Buy"
	_buy.pressed.connect(func() -> void:
		if Profile.bought(product):
			if _pick_mode() != "":
				close()
				_open_picker()
			return
		_status.text = "Opening Google Play…"
		Store.buy(product)
	)
	body.add_child(_buy)
	if bool(info.get("trial", false)) and not Profile.bought(product):
		_trial = UIKit.button("Try it free for 1 hour with a video", "ghost", Style.AMBER, 84, 23, "play")
		_trial.name = "Trial"
		_trial.pressed.connect(func() -> void:
			if Profile.trial_left(product) > 0:
				close()
				_open_picker()
				return
			if not AdManager.rewarded_ready():
				_status.text = "No video available right now. Try again in a little while." if AdManager.provider != null else "Video trials are available in the Android app."
				return
			AdManager.show_rewarded(func(ok: bool) -> void:
				if not is_inside_tree():
					return
				if ok:
					Profile.start_trial(product)
					Audio.play("unlock", 1.0, -3.0)
					close()
					_open_picker()
				else:
					_status.text = "The video was closed early, so the trial didn't start."
			)
		)
		body.add_child(_trial)
	var links: HBoxContainer = UIKit.hbox(12)
	var restore: Button = UIKit.button("Restore purchase", "ghost", Style.AMBER, 64, 21)
	restore.name = "Restore"
	restore.pressed.connect(func() -> void:
		_status.text = "Checking your purchases…"
		Store.restore()
	)
	links.add_child(restore)
	if show_shop_link:
		var shop: Button = UIKit.button("See the shop", "ghost", Style.AMBER, 64, 21)
		shop.name = "SeeShop"
		shop.pressed.connect(func() -> void:
			close()
			app.go("shop")
		)
		links.add_child(shop)
	body.add_child(links)
	Store.purchase_finished.connect(_on_result)
	Store.restore_finished.connect(func(ok: bool, msg: String) -> void: _on_result(ok, msg, product))
	Store.price_updated.connect(func(_id: String, _p: String) -> void: _refresh())
	_refresh()


func _pick_mode() -> String:
	return "themes" if product == "theme_pack" else ("styles" if product == "style_pack" else "")


func _open_picker() -> void:
	if _pick_mode() != "":
		var p: PickerCard = PickerCard.new()
		p.mode = _pick_mode()
		app.open(p)


func _refresh() -> void:
	if not is_inside_tree():
		return
	if Profile.bought(product):
		_buy.text = "Choose one" if _pick_mode() != "" else "It's yours ♥"
		_buy.disabled = _pick_mode() == ""
	else:
		_buy.text = "%s %s" % ["Support for" if product == "supporter_pack" else "Get it for", Store.price(product)]
		_buy.disabled = false


func _on_result(ok: bool, message: String, _id: String) -> void:
	if not is_inside_tree():
		return
	_status.text = message
	if ok:
		Audio.play("unlock", 1.0, -3.0)
		Haptics.success()
	_refresh()
	refit()
