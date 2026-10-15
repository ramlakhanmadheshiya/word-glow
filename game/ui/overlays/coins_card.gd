class_name CoinsCard
extends Overlay
## Coins: four bags to buy, and free coins from a short video (a few a day).

var _status: Label
var _video: Button


func build() -> void:
	name = "CoinsShop"
	add_title("Coins")
	body.add_child(UIKit.para("Coins pay for Sparks and Lanterns. You also earn them from levels, stars, chapters, the daily lantern and achievements.", Style.SIZE_SMALL))
	var grid: GridContainer = GridContainer.new()
	grid.name = "CoinPacks"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for id: String in Store.COIN_PACKS:
		grid.add_child(_tile(id))
	_video = UIKit.button("", "soft", Style.AMBER, 84, 23, "art:video")
	_video.name = "FreeCoins"
	_video.pressed.connect(_watch)
	body.add_child(_video)
	_status = UIKit.para("", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	body.add_child(_status)
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


## A coin bag: tap to buy.
func _tile(id: String) -> Button:
	var pack: Array = Store.COIN_PACKS[id]
	var b: Button = Button.new()
	b.name = "Buy_" + id
	b.custom_minimum_size = Vector2(0, 220)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lip_c: Color = Color("140F36")
	b.add_theme_stylebox_override("normal", UIKit.lip_box(Color("2E2870"), 26, lip_c, 7, Vector2(8, 8)))
	b.add_theme_stylebox_override("hover", UIKit.lip_box(Color("352E80"), 26, lip_c, 7, Vector2(8, 8)))
	b.add_theme_stylebox_override("pressed", UIKit.lip_box(Color("2A2466"), 26, lip_c, 7, Vector2(8, 8), true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UIKit.juice(b)
	b.pressed.connect(func() -> void:
		_status.text = "Opening Google Play…"
		Store.buy(id)
	)
	var col: VBoxContainer = UIKit.vbox(2)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var pv: ProductPreview = ProductPreview.new(id, 92)
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(pv)
	col.add_child(UIKit.label("%s coins" % _thousands(int(pack[0])), 26, Style.INK, 700))
	col.add_child(UIKit.label(str(pack[2]), 18, Style.MUTED, 500))
	var price: PanelContainer = UIKit.panel(UIKit.label(Store.price(id), 22, Style.PAPER_INK, 800), Style.GOLD, 18, Vector2(16, 2))
	price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price)
	return b


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
