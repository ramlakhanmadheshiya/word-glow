class_name Overlay
extends Control
## Base for modal cards (pause, settings, results...). Dims the screen, pops a
## card in, scrolls when the content is taller than the screen, and closes with
## Back, the close button or (if dismissable) a tap outside.

signal closed

var app: App
var dismissable: bool = true
var body: VBoxContainer
var card: PanelContainer
var _dim: ColorRect
var _scroll: TouchScroll
var _closing: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("modal")


func _ready() -> void:
	_dim = ColorRect.new()
	_dim.color = Style.DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.card_style())
	add_child(card)
	# Drag anywhere (even on a button) or use the wheel to scroll; no scrollbar.
	_scroll = TouchScroll.new()
	card.add_child(_scroll)
	body = UIKit.vbox(16)
	_scroll.set_content(body)
	build()
	resized.connect(_fit)
	_fit.call_deferred()
	_dim.modulate.a = 0.0
	card.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel()
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	card.scale = Vector2(0.92, 0.92)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("open", 1.0, -10.0)


func build() -> void:
	pass


## Heading with an optional close (X) button on the right.
func add_title(text: String, with_close: bool = true) -> void:
	var row: HBoxContainer = UIKit.hbox(8, BoxContainer.ALIGNMENT_BEGIN)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(Style.CLOSE_BUTTON, Style.CLOSE_BUTTON)
	row.add_child(spacer)
	var l: Label = UIKit.label(text, Style.SIZE_H1, Style.INK, 600)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	if with_close:
		var x: Button = UIKit.icon_button("x", Style.CLOSE_BUTTON)
		x.name = "Close"
		x.pressed.connect(close)
		row.add_child(x)
	else:
		var s2: Control = Control.new()
		s2.custom_minimum_size = Vector2(Style.CLOSE_BUTTON, Style.CLOSE_BUTTON)
		row.add_child(s2)
	body.add_child(row)


## Sizes the card in two passes: first fix the width, then (once wrapped labels
## know that width) fit the height, scrolling if the content is taller than the screen.
func _fit() -> void:
	if not is_inside_tree():
		return
	var w: float = minf(size.x - 2 * Style.GUTTER, 640.0)
	var pad: float = 72.0
	body.custom_minimum_size.x = w - pad
	_scroll.custom_minimum_size = Vector2(w - pad, _scroll.custom_minimum_size.y)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var insets: Vector4 = App.safe_insets(self)
	var max_h: float = size.y - insets.y - insets.w - AdManager.banner_height - 80.0
	var content_h: float = body.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(content_h, max_h - pad)
	card.size = Vector2(w, 0)
	card.reset_size()
	card.position = ((size - Vector2(0, AdManager.banner_height) - card.size) / 2.0).round()
	card.pivot_offset = card.size / 2.0


## Opens another card on top of this one and hides this one meanwhile; closing
## the child brings this card back (e.g. Settings > Credits > close > Settings).
func open_child(child: Overlay) -> void:
	visible = false
	child.closed.connect(func() -> void:
		if is_instance_valid(self) and not _closing:
			visible = true
			refit()
	)
	app.open(child)


## Re-measure after content changes.
func refit() -> void:
	_fit.call_deferred()


func _on_dim_input(e: InputEvent) -> void:
	if dismissable and e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		close()


## Back closes the card unless it insists on an explicit choice.
func on_back() -> void:
	if dismissable:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw: Tween = create_tween().set_parallel()
	tw.tween_property(_dim, "modulate:a", 0.0, 0.16)
	tw.tween_property(card, "modulate:a", 0.0, 0.14)
	tw.tween_property(card, "scale", Vector2(0.95, 0.95), 0.14)
	tw.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free()
	)
