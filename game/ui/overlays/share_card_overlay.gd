class_name ShareCardOverlay
extends Overlay
## Share your puzzle, like Single Shot: a preview of the picture, then Share
## (the picture and a link, through the phone's share sheet), Save (the picture,
## to the gallery) and Copy link.

var info: Dictionary = {}
var _image: Image
var _preview: TextureRect
var _status: Label


func build() -> void:
	name = "Share"
	add_title("Share your puzzle")
	var holder: CenterContainer = CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 470)
	body.add_child(holder)
	_preview = TextureRect.new()
	_preview.name = "Preview"
	_preview.custom_minimum_size = Vector2(360, 450)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(_preview)
	_preview.pivot_offset = Vector2(180, 225)
	_preview.rotation = deg_to_rad(-2.0)
	_status = UIKit.para("Making your picture…", Style.SIZE_SMALL, Style.MUTED)
	_status.name = "Status"
	body.add_child(_status)
	var row: HBoxContainer = UIKit.hbox(28)
	body.add_child(row)
	row.add_child(_action("share-2", "SHARE", "ShareNow", func() -> void:
		if _ready_to_use():
			ShareService.share(_image, info)
	))
	row.add_child(_action("download", "SAVE", "Save", func() -> void:
		if _ready_to_use():
			_status.text = "Saving…"
			ShareService.save(_image, info)
	))
	row.add_child(_action("link", "COPY LINK", "CopyLink", func() -> void: ShareService.copy_link(info)))
	ShareService.finished.connect(func(_ok: bool, msg: String) -> void:
		if is_inside_tree() and not msg.is_empty():
			_status.text = msg
	)
	ShareImage.render(self, info, func(img: Image) -> void:
		if not is_inside_tree():
			return
		_image = img
		if img != null:
			_preview.texture = ImageTexture.create_from_image(img)
			_status.text = "Can your friends find every word?"
		else:
			_status.text = "Share the link with your friends."
	)


## The picture takes a moment to render; until then Share and Save wait.
func _ready_to_use() -> bool:
	if _image == null and DisplayServer.get_name() != "headless":
		_status.text = "One moment, the picture is still being made…"
		return false
	return true


func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> VBoxContainer:
	var box: VBoxContainer = UIKit.vbox(6)
	var b: Button = UIKit.icon_button(icon_name, 84)
	b.name = node_name
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.caption(caption, Style.MUTED, 16))
	return box
