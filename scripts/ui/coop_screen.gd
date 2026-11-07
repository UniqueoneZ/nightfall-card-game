extends Control
## 双人合作 PVE 界面：共享回合、双人面板、互相掩护、倒下与复活。

const HAND_X := 360.0
const HAND_W := 720.0
const HAND_Y := 640.0
const DEFAULT_HINT := "点卡出牌 · 掩护/鼓舞类卡牌可选队友 · 空格结束回合"

const DECKS := [
	["g_strike", "g_strike", "g_strike", "g_strike", "g_guard", "g_guard", "g_guard",
	 "g_bash", "g_iron", "g_riposte", "g_bulwark", "cover"],
	["strike", "strike", "strike", "defend", "defend",
	 "cover", "rally", "flurry", "poison_blade", "fireball", "insight", "revive_call"],
]

var engine: CoopEngine
var bg: ArenaBackground
var boss_view: UnitView
var p_views: Array = []
var hotspots: Array = []
var hand_layer: Control
var fx_layer: Control
var round_label: Label
var info_label: Label
var hint_label: Label
var end_button: Button
var tab_buttons: Array = []
var overlay: Control
var title_wm: Label

var cards: Array = []
var active_idx := 0
var targeting_idx := -1
var busy := false
var shot_mode := false

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	shot_mode = args.has("--shot")
	for a in args:
		if a.begins_with("--p="):
			active_idx = clampi(int(a.substr(4)), 0, 1)
	_build()
	_start_battle()
	if shot_mode:
		_run_shot()

# ---------------------------------------------------------------- 构建

func _build() -> void:
	bg = ArenaBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_make_vignette())

	var units_layer := _make_layer(1)
	hand_layer = _make_layer(5)
	fx_layer = _make_layer(900)

	title_wm = _make_label("无光王座", 30, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.06))
	title_wm.position = Vector2(0, 44)
	title_wm.size = Vector2(1440, 40)
	title_wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_wm)

	round_label = _make_label("", 17, UITheme.GOLD)
	round_label.position = Vector2(40, 22)
	round_label.size = Vector2(600, 28)
	add_child(round_label)

	info_label = _make_label("", 14, UITheme.TEXT_DIM)
	info_label.position = Vector2(900, 22)
	info_label.size = Vector2(500, 28)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(info_label)

	var line := ColorRect.new()
	line.color = Color(0.18, 0.21, 0.28, 0.6)
	line.position = Vector2(36, 60)
	line.size = Vector2(1368, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	boss_view = UnitView.new()
	boss_view.position = Vector2(620, 96)
	units_layer.add_child(boss_view)

	for i in 2:
		var pv := PlayerView.new()
		pv.position = Vector2(24.0 if i == 0 else 1096.0, 470.0)
		add_child(pv)
		p_views.append(pv)

		var hs := Panel.new()
		hs.position = Vector2(24.0 if i == 0 else 1096.0, 470.0)
		hs.size = Vector2(PlayerView.W, PlayerView.H)
		hs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hs.visible = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(3)
		sb.border_color = UITheme.JADE
		hs.add_theme_stylebox_override("panel", sb)
		var pid := "p%d" % i
		hs.gui_input.connect(_on_hotspot_input.bind(pid))
		add_child(hs)
		hotspots.append(hs)

	for i in 2:
		var b := Button.new()
		b.text = "玩家 %d" % (i + 1)
		b.position = Vector2(360.0 + i * 120.0, 590)
		b.size = Vector2(110, 36)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_switch_player.bind(i))
		add_child(b)
		tab_buttons.append(b)

	end_button = Button.new()
	end_button.text = "结束回合"
	end_button.position = Vector2(1150, 760)
	end_button.size = Vector2(230, 64)
	end_button.add_theme_font_size_override("font_size", 19)
	end_button.pressed.connect(_on_end_round)
	add_child(end_button)

	hint_label = _make_label(DEFAULT_HINT, 13, Color(0.42, 0.46, 0.54))
	hint_label.position = Vector2(360, 862)
	hint_label.size = Vector2(720, 20)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)

func _make_layer(z: int) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = z
	add_child(c)
	return c

func _make_label(text: String, size: int, color: Color) -> Label:
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
	float v = smoothstep(0.40, 0.95, d);
	COLOR = vec4(0.0, 0.0, 0.0, v * 0.50);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	return rect

# ---------------------------------------------------------------- 战斗

func _start_battle() -> void:
	engine = CoopEngine.new()
	engine.setup(DB.cards, [DECKS[0].duplicate(), DECKS[1].duplicate()], DB.enemy("warden"), 20261107)
	active_idx = 0
	targeting_idx = -1
	busy = false
	_close_overlay()
	boss_view.configure(engine.boss)
	_refresh()

