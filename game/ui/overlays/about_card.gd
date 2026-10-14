class_name AboutCard
extends Overlay
## What the game is, who made it, and links to the website, help and privacy pages.

const SITE: String = "https://theramlakhan.com/word-lantern/"
const AUTHOR_SITE: String = "https://theramlakhan.com/"


func build() -> void:
	name = "About"
	var head: HBoxContainer = UIKit.hbox(0, BoxContainer.ALIGNMENT_END)
	var x: Button = UIKit.icon_button("x", 72)
	x.name = "Close"
	x.pressed.connect(close)
	head.add_child(x)
	body.add_child(head)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/icon.svg")
	icon.custom_minimum_size = Vector2(150, 150)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(icon)
	body.add_child(UIKit.label("Word Lantern", Style.SIZE_H1, Style.INK, 600))
	var version: String = str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	body.add_child(UIKit.caption("A calm word-light puzzle · version %s" % version))
	body.add_child(UIKit.para("Trace hidden words through a grid of paper tiles until every lantern glows. 160 handmade levels across 8 worlds, plus a new daily lantern every day. Every level is checked by a solver, so each answer fits in exactly one place.", Style.SIZE_SMALL + 1, Style.INK))
	body.add_child(UIKit.gap(6))
	body.add_child(UIKit.caption("Made by"))
	var me: Button = UIKit.button("Ramlakhan Madheshiya", "ghost", Style.AMBER, 76, 30)
	me.name = "Author"
	me.pressed.connect(func() -> void: OS.shell_open(AUTHOR_SITE))
	body.add_child(me)
	body.add_child(UIKit.label("Game designer and developer · theramlakhan.com", Style.SIZE_CAPTION, Style.MUTED))
	body.add_child(UIKit.gap(2))
	body.add_child(UIKit.label("Claude Opus 5.5", Style.SIZE_BODY, Style.INK, 500))
	body.add_child(UIKit.label("AI co-developer, by Anthropic", Style.SIZE_CAPTION, Style.MUTED))
	body.add_child(UIKit.gap(8))
	var row: HBoxContainer = UIKit.hbox(12)
	for item: Array in [["Website", "", "globe"], ["Help", "help/", "circle-help"], ["Privacy", "privacy/", "shield"]]:
		var b: Button = UIKit.button(str(item[0]), "soft", Style.AMBER, 76, 24, str(item[2]))
		b.name = str(item[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var url: String = SITE + str(item[1])
		b.pressed.connect(func() -> void: OS.shell_open(url))
		row.add_child(b)
	body.add_child(row)
	body.add_child(UIKit.para("No account, no ads, no tracking. Your progress is saved only on this device.", Style.SIZE_CAPTION))
