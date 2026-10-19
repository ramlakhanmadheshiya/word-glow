class_name SegmentedSlider
extends Control
## A thin pill with a few options and a knob that slides to the chosen one
## (Settings › Appearance: Auto / Dark / Light). Tap an option or drag the knob.

signal changed(index: int)

var options: PackedStringArray = PackedStringArray()
var index: int = 0
var accent: Color = Style.AMBER
var _knob_x: float = 0.0
var _tween: Tween
var _dragging: bool = false


func _init(labels: PackedStringArray = PackedStringArray(), start: int = 0) -> void:
	options = labels
	index = start
	custom_minimum_size = Vector2(0, 60)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(func() -> void:
		_knob_x = _slot_x(index)
		queue_redraw()
	)


func _slot_w() -> float:
	return size.x / float(maxi(1, options.size()))


func _slot_x(i: int) -> float:
	return _slot_w() * i


func select(i: int, animate: bool = true) -> void:
	i = clampi(i, 0, options.size() - 1)
	var was: int = index
	index = i
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_method(func(v: float) -> void:
			_knob_x = v
			queue_redraw(), _knob_x, _slot_x(i), 0.28)
	else:
		_knob_x = _slot_x(i)
		queue_redraw()
	if i != was:
		Audio.play("click", 1.0 + 0.1 * i, -4.0)
		Haptics.tick()
		changed.emit(i)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e
		if mb.pressed:
			_dragging = true
		else:
			_dragging = false
			select(int(clampf(mb.position.x / _slot_w(), 0.0, options.size() - 0.001)))
		accept_event()
	elif e is InputEventMouseMotion and _dragging:
		_knob_x = clampf((e as InputEventMouseMotion).position.x - _slot_w() / 2.0, 0.0, size.x - _slot_w())
		queue_redraw()
		accept_event()
	elif e.is_action_pressed("ui_left"):
		select(index - 1)
		accept_event()
	elif e.is_action_pressed("ui_right"):
		select(index + 1)
		accept_event()


func _draw() -> void:
	var r: float = size.y / 2.0
	draw_style_box(UIKit.box(Color(Style.INK, 0.08), int(r), Color(Style.INK, 0.12), 2), Rect2(Vector2.ZERO, size))
	var knob: Rect2 = Rect2(Vector2(_knob_x, 0), Vector2(_slot_w(), size.y)).grow(-4)
	draw_style_box(UIKit.box(accent, int(r - 4)), knob)
	if has_focus():
		draw_style_box(UIKit.box(Color.TRANSPARENT, int(r + 3), Color(Style.INK, 0.7), 3), Rect2(Vector2.ZERO, size).grow(4))
	var f: Font = UIKit.font(700)
	var fs: int = 22
	for i: int in options.size():
		var center: Vector2 = Vector2(_slot_x(i) + _slot_w() / 2.0, size.y / 2.0)
		var w: float = f.get_string_size(options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var on: bool = absf(_knob_x - _slot_x(i)) < _slot_w() / 2.0
		draw_string(f, Vector2(center.x - w / 2.0, center.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), options[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.PAPER_INK if on else Color(Style.INK, 0.75))
