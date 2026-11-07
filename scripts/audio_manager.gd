extends Node
## 音频：程序合成的音效与 BGM。按名字播放，自动轮转播放器避免互相打断。

const NAMES := ["hit", "block", "card", "draw", "heal", "win", "lose"]

var streams: Dictionary = {}
var pool: Array = []
var idx := 0
var bgm: AudioStreamPlayer
var muted := false

func _ready() -> void:
	for n in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			streams[n] = load(p)
	for i in 8:
		var ap := AudioStreamPlayer.new()
		ap.volume_db = -9.0
		add_child(ap)
		pool.append(ap)
	bgm = AudioStreamPlayer.new()
	bgm.volume_db = -20.0
	add_child(bgm)
	if ResourceLoader.exists("res://assets/sfx/bgm.wav"):
		bgm.stream = load("res://assets/sfx/bgm.wav")
		bgm.finished.connect(func() -> void:
			if not muted:
				bgm.play())
	set_process_unhandled_key_input(true)

func play(name: String) -> void:
	if muted or not streams.has(name) or pool.is_empty():
		return
	var ap: AudioStreamPlayer = pool[idx]
	idx = (idx + 1) % pool.size()
	ap.stream = streams[name]
	ap.play()

func start_bgm() -> void:
	if bgm != null and bgm.stream != null and not bgm.playing and not muted:
		bgm.play()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		muted = not muted
		if muted and bgm != null:
			bgm.stop()
		elif not muted:
			start_bgm()
