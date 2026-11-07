extends Control
## 分支地图：选择下一个节点，战斗 / 精英 / 事件 / 商店 / 篝火 / Boss。

const NODE_SIZE := 82.0
const X_GAP := 250.0
const Y_GAP := 96.0
const BASE_Y := 806.0

var node_buttons: Array = []
var modal: Control = null
var hud: Label
var hint: Label

func _ready() -> void:
	theme = UITheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.ensure_run()
	Game.last_stats = {}
	_build_hud()
	_refresh()
	if Game.pending_relic:
		Game.pending_relic = false
		_show_relic_reward()

func _pos(f: int, i: int) -> Vector2:
	var w: int = Game.map[f].size()
	var x := 720.0 + (float(i) - float(w - 1) * 0.5) * X_GAP
	var y := BASE_Y - float(f) * Y_GAP
	return Vector2(x, y)

func _build_hud() -> void:
	hud = _label("", 17, UITheme.GOLD)
	hud.position = Vector2(40, 22)
	hud.size = Vector2(900, 28)
	add_child(hud)

	var back := Button.new()
	back.text = "放弃本局"
	back.position = Vector2(1250, 18)
	back.size = Vector2(150, 40)
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	add_child(back)

	hint = _label("", 13, Color(0.45, 0.49, 0.57))
	hint.position = Vector2(0, 860)
	hint.size = Vector2(1440, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

func _refresh() -> void:
	for b in node_buttons:
		if is_instance_valid(b):
			b.queue_free()
	node_buttons.clear()
	_close_modal()

	hud.text = "生命 %d/%d      金币 %d      第 %d / %d 层" % [
		Game.hp, Game.max_hp, Game.gold, maxi(Game.floor_idx, 0) + 1, Game.map.size()]
	hint.text = "点击高亮节点前进"
	Game.save_run()

	var reach: Array = Game.reachable()
	for f in Game.map.size():
		for i in Game.map[f].size():
			var node: Dictionary = Game.map[f][i]
			var p := _pos(f, i)
			var b := Button.new()
			b.size = Vector2(NODE_SIZE, NODE_SIZE)
			b.position = p - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
			b.text = RunMap.type_label(str(node["type"]))
			b.add_theme_font_size_override("font_size", 13)
			var col := RunMap.type_color(str(node["type"]))
			var active: bool = reach.has(Vector2i(f, i))
			var visited: bool = bool(node.get("visited", false))
			var bg := Color(0.08, 0.10, 0.14, 0.95 if active else 0.35)
			var border := col if active else col.darkened(0.55)
			var sb := UITheme.button_box(bg, border, 2 if active else 1, int(NODE_SIZE * 0.5))
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", UITheme.button_box(Color(0.14, 0.17, 0.24, 1), col, 3, int(NODE_SIZE * 0.5)))
			b.add_theme_color_override("font_color", col if active else col.darkened(0.45))
			b.disabled = not active
			if visited:
				b.modulate = Color(0.55, 0.6, 0.7, 0.7)
			b.pressed.connect(_on_node.bind(f, i))
			add_child(b)
			node_buttons.append(b)
	queue_redraw()

func _draw() -> void:
	var s := size
	for i in 8:
		var f := float(i) / 8.0
		draw_rect(Rect2(0, s.y * f, s.x, s.y / 8.0 + 1.0),
			UITheme.BG_DEEP.lerp(Color("#111827"), f))
	if Game.map.is_empty():
		return
	for f in Game.map.size() - 1:
		for i in Game.map[f].size():
			for j in Game.map[f + 1].size():
				if absi(i - j) > 1:
					continue
				var a := _pos(f, i)
				var b := _pos(f + 1, j)
				var reach: Array = Game.reachable()
				var on_path: bool = reach.has(Vector2i(f + 1, j)) and f == Game.floor_idx
				draw_line(a, b, Color(0.35, 0.42, 0.58, 0.55 if on_path else 0.16), 2.0 if on_path else 1.0, true)

func _on_node(f: int, i: int) -> void:
	if not Game.can_travel(f, i):
		return
	Game.travel(f, i)
	var t := Game.node_type()
	if Game.is_battle_node():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	_open_non_battle(t)

# ---------------------------------------------------------------- 非战斗节点

func _open_non_battle(t: String) -> void:
	match t:
		"rest":
			_show_rest()
		"event":
			_show_event()
		"shop":
			_show_shop()
		_:
			Game.mark_visited()
			_refresh()

func _show_rest() -> void:
	var amount := int(Game.max_hp * 0.3)
	_open_modal("篝火", "火光很暖。你可以休息，也可以磨砺一张卡牌。", [
		{"text": "休息（回复 %d 生命）" % amount, "cb": func() -> void:
			Game.heal(amount)
			Game.mark_visited()
			_refresh()},
		{"text": "升级一张卡牌", "cb": func() -> void:
			_show_upgrade()},
	])

func _show_event() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + Game.floor_idx * 31 + Game.node_idx
	var flavors := [
		"路边躺着一个破旧的旅行箱。",
		"一个无名的祭坛，石面上刻着看不懂的字。",
		"一具枯骨，手里还攥着什么东西。",
	]
	var flavor: String = str(flavors[rng.randi_range(0, 2)])
	_open_modal("事件", flavor, [
		{"text": "搜刮（+40 金币）", "cb": func() -> void:
			Game.gold += 40
			Game.mark_visited()
			_refresh()},
		{"text": "祈祷（回复 20 生命）", "cb": func() -> void:
			Game.heal(20)
			Game.mark_visited()
			_refresh()},
		{"text": "带走卡牌", "cb": func() -> void:
			var pool := ["heavy_blow", "iron_wall", "poison_blade", "sunder", "cross_slash", "elixir"]
			Game.add_card(str(pool[rng.randi_range(0, pool.size() - 1)]))
			Game.mark_visited()
			_refresh()},
	])

func _show_shop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.run_seed + Game.floor_idx * 71 + Game.node_idx
	var pool := ["heavy_blow", "iron_wall", "poison_blade", "sunder", "cross_slash", "elixir", "fireball", "empower"]
	var picks: Array = []
	while picks.size() < 3:
		var c := str(pool[rng.randi_range(0, pool.size() - 1)])
		if not picks.has(c):
			picks.append(c)
	var choices: Array = []
	for cid in picks:
		var def := DB.card(str(cid))
		choices.append({
			"text": "%s（%d 金币）" % [str(def.get("name", cid)), 50],
			"cb": func() -> void:
				if Game.gold >= 50:
					Game.gold -= 50
					Game.add_card(str(cid))
				_refresh(),
		})
	choices.append({"text": "离开", "cb": func() -> void:
		Game.mark_visited()
		_refresh()})
	_open_modal("商店", "金币 %d" % Game.gold, choices)

# ---------------------------------------------------------------- 模态框

func _show_upgrade() -> void:
	var uniq: Array = []
	for c in Game.deck:
		var id := str(c)
		if id.ends_with("+") or not DB.cards.has(id + "+"):
			continue
		if not uniq.has(id):
			uniq.append(id)
	if uniq.is_empty():
		_open_modal("篝火", "牌组里已经没有可升级的卡了。", [
			{"text": "返回", "cb": func() -> void: _refresh()}])
		return
	_close_modal()
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 100
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(300, 140)
	panel.size = Vector2(840, 560)
	panel.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.07, 0.085, 0.12, 0.98), UITheme.GOLD_DIM, 16, 2))
	modal.add_child(panel)
	var t := _label("升级一张卡牌", 26, UITheme.GOLD)
	t.position = Vector2(0, 24)
	t.size = Vector2(840, 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(t)
	var cols := 3
	for i in uniq.size():
		var id := str(uniq[i])
		var base := DB.card(id)
		var up := DB.card(id + "+")
		var b := Button.new()
		b.size = Vector2(250, 64)
		b.position = Vector2(30 + (i % cols) * 262, 84 + (i / cols) * 76)
		b.text = "%s\n%s" % [str(base.get("name", id)), str(up.get("desc", ""))]
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func() -> void:
			var idx := Game.deck.find(id)
			if idx >= 0:
				Game.deck[idx] = id + "+"
			Game.mark_visited()
			_refresh())
		panel.add_child(b)

