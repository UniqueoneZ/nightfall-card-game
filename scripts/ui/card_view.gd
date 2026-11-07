class_name CardView
extends Control
## 手牌：完全程序化绘制的卡面。

signal card_pressed(index: int)

const W := 150.0
const H := 208.0

var card: Dictionary = {}
var index := 0
var playable := true
var hovered := false
var targeted := false
var home := Vector2.ZERO
var tex: Texture2D = null
var art_tex: Texture2D = null
var _tw: Tween = null

func configure(p_card: Dictionary, p_index: int, p_playable: bool) -> void:
	card = p_card
	index = p_index
	playable = p_playable
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(W, H)
	if size != Vector2(W, H):
		size = Vector2(W, H)
	pivot_offset = Vector2(W, H) * 0.5
	modulate = Color(1, 1, 1, 1) if playable else Color(0.66, 0.68, 0.74, 0.9)
	tooltip_text = ""
	tex = _pick_icon(card)
	art_tex = _pick_art(card)
	queue_redraw()

const CLASS_ICONS := {
	"oathbound": ["block", "thorns", "sunder", "relic", "strength", "sun"],
	"emberwright": ["fire", "magic", "skull", "potion", "lightning", "sun"],
	"shadowblade": ["bleed", "poison", "shadow", "multi", "draw", "curse"],
	"hierophant": ["holy", "heal", "regen", "scroll", "sun", "block"],
	"beastcaller": ["summon", "ranged", "vulnerable", "gold", "moon", "energy"],
}

const CLASS_FAMILY := {
	"oathbound": "paladin", "hierophant": "paladin",
	"emberwright": "warlock", "beastcaller": "warlock",
	"shadowblade": "rogue",
}

func _pick_art(c: Dictionary) -> Texture2D:
	var fam := str(CLASS_FAMILY.get(str(c.get("class", "")), "neutral"))
	var kind := "spell"
	match str(c.get("type", "")):
		"skill": kind = "landmark"
		"power": kind = "talent"
	var path := "res://assets/art/%s_%s.webp" % [fam, kind]
	if not ResourceLoader.exists(path):
		path = "res://assets/art/neutral_spell.webp"
	return load(path) if ResourceLoader.exists(path) else null

func _pick_icon(c: Dictionary) -> Texture2D:
	# 1) 效果优先：治疗/抽牌/中毒/灼烧 用专属图标
	var key := ""
	for e in c.get("effects", []):
		var k := str(e.get("k", ""))
		var st := str(e.get("status", ""))
		if k == "heal":
			key = "heal"
		elif k == "draw":
			key = "draw"
		elif st == "poison":
			key = "poison"
		elif st == "burn":
			key = "fire"
		elif st == "thorns":
			key = "thorns"
		elif st == "vulnerable":
			key = "vulnerable"
		elif st == "mark":
			key = "vulnerable"
		elif k == "self_damage":
			key = "skull"
		if key != "":
			break
	# 2) 否则按职业轮转，保证同类卡图不重复
	if key == "":
		var cls := str(c.get("class", ""))
		var pool: Array = CLASS_ICONS.get(cls, [])
		if not pool.is_empty():
			var h: int = absi(str(c.get("id", "")).hash())
			key = str(pool[h % pool.size()])
		else:
			key = "attack"
	var path := "res://assets/icons/%s.svg" % key
	return load(path) if ResourceLoader.exists(path) else null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	z_index = 10

func set_home(pos: Vector2) -> void:
	home = pos
	if not hovered:
		position = pos

func _on_enter() -> void:
	hovered = true
	z_index = 100
	_lift(true)
	queue_redraw()

func _on_exit() -> void:
	hovered = false
	z_index = 10
	_lift(false)
	queue_redraw()

func _lift(up: bool) -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_pos := home + (Vector2(0, -46) if up else Vector2.ZERO)
	var target_scale := Vector2(1.07, 1.07) if up else Vector2.ONE
	_tw.tween_property(self, "position", target_pos, 0.14)
	_tw.tween_property(self, "scale", target_scale, 0.14)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		card_pressed.emit(index)

# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	if card.is_empty():
		return
	var font := get_theme_default_font()
	var accent := UITheme.accent_for(str(card.get("type", "skill")))
	var w := W
	var h := H

	var body := StyleBoxFlat.new()
	body.bg_color = Color("#151A26")
	body.set_corner_radius_all(12)
	body.set_border_width_all(2 if hovered else 1)
	body.border_color = accent if playable else Color("#3A3F4C")
	body.shadow_color = Color(accent.r, accent.g, accent.b, 0.40 if hovered else 0.16)
	body.shadow_size = 16 if hovered else 7
	draw_style_box(body, Rect2(0, 0, w, h))

	# 插画区
	var art := Rect2(6, 6, w - 12, 84)
	draw_rect(art, Color(accent.r, accent.g, accent.b, 0.15))
	if art_tex != null:
		# 居中裁切，避免拉伸变形
		var tw: float = float(art_tex.get_width())
		var th: float = float(art_tex.get_height())
		var band_ratio: float = art.size.x / art.size.y
		var src_w := tw
		var src_h := tw / band_ratio
		if src_h > th:
			src_h = th
			src_w = th * band_ratio
		var src := Rect2((tw - src_w) * 0.5, (th - src_h) * 0.28, src_w, src_h)
		draw_texture_rect_region(art_tex, art, src, Color(1, 1, 1, 0.55))
		draw_rect(art, Color(0.05, 0.06, 0.09, 0.35))
	draw_circle(art.get_center(), 34.0, Color(accent.r, accent.g, accent.b, 0.13))
	draw_circle(art.get_center(), 20.0, Color(accent.r, accent.g, accent.b, 0.10))
	if tex != null:
		var isz := 54.0
		draw_texture_rect(tex, Rect2(art.get_center() - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false,
			Color(1, 1, 1, 0.92))
	else:
		_draw_sigil(art.get_center() + Vector2(0, 2), accent)
	draw_line(Vector2(6, art.end.y), Vector2(w - 6, art.end.y), Color(accent.r, accent.g, accent.b, 0.5), 1.0)

	# 费用
	var cpos := Vector2(22, 24)
	draw_circle(cpos, 15.0, Color("#090C13"))
	draw_arc(cpos, 15.0, 0, TAU, 36, UITheme.GOLD if playable else Color("#5A5F6E"), 2.0, true)
	var cost_col := UITheme.GOLD if playable else Color("#7A8090")
	draw_string(font, Vector2(cpos.x - 14, cpos.y + 7), str(int(card.get("cost", 0))),
		HORIZONTAL_ALIGNMENT_CENTER, 28, 19, cost_col)

	# 名称
	var name_col := UITheme.TEXT if playable else Color("#9AA0AE")
	draw_string(font, Vector2(0, 116), str(card.get("name", "")),
		HORIZONTAL_ALIGNMENT_CENTER, w, 19, name_col)

	# 描述
	var desc_col := Color("#C9C3B6") if playable else Color("#7C8290")
	draw_multiline_string(font, Vector2(10, 138), str(card.get("desc", "")),
		HORIZONTAL_ALIGNMENT_CENTER, w - 20, 13, 4, desc_col)

	# 底部类型
	var type_cn: String = {"attack": "攻击", "skill": "技能", "power": "能力"}.get(str(card.get("type", "")), "")
	if bool(card.get("exhaust", false)):
		type_cn += " · 消耗"
	draw_string(font, Vector2(0, h - 12), type_cn, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(accent.r, accent.g, accent.b, 0.9))

	# 稀有度宝石
	_draw_gem(Vector2(w - 16, 16), _rarity_color(str(card.get("rarity", "common"))))

	# 内描边 + 四角装饰
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.set_corner_radius_all(9)
	inner.set_border_width_all(1)
	inner.border_color = Color(accent.r, accent.g, accent.b, 0.25)
	draw_style_box(inner, Rect2(4, 4, w - 8, h - 8))
	for corner in [Vector2(8, 8), Vector2(w - 8, 8), Vector2(8, h - 8), Vector2(w - 8, h - 8)]:
		var sx := 1.0 if corner.x < w * 0.5 else -1.0
		var sy := 1.0 if corner.y < h * 0.5 else -1.0
		draw_line(corner, corner + Vector2(7 * sx, 0), Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.45), 1.0, true)
		draw_line(corner, corner + Vector2(0, 7 * sy), Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.45), 1.0, true)

	# 名称下方分隔线
	draw_line(Vector2(14, 124), Vector2(w - 14, 124), Color(accent.r, accent.g, accent.b, 0.35), 1.0)

	if targeted:
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(0, 0, 0, 0)
		ring.set_corner_radius_all(12)
		ring.set_border_width_all(3)
		ring.border_color = UITheme.JADE
		draw_style_box(ring, Rect2(0, 0, w, h))

func _draw_sigil(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -20), c + Vector2(20, 0), c + Vector2(0, 20), c + Vector2(-20, 0),
	])
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(col.r, col.g, col.b, 0.85), 1.5, true)
	draw_circle(c, 5.0, Color(col.r, col.g, col.b, 0.55))
	if str(card.get("type", "")) == "attack":
		draw_line(c + Vector2(-26, -26), c + Vector2(-14, -14), Color(col.r, col.g, col.b, 0.45), 1.5, true)
		draw_line(c + Vector2(26, -26), c + Vector2(14, -14), Color(col.r, col.g, col.b, 0.45), 1.5, true)
	elif str(card.get("type", "")) == "power":
		draw_arc(c, 27.0, 0, TAU, 40, Color(col.r, col.g, col.b, 0.35), 1.0, true)

func _draw_gem(p: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)])
	draw_colored_polygon(pts, col)

func _rarity_color(r: String) -> Color:
	match r:
		"uncommon": return Color("#5FB3E8")
		"rare": return Color("#E8C060")
		"starter": return Color("#6C7486")
	return Color("#A9B4C4")
