extends Control
## 战斗场景：把 BattleEngine 的事件流翻译成动画与界面。

const HAND_X := 370.0
const HAND_W := 780.0
const HAND_Y := 632.0
const DEFAULT_HINT := "点击卡牌出牌 · 右键取消选择 · 空格结束回合"

var engine: BattleEngine
var bg: ArenaBackground
var units_layer: Control
var hand_layer: Control
var fx_layer: Control
var player_view: PlayerView
var floor_label: Label
var turn_label: Label
var pile_label: Label
var title_wm: Label
var end_button: Button
var hint_label: Label
var overlay: Control

var units: Dictionary = {}
var cards: Array = []
var busy := false
var targeting := -1
var shot_mode := false
var auto_mode := false
var auto_all := false
var enc_index := 0

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	shot_mode = args.has("--shot")
	auto_mode = args.has("--auto") or args.has("--autoall")
	auto_all = args.has("--autoall")
	for a in args:
		if a.begins_with("--enc="):
			enc_index = int(a.substr(6))
	_build()
	Game.ensure_run()
	_start_battle()
	if shot_mode:
		_run_shot()
	elif auto_mode:
		_run_auto()

# ---------------------------------------------------------------- 构建

func _build() -> void:
	bg = ArenaBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	add_child(_make_vignette())

	units_layer = _make_layer(1)
	hand_layer = _make_layer(5)
	fx_layer = _make_layer(900)

	player_view = PlayerView.new()
	player_view.position = Vector2(36, 512)
	add_child(player_view)

	floor_label = _make_label("", 17, UITheme.GOLD)
	floor_label.position = Vector2(40, 22)
	floor_label.size = Vector2(700, 28)
	add_child(floor_label)

	turn_label = _make_label("", 17, UITheme.TEXT_DIM)
	turn_label.position = Vector2(620, 22)
	turn_label.size = Vector2(200, 28)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(turn_label)

	pile_label = _make_label("", 15, UITheme.TEXT_DIM)
	pile_label.position = Vector2(900, 22)
	pile_label.size = Vector2(500, 28)
	pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(pile_label)

	title_wm = _make_label("", 30, Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.07))
	title_wm.position = Vector2(0, 66)
	title_wm.size = Vector2(1440, 44)
	title_wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_wm)

	var line := ColorRect.new()
	line.color = Color(0.18, 0.21, 0.28, 0.6)
	line.position = Vector2(36, 60)
	line.size = Vector2(1368, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	end_button = Button.new()
	end_button.text = "结束回合"
	end_button.position = Vector2(1176, 772)
	end_button.size = Vector2(224, 68)
	end_button.add_theme_font_size_override("font_size", 19)
	end_button.pressed.connect(_on_end_turn)
	add_child(end_button)

	hint_label = _make_label(DEFAULT_HINT, 13, Color(0.42, 0.46, 0.54))
	hint_label.position = Vector2(390, 870)
	hint_label.size = Vector2(680, 20)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint_label)

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
	rect.color = Color(1, 1, 1, 1)
	return rect

func _make_layer(z: int) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = z
	add_child(c)
	return c

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---------------------------------------------------------------- 战斗装载

func _start_battle() -> void:
	engine = Game.create_battle()
	busy = false
	targeting = -1
	hint_label.text = DEFAULT_HINT
	_close_overlay()
	for c in units_layer.get_children():
		c.queue_free()
	for c in hand_layer.get_children():
		c.queue_free()
	units.clear()
	cards.clear()
	_spawn_units()
	_refresh()

func _spawn_units() -> void:
	var n := engine.enemies.size()
	var spacing := 250.0
	var total := spacing * float(n - 1) + UnitView.W
	var start_x := 720.0 - total * 0.5
	for i in n:
		var e: Dictionary = engine.enemies[i]
		var v := UnitView.new()
		v.position = Vector2(start_x + i * spacing, 136)
		units_layer.add_child(v)
		v.configure(e)
		v.clicked.connect(_on_unit_clicked)
		units[str(e["id"])] = v

func _refresh() -> void:
	floor_label.text = "第 %d / %d 层    %s" % [
		Game.floor_idx + 1, Game.map.size(), RunMap.type_label(Game.node_type())
	]
	title_wm.text = RunMap.type_label(Game.node_type())
	turn_label.text = "回合 %d" % engine.turn
	pile_label.text = "抽牌堆 %d      弃牌堆 %d      消耗 %d" % [
		engine.draw_pile.size(), engine.discard_pile.size(), engine.exhaust_pile.size()
	]
	player_view.configure(engine.player, engine.energy, engine.max_energy)

	for id in units.keys():
		var v: UnitView = units[id]
		var e := engine.get_enemy(str(id))
		if not e.is_empty():
			v.configure(e)
			v.targeted = targeting >= 0 and bool(e["alive"])

	_rebuild_hand()
	end_button.disabled = engine.phase != "player" or busy

