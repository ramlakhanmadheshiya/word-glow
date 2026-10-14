class_name App
extends Control
## The app shell: night-sky backdrop, one screen at a time with slide/fade
## transitions, a stack of overlay cards, toasts, Back handling, and the
## loading and error states shown at start-up.

const SCREENS: Dictionary = {
	"home": "res://game/ui/screens/home_screen.tscn",
	"chapters": "res://game/ui/screens/chapters_screen.tscn",
	"levels": "res://game/ui/screens/levels_screen.tscn",
	"play": "res://game/ui/screens/play_screen.tscn",
	"shop": "res://game/ui/screens/shop_screen.tscn",
}

static var instance: App

var backdrop: Backdrop
var screen: Screen
var screen_name: String = ""
var _screen_host: Control
var _overlay_host: Control
var _toast_host: Control
var _busy: bool = false


func _init() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null
	UIKit.clear_caches()
	Style.clear_caches()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().set_auto_accept_quit(false)
	backdrop = Backdrop.new()
	add_child(backdrop)
	_screen_host = _layer("Screens")
	_overlay_host = _layer("Overlays")
	_toast_host = _layer("Toasts")
	_toast_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Profile.achievement_unlocked.connect(func(a: Dictionary) -> void:
		toast("%s  +%d" % [a["title"], a["reward"]], "trophy", Style.GOLD)
		Audio.play("unlock", 1.0, -3.0)
	)
	_boot()


func _layer(n: String) -> Control:
	var c: Control = Control.new()
	c.name = n
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## Loading state: a lantern lights up while content loads, then Home (or an error card).
func _boot() -> void:
	var loading: CenterContainer = CenterContainer.new()
	loading.name = "Loading"
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: VBoxContainer = UIKit.vbox(18)
	loading.add_child(col)
	var art: LanternArt = LanternArt.new(240)
	art.lit = 0.0
	col.add_child(art)
	col.add_child(UIKit.label("Word Lantern", Style.SIZE_H1, Style.INK, 600))
	col.add_child(UIKit.caption("Lighting the lanterns"))
	_screen_host.add_child(loading)
	var tw: Tween = create_tween()
	tw.tween_property(art, "lit", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	await tw.finished
	loading.queue_free()
	if not Catalog.last_error.is_empty() or Catalog.chapter_count() == 0:
		_show_error(Catalog.last_error if not Catalog.last_error.is_empty() else "No levels were found.")
		return
	if Save.recovered_from != "":
		toast("Your save was repaired" if Save.recovered_from == "backup" else "Save data could not be read, starting fresh", "info", Style.AMBER)
	Audio.music("menu")
	go("home")
	AdManager.refresh_banner()


func _show_error(message: String) -> void:
	var o: MessageCard = MessageCard.new()
	o.dismissable = false
	o.title_text = "Something went wrong"
	o.message = "%s\n\nTry again, or reinstall the game if this keeps happening." % message
	o.icon_name = "info"
	o.buttons = [["Try again", "primary", func() -> void:
		o.close()
		Catalog.reload()
		_boot()
	]]
	open(o)


# --- Screens -----------------------------------------------------------------

## Shows a screen. Back always goes one step up a fixed chain
## (level -> its chapter's levels -> chapters -> home), like Single Shot.
func go(name: String, args: Dictionary = {}) -> void:
	if _busy or not SCREENS.has(name):
		return
	_swap(name, args, 1.0)


## The screen one step "up" from the current one.
func parent_route() -> Array:
	match screen_name:
		"levels":
			return ["chapters", {}]
		"play":
			if screen != null and screen.args.has("chapter"):
				return ["levels", {"chapter": screen.args["chapter"]}]
			return ["home", {}]
	return ["home", {}]


func back() -> void:
	if _busy or screen_name == "home":
		return
	var route: Array = parent_route()
	_swap(route[0], route[1], -1.0)


func _swap(name: String, args: Dictionary, direction: float) -> void:
	_busy = true
	var next: Screen = (load(SCREENS[name]) as PackedScene).instantiate()
	next.app = self
	next.args = args
	var old: Screen = screen
	screen = next
	screen_name = name
	_screen_host.add_child(next)
	var colors: Array[Color] = next.sky()
	backdrop.set_sky(colors[0], colors[1])
	next.modulate.a = 0.0
	next.position.x = 60.0 * direction
	var tw: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(next, "modulate:a", 1.0, 0.28)
	tw.tween_property(next, "position:x", 0.0, 0.32)
	if old != null:
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tw.tween_property(old, "modulate:a", 0.0, 0.18)
		tw.tween_property(old, "position:x", -60.0 * direction, 0.25)
	await tw.finished
	if old != null:
		old.queue_free()
	_busy = false


## Shows the current screen again (e.g. after a colour theme change).
func reload_screen() -> void:
	if screen != null and not _busy:
		_swap(screen_name, screen.args, 0.0)


## Settings, from anywhere. In a level, Reset progress is hidden.
func open_settings() -> void:
	open(SettingsCard.new())


# --- Overlays and toasts -------------------------------------------------------

func open(o: Overlay) -> Overlay:
	o.app = self
	o.closed.connect(func() -> void:
		if screen != null and is_instance_valid(screen):
			screen.refresh()
	)
	_overlay_host.add_child(o)
	return o


func top_overlay() -> Overlay:
	for i: int in range(_overlay_host.get_child_count() - 1, -1, -1):
		var c: Node = _overlay_host.get_child(i)
		if c is Overlay and not (c as Overlay)._closing:
			return c
	return null


func toast(text: String, icon_name: String = "", tint: Color = Style.AMBER) -> void:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UIKit.box(Color("1E1A4A"), 36, Color(tint, 0.6), 2, Vector2(28, 16)))
	var row: HBoxContainer = UIKit.hbox(12)
	if not icon_name.is_empty():
		row.add_child(UIKit.icon_rect(icon_name, 34, tint))
	row.add_child(UIKit.label(text, Style.SIZE_SMALL, Style.INK, 600))
	pill.add_child(row)
	_toast_host.add_child(pill)
	var y: float = App.safe_insets(self).y + 24.0
	var shown: int = _toast_host.get_child_count() - 1
	pill.reset_size()
	pill.position = Vector2((size.x - pill.size.x) / 2.0, y - 40.0 + shown * 86.0)
	pill.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel().tween_property(pill, "modulate:a", 1.0, 0.25)
	tw.tween_property(pill, "position:y", y + shown * 86.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.4)
	tw.chain().tween_property(pill, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(pill.queue_free)


# --- Back, quit and layout helpers ---------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		handle_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func handle_back() -> void:
	var o: Overlay = top_overlay()
	if o != null:
		o.on_back()
		return
	if screen != null and screen.on_back():
		return
	if screen_name == "home":
		if OS.has_feature("android"):
			quit_game()
		return
	back()


## Saves, silences audio, and quits once the audio server has let go of the streams.
func quit_game() -> void:
	Save.flush()
	Audio.stop_all()
	await get_tree().process_frame
	get_tree().quit()


## Safe-area insets (left, top, right, bottom) in the control's canvas units,
## so content stays clear of notches and rounded corners.
static func safe_insets(c: Control) -> Vector4:
	if not c.is_inside_tree() or not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return Vector4.ZERO
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var vp: Vector2 = c.get_viewport_rect().size
	var k: Vector2 = vp / win
	return Vector4(safe.position.x * k.x, safe.position.y * k.y,
		maxf(0.0, (win.x - safe.end.x) * k.x), maxf(0.0, (win.y - safe.end.y) * k.y))
