class_name LockedCard
extends Overlay
## A locked level: open it now with a level key, get a key, or see how it opens
## by playing.

var chapter_idx: int = 0
var level: int = 1
var _status: Label


func build() -> void:
	name = "Locked"
	var ch: Dictionary = Catalog.chapter(chapter_idx)
	add_title("Level %d is locked" % level)
	body.add_child(UIKit.art_rect("lock", 92))
	var how: String
	if not Profile.chapter_unlocked(chapter_idx):
		how = "Clear %d levels in %s to open this chapter." % [Catalog.unlock_clears, Catalog.chapter(chapter_idx - 1).get("name", "")]
	else:
		how = "Clear level %d of %s to open it, or use a level key now." % [level - 1, ch["name"]]
	body.add_child(UIKit.para(how, Style.SIZE_BODY - 2, Style.INK))
	body.add_child(UIKit.caption("%s · %s" % [ch["name"], Catalog.tier_name(level)]))
	var k: int = Profile.keys()
	if Profile.chapter_unlocked(chapter_idx):
		var use: Button = UIKit.button("Use a key  (%d left)" % k if k > 0 else "No keys yet", "primary", Style.AMBER, 92, 28, "art:key")
		use.name = "UseKey"
		use.disabled = k <= 0
		use.pressed.connect(func() -> void:
			var id: String = Catalog.level_id(ch["id"], level)
			if Profile.use_key(id):
				Audio.play("unlock")
				close()
				app.go("play", {"chapter": chapter_idx, "level": level})
		)
		body.add_child(use)
		var get_keys: Button = UIKit.button("Get keys", "soft", Style.AMBER, 80, 24, "plus")
		get_keys.name = "GetKeys"
		get_keys.pressed.connect(func() -> void:
			close()
			app.open(KeysCard.new())
		)
		body.add_child(get_keys)
	var ok: Button = UIKit.button("Keep playing", "ghost", Style.AMBER, 76, 24)
	ok.name = "KeepPlaying"
	ok.pressed.connect(close)
	body.add_child(ok)
