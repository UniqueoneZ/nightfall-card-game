class_name CoopEngine
extends RefCounted
## 双人合作 PVE：共享回合、双人分摊伤害、倒下与复活、合击加成。
## 同样是不依赖节点的纯逻辑，可直接单测，也可搬到服务端做联机权威结算。

const HAND_SIZE := 5
const MAX_HAND := 8
const ENERGY := 3
const COOP_BONUS := 3          # 同一回合两人都攻击 Boss 时的协同伤害
const REVIVE_ROUNDS := 2       # 倒下后经过多少回合自动复活
const PLAYER_HP := 60

var rng := RandomNumberGenerator.new()
var cards: Dictionary = {}

var players: Array = []
var boss: Dictionary = {}
var events: Array = []

var round := 0
var stage := 0
var stage_count := 1
var boss_defs: Array = []
var phase := "idle"            # player / boss / reward / victory / defeat
var ready_flags := [false, false]
var reward_options := [[], []]
var reward_picks := ["", ""]
var stats := {"damage": 0, "cards_played": 0, "coop_hits": 0}

# ---------------------------------------------------------------- 初始化

func setup(card_db: Dictionary, decks: Array, boss_def: Dictionary, p_seed: int = 0) -> void:
	setup_stages(card_db, decks, [boss_def], p_seed)

func setup_stages(card_db: Dictionary, decks: Array, p_boss_defs: Array, p_seed: int = 0) -> void:
	cards = card_db
	rng.seed = p_seed
	events.clear()
	players.clear()
	round = 0
	phase = "player"
	stats = {"damage": 0, "cards_played": 0, "coop_hits": 0}

	var names := ["守誓者", "影刃"]
	for i in decks.size():
		players.append(_make_player("p%d" % i, names[i % names.size()], PLAYER_HP, decks[i].duplicate()))
		_shuffle(players[i]["draw"])

	boss_defs = p_boss_defs
	stage = 0
	stage_count = p_boss_defs.size()
	boss = _make_boss(p_boss_defs[0])
	ready_flags = [false, false]
	start_round()

func _make_boss(d: Dictionary) -> Dictionary:
	var b := {
		"id": "boss",
		"name": str(d.get("name", "深渊守卫")),
		"hp": int(d.get("hp", 120)),
		"max_hp": int(d.get("hp", 120)),
		"block": 0,
		"statuses": {"strength": 0, "vulnerable": 0, "weak": 0, "poison": 0, "burn": 0, "thorns": 0, "retain": 0},
		"def": d,
		"pattern_idx": 0,
		"alive": true,
	}
	b["intent"] = _intent_for(b)
	return b

func _make_player(id: String, nm: String, hp: int, deck: Array) -> Dictionary:
	return {
		"id": id,
		"name": nm,
		"hp": hp,
		"max_hp": hp,
		"block": 0,
		"statuses": {"strength": 0, "vulnerable": 0, "weak": 0, "poison": 0, "burn": 0, "thorns": 0, "retain": 0},
		"energy": ENERGY,
		"hand": [],
		"draw": deck,
		"discard": [],
		"downed": false,
		"revive_in": 0,
		"attacked": false,
		"attacks": 0,
		"threat": 0,
		"dmg_round": 0,
	}

# ---------------------------------------------------------------- 回合

func start_round() -> void:
	round += 1
	phase = "player"
	_emit({"t": "round_start", "round": round})
	ready_flags = [false, false]
	for p in players:
		p["threat"] = int(p["dmg_round"])
		p["dmg_round"] = 0
		if p["downed"]:
			p["revive_in"] = int(p["revive_in"]) - 1
			if int(p["revive_in"]) <= 0:
				_revive(p, int(p["max_hp"]) * 0.3)
			continue
		if int(p["statuses"]["retain"]) > 0:
			p["block"] = int(p["block"]) / 2
		else:
			p["block"] = 0
		p["energy"] = ENERGY
		p["attacked"] = false
		p["attacks"] = 0
		p["discard"].append_array(p["hand"])
		p["hand"].clear()
		_draw(p, HAND_SIZE)
	_emit({"t": "state"})

## 双人合作：必须两人都准备才结束回合
func set_ready(pi: int) -> bool:
	if phase != "player" or pi < 0 or pi >= 2:
		return false
	if players[pi]["downed"]:
		return false
	ready_flags[pi] = true
	_emit({"t": "ready", "player": "p%d" % pi, "value": true})
	if ready_flags[0] and ready_flags[1]:
		end_round()
	return true

