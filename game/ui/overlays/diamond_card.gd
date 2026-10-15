class_name DiamondCard
extends Overlay
## Diamond keys: each opens a whole locked chapter (from level 1; the rest of
## the chapter opens by playing). Earned by clearing level 40 of any chapter,
## bought here, or one a day from a short video.

var _status: Label
var _have: Label
var _video: Button


func build() -> void:
	name = "DiamondShop"
	add_title("Diamond keys")
	body.add_child(UIKit.art_rect("diamond_key", 110))
	body.add_child(UIKit.para("A diamond key opens a locked chapter right away. You start at its level 1, and the rest opens as you play. You also earn one every time you clear level 40 of a chapter.", Style.SIZE_SMALL))
	_have = UIKit.label("", Style.SIZE_SMALL + 1, Style.INK, 700)
	_have.name = "Have"
	body.add_child(_have)
	var row: HBoxContainer = UIKit.hbox(14)
	for id: String in Store.DIAMOND_PACKS:
		var n: int = int(Store.DIAMOND_PACKS[id][0])
		var b: Button = UIKit.button("%d %s · %s" % [n, "key" if n == 1 else "keys", Store.price(id)], "primary" if n > 1 else "soft", Color("5FC8FF"), 88, 24, "art:diamond_key")
		b.name = "Buy_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_status.text = "Opening Google Play…"
			Store.buy(id)
		)
		row.add_child(b)
	body.add_child(row)
	_video = UIKit.button("", "soft", Style.AMBER, 84, 23, "art:video")
	_video.name = "VideoDiamond"
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
	_refresh()


func _refresh() -> void:
	var d: int = Profile.diamonds()
	_have.text = "You have %d diamond %s" % [d, "key" if d == 1 else "keys"]
	var left: int = Profile.video_diamonds_left()
	_video.text = "Watch a video: +1 diamond key" if left > 0 else "Free diamond key is back tomorrow"
	_video.disabled = left <= 0


func _watch() -> void:
	if not AdManager.rewarded_ready():
		_status.text = "No video available right now. Try again in a little while." if AdManager.provider != null else "Videos are available in the Android app."
		return
	AdManager.show_rewarded(func(ok: bool) -> void:
		if not is_inside_tree():
			return
		if ok and Profile.add_video_diamond():
			Audio.play("unlock", 1.0, -3.0)
			_status.text = "+1 diamond key. Thank you for watching!"
		elif not ok:
			_status.text = "The video was closed early, so no key this time."
		_refresh()
	)
