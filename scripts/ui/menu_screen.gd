extends Control
## 主菜单：单人爬塔 / 双人合作

var _tw: Tween

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 深链：Web 版可用 ?mode=coop 直接进入双人合作
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and (str(q).contains("mode=coop") or str(q).contains("mode=online")):
			get_tree().change_scene_to_file.call_deferred("res://scenes/coop.tscn")
			return
	elif "--coop" in OS.get_cmdline_user_args() or _has_online_arg():
		get_tree().change_scene_to_file.call_deferred("res://scenes/coop.tscn")
		return

	var bg := ArenaBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_make_vignette())

	var title := _label("夜 蚀", 64, UITheme.GOLD)
	title.position = Vector2(0, 200)
	title.size = Vector2(1440, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := _label("N I G H T F A L L   ·   卡牌构筑 Roguelike", 16, Color(0.52, 0.56, 0.64))
	sub.position = Vector2(0, 292)
	sub.size = Vector2(1440, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var solo := _menu_button("单人爬塔", "独自深入，构筑卡组", Vector2(500, 400))
	solo.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/map.tscn"))
	add_child(solo)

	var coop := _menu_button("双人合作", "共享回合，一起打 Boss", Vector2(500, 520))
	coop.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/coop.tscn"))
	add_child(coop)

	var foot := _label("原型 v0.3 · Godot 4.5 · 双人合作：掩护队友、合击加成、倒下复活", 13,
		Color(0.34, 0.37, 0.44))
	foot.position = Vector2(0, 840)
	foot.size = Vector2(1440, 24)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)

	title.modulate.a = 0.0
	sub.modulate.a = 0.0
	solo.modulate.a = 0.0
	coop.modulate.a = 0.0
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(title, "modulate:a", 1.0, 0.6)
	_tw.tween_property(sub, "modulate:a", 1.0, 0.6).set_delay(0.15)
	_tw.tween_property(solo, "modulate:a", 1.0, 0.5).set_delay(0.3)
	_tw.tween_property(coop, "modulate:a", 1.0, 0.5).set_delay(0.4)

func _menu_button(title: String, desc: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = ""
	b.position = pos
	b.size = Vector2(440, 96)
	b.add_theme_stylebox_override("normal", UITheme.button_box(Color(0.07, 0.085, 0.12, 0.9), UITheme.LINE, 1, 14))
	b.add_theme_stylebox_override("hover", UITheme.button_box(Color(0.10, 0.12, 0.17, 0.95), UITheme.GOLD, 2, 14))
	b.add_theme_stylebox_override("pressed", UITheme.button_box(Color(0.05, 0.06, 0.09, 1.0), UITheme.GOLD, 2, 14))
	var t := _label(title, 24, UITheme.TEXT)
	t.position = Vector2(28, 18)
	t.size = Vector2(380, 34)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(t)
	var d := _label(desc, 13, Color(0.48, 0.52, 0.60))
	d.position = Vector2(28, 56)
	d.size = Vector2(380, 24)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(d)
	return b

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_vignette() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.06, 1.0));
	float v = smoothstep(0.35, 0.95, d);
	COLOR = vec4(0.0, 0.0, 0.0, v * 0.55);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	return rect

func _has_online_arg() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--online="):
			return true
	return false
