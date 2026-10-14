extends Screen
## The eight worlds as a two-column map. Locked worlds say what opens them.


func build() -> void:
	body.add_child(top_bar("Worlds", "%d of %d open" % [Profile.unlocked_world_count(), Catalog.world_count()], true, UIKit.coin_chip()))
	body.add_child(UIKit.gap(6))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	for i: int in Catalog.world_count():
		var w: Dictionary = Catalog.world(i)
		var unlocked: bool = Profile.world_unlocked(i)
		var hint: String = ""
		if not unlocked and i > 0:
			var prev: Dictionary = Catalog.world(i - 1)
			var need: int = maxi(0, Catalog.unlock_clears - Profile.world_clears(i - 1))
			hint = "Clear %d more in %s" % [need, prev["name"]]
		var tile: WorldTile = WorldTile.new(w, Profile.world_clears(i), unlocked, hint)
		var idx: int = i
		tile.pressed.connect(func() -> void:
			if Profile.world_unlocked(idx):
				app.go("levels", {"world": idx})
			else:
				Audio.play("error", 1.2, -8.0)
				app.toast(hint, "lock", Style.MUTED)
		)
		grid.add_child(tile)
