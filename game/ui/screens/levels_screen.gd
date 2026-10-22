extends Screen
## One chapter's 40 levels as a single grid of tiles. Every number is shown,
## open or locked, so the whole chapter is visible at a glance; a hero card shows
## the chapter's stars and progress. Locked levels can be opened with a key.

var chapter_idx: int = 0
var _tiles: Array[LevelTile] = []
var _scroll: TouchScroll
var _grid: GridContainer


func chapter_info() -> Dictionary:
	return Catalog.chapter(clampi(int(args.get("chapter", 0)), 0, maxi(0, Catalog.chapter_count() - 1)))


func build() -> void:
	chapter_idx = clampi(int(args.get("chapter", 0)), 0, maxi(0, Catalog.chapter_count() - 1))
	var ch: Dictionary = Catalog.chapter(chapter_idx)
	body.add_child(header(str(ch["name"]), "Chapter %d · %s" % [chapter_idx + 1, str(ch.get("concept", ""))]))
	_scroll = TouchScroll.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	var list: VBoxContainer = UIKit.vbox(14)
	_scroll.set_content(list)
	list.add_child(_hero(ch))
	list.add_child(chip_row([UIKit.key_chip(), UIKit.coin_chip()]))
	var center: CenterContainer = CenterContainer.new()
	list.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 8)
	center.add_child(_grid)
	var next: Array[int] = Profile.next_level()
	var focus: LevelTile = null
	for n: int in range(1, Catalog.levels_per_chapter + 1):
		var tile: LevelTile = LevelTile.new()
		tile.name = "Level%d" % n
		tile.number = n
		tile.accent = accent()
		var level: int = n
		tile.pressed.connect(func() -> void: _on_tile(level))
		_grid.add_child(tile)
		_tiles.append(tile)
		if next[0] == chapter_idx and next[1] == n:
			focus = tile
		tile.modulate.a = 0.0
		create_tween().tween_property(tile, "modulate:a", 1.0, 0.22).set_delay(0.01 * n)
	_refresh_tiles()
	var next_ch: int = chapter_idx + 1
	if next_ch < Catalog.chapter_count() and not Profile.chapter_unlocked(next_ch):
		var need: int = maxi(0, Catalog.unlock_clears - Profile.chapter_clears(chapter_idx))
		list.add_child(UIKit.para("Clear %d more to open %s" % [need, Catalog.chapter(next_ch)["name"]], Style.SIZE_SMALL, Style.MUTED))
	list.add_child(UIKit.gap(20))
	Profile.keys_changed.connect(func(_k: int) -> void: _refresh_tiles())
	_scroll_to_current.call_deferred(focus)


## Brings the current level into view once layout has settled, keeping the hero
## card on screen when it fits.
func _scroll_to_current(focus: LevelTile) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if focus == null or not focus.is_inside_tree() or _scroll.content == null:
		return
	var bottom: float = focus.global_position.y - _scroll.content.global_position.y + focus.size.y + 24.0
	if bottom > _scroll.size.y:
		_scroll.scroll_to(bottom - _scroll.size.y + focus.size.y)


func _refresh_tiles() -> void:
	var ch_id: String = Catalog.chapter(chapter_idx)["id"]
	var next: Array[int] = Profile.next_level()
	var cell: float = _cell_size()
	for t: LevelTile in _tiles:
		var id: String = Catalog.level_id(ch_id, t.number)
		t.stars = Profile.stars_for(id)
		t.open = Profile.level_unlocked(chapter_idx, t.number)
		t.keyed = Profile.key_unlocked(id)
		t.in_progress = not Profile.saved_progress(id).is_empty()
		t.current = next[0] == chapter_idx and next[1] == t.number
		t.custom_minimum_size = Vector2(cell, cell + 8)
		t.queue_redraw()


func _cell_size() -> float:
	var w: float = minf(size.x, Style.MAX_WIDTH) - 2 * Style.GUTTER if size.x > 0 else 672.0
	return clampf((w - 4 * 12) / 5.0, 96.0, 132.0)


func _fit() -> void:
	super._fit()
	if _grid != null:
		var cell: float = _cell_size()
		for t: LevelTile in _tiles:
			t.custom_minimum_size = Vector2(cell, cell + 8)


func _on_tile(n: int) -> void:
	if Profile.level_unlocked(chapter_idx, n):
		app.go("play", {"chapter": chapter_idx, "level": n})
	else:
		Audio.play("error", 1.2, -8.0)
		var o: LockedCard = LockedCard.new()
		o.chapter_idx = chapter_idx
		o.level = n
		app.open(o)


func refresh() -> void:
	_refresh_tiles()


## The chapter at a glance: tagline, stars, open / cleared / locked progress,
## and a button that explains the chapter's idea.
func _hero(ch: Dictionary) -> PanelContainer:
	var v: VBoxContainer = UIKit.vbox(10)
	var top: HBoxContainer = UIKit.hbox(16, BoxContainer.ALIGNMENT_BEGIN)
	v.add_child(top)
	var text: VBoxContainer = UIKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text)
	var tag: Label = UIKit.label(str(ch["tagline"]), Style.SIZE_BODY, Style.INK, 500, HORIZONTAL_ALIGNMENT_LEFT)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(tag)
	var total: int = Catalog.levels_per_chapter
	var stars: Label = UIKit.label("★ %d / %d" % [Profile.chapter_stars(chapter_idx), total * 3], Style.SIZE_SMALL, Style.GOLD, 700, HORIZONTAL_ALIGNMENT_LEFT)
	stars.name = "Stars"
	text.add_child(stars)
	var art: LanternArt = LanternArt.new(110)
	art.color = accent()
	art.letter = str(chapter_idx + 1)
	art.lit = 0.35 + 0.65 * float(Profile.chapter_clears(chapter_idx)) / float(total)
	top.add_child(art)
	var open: int = Profile.open_in(chapter_idx)
	var cleared: int = Profile.chapter_clears(chapter_idx)
	var bar: ProgressBar = UIKit.progress_bar(float(cleared) / float(total), accent(), 12)
	v.add_child(bar)
	var legend: Label = UIKit.label("%d of %d open · %d cleared · %d locked" % [open, total, cleared, total - open], Style.SIZE_CAPTION + 1, Style.MUTED, 500, HORIZONTAL_ALIGNMENT_LEFT)
	legend.name = "Legend"
	v.add_child(legend)
	var lesson: String = str(ch.get("lesson", ""))
	if HowToCard.PAGES.has(lesson):
		var how: Button = UIKit.button("How it works", "soft", accent(), 64, 22)
		how.name = "HowItWorks"
		how.pressed.connect(func() -> void:
			var o: HowToCard = HowToCard.new()
			o.pages = [lesson]
			o.heading = str(ch.get("concept", ""))
			app.open(o))
		v.add_child(how)
	var p: PanelContainer = UIKit.panel(v, Color(0, 0, 0, 0.25), 34, Vector2(26, 20))
	p.name = "Hero"
	return p
