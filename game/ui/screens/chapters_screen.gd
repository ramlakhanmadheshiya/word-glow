extends Screen
## All 16 chapters as a calm vertical list, each card in its own colours.

var _first: Control


func build() -> void:
	body.add_child(header("Chapters", "★ %d / %d" % [Profile.total_stars(), Catalog.total_levels() * 3]))
	body.add_child(chip_row([UIKit.chapter_key_chip(), UIKit.key_chip(), UIKit.coin_chip()]))
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list: VBoxContainer = UIKit.vbox(18)
	list.name = "List"
	scroll.set_content(list)
	var focus_card: Control = null
	for i: int in Catalog.chapter_count():
		var ch: Dictionary = Catalog.chapter(i)
		var card: ChapterCard = ChapterCard.new()
		card.name = "Chapter_" + str(ch["id"])
		card.chapter = ch
		card.index = i
		card.clears = Profile.chapter_clears(i)
		card.stars = Profile.chapter_stars(i)
		card.unlocked = Profile.chapter_unlocked(i)
		if not card.unlocked and i > 0:
			var need: int = maxi(0, Catalog.unlock_clears - Profile.chapter_clears(i - 1))
			card.lock_text = "Clear %d more in %s, or use a chapter key" % [need, Catalog.chapter(i - 1)["name"]]
		var idx: int = i
		card.pressed.connect(func() -> void:
			if Profile.chapter_unlocked(idx):
				app.go("levels", {"chapter": idx})
			else:
				Audio.play("error", 1.2, -8.0)
				var o: LockedChapterCard = LockedChapterCard.new()
				o.chapter_idx = idx
				app.open(o)
		)
		list.add_child(card)
		if card.unlocked:
			focus_card = card
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.03 * i)
	list.add_child(UIKit.gap(16))
	_first = focus_card
	_scroll_to.call_deferred(scroll, focus_card)


## Brings the furthest open chapter into view, lined up on a card edge.
func _scroll_to(scroll: TouchScroll, card: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if card == null or not card.is_inside_tree():
		return
	if card.position.y + card.size.y + 24.0 > scroll.size.y:
		# Keep a card's top edge at the top, with the furthest open chapter and
		# the next (locked) one in view below it.
		var stride: float = card.size.y + 18.0
		var fit: int = maxi(2, int(scroll.size.y / stride))
		scroll.scroll_to(card.position.y - (fit - 2) * stride)