func pick_reward(pi: int, card_id: String) -> bool:
	if phase != "reward" or pi < 0 or pi >= 2:
		return false
	if reward_picks[pi] != "":
		return false
	if not reward_options[pi].has(card_id):
		return false
	reward_picks[pi] = card_id
	players[pi]["draw"].append(card_id)
	_emit({"t": "picked", "player": "p%d" % pi, "card": card_id})
	if reward_picks[0] != "" and reward_picks[1] != "":
		_next_stage()
	return true

func _next_stage() -> void:
	stage += 1
	if stage >= stage_count:
		_finish("victory")
		return
	boss = _make_boss(boss_defs[stage])
	for p in players:
		if not p["downed"]:
			p["hp"] = mini(int(p["max_hp"]), int(p["hp"]) + 15)
	reward_options = [[], []]
	reward_picks = ["", ""]
	phase = "player"
	_emit({"t": "stage", "stage": stage})
	start_round()

func _roll_rewards() -> void:
	reward_options = [[], []]
	reward_picks = ["", ""]
	for i in 2:
		var pool := _pool_for(i)
		var picks: Array = []
		var guard := 0
		while picks.size() < 3 and guard < 200:
			guard += 1
			if pool.is_empty():
				break
			var cid := str(pool[rng.randi_range(0, pool.size() - 1)])
			if not picks.has(cid):
				picks.append(cid)
		reward_options[i] = picks
	_emit({"t": "reward", "options": reward_options})

func _pool_for(pi: int) -> Array:
	var out: Array = []
	for id in cards:
		var c: Dictionary = cards[id]
		if str(c.get("rarity", "")) == "starter":
			continue
		var cls := str(c.get("class", ""))
		if pi == 0 and cls == "oathbound":
			out.append(id)
		elif pi == 1 and cls != "oathbound":
			out.append(id)
	return out

func end_round() -> void:
	if phase != "player":
		return
	for p in players:
		p["discard"].append_array(p["hand"])
		p["hand"].clear()
		if not p["downed"]:
			_tick_player_statuses(p)

	if _all_downed():
		_finish("defeat")
		return

	phase = "boss"
	_emit({"t": "boss_turn_start"})
	boss["block"] = 0
	_boss_act()
	_tick_boss_statuses()

	if not boss["alive"]:
		_on_boss_defeated()
		return
	if _all_downed():
		_finish("defeat")
		return

	boss["pattern_idx"] = int(boss["pattern_idx"]) + 1
	boss["intent"] = _intent_for(boss)
	_emit({"t": "intent", "intent": boss["intent"].duplicate(true)})
	start_round()

func _boss_act() -> void:
	var intent: Dictionary = boss["intent"]
	_emit({"t": "boss_act", "name": intent.get("name", ""), "intent": intent.duplicate(true)})
	match str(intent.get("type", "")):
		"attack":
			var tgt := _find_player(str(intent.get("target", "")))
			if tgt.is_empty() or tgt["downed"]:
				tgt = _pick_threat_target()
			if not tgt.is_empty():
				_attack(boss, tgt, int(intent.get("damage", 0)))
		"aoe":
			for p in players:
				if not p["downed"]:
					_attack(boss, p, int(intent.get("damage", 0)))
		"debuff":
			var t2 := _pick_threat_target()
			if not t2.is_empty():
				_apply_status(t2, str(intent.get("status", "weak")), int(intent.get("value", 1)))
		"buff":
			_apply_status(boss, str(intent.get("status", "strength")), int(intent.get("value", 1)))

# ---------------------------------------------------------------- 出牌

func can_play(pi: int, hand_index: int, target_id: String = "") -> bool:
	if phase != "player":
		return false
	if pi < 0 or pi >= players.size():
		return false
	var p: Dictionary = players[pi]
	if p["downed"]:
		return false
	if hand_index < 0 or hand_index >= p["hand"].size():
		return false
	var card := card_def(str(p["hand"][hand_index]))
	if card.is_empty():
		return false
	if int(p["energy"]) < int(card.get("cost", 0)):
		return false
	match str(card.get("target", "none")):
		"enemy":
			return boss["alive"]
		"ally":
			var t := _find_player(target_id)
			return not t.is_empty()
	return true