func _rebuild_hand() -> void:
	for c in cards:
		if is_instance_valid(c):
			c.queue_free()
	cards.clear()
	var n := engine.hand.size()
	if n == 0:
		return
	var spacing := 122.0
	if n > 1:
		spacing = minf(122.0, (HAND_W - CardView.W) / float(n - 1))
	var total := spacing * float(n - 1) + CardView.W
	var start_x := HAND_X + (HAND_W - total) * 0.5
	var tid := _first_alive_id()
	for i in n:
		var def := engine.card_def(str(engine.hand[i]))
		var v := CardView.new()
		hand_layer.add_child(v)
		v.configure(def, i, engine.can_play(i, tid))
		var arc := float(i) - float(n - 1) * 0.5
		v.pivot_offset = Vector2(CardView.W * 0.5, CardView.H)
		v.rotation = deg_to_rad(clampf(arc * 1.8, -7.0, 7.0))
		v.set_home(Vector2(start_x + i * spacing, HAND_Y + absf(arc) * 6.0))
		v.card_pressed.connect(_on_card_pressed)
		cards.append(v)

# ---------------------------------------------------------------- 交互

func _on_card_pressed(idx: int) -> void:
	if busy or engine.phase != "player":
		return
	var def := engine.card_def(str(engine.hand[idx]))
	if def.is_empty():
		return
	var alive := engine.living_enemies()
	if str(def.get("target", "none")) == "enemy" and alive.size() > 1:
		_set_targeting(idx)
		return
	_play(idx, "" if alive.is_empty() else str(alive[0]["id"]))

func _set_targeting(idx: int) -> void:
	targeting = idx
	for id in units.keys():
		var e := engine.get_enemy(str(id))
		units[id].targeted = not e.is_empty() and bool(e["alive"])
	hint_label.text = "选择攻击目标 · 右键取消"

func _cancel_targeting() -> void:
	if targeting < 0:
		return
	targeting = -1
	hint_label.text = DEFAULT_HINT
	_refresh()

func _on_unit_clicked(id: String) -> void:
	if targeting < 0 or busy:
		return
	var idx := targeting
	targeting = -1
	hint_label.text = DEFAULT_HINT
	_play(idx, id)

func _play(idx: int, tid: String) -> void:
	if busy or engine.phase != "player":
		return
	if not engine.play_card(idx, tid):
		_nudge_player()
		return
	busy = true
	targeting = -1
	end_button.disabled = true
	var evs := engine.take_events()
	_rebuild_hand()
	await _animate(evs)
	busy = false
	_refresh()
	_check_outcome()

func _on_end_turn() -> void:
	if busy or engine.phase != "player":
		return
	busy = true
	targeting = -1
	end_button.disabled = true
	engine.end_turn()
	var evs := engine.take_events()
	_rebuild_hand()
	await _animate(evs)
	busy = false
	_refresh()
	_check_outcome()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_targeting()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_end_turn()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_cancel_targeting()

# ---------------------------------------------------------------- 演出

func _animate(evs: Array) -> void:
	for ev in evs:
		match str(ev.get("t", "")):
			"damage":
				var pos := _anchor_of(str(ev.get("target", "")))
				var col := UITheme.BLOOD
				if str(ev.get("source", "")) == "poison":
					col = Color("#6FBF73")
				_float_text(pos + Vector2(randf_range(-16, 16), 0), "-%d" % int(ev.get("amount", 0)), col, 26)
				var v: UnitView = units.get(str(ev.get("target", "")))
				if v != null:
					v.flash()
				else:
					_nudge_player(10.0)
				if int(ev.get("blocked", 0)) > 0:
					_float_text(pos + Vector2(46, -22), "格挡 %d" % int(ev.get("blocked", 0)), UITheme.JADE, 14)
				await _wait(0.20)
			"heal":
				_float_text(_anchor_of("player"), "+%d" % int(ev.get("amount", 0)), Color("#7FD69A"), 24)
				await _wait(0.18)
			"block":
				_float_text(_anchor_of(str(ev.get("target", ""))) + Vector2(-44, -12),
					"+%d 格挡" % int(ev.get("amount", 0)), UITheme.JADE, 14)
				await _wait(0.10)
			"enemy_act":
				var v2: UnitView = units.get(str(ev.get("id", "")))
				if v2 != null:
					_float_text(v2.position + Vector2(UnitView.W * 0.5, -4),
						str(ev.get("intent", {}).get("name", "")), UITheme.GOLD, 14)
				await _wait(0.28)
			"card_played":
				await _wait(0.10)
			_:
				pass