func _show_relic_reward() -> void:
	var choices: Array = Game.roll_relic_choices(Game.run_seed + Game.floor_idx * 977 + Game.battles_won)
	var btns: Array = []
	for id in choices:
		var d := Relics.get_def(str(id))
		btns.append({"text": "%s · %s" % [str(d.get("name", id)), str(d.get("desc", ""))],
			"cb": func() -> void:
				Game.add_relic(str(id))
				_refresh()})
	if btns.is_empty():
		_refresh()
		return
	_open_modal("获得遗物", "精英的遗物。选一件带走。", btns)

func _open_modal(title: String, body: String, choices: Array) -> void:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 100
	add_child(modal)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(440, 250)
	panel.size = Vector2(560, 380)
	panel.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.07, 0.085, 0.12, 0.98), UITheme.GOLD_DIM, 16, 2))
	modal.add_child(panel)

	var t := _label(title, 28, UITheme.GOLD)
	t.position = Vector2(0, 30)
	t.size = Vector2(560, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(t)

	var b := _label(body, 15, UITheme.TEXT_DIM)
	b.position = Vector2(40, 84)
	b.size = Vector2(480, 60)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(b)

	var y := 170.0
	for c in choices:
		var btn := Button.new()
		btn.text = str(c["text"])
		btn.position = Vector2(140, y)
		btn.size = Vector2(280, 48)
		btn.add_theme_font_size_override("font_size", 15)
		var cb: Callable = c["cb"]
		btn.pressed.connect(func() -> void: cb.call())
		panel.add_child(btn)
		y += 58.0

func _close_modal() -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