func play_card(pi: int, hand_index: int, target_id: String = "") -> bool:
	if not can_play(pi, hand_index, target_id):
		return false
	var p: Dictionary = players[pi]
	var cid := str(p["hand"][hand_index])
	var card := card_def(cid)
	p["energy"] = int(p["energy"]) - int(card.get("cost", 0))
	p["hand"].remove_at(hand_index)
	stats["cards_played"] += 1
	_emit({"t": "card_played", "player": p["id"], "card": cid, "name": card.get("name", "")})

	var target: Dictionary = p
	match str(card.get("target", "none")):
		"enemy":
			target = boss
		"ally":
			var t := _find_player(target_id)
			if not t.is_empty():
				target = t

	# 合击：队友本回合已攻击过，且自己还没攻击
	var coop := false
	if str(card.get("type", "")) == "attack" and not bool(p["attacked"]):
		var mate := _partner(pi)
		if mate != null and bool(mate["attacked"]) and not bool(mate["downed"]):
			coop = true
			stats["coop_hits"] += 1
			_emit({"t": "coop", "player": p["id"], "amount": COOP_BONUS})
	p["attacked"] = true if str(card.get("type", "")) == "attack" else p["attacked"]

	for eff in card.get("effects", []):
		_resolve_effect(eff, p, target)

	if coop and boss["alive"]:
		_attack(p, boss, COOP_BONUS, true)

	if str(card.get("type", "")) == "attack":
		p["attacks"] = int(p.get("attacks", 0)) + 1
	p["discard"].append(cid)
	_emit({"t": "state"})

	if int(boss["hp"]) <= 0:
		_on_boss_defeated()
	return true

func _resolve_effect(eff: Dictionary, caster: Dictionary, target: Dictionary) -> void:
	match str(eff.get("k", "")):
		"damage":
			var hits := int(eff.get("hits", 1))
			for i in hits:
				if target.has("alive") and not bool(target["alive"]):
					break
				_attack(caster, target, int(eff.get("v", 0)))
		"block":
			_add_block(target, int(eff.get("v", 0)))
		"self_block":
			_add_block(caster, int(eff.get("v", 0)))
		"damage_combo":
			var per := int(eff.get("per", 2))
			var base := int(eff.get("v", 0)) + per * int(caster.get("attacks", 0))
			_attack(caster, target, base)
		"damage_by_block":
			var mult := float(eff.get("mult", 1.0))
			var add := int(eff.get("add", 0))
			for i in int(eff.get("hits", 1)):
				if target.has("alive") and not bool(target["alive"]):
					break
				var raw := int(floor(float(caster["block"]) * mult)) + add
				_attack(caster, target, raw)
		"draw":
			_draw(caster, int(eff.get("v", 1)))
		"energy":
			caster["energy"] = int(caster["energy"]) + int(eff.get("v", 1))
		"heal":
			_heal(target, int(eff.get("v", 0)))
		"self_damage":
			caster["hp"] = maxi(0, int(caster["hp"]) - int(eff.get("v", 0)))
			_emit({"t": "damage", "target": caster["id"], "amount": int(eff.get("v", 0)), "blocked": 0, "hp": caster["hp"], "source": "self"})
			if int(caster["hp"]) <= 0:
				_down(caster)
		"status":
			_apply_status(target, str(eff.get("status", "")), int(eff.get("v", 0)))
		"self_status":
			_apply_status(caster, str(eff.get("status", "")), int(eff.get("v", 0)))
		"revive":
			if bool(target["downed"]):
				_revive(target, int(eff.get("v", 15)))
			else:
				_heal(target, int(eff.get("v", 15)))

# ---------------------------------------------------------------- 数值

func attack_value(src: Dictionary, base: int) -> int:
	var d := float(base) + float(src["statuses"]["strength"])
	if int(src["statuses"]["weak"]) > 0:
		d *= 0.75
	return maxi(0, int(floor(d)))