func _anchor_of(id: String) -> Vector2:
	if id == "player":
		return player_view.position + Vector2(56, 60)
	var v: UnitView = units.get(id)
	if v != null:
		return v.position + Vector2(UnitView.W * 0.5, 152)
	return Vector2(720, 300)

func _float_text(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(180, 34)
	l.position = pos - Vector2(90, 17)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 56.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.30)
	tw.finished.connect(l.queue_free)

func _nudge_player(amount: float = 6.0) -> void:
	var tw := create_tween()
	var x := player_view.position.x
	tw.tween_property(player_view, "position:x", x - amount, 0.05)
	tw.tween_property(player_view, "position:x", x + amount, 0.09)
	tw.tween_property(player_view, "position:x", x, 0.06)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

# ---------------------------------------------------------------- 结算

func _check_outcome() -> void:
	if engine.phase == "victory":
		await _wait(0.7)
		_on_victory()
	elif engine.phase == "defeat":
		await _wait(0.7)
		_on_defeat()

func _on_victory() -> void:
	var st := engine.stats
	var sub := "造成 %d 点伤害 · 打出 %d 张牌" % [int(st["damage_dealt"]), int(st["cards_played"])]
	if engine.phase == "victory":
		Game.hp = int(engine.player["hp"])
		Game.mark_visited()
		Game.gold += 25 + maxi(Game.floor_idx, 0) * 5
		var boss := Game.node_type() == "boss"
		if boss:
			_show_overlay("黎明之前", "%s\n\n你击败了无光之王。" % sub, "再来一局", _restart)
		else:
			_show_overlay("战斗胜利", "%s\n\n+%d 金币" % [sub, 25 + maxi(Game.floor_idx, 0) * 5], "返回地图", _back_to_map)

func _on_defeat() -> void:
	_show_overlay("你倒下了", "夜色合拢。\n但牌局从来不止一次。", "再试一次", _restart)

func _back_to_map() -> void:
	_close_overlay()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _restart() -> void:
	_close_overlay()
	Game.new_run(0)
	get_tree().change_scene_to_file("res://scenes/map.tscn")

# ---------------------------------------------------------------- 遮罩层

func _show_overlay(title: String, sub: String, btn_text: String, cb: Callable) -> void:
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
	panel.size = Vector2(560, 308)
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
	b.text = btn_text
	b.position = Vector2(180, 214)
	b.size = Vector2(200, 56)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func() -> void: cb.call())
	panel.add_child(b)

	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.25)

func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

# ---------------------------------------------------------------- 工具

func _first_alive_id() -> String:
	var alive := engine.living_enemies()
	return "" if alive.is_empty() else str(alive[0]["id"])

# ---------------------------------------------------------------- 截图自检

func _run_shot() -> void:
	await _wait(1.0)
	var played := false
	for i in engine.hand.size():
		var def := engine.card_def(str(engine.hand[i]))
		if str(def.get("type", "")) == "attack" and engine.can_play(i, _first_alive_id()):
			_play(i, _first_alive_id())
			played = true
			break
	await _wait(1.8)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://shot.png")
		img.save_png(path)
		print("SHOT_SAVED: ", path, " played=", played)
	get_tree().quit()

# ---------------------------------------------------------------- 自动演示

func _run_auto() -> void:
	await _wait(0.6)
	if auto_all:
		var battles := 0
		while battles < 6 and engine.phase == "player":
			battles += 1
			await _autoplay_battle()
			print("AUTO: 第 %d 场结束 phase=%s turns=%d hp=%d" % [
				Game.floor_idx + 1, engine.phase, engine.turn, int(engine.player["hp"])])
			if engine.phase != "victory":
				break
			if true:
				break
			await _wait(0.6)
			_back_to_map()
			await _wait(0.4)
	else:
		await _autoplay_battle()
		print("AUTO: 战斗结束 phase=", engine.phase, " turns=", engine.turn)

	await _wait(1.2)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://shot_auto.png")
		img.save_png(path)
		print("AUTO_SAVED: ", path, " phase=", engine.phase, " turns=", engine.turn)
	get_tree().quit()

func _autoplay_battle() -> void:
	var guard := 0
	while guard < 200 and engine.phase == "player":
		guard += 1
		var idx := -1
		for i in engine.hand.size():
			if engine.can_play(i, _first_alive_id()):
				idx = i
				break
		if idx >= 0:
			_play(idx, _first_alive_id())
		else:
			_on_end_turn()
		await _wait(0.85)
		while busy:
			await _wait(0.1)
