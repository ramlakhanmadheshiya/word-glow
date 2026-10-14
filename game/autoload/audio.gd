extends Node
## Sound effects and music, honouring the player's settings.
## Effects play from a small pool of players so quick sounds can overlap.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const POOL_SIZE: int = 8
const MUSIC_DB: float = -9.0
## Major-pentatonic steps (semitones) for the rising letter taps.
const TAP_STEPS: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _music_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	Profile.settings_changed.connect(_apply_settings)


## Releases playing streams on quit so nothing is left referenced.
func _exit_tree() -> void:
	stop_all()


func stop_all() -> void:
	_music.stop()
	_music.stream = null
	for p: AudioStreamPlayer in _pool:
		p.stop()
		p.stream = null
	_streams.clear()


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path: String = SFX_DIR + name + ".wav"
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]


func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not Profile.setting("sfx"):
		return
	var s: AudioStream = _stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## The tick for the n-th letter of a trace: each one a step higher.
func tap(index: int) -> void:
	var step: int = TAP_STEPS[clampi(index, 0, TAP_STEPS.size() - 1)]
	play("tap", pow(2.0, step / 12.0) * 0.5, -4.0)


func music(name: String) -> void:
	_music_name = name
	# Headless runs (tests, CI) have no audio output; skip the long-lived stream.
	if not Profile.setting("music") or DisplayServer.get_name() == "headless":
		_music.stop()
		return
	var path: String = MUSIC_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var s: AudioStream = load(path)
	if _music.stream == s and _music.playing:
		return
	if s is AudioStreamWAV:
		var w: AudioStreamWAV = s
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 1.5)


func _apply_settings() -> void:
	if Profile.setting("music"):
		if not _music.playing and not _music_name.is_empty():
			music(_music_name)
	else:
		_music.stop()
