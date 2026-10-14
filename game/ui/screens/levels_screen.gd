extends Screen
## The 20 levels of one world on a 4-column grid. Levels open one at a time.

var world_idx: int = 0
var _grid: GridContainer


func sky() -> Array[Color]:
	var w: Dictionary = Catalog.world(int(args.get("world", 0)))
	if w.is_empty():
		return super.sky()
	return [w["sky_top"], w["sky_bottom"]]


func build() -> void:
	world_idx = clampi(int(args.get("world", 0)), 0, maxi(0, Catalog.world_count() - 1))
	var w: Dictionary = Catalog.world(world_idx)
	body.add_child(top_bar(str(w["name"]), "World %d" % (world_idx + 1), true, UIKit.coin_chip()))
	var tag: Label = UIKit.para(str(w["tagline"]), Style.SIZE_SMALL, Style.MUTED)
	body.add_child(tag)
	var clears: int = Profile.world_clears(world_idx)
	var prog: HBoxContainer = UIKit.hbox(14)
	var bar: ProgressBar = UIKit.progress_bar(clears / float(Catalog.LEVELS_PER_WORLD), w["accent"], 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prog.add_child(bar)
	var count: Label = UIKit.label("%d / %d lit" % [clears, Catalog.LEVELS_PER_WORLD], Style.SIZE_SMALL, Style.INK, 600)
	count.name = "Cleared"
	prog.add_child(count)
	body.add_child(prog)
	body.add_child(UIKit.gap(8))
	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	center.add_child(_grid)
	_fill()
	var next_world: int = world_idx + 1
	if next_world < Catalog.world_count() and not Profile.world_unlocked(next_world):
		var need: int = maxi(0, Catalog.unlock_clears - clears)
		body.add_child(UIKit.para("Clear %d more to open %s" % [need, Catalog.world(next_world)["name"]], Style.SIZE_SMALL, Style.MUTED))
	body.add_child(UIKit.gap(8))


## Tile edge length that fits four columns in the current width.
func _cell_size() -> float:
	if size.x <= 0:
		return 140.0
	return clampf((minf(size.x, Style.MAX_WIDTH) - 2 * Style.GUTTER - 3 * 18) / 4.0, 100.0, 150.0)


func _fill() -> void:
	var w: Dictionary = Catalog.world(world_idx)
	var cell: float = _cell_size()
	for n: int in range(1, Catalog.LEVELS_PER_WORLD + 1):
		var id: String = Catalog.level_id(w["id"], n)
		var kind: LevelTile.Kind = LevelTile.Kind.LOCKED
		if Profile.is_cleared(id):
			kind = LevelTile.Kind.CLEARED
		elif Profile.level_unlocked(world_idx, n):
			kind = LevelTile.Kind.OPEN
		var tile: LevelTile = LevelTile.new(n, kind, Profile.is_flawless(id), not Profile.saved_progress(id).is_empty(), w["accent"])
		tile.custom_minimum_size = Vector2(cell, cell)
		var level: int = n
		tile.pressed.connect(func() -> void:
			if Profile.level_unlocked(world_idx, level):
				app.go("play", {"world": world_idx, "level": level})
			else:
				Audio.play("error", 1.2, -8.0)
				app.toast("Clear level %d first" % (level - 1), "lock", Style.MUTED)
		)
		_grid.add_child(tile)


func _fit() -> void:
	super._fit()
	if _grid != null:
		var cell: float = _cell_size()
		for tile: Control in _grid.get_children():
			tile.custom_minimum_size = Vector2(cell, cell)