func _refresh() -> void:
	round_label.text = "双人合作 · 回合 %d" % engine.round
	info_label.text = "P1 抽牌堆 %d    P2 抽牌堆 %d" % [
		engine.players[0]["draw"].size(), engine.players[1]["draw"].size()
	]
	boss_view.configure(engine.boss)
	for i in 2:
		var p: Dictionary = engine.players[i]
		p_views[i].configure(p, int(p["energy"]), CoopEngine.ENERGY,
			bool(p["downed"]), i == active_idx and not bool(p["downed"]))
	for i in 2:
		var b: Button = tab_buttons[i]
		b.disabled = busy
		var on := i == active_idx
		b.add_theme_stylebox_override("normal",
			UITheme.button_box(Color(0.10, 0.12, 0.17, 0.95) if on else UITheme.PANEL,
				UITheme.GOLD if on else UITheme.LINE, 2 if on else 1, 8))
		b.add_theme_color_override("font_color", UITheme.GOLD if on else UITheme.TEXT_DIM)
	_rebuild_hand()
	end_button.disabled = engine.phase != "player" or busy

func _rebuild_hand() -> void:
	for c in cards:
		if is_instance_valid(c):
			c.queue_free()
	cards.clear()
	var p: Dictionary = engine.players[active_idx]
	var n: int = p["hand"].size()
	if n == 0:
		return
	var spacing := 122.0
	if n > 1:
		spacing = minf(122.0, (HAND_W - CardView.W) / float(n - 1))
	var total := spacing * float(n - 1) + CardView.W
	var start_x := HAND_X + (HAND_W - total) * 0.5
	for i in n:
		var def := engine.card_def(str(p["hand"][i]))
		var v := CardView.new()
		hand_layer.add_child(v)
		v.configure(def, i, engine.can_play(active_idx, i, _default_ally()))
		var arc := float(i) - float(n - 1) * 0.5
		v.pivot_offset = Vector2(CardView.W * 0.5, CardView.H)
		v.rotation = deg_to_rad(clampf(arc * 1.8, -7.0, 7.0))
		v.set_home(Vector2(start_x + i * spacing, HAND_Y + absf(arc) * 6.0))
		v.card_pressed.connect(_on_card_pressed)
		cards.append(v)

func _default_ally() -> String:
	return str(engine.players[1 - active_idx]["id"])

# ---------------------------------------------------------------- 交互

func _switch_player(i: int) -> void:
	if busy or engine.phase != "player":
		return
	if i == active_idx:
		return
	active_idx = i
	targeting_idx = -1
	_clear_hotspots()
	hint_label.text = DEFAULT_HINT
	_refresh()

func _on_card_pressed(idx: int) -> void:
	if busy or engine.phase != "player":
		return
	var p: Dictionary = engine.players[active_idx]
	if idx < 0 or idx >= p["hand"].size():
		return
	var def := engine.card_def(str(p["hand"][idx]))
	match str(def.get("target", "none")):
		"ally":
			_enter_ally_targeting(idx)
		"enemy":
			_play(idx, "boss")
		_:
			_play(idx, str(p["id"]))

func _enter_ally_targeting(idx: int) -> void:
	targeting_idx = idx
	hint_label.text = "选择要施加的目标玩家"
	for hs in hotspots:
		hs.visible = true
		hs.mouse_filter = Control.MOUSE_FILTER_STOP

