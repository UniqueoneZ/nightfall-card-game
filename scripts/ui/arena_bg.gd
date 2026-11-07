class_name ArenaBackground
extends Control
## 程序化背景：渐变、祭坛光晕、地台、浮尘、暗角。

var _t := 0.0
var _dust: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng_dust()
	set_process(true)

func _rng_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	for i in 90:
		_dust.append({
			"p": Vector2(rng.randf(), rng.randf() * 0.72),
			"r": 0.8 + rng.randf() * 1.6,
			"ph": rng.randf() * TAU,
			"sp": 0.15 + rng.randf() * 0.45,
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 0:
		return

	# 竖向渐变
	var bands := 56
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := UITheme.BG_DEEP.lerp(Color("#101728"), f)
		draw_rect(Rect2(0, s.y * f, s.x, s.y / bands + 1.0), c)

	# 祭坛光晕
	var glow := Vector2(s.x * 0.5, s.y * 0.34)
	for i in range(7, 0, -1):
		draw_circle(glow, 90.0 * i, Color(0.20, 0.30, 0.48, 0.018))

	# 地台
	var floor_y := s.y * 0.56
	draw_rect(Rect2(0, floor_y, s.x, s.y - floor_y), Color(0.024, 0.031, 0.05, 0.85))
	draw_line(Vector2(0, floor_y), Vector2(s.x, floor_y), Color(0.26, 0.32, 0.45, 0.22), 1.0)
	# 敌人脚下的光斑
	var ec := Vector2(s.x * 0.5, 470.0)
	for i in 3:
		draw_circle(ec, 150.0 + i * 26.0, Color(0.30, 0.36, 0.52, 0.012))

	# 浮尘
	for d in _dust:
		var p: Vector2 = d["p"]
		var tw := 0.5 + 0.5 * sin(_t * float(d["sp"]) * 2.0 + float(d["ph"]))
		var y := p.y * s.y + sin(_t * 0.3 + float(d["ph"])) * 8.0
		draw_circle(Vector2(p.x * s.x, y), float(d["r"]), Color(0.85, 0.78, 0.55, 0.04 + 0.12 * tw))
