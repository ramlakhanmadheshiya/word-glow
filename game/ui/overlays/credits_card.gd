class_name CreditsCard
extends Overlay
## Who made what, section by section. Matches docs/CREDITS in the README.

const SECTIONS: Array = [
	["Made by", [
		["Ramlakhan Madheshiya", "Game design, development and puzzles", "https://theramlakhan.com/"],
		["Claude Opus 5.5", "AI co-developer, by Anthropic", ""],
	]],
	["Engine", [["Godot Engine 4.7", "MIT licence. godotengine.org", "https://godotengine.org/"]]],
	["Type", [["Outfit", "By the Outfit Project Authors. SIL Open Font License 1.1.", ""]]],
	["Icons", [["Lucide", "By the Lucide contributors. ISC licence. lucide.dev", "https://lucide.dev/"],
		["Lantern, coin, flame and other game icons", "Drawn for Word Lantern.", ""]]],
	["Sound and music", [["Synthesised for Word Lantern", "Every sound and both music loops are generated in code for this game, no samples.", ""]]],
	["Words and levels", [["Handpicked theme words", "46 themes chosen for this game. Every level is generated from them and checked by a solver.", ""]]],
]


func build() -> void:
	name = "Credits"
	add_title("Credits")
	body.add_theme_constant_override("separation", 4)
	for section: Array in SECTIONS:
		body.add_child(UIKit.caption(str(section[0]), Style.AMBER, Style.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT))
		body.add_child(UIKit.gap(2))
		for entry: Array in section[1]:
			var url: String = str(entry[2])
			if url.is_empty():
				var v: Label = UIKit.label(str(entry[0]), Style.SIZE_BODY, Style.INK, 600, HORIZONTAL_ALIGNMENT_LEFT)
				v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				body.add_child(v)
			else:
				var link: LinkButton = LinkButton.new()
				link.text = str(entry[0])
				link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
				link.add_theme_font_override("font", UIKit.font(600))
				link.add_theme_font_size_override("font_size", Style.SIZE_BODY)
				link.add_theme_color_override("font_color", Style.INK)
				link.add_theme_color_override("font_hover_color", Style.AMBER)
				link.custom_minimum_size.y = 48
				link.pressed.connect(func() -> void: OS.shell_open(url))
				body.add_child(link)
			body.add_child(UIKit.para(str(entry[1]), Style.SIZE_SMALL, Style.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
			body.add_child(UIKit.gap(8))
		body.add_child(UIKit.gap(8))
	body.add_child(UIKit.label("Thank you for playing", Style.SIZE_BODY, Style.AMBER, 600))
