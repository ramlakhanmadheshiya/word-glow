extends Node
## Short vibrations on phones, if the player allows them.


func tick() -> void:
	_buzz(12)


func success() -> void:
	_buzz(35)


func error() -> void:
	_buzz(60)


func _buzz(ms: int) -> void:
	if not bool(Profile.setting("haptics", true)):
		return
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		Input.vibrate_handheld(ms)
