class_name UnitView
extends Control
## 敌人单位：程序化剪影 + 意图气泡 + 血条 + 状态。

signal clicked(id: String)

const W := 200.0
const H := 300.0

var data: Dictionary = {}
var intent: Dictionary = {}
var targeted := false
var alive := true

var _t := 0.0
var _flash := 0.0

func configure(p_data: Dictionary) -> void:
	data = p_data
	intent = p_data.get("intent", {})
	alive = bool(p_data.get("alive", true))
	modulate = Color(1, 1, 1, 1) if alive else Color(1, 1, 1, 0.30)
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W, H) * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if alive else Control.CURSOR_ARROW

func _process(delta: float) -> void:
	if alive:
		_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
	queue_redraw()

func flash() -> void:
	_flash = 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(str(data.get("id", "")))

# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	if data.is_empty():
		return
	var font := get_theme_default_font()
	var def: Dictionary = data.get("def", {})
	var tint := Color(str(def.get("tint", "#7C8494")))
	var s := float(def.get("scale", 1.0))
	var bob := sin(_t * 1.6) * 3.0 if alive else 0.0
	var c := Vector2(W * 0.5, 168.0 + bob)

	if alive:
		_draw_intent(font, tint)

	# 光晕
	for i in 5:
		draw_circle(c, (70.0 - i * 10.0) * s, Color(tint.r, tint.g, tint.b, 0.035))

	match str(def.get("shape", "eye")):
		"fang": _draw_fang(c, s, tint)
		"spike": _draw_spike(c, s, tint)
		_: _draw_eye(c, s, tint)

	if _flash > 0.0:
		draw_circle(c, 58.0 * s, Color(1, 0.85, 0.8, 0.35 * _flash))

	if targeted and alive:
		var a := 0.55 + 0.35 * sin(_t * 7.0)
		draw_arc(c, 78.0 * s, 0, TAU, 64, Color(UITheme.JADE.r, UITheme.JADE.g, UITheme.JADE.b, a), 2.5, true)

	# 名字
	draw_string(font, Vector2(0, 240), str(data.get("name", "")),
		HORIZONTAL_ALIGNMENT_CENTER, W, 15, UITheme.TEXT_DIM)

	# 血条
	var bw := 168.0
	var bx := (W - bw) * 0.5
	var by := 249.0
	draw_rect(Rect2(bx, by, bw, 16), Color("#10141D"))
	var hp := int(data.get("hp", 0))
	var mx := maxi(1, int(data.get("max_hp", 1)))
	var ratio := clampf(float(hp) / float(mx), 0.0, 1.0)
	draw_rect(Rect2(bx, by, bw * ratio, 16), Color("#8E2F3C"))
	draw_rect(Rect2(bx, by, bw * ratio, 6), Color(1, 1, 1, 0.06))
	draw_rect(Rect2(bx, by, bw, 16), Color("#2C3446"), false, 1.0)
	draw_string(font, Vector2(bx, by + 12.5), "%d / %d" % [hp, mx],
		HORIZONTAL_ALIGNMENT_CENTER, bw, 12, Color(0.94, 0.91, 0.86))

	# 格挡
	var blk := int(data.get("block", 0))
	if blk > 0:
		var bp := Vector2(bx - 16, by + 7)
		draw_circle(bp, 13.0, Color("#0C1512"))
		draw_arc(bp, 13.0, 0, TAU, 28, UITheme.JADE, 2.0, true)
		draw_string(font, Vector2(bp.x - 13, bp.y + 5), str(blk), HORIZONTAL_ALIGNMENT_CENTER, 26, 12, UITheme.JADE)

	_draw_statuses(font, by + 26)

func _draw_intent(font: Font, tint: Color) -> void:
	if intent.is_empty():
		return
	var ty := str(intent.get("type", ""))
	var label := str(intent.get("name", ""))
	match ty:
		"attack":
			label = "%s  %d" % [label, int(intent.get("preview", 0))]
		"attack_block":
			label = "%s  %d·%d" % [label, int(intent.get("preview", 0)), int(intent.get("block", 0))]
		"defend":
			label = "%s  %d" % [label, int(intent.get("block", 0))]
	var col := UITheme.BLOOD
	match ty:
		"defend": col = UITheme.JADE
		"buff": col = UITheme.GOLD
		"debuff": col = Color("#9A7CC0")

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	box.set_corner_radius_all(9)
	box.set_border_width_all(1)
	box.border_color = Color(col.r, col.g, col.b, 0.75)
	var w := 116.0
	var r := Rect2((W - w) * 0.5, 10.0, w, 34.0)
	draw_style_box(box, r)
	draw_string(font, Vector2(r.position.x, 32), label, HORIZONTAL_ALIGNMENT_CENTER, w, 14, col)

