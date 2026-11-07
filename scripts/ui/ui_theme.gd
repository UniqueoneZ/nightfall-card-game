class_name UITheme
extends RefCounted
## 全局视觉规范：颜色、字体、控件皮肤。全部代码生成，工程内零美术资源。

const BG := Color("#0B0E16")
const BG_DEEP := Color("#070911")
const PANEL := Color("#141926")
const PANEL_HI := Color("#1C2333")
const LINE := Color("#2C3446")
const GOLD := Color("#D8B36A")
const GOLD_DIM := Color("#8A7443")
const TEXT := Color("#E9E3D6")
const TEXT_DIM := Color("#8A90A0")
const BLOOD := Color("#B8454F")
const JADE := Color("#5FA88B")
const MANA := Color("#6AA8E8")

const ATTACK := Color("#C1544F")
const SKILL := Color("#5B8FC0")
const POWER := Color("#9270C0")

static func accent_for(type: String) -> Color:
	match type:
		"attack": return ATTACK
		"skill": return SKILL
		"power": return POWER
	return LINE

## 中文字体：优先直接加载系统中文字体文件（无头模式与打包后都稳定），
## 失败时回退到 SystemFont。正式发布建议内置一份 OFL 授权的思源黑体/Noto Sans SC。
const BUNDLED_FONT := "res://assets/fonts/NotoSansSC-Regular.otf"

static func cjk_font() -> Font:
	# 内置字体优先：Web 版没有系统字体可用，必须打包进 pck
	if ResourceLoader.exists(BUNDLED_FONT):
		var bundled := load(BUNDLED_FONT) as Font
		if bundled != null:
			return bundled
	for path in _font_candidates():
		if FileAccess.file_exists(path):
			var ff := FontFile.new()
			if ff.load_dynamic_font(path) == OK:
				ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
				return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Heiti SC",
		"Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "sans-serif",
	])
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.allow_system_fallback = true
	return sf

static func _font_candidates() -> Array:
	match OS.get_name():
		"macOS":
			return [
				"/System/Library/Fonts/PingFang.ttc",
				"/System/Library/Fonts/Hiragino Sans GB.ttc",
				"/System/Library/Fonts/STHeiti Medium.ttc",
				"/Library/Fonts/Arial Unicode.ttf",
			]
		"Windows":
			return [
				"C:/Windows/Fonts/msyh.ttc",
				"C:/Windows/Fonts/simhei.ttf",
				"C:/Windows/Fonts/simsun.ttc",
			]
		_:
			return [
				"/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
				"/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
				"/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
			]

static func build() -> Theme:
	var t := Theme.new()
	var f := cjk_font()
	ThemeDB.fallback_font = f
	ThemeDB.fallback_font_size = 18
	t.default_font = f
	t.default_font_size = 18

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)

	t.set_stylebox("normal", "Button", button_box(PANEL, LINE, 1))
	t.set_stylebox("hover", "Button", button_box(PANEL_HI, GOLD_DIM, 1))
	t.set_stylebox("pressed", "Button", button_box(Color("#0F131C"), GOLD, 1))
	t.set_stylebox("disabled", "Button", button_box(Color("#0F131C"), Color("#22283A"), 1))
	t.set_color("font_disabled_color", "Button", Color("#4A5164"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return t

static func button_box(bg: Color, border: Color, bw: int, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func panel_box(bg: Color, border: Color, radius: int = 12, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(bw)
	sb.border_color = border
	return sb
