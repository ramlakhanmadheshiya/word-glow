class_name CoinsCard
extends Overlay
## Coins: four bags to buy, and free coins from a short video (a few a day).

var _status: Label
var _video: Button


func build() -> void:
	name = "CoinsShop"
	add_title("Coins")
	body.add_child(UIKit.para("Coins pay for letter hints and word hints. You also earn them from levels, stars, chapters, the daily puzzle and achievements.", Style.SIZE_SMALL))
	var list: VBoxContainer = UIKit.vbox(12)
	list.name = "CoinPacks"
	body.add_child(list)
	for id: String in Store.COIN_PACKS:
		list.add_child(_row(id))
	_video = UIKit.button("", "soft", Style.AMBER, 84, 23, "art:watch")
	_video.name = "FreeCoins"
	_video.pressed.connect(_watch)
	body.add_child(_video)
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	body.add_child(_status)
	body.add_child(UIKit.no_refunds())
	Store.purchase_finished.connect(func(ok: bool, msg: String, _id: String) -> void:
		if is_inside_tree():
			_status.text = msg
			if ok:
				Audio.play("coin")
	)
	_refresh()


func _refresh() -> void:
	var left: int = Profile.video_coins_left()
	_video.text = "Watch a video: +%d coins  (%d left today)" % [Economy.VIDEO_COINS, left] if left > 0 else "Free coins are back tomorrow"
	_video.disabled = left <= 0


## A coin bag as a list row: icon, amount and value on the left, price on the
## right. Tap to buy.
func _row(id: String) -> Button:
	var pack: Array = Store.COIN_PACKS[id]
	var b: Button = Button.new()
	b.name = "Buy_" + id
	b.custom_minimum_size = Vector2(0, 108)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lip_c: Color = Style.LIP
	b.add_theme_stylebox_override("normal", UIKit.lip_box(Style.SURFACE, 26, lip_c, 6, Vector2(8, 6)))
	b.add_theme_stylebox_override("hover", UIKit.lip_box(Style.SURFACE.lightened(0.05), 26, lip_c, 6, Vector2(8, 6)))
	b.add_theme_stylebox_override("pressed", UIKit.lip_box(Style.SURFACE.darkened(0.05), 26, lip_c, 6, Vector2(8, 6), true))
	b.add_theme_stylebox_override("hover_pressed", UIKit.lip_box(Style.SURFACE.darkened(0.05), 26, lip_c, 6, Vector2(8, 6), true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UIKit.juice(b)
	b.pressed.connect(func() -> void:
		_status.text = "Opening Google Play…"
		Store.buy(id)
	)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	b.add_child(margin)
	var row: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var pv: ProductPreview = ProductPreview.new(id, 76)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var text: VBoxContainer = UIKit.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(UIKit.label("%s coins" % _thousands(int(pack[0])), 27, Style.INK, 700, HORIZONTAL_ALIGNMENT_LEFT))
	var bonus: int = _bonus(id)
	text.add_child(UIKit.label(str(pack[1]) + ("  ·  +%d%% more coins" % bonus if bonus > 0 else ""), 18, Style.SUCCESS if bonus > 0 else Style.MUTED, 600, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(text)
	var price: PanelContainer = UIKit.panel(UIKit.label(Store.price(id), 22, Style.PAPER_INK, 800), Style.GOLD, 18, Vector2(14, 4))
	price.name = "Price"
	price.custom_minimum_size.x = 104
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price)
	return b


## Extra coins per rupee compared with the smallest bag, as a percentage.
static func _bonus(id: String) -> int:
	var base: Array = Store.COIN_PACKS[Store.COIN_PACKS.keys()[0]]
	var pack: Array = Store.COIN_PACKS[id]
	var per: float = float(pack[0]) / float(pack[2])
	var base_per: float = float(base[0]) / float(base[2])
	return int(round((per / base_per - 1.0) * 100.0 / 5.0)) * 5


static func _thousands(n: int) -> String:
	return str(n) if n < 1000 else "%d,%03d" % [n / 1000, n % 1000]


func _watch() -> void:
	if Profile.video_coins_left() <= 0:
		return
	if not AdManager.rewarded_ready():
		_status.text = "No video available right now. Try again in a little while." if AdManager.provider != null else "Videos are available in the Android app."
		return
	AdManager.show_rewarded(func(ok: bool) -> void:
		if not is_inside_tree():
			return
		if ok and Profile.claim_video_coins():
			Audio.play("coin")
			_status.text = "+%d coins. Thank you for watching!" % Economy.VIDEO_COINS
		elif not ok:
			_status.text = "The video was closed early, so no coins this time."
		_refresh()
	)