func _draw_eye(c: Vector2, s: float, tint: Color) -> void:
	var r := 54.0 * s
	draw_circle(c, r, Color(tint.r, tint.g, tint.b, 0.20))
	draw_arc(c, r, 0, TAU, 64, Color(tint.r, tint.g, tint.b, 0.95), 2.0, true)
	draw_circle(c, r * 0.62, Color("#0A0C12"))
	draw_circle(c, r * 0.34, Color(tint.r, tint.g, tint.b, 0.85))
	draw_circle(c, r * 0.15, Color("#05060A"))
	# 眼睑
	draw_line(c + Vector2(-r, -r * 0.55), c + Vector2(0, -r * 1.05), Color(tint.r, tint.g, tint.b, 0.60), 2.0, true)
	draw_line(c + Vector2(r, -r * 0.55), c + Vector2(0, -r * 1.05), Color(tint.r, tint.g, tint.b, 0.60), 2.0, true)

func _draw_spike(c: Vector2, s: float, tint: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0 - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * 58.0 * s)
	draw_colored_polygon(pts, Color(tint.r, tint.g, tint.b, 0.20))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(tint.r, tint.g, tint.b, 0.95), 2.0, true)
	var inner := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0 - PI * 0.5
		inner.append(c + Vector2(cos(a), sin(a)) * 30.0 * s)
	draw_colored_polygon(inner, Color(tint.r, tint.g, tint.b, 0.18))
	draw_circle(c, 8.0 * s, Color(tint.r, tint.g, tint.b, 0.9))

func _draw_fang(c: Vector2, s: float, tint: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-52, -52) * s, c + Vector2(52, -52) * s,
		c + Vector2(44, 8) * s, c + Vector2(28, -12) * s,
		c + Vector2(14, 30) * s, c + Vector2(0, -6) * s,
		c + Vector2(-14, 30) * s, c + Vector2(-28, -12) * s,
		c + Vector2(-44, 8) * s,
	])
	draw_colored_polygon(pts, Color(tint.r, tint.g, tint.b, 0.22))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(tint.r, tint.g, tint.b, 0.95), 2.0, true)
	draw_circle(c + Vector2(-20, -26) * s, 5.0 * s, Color(tint.r, tint.g, tint.b, 0.95))
	draw_circle(c + Vector2(20, -26) * s, 5.0 * s, Color(tint.r, tint.g, tint.b, 0.95))

func _draw_statuses(font: Font, y: float) -> void:
	var st: Dictionary = data.get("statuses", {})
	var items: Array = []
	var names := {"strength": "力", "vulnerable": "易", "weak": "弱", "poison": "毒"}
	var cols := {
		"strength": UITheme.GOLD, "vulnerable": Color("#E08A48"),
		"weak": Color("#9A7CC0"), "poison": Color("#6FBF73"),
	}
	for k in ["strength", "vulnerable", "weak", "poison"]:
		var v := int(st.get(k, 0))
		if v > 0:
			items.append([str(names[k]), v, cols[k]])
	if items.is_empty():
		return
	var pw := 42.0
	var total := items.size() * pw + (items.size() - 1) * 6.0
	var x := (W - total) * 0.5
	for it in items:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.07, 0.10, 0.95)
		box.set_corner_radius_all(7)
		box.set_border_width_all(1)
		box.border_color = Color(it[2].r, it[2].g, it[2].b, 0.8)
		draw_style_box(box, Rect2(x, y, pw, 20.0))
		draw_string(font, Vector2(x, y + 15), "%s%d" % [it[0], it[1]],
			HORIZONTAL_ALIGNMENT_CENTER, pw, 12, it[2])
		x += pw + 6.0
