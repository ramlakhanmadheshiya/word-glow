class_name AchievementsCard
extends Overlay
## Every achievement with its progress, reward and whether it is done, plus stats.


func build() -> void:
	name = "Achievements"
	add_title("Achievements")
	var done: int = 0
	for a: Dictionary in Achievements.all():
		if Profile.achievement_done(a["id"]):
			done += 1
	body.add_child(UIKit.caption("%d of %d unlocked" % [done, Achievements.all().size()]))
	var stats: HBoxContainer = UIKit.hbox(10)
	for s: Array in [["Levels", "levels"], ["Stars", "stars"], ["Words", "words"], ["Best streak", "best_streak"]]:
		var col: VBoxContainer = UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(str(Profile.stat(s[1])), Style.SIZE_H2, Style.INK, 700))
		col.add_child(UIKit.label(str(s[0]), Style.SIZE_CAPTION, Style.MUTED))
		stats.add_child(col)
	body.add_child(UIKit.panel(stats, Style.FIELD, 26, Vector2(12, 14)))
	if done == 0:
		body.add_child(UIKit.para("Nothing unlocked yet. Clear your first level to earn First Light.", Style.SIZE_SMALL))
	for a: Dictionary in Achievements.all():
		body.add_child(_row(a))


func _row(a: Dictionary) -> PanelContainer:
	var got: bool = Profile.achievement_done(a["id"])
	var have: int = mini(Profile.stat(a["stat"]), int(a["goal"]))
	var row: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	var tint: Color = Style.GOLD if got else Color(Style.MUTED, 0.6)
	var art_name: String = {"lantern": "lantern", "trophy": "trophy", "star": "star", "star-filled": "star", "book": "", "calendar": "calendar", "flame": "flame", "globe": ""}.get(a["icon"], "")
	if art_name.is_empty():
		row.add_child(UIKit.icon_rect(a["icon"], 48, tint))
	else:
		var ar: TextureRect = UIKit.art_rect(art_name, 52)
		ar.modulate = Color.WHITE if got else Color(1, 1, 1, 0.35)
		row.add_child(ar)
	var mid: VBoxContainer = UIKit.vbox(4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UIKit.label(a["title"], Style.SIZE_BODY - 2, Style.INK if got else Color(Style.INK, 0.8), 600, HORIZONTAL_ALIGNMENT_LEFT))
	mid.add_child(UIKit.label(a["desc"], Style.SIZE_CAPTION, Style.MUTED, 400, HORIZONTAL_ALIGNMENT_LEFT))
	if not got:
		mid.add_child(UIKit.progress_bar(float(have) / float(a["goal"]), Style.AMBER, 8))
	row.add_child(mid)
	var right: Label = UIKit.label("Done" if got else "+%d" % int(a["reward"]), Style.SIZE_SMALL, Style.SUCCESS if got else Style.GOLD, 700)
	row.add_child(right)
	return UIKit.panel(row, Color(1, 1, 1, 0.09 if got else 0.05), 26, Vector2(20, 14))