func _attack(src: Dictionary, tgt: Dictionary, base: int, ignore_coop_bonus: bool = false) -> void:
	if tgt.has("downed") and bool(tgt["downed"]):
		return
	if tgt.has("alive") and not bool(tgt["alive"]):
		return
	var dmg := attack_value(src, base)
	if int(tgt["statuses"]["vulnerable"]) > 0:
		dmg = int(floor(dmg * 1.5))
	var blocked := mini(int(tgt["block"]), dmg)
	tgt["block"] = int(tgt["block"]) - blocked
	var hp_loss := dmg - blocked
	tgt["hp"] = maxi(0, int(tgt["hp"]) - hp_loss)

	if src.get("id", "") != "boss":
		stats["damage"] += hp_loss
		if src.has("dmg_round"):
			src["dmg_round"] = int(src["dmg_round"]) + hp_loss

	_emit({"t": "damage", "target": tgt["id"], "amount": dmg, "blocked": blocked, "hp": tgt["hp"]})

	# 反击：受到攻击时对攻击者造成伤害（无视格挡）
	var th := int(tgt["statuses"].get("thorns", 0))
	if th > 0 and str(src.get("id", "")) != str(tgt.get("id", "")) and src.has("hp"):
		src["hp"] = maxi(0, int(src["hp"]) - th)
		_emit({"t": "damage", "target": src["id"], "amount": th, "blocked": 0, "hp": src["hp"], "source": "thorns"})
		if int(src["hp"]) <= 0:
			if str(src.get("id", "")) == "boss":
				src["alive"] = false
				_emit({"t": "death", "target": "boss"})
			else:
				_down(src)

	if int(tgt["hp"]) <= 0:
		if tgt.get("id", "") == "boss":
			tgt["alive"] = false
			_emit({"t": "death", "target": "boss"})
		else:
			_down(tgt)

func _down(p: Dictionary) -> void:
	if p["downed"]:
		return
	p["downed"] = true
	p["revive_in"] = REVIVE_ROUNDS + 1
	p["block"] = 0
	p["hand"].clear()
	_emit({"t": "downed", "player": p["id"]})

func _revive(p: Dictionary, hp: int) -> void:
	p["downed"] = false
	p["revive_in"] = 0
	p["hp"] = clampi(hp, 1, int(p["max_hp"]))
	_emit({"t": "revived", "player": p["id"], "hp": p["hp"]})

func _heal(actor: Dictionary, amount: int) -> void:
	if actor.has("downed") and bool(actor["downed"]):
		return
	var before := int(actor["hp"])
	actor["hp"] = mini(int(actor["max_hp"]), before + amount)
	if int(actor["hp"]) > before:
		_emit({"t": "heal", "target": actor["id"], "amount": int(actor["hp"]) - before, "hp": actor["hp"]})

func _add_block(actor: Dictionary, amount: int) -> void:
	if amount <= 0 or (actor.has("downed") and bool(actor["downed"])):
		return
	actor["block"] = int(actor["block"]) + amount
	_emit({"t": "block", "target": actor["id"], "amount": amount, "total": actor["block"]})

func _apply_status(actor: Dictionary, status: String, stacks: int) -> void:
	if status == "" or stacks == 0:
		return
	var cur := int(actor["statuses"].get(status, 0))
	actor["statuses"][status] = maxi(0, cur + stacks)
	_emit({"t": "status", "target": actor["id"], "status": status, "value": actor["statuses"][status]})

func _tick_player_statuses(p: Dictionary) -> void:
	var burn := int(p["statuses"].get("burn", 0))
	if burn > 0:
		p["hp"] = maxi(0, int(p["hp"]) - burn)
		p["statuses"]["burn"] = burn - 1
		_emit({"t": "damage", "target": p["id"], "amount": burn, "blocked": 0, "hp": p["hp"], "source": "burn"})
		if int(p["hp"]) <= 0:
			_down(p)
	var poison := int(p["statuses"]["poison"])
	if poison > 0:
		p["hp"] = maxi(0, int(p["hp"]) - poison)
		p["statuses"]["poison"] = poison - 1
		_emit({"t": "damage", "target": p["id"], "amount": poison, "blocked": 0, "hp": p["hp"], "source": "poison"})
		if int(p["hp"]) <= 0:
			_down(p)
	for s in ["weak", "vulnerable"]:
		if int(p["statuses"][s]) > 0:
			p["statuses"][s] = int(p["statuses"][s]) - 1

func _tick_boss_statuses() -> void:
	var burn := int(boss["statuses"].get("burn", 0))
	if burn > 0:
		boss["hp"] = maxi(0, int(boss["hp"]) - burn)
		boss["statuses"]["burn"] = burn - 1
		_emit({"t": "damage", "target": "boss", "amount": burn, "blocked": 0, "hp": boss["hp"], "source": "burn"})
	var poison := int(boss["statuses"]["poison"])
	if poison > 0:
		boss["hp"] = maxi(0, int(boss["hp"]) - poison)
		boss["statuses"]["poison"] = poison - 1
		_emit({"t": "damage", "target": "boss", "amount": poison, "blocked": 0, "hp": boss["hp"], "source": "poison"})
	for s in ["weak", "vulnerable"]:
		if int(boss["statuses"][s]) > 0:
			boss["statuses"][s] = int(boss["statuses"][s]) - 1