func _clear_hotspots() -> void:
	for hs in hotspots:
		hs.visible = false
		hs.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_hotspot_input(event: InputEvent, pid: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if targeting_idx < 0 or busy:
		return
	var idx := targeting_idx
	targeting_idx = -1
	_clear_hotspots()
	hint_label.text = DEFAULT_HINT
	_play(idx, pid)

func _play(idx: int, target_id: String) -> void:
	if busy or engine.phase != "player":
		return
	if not engine.play_card(active_idx, idx, target_id):
		return
	busy = true
	end_button.disabled = true
	var evs := engine.take_events()
	_rebuild_hand()
	await _animate(evs)
	busy = false
	_refresh()
	_check_outcome()

func _on_end_round() -> void:
	if busy or engine.phase != "player":
		return
	busy = true
	targeting_idx = -1
	_clear_hotspots()
	end_button.disabled = true
	engine.end_round()
	var evs := engine.take_events()
	_rebuild_hand()
	await _animate(evs)
	busy = false
	_refresh()
	_check_outcome()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_end_round()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			_switch_player(1 - active_idx)
		elif event.keycode == KEY_ESCAPE and targeting_idx >= 0:
			targeting_idx = -1
			_clear_hotspots()
			hint_label.text = DEFAULT_HINT

# ---------------------------------------------------------------- 演出

func _animate(evs: Array) -> void:
	for ev in evs:
		match str(ev.get("t", "")):
			"damage":
				var pos := _anchor_of(str(ev.get("target", "")))
				var col := UITheme.BLOOD
				if str(ev.get("source", "")) == "poison":
					col = Color("#6FBF73")
				_float_text(pos + Vector2(randf_range(-14, 14), 0), "-%d" % int(ev.get("amount", 0)), col, 26)
				if str(ev.get("target", "")) == "boss":
					boss_view.flash()
				else:
					_nudge_panel(str(ev.get("target", "")))
				await _wait(0.18)
			"coop":
				_float_text(_anchor_of("boss") + Vector2(0, -70), "合击 +%d" % int(ev.get("amount", 0)),
					UITheme.GOLD, 22)
				await _wait(0.22)
			"block":
				_float_text(_anchor_of(str(ev.get("target", ""))) + Vector2(-40, -14),
					"+%d 格挡" % int(ev.get("amount", 0)), UITheme.JADE, 14)
				await _wait(0.10)
			"heal":
				_float_text(_anchor_of(str(ev.get("target", ""))), "+%d" % int(ev.get("amount", 0)),
					Color("#7FD69A"), 24)
				await _wait(0.16)
			"downed":
				_float_text(_anchor_of(str(ev.get("player", ""))) + Vector2(0, -40), "倒下", UITheme.BLOOD, 22)
				await _wait(0.35)
			"revived":
				_float_text(_anchor_of(str(ev.get("player", ""))) + Vector2(0, -40), "复活", Color("#7FD69A"), 22)
				await _wait(0.35)
			"boss_act":
				_float_text(boss_view.position + Vector2(UnitView.W * 0.5, 10),
					str(ev.get("name", "")), UITheme.GOLD, 15)
				await _wait(0.30)
			"card_played":
				await _wait(0.08)
			"round_start":
				await _wait(0.10)
			_:
				pass

func _anchor_of(id: String) -> Vector2:
	if id == "boss":
		return boss_view.position + Vector2(UnitView.W * 0.5, 150)
	var m := RegEx.create_from_string("p(\\d+)").search(id)
	if m != null:
		var i := int(m.get_string(1))
		if i >= 0 and i < p_views.size():
			return p_views[i].position + Vector2(PlayerView.W * 0.5, 60)
	return Vector2(720, 300)

func _nudge_panel(id: String) -> void:
	var m := RegEx.create_from_string("p(\\d+)").search(id)
	if m == null:
		return
	var i := int(m.get_string(1))
	if i < 0 or i >= p_views.size():
		return
	var pv: PlayerView = p_views[i]
	var tw := create_tween()
	var x := pv.position.x
	tw.tween_property(pv, "position:x", x - 8.0, 0.05)
	tw.tween_property(pv, "position:x", x + 8.0, 0.09)
	tw.tween_property(pv, "position:x", x, 0.06)

func _float_text(pos: Vector2, text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(180, 34)
	l.position = pos - Vector2(90, 17)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 54.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.30)
	tw.finished.connect(l.queue_free)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

# ---------------------------------------------------------------- 结算

func _check_outcome() -> void:
	if engine.phase == "victory":
		await _wait(0.7)
		_show_overlay("守卫陨落", "你们击败了双子守卫。\n造成 %d 伤害 · 合击 %d 次" % [
			int(engine.stats["damage"]), int(engine.stats["coop_hits"])], "再来一局", _start_battle)
	elif engine.phase == "defeat":
		await _wait(0.7)
		_show_overlay("双双倒下", "无光王座之下，无人应答。", "再来一局", _start_battle)

func _show_overlay(title: String, sub: String, btn: String, cb: Callable) -> void:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(440, 296)
	panel.size = Vector2(560, 300)
	panel.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.07, 0.085, 0.12, 0.98), UITheme.GOLD_DIM, 16, 2))
	overlay.add_child(panel)
	var t := _make_label(title, 34, UITheme.GOLD)
	t.position = Vector2(0, 44)
	t.size = Vector2(560, 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(t)
	var s := _make_label(sub, 15, UITheme.TEXT_DIM)
	s.position = Vector2(40, 106)
	s.size = Vector2(480, 80)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(s)
	var b := Button.new()
	b.text = btn
	b.position = Vector2(180, 210)
	b.size = Vector2(200, 56)
	b.pressed.connect(func() -> void: cb.call())
	panel.add_child(b)
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.25)

func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

# ---------------------------------------------------------------- 截图自检

func _run_shot() -> void:
	await _wait(0.9)
	# 打一张牌制造状态差异
	var p: Dictionary = engine.players[active_idx]
	for i in p["hand"].size():
		var def := engine.card_def(str(p["hand"][i]))
		if str(def.get("target", "none")) == "ally":
			_play(i, _default_ally())
			break
	await _wait(1.4)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://shot_coop.png"))
		print("SHOT_SAVED coop")
	get_tree().quit()
