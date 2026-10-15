class_name MessageCard
extends Overlay
## A simple card: icon, title, message and up to three buttons.
## `buttons` is an Array of [text, style, Callable].

var title_text: String = ""
var message: String = ""
var icon_name: String = ""
var icon_color: Color = Style.AMBER
var buttons: Array = []


func build() -> void:
	if name.is_empty() or name.begins_with("@"):
		name = "Message"
	body.add_theme_constant_override("separation", 18)
	if not icon_name.is_empty():
		if UIKit.art(icon_name) != null:
			body.add_child(UIKit.art_rect(icon_name, 96))
		else:
			body.add_child(UIKit.icon_rect(icon_name, 88, icon_color))
	var t: Label = UIKit.label(title_text, Style.SIZE_H1, Style.INK, 600)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(t)
	body.add_child(UIKit.para(message, Style.SIZE_BODY))
	body.add_child(UIKit.gap(8))
	for spec: Array in buttons:
		var b: Button = UIKit.button(str(spec[0]), str(spec[1]))
		b.name = str(spec[0]).replace(" ", "")
		b.pressed.connect(spec[2])
		body.add_child(b)


## Asks a yes/no question; `on_yes` runs only on confirmation.
static func confirm(app: App, title: String, text: String, yes_text: String, on_yes: Callable, danger: bool = false) -> MessageCard:
	var o: MessageCard = MessageCard.new()
	o.title_text = title
	o.message = text
	o.icon_name = "info"
	o.buttons = [
		[yes_text, "danger" if danger else "primary", func() -> void:
			o.close()
			on_yes.call()],
		["Cancel", "soft", func() -> void: o.close()],
	]
	app.open(o)
	return o
