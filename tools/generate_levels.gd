extends SceneTree
## Builds every chapter level with PuzzleGenerator and writes
## data/levels/<chapter>.json. Daily puzzles are not stored: the game builds
## each day's puzzle from the date (see PuzzleGenerator.daily).
##
##   godot --headless --path . -s res://tools/generate_levels.gd
##   godot --headless --path . -s res://tools/generate_levels.gd -- harbor
##
## Deterministic: the same inputs always give the same levels. Within each
## chapter every level is a little harder than the one before it.

const OUT_DIR: String = "res://data/levels/"


func _init() -> void:
	var themes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/themes.json"))
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var gen: PuzzleGenerator = PuzzleGenerator.new(themes, plan)
	var only: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var t0: int = Time.get_ticks_msec()
	var chapters: Array = plan["chapters"]
	for ci: int in chapters.size():
		var ch: Dictionary = chapters[ci]
		if not only.is_empty() and not only.has(ch["id"]):
			continue
		var puzzles: Array[Puzzle] = gen.chapter_levels(ci)
		if puzzles.is_empty():
			push_error("FAILED chapter %s" % ch["id"])
			quit(1)
			return
		var levels: Array = []
		for k: int in puzzles.size():
			var p: Puzzle = puzzles[k]
			levels.append(p.to_dict())
			print("%s  %dx%d  %-12s words=%d shadows=%d beacons=%d score=%.2f" % [p.id, p.rows, p.cols, p.theme_id, p.words.size(), p.shadows.size(), p.beacons.size(), PuzzleGenerator.difficulty(p)])
		var f: FileAccess = FileAccess.open(OUT_DIR + ch["id"] + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"chapter": ch["id"], "levels": levels}, "\t", false))
		f.close()
	print("GENERATED in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)
