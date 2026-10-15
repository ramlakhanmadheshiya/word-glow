class_name LockedChapterCard
extends Overlay
## A locked chapter: open it now with a diamond key (starting at level 1), get
## diamond keys, or see how it opens by playing.

var chapter_idx: int = 1


func build() -> void:
	name = "LockedChapter"
	var ch: Dictionary = Catalog.chapter(chapter_idx)
	var prev: Dictionary = Catalog.chapter(chapter_idx - 1)
	add_title("%s is locked" % ch["name"])
	body.add_child(UIKit.art_rect("diamond_key", 96))
	var need: int = maxi(0, Catalog.unlock_clears - Profile.chapter_clears(chapter_idx - 1))
	body.add_child(UIKit.para("Clear %d more %s in %s to open it, or use a diamond key now and start at level 1." % [need, "level" if need == 1 else "levels", prev.get("name", "")], Style.SIZE_BODY - 2, Style.INK))
	body.add_child(UIKit.caption("Chapter %d · %d levels" % [chapter_idx + 1, Catalog.levels_per_chapter]))
	var d: int = Profile.diamonds()
	var use: Button = UIKit.button("Use a diamond key  (%d left)" % d if d > 0 else "No diamond keys yet", "primary", Color("5FC8FF"), 92, 26, "art:diamond_key")
	use.name = "UseDiamond"
	use.disabled = d <= 0
	use.pressed.connect(func() -> void:
		if Profile.use_diamond(chapter_idx):
			Audio.play("unlock")
			app.toast("%s is open!" % ch["name"], "", Color("5FC8FF"))
			app.go("levels", {"chapter": chapter_idx})
	)
	body.add_child(use)
	var get_more: Button = UIKit.button("Get diamond keys", "soft", Style.AMBER, 80, 24, "plus")
	get_more.name = "GetDiamonds"
	get_more.pressed.connect(func() -> void: open_child(DiamondCard.new()))
	body.add_child(get_more)
	var ok: Button = UIKit.button("Keep playing", "ghost", Style.AMBER, 76, 24)
	ok.name = "KeepPlaying"
	ok.pressed.connect(close)
	body.add_child(ok)
