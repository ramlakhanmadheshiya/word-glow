class_name KeysCard
extends Overlay
## Level keys: pick how many with − / +, see the price (10% off at five or more),
## or watch a video for a free one (a few a day).

var _count: int = 1
var _num: Label
var _buy: Button
var _deal: Label
var _have: Label
var _status: Label
var _video: Button


func build() -> void:
	name = "KeysShop"
	add_title("Level keys")
	body.add_child(UIKit.para("A key opens any locked level, for good. Clear it and the next level opens as usual.", Style.SIZE_SMALL))
	_have = UIKit.label("", Style.SIZE_SMALL + 1, Style.INK, 600)
	body.add_child(_have)
	var row: HBoxContainer = UIKit.hbox(26)
	var minus: Button = UIKit.icon_button("minus", 80)
	minus.name = "Minus"
	minus.pressed.connect(func() -> void: _set_count(_count - 1))
	row.add_child(minus)
	var mid: HBoxContainer = UIKit.hbox(10)
	mid.add_child(UIKit.art_rect("key", 56))
	_num = UIKit.label("1", 64, Style.INK, 500)
	_num.custom_minimum_size.x = 90
	mid.add_child(_num)
	row.add_child(mid)
	var plus: Button = UIKit.icon_button("plus", 80)
	plus.name = "Plus"
	plus.pressed.connect(func() -> void: _set_count(_count + 1))
	row.add_child(plus)
	body.add_child(row)
	var quick: HBoxContainer = UIKit.hbox(12)
	for n: int in [1, 2, 5, 10]:
		var q: Button = UIKit.button(str(n), "soft", Style.AMBER, 56, 22)
		q.name = "Quick_%d" % n
		q.custom_minimum_size.x = 96
		q.pressed.connect(func() -> void: _set_count(n))
		quick.add_child(q)
	body.add_child(quick)
	_deal = UIKit.label("", Style.SIZE_CAPTION + 1, Style.AMBER, 700)
	body.add_child(_deal)
	_buy = UIKit.button("", "primary", Style.AMBER, 92, 30)
	_buy.name = "BuyKeys"
	_buy.pressed.connect(func() -> void:
		_status.text = "Opening Google Play…"
		Store.buy("keys_%d" % _count)
	)
	body.add_child(_buy)
	_video = UIKit.button("", "soft", Style.AMBER, 80, 23, "art:watch")
	_video.name = "VideoKey"
	_video.pressed.connect(_watch)
	body.add_child(_video)
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	body.add_child(_status)
	Store.purchase_finished.connect(func(ok: bool, msg: String, _id: String) -> void:
		if is_inside_tree():
			_status.text = msg
			if ok:
				Audio.play("unlock", 1.0, -3.0)
			_refresh()
	)
	_set_count(1)


func _set_count(n: int) -> void:
	_count = clampi(n, 1, Store.KEY_MAX)
	_refresh()


func _refresh() -> void:
	_num.text = str(_count)
	var k: int = Profile.keys()
	_have.text = "You have %d %s" % [k, "key" if k == 1 else "keys"]
	_deal.text = "10% off for 5 or more" if _count >= Store.KEY_BULK else "Buy 5 or more for 10% off"
	_buy.text = "Get %d %s for %s" % [_count, "key" if _count == 1 else "keys", Store.price("keys_%d" % _count)]
	var left: int = Profile.video_keys_left()
	_video.text = "Free key: watch a video (%d left today)" % left if left > 0 else "Free keys are back tomorrow"
	_video.disabled = left <= 0


func _watch() -> void:
	if not AdManager.rewarded_ready():
		_status.text = "No video available right now. Try again in a little while." if AdManager.provider != null else "Videos are available in the Android app."
		return
	AdManager.show_rewarded(func(ok: bool) -> void:
		if not is_inside_tree():
			return
		if ok and Profile.add_video_key():
			Audio.play("unlock", 1.0, -3.0)
			_status.text = "+1 key. Thank you for watching!"
		elif not ok:
			_status.text = "The video was closed early, so no key this time."
		_refresh()
	)
