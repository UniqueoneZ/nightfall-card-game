extends SceneTree
## 双人合作规则测试
## 运行: Godot --headless --path . --script res://tests/test_coop.gd

const DatabaseScript := preload("res://scripts/data/database.gd")

var _db
var _passed := 0
var _failed := 0

func _initialize() -> void:
	_db = DatabaseScript.new()
	_db.reload()
	_test_initial()
	_test_ally_block()
	_test_ally_strength()
	_test_coop_bonus()
	_test_boss_targets_threat()
	_test_aoe_hits_both()
	_test_down_and_revive()
	_test_card_revive()
	_test_defeat_when_all_down()
	_test_victory()
	_test_thorns()
	_test_retain()
	_test_damage_by_block()
	_test_card_pool()
	_test_ready_gate()
	_test_stage_reward()
	_test_fuzz()
	print("\n===== %d passed, %d failed =====" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

# ------------------------------------------------------------ 用例

func _test_initial() -> void:
	var e := _engine()
	_check("开局回合为 1", e.round == 1)
	_check("两名玩家", e.players.size() == 2)
	_check("每人抽 5 张", e.players[0]["hand"].size() == 5 and e.players[1]["hand"].size() == 5)
	_check("每人 3 点能量", int(e.players[0]["energy"]) == 3 and int(e.players[1]["energy"]) == 3)
	_check("Boss 150 血", int(e.boss["hp"]) == 150)

func _test_ally_block() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	e.players[1]["hand"] = ["cover"]
	e.players[1]["energy"] = 3
	_check("掩护可对队友打出", e.play_card(1, 0, "p0"))
	_check("队友获得 8 格挡", int(e.players[0]["block"]) == 8)
	_check("自己没拿到格挡", int(e.players[1]["block"]) == 0)

func _test_ally_strength() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	e.players[0]["hand"] = ["rally"]
	e.players[0]["energy"] = 3
	e.play_card(0, 0, "p1")
	_check("鼓舞给队友 +2 力量", int(e.players[1]["statuses"]["strength"]) == 2)
	_check("自己力量不变", int(e.players[0]["statuses"]["strength"]) == 0)

func _test_coop_bonus() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	e.players[0]["hand"] = ["strike"]
	e.players[1]["hand"] = ["strike"]
	e.players[0]["energy"] = 3
	e.players[1]["energy"] = 3
	e.play_card(0, 0, "")
	var after_first := 150 - int(e.boss["hp"])
	e.play_card(1, 0, "")
	var after_second := 150 - int(e.boss["hp"])
	_check("第一击 6 点", after_first == 6)
	_check("第二击含协同 +3，共 9 点", after_second - after_first == 9)
	_check("统计记录合击", int(e.stats["coop_hits"]) == 1)

func _test_boss_targets_threat() -> void:
	var e := _engine()
	e.players[0]["hand"] = ["fireball"]
	e.players[0]["energy"] = 3
	e.play_card(0, 0, "")
	e.boss["intent"] = {"type": "attack", "damage": 9, "preview": 9}
	e.boss["target"] = "p0"
	var hp0 := int(e.players[0]["hp"])
	var hp1 := int(e.players[1]["hp"])
	# 重新生成意图，应朝威胁更高的 p0
	e.boss["pattern_idx"] = 0
	e.end_round()
	_check("Boss 打向威胁更高的玩家", int(e.players[0]["hp"]) < hp0 or int(e.players[1]["hp"]) == hp1)

func _test_aoe_hits_both() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "aoe", "damage": 7, "preview": 7}
	var hp0 := int(e.players[0]["hp"])
	var hp1 := int(e.players[1]["hp"])
	e.end_round()
	_check("横扫同时命中两人", int(e.players[0]["hp"]) == hp0 - 7 and int(e.players[1]["hp"]) == hp1 - 7)

func _test_down_and_revive() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	e.players[0]["hp"] = 1
	e._attack(e.boss, e.players[0], 50)
	_check("生命归零进入倒地", bool(e.players[0]["downed"]))
	var r0 := int(e.round)
	e.end_round()
	_check("倒地后跳过其回合", int(e.players[0]["hp"]) == 0)
	e.end_round()
	e.end_round()
	_check("若干回合后自动复活", not bool(e.players[0]["downed"]) and int(e.players[0]["hp"]) > 0)
	_check("回合在推进", int(e.round) > r0)

func _test_card_revive() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	e._down(e.players[1])
	e.players[0]["hand"] = ["revive_call"]
	e.players[0]["energy"] = 3
	_check("复苏可对倒下的队友使用", e.play_card(0, 0, "p1"))
	_check("队友被救起并回血", not bool(e.players[1]["downed"]) and int(e.players[1]["hp"]) == 18)

