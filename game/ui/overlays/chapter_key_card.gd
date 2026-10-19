class_name ChapterKeyCard
extends Overlay
## Chapter keys, sold like level keys: pick 1-5 with − / +, or watch a video for
## one free key a day. A chapter key opens a locked chapter at its level 1
## (the rest opens by playing), without first clearing 15 levels of the one
## before. Clearing level 40 of a chapter also earns one.

var _count: int = 1
var _num: Label
var _buy: Button
var _have: Label
var _status: Label
var _video: Button


func build() -> void:
	name = "ChapterKeyShop"
	add_title("Chapter keys")
	body.add_child(UIKit.art_rect("chapter_key", 100))
	body.add_child(UIKit.para("A chapter key opens a locked chapter right away, without clearing 15 levels of the chapter before it. You start at its level 1 and the rest opens as you play. You also get one each time you clear level 40 of a chapter.", Style.SIZE_SMALL))
	_have = UIKit.label("", Style.SIZE_SMALL + 1, Style.INK, 700)
	_have.name = "Have"
	body.add_child(_have)
	var row: HBoxContainer = UIKit.hbox(26)
	var minus: Button = UIKit.icon_button("minus", 80)
	minus.name = "Minus"
	minus.pressed.connect(func() -> void: _set_count(_count - 1))
	row.add_child(minus)
	var mid: HBoxContainer = UIKit.hbox(10)
	mid.add_child(UIKit.art_rect("chapter_key", 56))
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
	for n: int in [1, 2, 3, 5]:
		var q: Button = UIKit.button(str(n), "soft", Style.AMBER, 56, 22)
		q.name = "Quick_%d" % n
		q.custom_minimum_size.x = 96
		q.pressed.connect(func() -> void: _set_count(n))
		quick.add_child(q)
	body.add_child(quick)
	body.add_child(UIKit.caption("Up to %d at a time" % Store.CHAPTER_KEY_MAX))
	_buy = UIKit.button("", "primary", Color("5FC8FF"), 92, 28, "art:chapter_key")
	_buy.name = "BuyChapterKeys"
	_buy.pressed.connect(func() -> void:
		_status.text = "Opening Google Play…"
		Store.buy("chapter_keys_%d" % _count)
	)
	body.add_child(_buy)
	_video = UIKit.button("", "soft", Style.AMBER, 84, 23, "art:watch")
	_video.name = "VideoChapterKey"
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
	_count = clampi(n, 1, Store.CHAPTER_KEY_MAX)
	_refresh()


func _refresh() -> void:
	_num.text = str(_count)
	var d: int = Profile.chapter_keys()
	_have.text = "You have %d chapter %s" % [d, "key" if d == 1 else "keys"]
	_buy.text = "Get %d for %s" % [_count, Store.price("chapter_keys_%d" % _count)]
	var left: int = Profile.video_chapter_keys_left()
	_video.text = "Watch a video: 1 free chapter key" if left > 0 else "Free chapter key is back tomorrow"
	_video.disabled = left <= 0


func _watch() -> void:
	if not AdManager.rewarded_ready():
		_status.text = "No video available right now. Try again in a little while." if AdManager.provider != null else "Videos are available in the Android app."
		return
	AdManager.show_rewarded(func(ok: bool) -> void:
		if not is_inside_tree():
			return
		if ok and Profile.add_video_chapter_key():
			Audio.play("unlock", 1.0, -3.0)
			_status.text = "+1 chapter key. Thank you for watching!"
		elif not ok:
			_status.text = "The video was closed early, so no key this time."
		_refresh()
	)
