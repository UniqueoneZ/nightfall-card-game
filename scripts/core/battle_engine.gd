class_name BattleEngine
extends RefCounted
## 纯逻辑战斗引擎：不引用任何节点/UI，可单测、可回放、可服务端复用。
##
## 用法：
##   var eng := BattleEngine.new()
##   eng.setup(deck_ids, hp, max_hp, enemy_defs, card_db, seed)
##   eng.play_card(0, "e0")
##   eng.end_turn()
##   var events := eng.take_events()      # 表现层据此播放动画

const MAX_HAND := 10
const HAND_DRAW := 5

var rng := RandomNumberGenerator.new()
var seed_value := 0
var cards: Dictionary = {}

var player: Dictionary = {}
var enemies: Array = []

var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []

var energy := 0
var max_energy := 3
var turn := 0
var phase := "idle"          # idle / player / enemy / victory / defeat
var outcome := ""
var events: Array = []
var stats := {"damage_dealt": 0, "damage_taken": 0, "cards_played": 0}

# ---------------------------------------------------------------- 初始化

func setup(deck: Array, hp: int, max_hp: int, enemy_defs: Array, card_db: Dictionary, p_seed: int = 0) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	cards = card_db
	events.clear()
	stats = {"damage_dealt": 0, "damage_taken": 0, "cards_played": 0}
	turn = 0
	outcome = ""

	player = _make_combatant("player", "旅人", hp, max_hp, true)
	enemies.clear()
	for i in enemy_defs.size():
		var d: Dictionary = enemy_defs[i]
		var e := _make_combatant("e%d" % i, str(d.get("name", "敌人")), int(d.get("hp", 10)), int(d.get("hp", 10)), false)
		e["def"] = d
		e["pattern_idx"] = 0
		e["intent"] = _intent_for(e)
		enemies.append(e)

	draw_pile = deck.duplicate()
	_shuffle(draw_pile)
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	energy = 0
	start_player_turn()

func _make_combatant(id: String, nm: String, hp: int, max_hp: int, is_player: bool) -> Dictionary:
	return {
		"id": id,
		"name": nm,
		"hp": clampi(hp, 0, max_hp),
		"max_hp": max_hp,
		"block": 0,
		"statuses": {"strength": 0, "vulnerable": 0, "weak": 0, "poison": 0},
		"is_player": is_player,
		"alive": hp > 0,
	}

# ---------------------------------------------------------------- 回合流程

func start_player_turn() -> void:
	phase = "player"
	turn += 1
	player["block"] = 0
	energy = max_energy
	_emit({"t": "turn_start", "turn": turn})
	_draw(HAND_DRAW)
	_emit({"t": "energy", "value": energy})

func end_turn() -> void:
	if phase != "player":
		return
	discard_pile.append_array(hand)
	hand.clear()
	_end_of_turn_tick(player)
	if not player["alive"]:
		_finish("defeat")
		return

	phase = "enemy"
	_emit({"t": "enemy_turn_start"})
	for e in enemies:
		if not e["alive"]:
			continue
		_enemy_act(e)
		if not player["alive"]:
			break
	if not player["alive"]:
		_finish("defeat")
		return
	if _all_enemies_dead():
		_finish("victory")
		return
	start_player_turn()

func _enemy_act(e: Dictionary) -> void:
	e["block"] = 0
	var intent: Dictionary = e["intent"]
	_emit({"t": "enemy_act", "id": e["id"], "name": e["name"], "intent": intent.duplicate(true)})

	match str(intent.get("type", "")):
		"attack":
			for i in int(intent.get("hits", 1)):
				_attack(e, player, int(intent.get("damage", 0)))
				if not player["alive"]:
					break
		"defend":
			_add_block(e, int(intent.get("block", 0)))
		"buff":
			_apply_status(e, str(intent.get("status", "strength")), int(intent.get("value", 1)))
		"debuff":
			_apply_status(player, str(intent.get("status", "weak")), int(intent.get("value", 1)))
		"attack_block":
			_attack(e, player, int(intent.get("damage", 0)))
			_add_block(e, int(intent.get("block", 0)))

	_end_of_turn_tick(e)
	e["pattern_idx"] = int(e["pattern_idx"]) + 1
	e["intent"] = _intent_for(e)
	_emit({"t": "intent", "id": e["id"], "intent": e["intent"].duplicate(true)})

# ---------------------------------------------------------------- 出牌

func can_play(hand_index: int, target_id: String = "") -> bool:
	if phase != "player":
		return false
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card := card_def(str(hand[hand_index]))
	if card.is_empty():
		return false
	if energy < int(card.get("cost", 0)):
		return false
	if str(card.get("target", "none")) == "enemy":
		var t := get_enemy(target_id)
		return not t.is_empty() and bool(t["alive"])
	return true

func play_card(hand_index: int, target_id: String = "") -> bool:
	if not can_play(hand_index, target_id):
		return false
	var cid := str(hand[hand_index])
	var card := card_def(cid)
	energy -= int(card.get("cost", 0))
	hand.remove_at(hand_index)
	stats["cards_played"] += 1
	_emit({"t": "card_played", "card": cid, "name": card.get("name", ""), "cost": int(card.get("cost", 0))})

	var target: Dictionary = player
	if str(card.get("target", "none")) == "enemy":
		target = get_enemy(target_id)

	for eff in card.get("effects", []):
		_resolve_effect(eff, target)

	if bool(card.get("exhaust", false)):
		exhaust_pile.append(cid)
		_emit({"t": "exhaust", "card": cid})
	else:
		discard_pile.append(cid)

	_emit({"t": "energy", "value": energy})
	if _all_enemies_dead():
		_finish("victory")
	return true