func _test_defeat_when_all_down() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	e._down(e.players[0])
	e._down(e.players[1])
	e.end_round()
	_check("两人都倒下判负", e.phase == "defeat")

func _test_victory() -> void:
	var e := _engine()
	e.boss["hp"] = 5
	e.players[0]["hand"] = ["strike"]
	e.players[0]["energy"] = 3
	e.play_card(0, 0, "")
	_check("击杀 Boss 判胜", e.phase == "victory")

func _test_thorns() -> void:
	var e := _engine()
	e.players[0]["statuses"]["thorns"] = 4
	e.boss["intent"] = {"type": "attack", "damage": 9, "preview": 9}
	var boss_hp := int(e.boss["hp"])
	e.end_round()
	_check("反击对攻击者造成 4 点伤害", int(e.boss["hp"]) == boss_hp - 4)

func _test_retain() -> void:
	var e := _engine()
	e.players[0]["statuses"]["retain"] = 1
	e.players[0]["block"] = 10
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	e.end_round()
	_check("壁垒保留一半格挡(5)", int(e.players[0]["block"]) == 5)

func _test_damage_by_block() -> void:
	var e := _engine()
	e.players[0]["hand"] = ["g_bash"]
	e.players[0]["energy"] = 3
	e.players[0]["block"] = 12
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	var hp := int(e.boss["hp"])
	e.play_card(0, 0, "")
	_check("盾击按格挡 12 点结算", hp - int(e.boss["hp"]) == 12)

func _test_card_pool() -> void:
	var oath := 0
	for id in _db.cards:
		var c: Dictionary = _db.cards[id]
		if str(id).ends_with("+"):
			continue
		if str(c.get("class", "")) == "oathbound":
			oath += 1
			_check("卡 %s 字段完整" % id, c.has("cost") and c.has("type") and c.has("effects"))
	_check("守誓者共 54 张", oath == 54)

func _test_ready_gate() -> void:
	var e := _engine()
	e.boss["intent"] = {"type": "wait", "name": "静观"}
	var r0 := int(e.round)
	e.set_ready(0)
	_check("只有一人准备时不结束回合", int(e.round) == r0 and e.phase == "player")
	e.set_ready(1)
	_check("两人都准备才进入下一回合", int(e.round) == r0 + 1)

func _test_stage_reward() -> void:
	var e := _engine()
	e.boss_defs = [ _db.enemy("warden"), _db.enemy("warden2") ]
	e.stage_count = 2
	e.boss = e._make_boss(e.boss_defs[0])
	e.boss["hp"] = 5
	e.players[0]["hand"] = ["g_strike"]
	e.players[0]["energy"] = 3
	e.play_card(0, 0, "")
	_check("击败第一关进入奖励阶段", e.phase == "reward")
	_check("每人都发 3 张备选", e.reward_options[0].size() == 3 and e.reward_options[1].size() == 3)
	var c0 := str(e.reward_options[0][0])
	var c1 := str(e.reward_options[1][0])
	e.pick_reward(0, c0)
	_check("一人选完仍在奖励阶段", e.phase == "reward")
	e.pick_reward(1, c1)
	_check("两人选完进入第 2 关", e.stage == 1 and e.phase == "player")
	_check("新 Boss 已就位", str(e.boss["name"]) == str(_db.enemy("warden2")["name"]))

func _test_fuzz() -> void:
	for seed in range(12):
		var e := _engine(seed)
		var guard := 0
		while e.phase == "player" and guard < 300:
			guard += 1
			var acted := false
			for pi in [0, 1]:
				var p = e.players[pi]
				if p["downed"]:
					continue
				for i in range(p["hand"].size() - 1, -1, -1):
					var tid := "p1" if pi == 0 else "p0"
					if e.can_play(pi, i, tid):
						e.play_card(pi, i, tid)
						acted = true
						break
			if not acted:
				e.end_round()
		_check("seed %d 战斗正常结束" % seed, e.phase in ["victory", "defeat"])

# ------------------------------------------------------------ 工具

func _engine(seed: int = 7) -> CoopEngine:
	var decks := [
		["strike", "strike", "strike", "defend", "defend", "cover", "heavy_blow", "iron_wall"],
		["strike", "strike", "defend", "flurry", "fireball", "cover", "revive_call", "insight"],
	]
	var e := CoopEngine.new()
	e.setup(_db.cards, decks, _db.enemy("warden"), seed)
	return e

func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)
