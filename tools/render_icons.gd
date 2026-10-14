extends SceneTree
## Renders the PNG launcher icons Android needs from the SVG sources.
##
##   godot --headless --path . -s res://tools/render_icons.gd

const JOBS: Array = [
	["res://assets/icon.svg", "res://assets/android/icon_main.png", 192],
	["res://assets/android/icon_foreground.svg", "res://assets/android/icon_foreground.png", 432],
	["res://assets/android/icon_background.svg", "res://assets/android/icon_background.png", 432],
	["res://assets/icon.svg", "res://web/images/icon-512.png", 512],
]


func _init() -> void:
	for job: Array in JOBS:
		var img: Image = Image.new()
		var svg: String = FileAccess.get_file_as_string(job[0])
		var err: Error = img.load_svg_from_string(svg, float(job[2]) / 1024.0)
		if err != OK:
			push_error("cannot render %s" % job[0])
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(job[1]).get_base_dir()))
		img.save_png(job[1])
		print("wrote %s (%dx%d)" % [job[1], img.get_width(), img.get_height()])
	quit(0)
