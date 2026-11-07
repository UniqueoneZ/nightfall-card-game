class_name PlayerView
extends Control
## 玩家面板：头像、生命、格挡、状态与能量球。

const W := 320.0
const H := 250.0

var data: Dictionary = {}
var energy := 0
var max_energy := 3
var downed := false
var active := false
var art: Texture2D = null

const CLASS_ART := {
	"oathbound": "paladin_landmark", "hierophant": "paladin_landmark",
	"emberwright": "warlock_landmark", "beastcaller": "warlock_landmark",
	"shadowblade": "rogue_landmark",
}

func set_class_art(cls: String) -> void:
	var key := str(CLASS_ART.get(cls, "paladin_landmark"))
	var path := "res://assets/art/%s.webp" % key
	art = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()
var _t := 0.0

func configure(p_data: Dictionary, p_energy: int, p_max_energy: int, p_downed: bool = false, p_active: bool = false) -> void:
	data = p_data
	energy = p_energy
	max_energy = p_max_energy
	downed = p_downed
	active = p_active
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	var font := get_theme_default_font()

	var border := UITheme.GOLD if active else UITheme.LINE
	var panel := UITheme.panel_box(Color(0.055, 0.065, 0.095, 0.92), border, 14, 2 if active else 1)
	draw_style_box(panel, Rect2(0, 0, W, H))

	# 头像
	var ac := Vector2(56, 62)
	if art != null:
		var box := Rect2(ac - Vector2(38, 38), Vector2(76, 76))
		var tw := float(art.get_width())
		var th := float(art.get_height())
		var side := minf(tw, th)
		var src := Rect2((tw - side) * 0.5, (th - side) * 0.22, side, side)
		draw_texture_rect_region(art, box, src, Color(1, 1, 1, 0.92))
		draw_rect(box, Color(0.03, 0.04, 0.07, 0.35))
	if art == null:
		draw_circle(ac, 38.0, Color("#0A0D14"))
	draw_arc(ac, 38.0, 0, TAU, 48, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.55), 1.5, true)
	draw_arc(ac, 26.0, -PI * 0.5, PI * 1.2, 32, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.25), 1.0, true)
	draw_arc(ac, 39.0, 0, TAU, 48, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.55), 2.0, true)

	# 名字
	draw_string(font, Vector2(104, 30), str(data.get("name", "旅人")), HORIZONTAL_ALIGNMENT_LEFT, 190, 16, UITheme.TEXT)

	# 生命
	var bw := 176.0
	var bx := 104.0
	var by := 40.0
	draw_rect(Rect2(bx, by, bw, 18), Color("#10141D"))
	var hp := int(data.get("hp", 0))
	var mx := maxi(1, int(data.get("max_hp", 1)))
	var ratio := clampf(float(hp) / float(mx), 0.0, 1.0)
	draw_rect(Rect2(bx, by, bw * ratio, 18), Color("#8E2F3C"))
	draw_rect(Rect2(bx, by, bw * ratio, 7), Color(1, 1, 1, 0.07))
	draw_rect(Rect2(bx, by, bw, 18), Color("#2C3446"), false, 1.0)
	draw_string(font, Vector2(bx, by + 14), "%d / %d" % [hp, mx], HORIZONTAL_ALIGNMENT_CENTER, bw, 12, Color(0.95, 0.92, 0.87))

	# 格挡（贴在生命条右侧）
	var blk := int(data.get("block", 0))
	if blk > 0:
		var bpos := Vector2(296, by + 9)
		draw_circle(bpos, 14.0, Color("#0C1512"))
		draw_arc(bpos, 14.0, 0, TAU, 28, UITheme.JADE, 2.0, true)
		draw_string(font, Vector2(bpos.x - 14, bpos.y + 5), str(blk), HORIZONTAL_ALIGNMENT_CENTER, 28, 12, UITheme.JADE)

	# 状态
	_draw_statuses(font, Vector2(16, 116))

	# 分隔线
	draw_line(Vector2(14, 142), Vector2(W - 14, 142), Color(UITheme.LINE.r, UITheme.LINE.g, UITheme.LINE.b, 0.9), 1.0)

	# 能量球
	_draw_energy(Vector2(58, 202))

	if downed:
		draw_rect(Rect2(0, 0, W, H), Color(0.25, 0.03, 0.05, 0.55))
		draw_string(font, Vector2(0, 140), "已倒下", HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color("#E88A90"))
		draw_string(font, Vector2(0, 172), "等待救援或自动复活", HORIZONTAL_ALIGNMENT_CENTER, W, 13, Color("#B08088"))

func _draw_energy(c: Vector2) -> void:
	var font := get_theme_default_font()
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	draw_circle(c, 44.0, Color(0.36, 0.58, 0.85, 0.06))
	draw_circle(c, 36.0, Color(0.10, 0.16, 0.26, 0.95))
	draw_arc(c, 36.0, 0, TAU, 48, Color(0.42, 0.66, 0.95, 0.55 + 0.25 * pulse), 2.0, true)
	draw_arc(c, 31.0, -PI * 0.5 + _t * 0.6, PI * 0.6 + _t * 0.6, 32, Color(0.55, 0.78, 1.0, 0.35), 1.5, true)
	draw_string(font, Vector2(c.x - 40, c.y + 11), "%d/%d" % [energy, max_energy],
		HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Color(0.85, 0.93, 1.0))
	draw_string(font, Vector2(c.x - 40, c.y + 30), "能量", HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(0.5, 0.62, 0.78))

func _draw_statuses(font: Font, origin: Vector2) -> void:
	var st: Dictionary = data.get("statuses", {})
	var names := {"strength": "力量", "vulnerable": "易伤", "weak": "虚弱", "poison": "中毒"}
	var cols := {
		"strength": UITheme.GOLD, "vulnerable": Color("#E08A48"),
		"weak": Color("#9A7CC0"), "poison": Color("#6FBF73"),
	}
	var x := origin.x
	var any := false
	for k in ["strength", "vulnerable", "weak", "poison"]:
		var v := int(st.get(k, 0))
		if v <= 0:
			continue
		any = true
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.06, 0.07, 0.10, 0.95)
		box.set_corner_radius_all(7)
		box.set_border_width_all(1)
		box.border_color = Color(cols[k].r, cols[k].g, cols[k].b, 0.8)
		draw_style_box(box, Rect2(x, origin.y, 56, 20))
		draw_string(font, Vector2(x, origin.y + 15), "%s%d" % [names[k], v],
			HORIZONTAL_ALIGNMENT_CENTER, 56, 12, cols[k])
		x += 62.0
	if not any:
		draw_string(font, origin + Vector2(0, 2), "—", HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.22, 0.24, 0.30))

func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