# ---------------------------------------------------------------- 牌堆

func _draw(p: Dictionary, n: int) -> void:
	for i in n:
		if p["hand"].size() >= MAX_HAND:
			break
		if p["draw"].is_empty():
			if p["discard"].is_empty():
				break
			p["draw"] = p["discard"].duplicate()
			p["discard"].clear()
			_shuffle(p["draw"])
		p["hand"].append(p["draw"].pop_back())
	_emit({"t": "state"})

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# ---------------------------------------------------------------- 查询

func card_def(id: String) -> Dictionary:
	return cards.get(id, {})

func player(i: int) -> Dictionary:
	return players[i]

func _partner(pi: int) -> Dictionary:
	var other := 1 - pi
	if other < 0 or other >= players.size():
		return {}
	return players[other]

func _find_player(id: String) -> Dictionary:
	for p in players:
		if str(p["id"]) == id:
			return p
	return {}

func _pick_threat_target() -> Dictionary:
	var best: Dictionary = {}
	var best_v := -1
	for p in players:
		if p["downed"]:
			continue
		var v := int(p["threat"])
		if v > best_v:
			best_v = v
			best = p
	return best

func _all_downed() -> bool:
	for p in players:
		if not p["downed"]:
			return false
	return true

func _intent_for(b: Dictionary) -> Dictionary:
	var d: Dictionary = b["def"]
	var moves: Array = d.get("moves", [])
	if moves.is_empty():
		return {"type": "wait", "name": "静观"}
	var pattern: Array = d.get("pattern", [])
	var idx := 0
	if not pattern.is_empty():
		idx = int(pattern[int(b["pattern_idx"]) % pattern.size()])
	idx = clampi(idx, 0, moves.size() - 1)
	var it: Dictionary = moves[idx].duplicate(true)
	it["move_index"] = idx
	if str(it.get("type", "")) in ["attack", "aoe"]:
		it["preview"] = attack_value(b, int(it.get("damage", 0)))
		if str(it.get("type", "")) == "attack":
			var tgt := _pick_threat_target()
			it["target"] = "" if tgt.is_empty() else str(tgt["id"])
			it["target_name"] = "" if tgt.is_empty() else str(tgt["name"])
	return it

## 联机指令入口：所有会影响状态的操作都从这里走，便于广播与回放
func execute(cmd: Dictionary) -> bool:
	match str(cmd.get("type", "")):
		"play":
			return play_card(int(cmd.get("pi", 0)), int(cmd.get("hand_index", -1)), str(cmd.get("target", "")))
		"ready":
			return set_ready(int(cmd.get("pi", 0)))
		"pick":
			return pick_reward(int(cmd.get("pi", 0)), str(cmd.get("card", "")))
		"end":
			end_round()
			return true
	return false

## 存档 / 回档：联机预测时用于回滚重放
func snapshot() -> Dictionary:
	return {
		"players": players.duplicate(true),
		"boss": boss.duplicate(true),
		"round": round,
		"phase": phase,
		"stats": stats.duplicate(true),
		"rng": rng.state,
	}

func restore(s: Dictionary) -> void:
	players = s["players"].duplicate(true)
	boss = s["boss"].duplicate(true)
	round = int(s["round"])
	phase = str(s["phase"])
	stats = s["stats"].duplicate(true)
	rng.state = int(s["rng"])
	events.clear()

## 状态指纹：两端比对用，不一致说明锁步崩了
func state_hash() -> String:
	var parts: Array = ["r%d" % round, "boss:%d/%d" % [int(boss["hp"]), int(boss["block"])], phase]
	for p in players:
		parts.append("%s:%d:%d:%d:%d:%s" % [
			p["id"], int(p["hp"]), int(p["block"]), int(p["energy"]),
			p["hand"].size(), ",".join(p["hand"]),
		])
	return "|".join(parts).sha256_text().substr(0, 16)

func _on_boss_defeated() -> void:
	if stage + 1 >= stage_count:
		_finish("victory")
		return
	phase = "reward"
	boss["alive"] = false
	_roll_rewards()

func _finish(result: String) -> void:
	if phase == "victory" or phase == "defeat":
		return
	phase = result
	_emit({"t": result})

func _emit(ev: Dictionary) -> void:
	events.append(ev)

func take_events() -> Array:
	var out := events
	events = []
	return out