func _resolve_effect(eff: Dictionary, target: Dictionary) -> void:
	match str(eff.get("k", "")):
		"damage":
			for i in int(eff.get("hits", 1)):
				if not target["alive"]:
					break
				_attack(player, target, int(eff.get("v", 0)))
		"block":
			_add_block(player, int(eff.get("v", 0)))
		"draw":
			_draw(int(eff.get("v", 1)))
		"energy":
			energy += int(eff.get("v", 1))
			_emit({"t": "energy", "value": energy})
		"heal":
			_heal(player, int(eff.get("v", 0)))
		"status":
			_apply_status(target, str(eff.get("status", "")), int(eff.get("v", 0)))
		"self_status":
			_apply_status(player, str(eff.get("status", "")), int(eff.get("v", 0)))

# ---------------------------------------------------------------- 数值结算

func attack_value(src: Dictionary, base: int) -> int:
	var d := float(base) + float(src["statuses"]["strength"])
	if int(src["statuses"]["weak"]) > 0:
		d *= 0.75
	return maxi(0, int(floor(d)))

func _attack(src: Dictionary, tgt: Dictionary, base: int) -> void:
	if not tgt["alive"]:
		return
	var dmg := attack_value(src, base)
	if int(tgt["statuses"]["vulnerable"]) > 0:
		dmg = int(floor(dmg * 1.5))
	var blocked := mini(int(tgt["block"]), dmg)
	tgt["block"] = int(tgt["block"]) - blocked
	var hp_loss := dmg - blocked
	tgt["hp"] = maxi(0, int(tgt["hp"]) - hp_loss)

	if src["is_player"]:
		stats["damage_dealt"] += hp_loss
	else:
		stats["damage_taken"] += hp_loss

	_emit({"t": "damage", "target": tgt["id"], "amount": dmg, "blocked": blocked, "hp": tgt["hp"]})
	if int(tgt["hp"]) <= 0:
		tgt["alive"] = false
		_emit({"t": "death", "target": tgt["id"]})

func _heal(actor: Dictionary, amount: int) -> void:
	var before := int(actor["hp"])
	actor["hp"] = mini(int(actor["max_hp"]), before + amount)
	var healed := int(actor["hp"]) - before
	if healed > 0:
		_emit({"t": "heal", "target": actor["id"], "amount": healed, "hp": actor["hp"]})

func _add_block(actor: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	actor["block"] = int(actor["block"]) + amount
	_emit({"t": "block", "target": actor["id"], "amount": amount, "total": actor["block"]})

func _apply_status(actor: Dictionary, status: String, stacks: int) -> void:
	if status == "" or stacks == 0:
		return
	var cur := int(actor["statuses"].get(status, 0))
	actor["statuses"][status] = maxi(0, cur + stacks)
	_emit({"t": "status", "target": actor["id"], "status": status, "value": actor["statuses"][status], "delta": stacks})

func _end_of_turn_tick(actor: Dictionary) -> void:
	var poison := int(actor["statuses"]["poison"])
	if poison > 0:
		actor["hp"] = maxi(0, int(actor["hp"]) - poison)
		actor["statuses"]["poison"] = poison - 1
		_emit({"t": "damage", "target": actor["id"], "amount": poison, "blocked": 0, "hp": actor["hp"], "source": "poison"})
		if int(actor["hp"]) <= 0:
			actor["alive"] = false
			_emit({"t": "death", "target": actor["id"]})
	for s in ["weak", "vulnerable"]:
		if int(actor["statuses"][s]) > 0:
			actor["statuses"][s] = int(actor["statuses"][s]) - 1
			_emit({"t": "status", "target": actor["id"], "status": s, "value": actor["statuses"][s], "delta": -1})

# ---------------------------------------------------------------- 牌堆

func _draw(n: int) -> void:
	for i in n:
		if hand.size() >= MAX_HAND:
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				_emit({"t": "draw_fail"})
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle(draw_pile)
			_emit({"t": "reshuffle", "count": draw_pile.size()})
		var cid := str(draw_pile.pop_back())
		hand.append(cid)
		_emit({"t": "draw", "card": cid})

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# ---------------------------------------------------------------- 查询

func card_def(id: String) -> Dictionary:
	return cards.get(id, {})

func get_enemy(id: String) -> Dictionary:
	for e in enemies:
		if str(e["id"]) == id:
			return e
	return {}

func living_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if bool(e["alive"]):
			out.append(e)
	return out

func _all_enemies_dead() -> bool:
	for e in enemies:
		if bool(e["alive"]):
			return false
	return true

func _intent_for(e: Dictionary) -> Dictionary:
	var d: Dictionary = e["def"]
	var moves: Array = d.get("moves", [])
	if moves.is_empty():
		return {"type": "wait", "name": "静观"}
	var pattern: Array = d.get("pattern", [])
	var idx := 0
	if not pattern.is_empty():
		idx = int(pattern[int(e["pattern_idx"]) % pattern.size()])
	idx = clampi(idx, 0, moves.size() - 1)
	var it: Dictionary = moves[idx].duplicate(true)
	it["move_index"] = idx
	if str(it.get("type", "")) in ["attack", "attack_block"]:
		it["preview"] = attack_value(e, int(it.get("damage", 0)))
	return it

# ---------------------------------------------------------------- 事件

func _emit(ev: Dictionary) -> void:
	events.append(ev)

func take_events() -> Array:
	var out := events
	events = []
	return out

func _finish(result: String) -> void:
	if phase == "victory" or phase == "defeat":
		return
	phase = result
	outcome = result
	_emit({"t": result})
