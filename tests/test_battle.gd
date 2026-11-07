extends SceneTree
## 无头规则回归测试
## 运行: Godot --headless --path Nightfall --script res://tests/test_battle.gd

const DatabaseScript := preload("res://scripts/data/database.gd")

var _db
var _passed := 0
var _failed := 0

func _initialize() -> void:
	_db = DatabaseScript.new()
	_db.reload()
	if _db.cards.is_empty():
		push_error("数据库加载失败: %s" % _db.load_error)
		quit(1)
		return

	_test_initial_state()
	_test_strike_damage()
	_test_block_absorbs()
	_test_energy_gate()
	_test_vulnerable()
	_test_strength_and_weak()
	_test_draw_and_reshuffle()
	_test_enemy_turn_and_intent()
	_test_poison()
	_test_victory()
	_test_deck_average()

	print("\n===== %d passed, %d failed =====" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

# ------------------------------------------------------------ 用例

func _test_initial_state() -> void:
	var e := _engine(["goblin"])
	_check("开局回合为 1", e.turn == 1)
	_check("开局抽 5 张", e.hand.size() == 5)
	_check("开局能量 3", e.energy == 3)
	_check("牌堆总数守恒", e.hand.size() + e.draw_pile.size() + e.discard_pile.size() == 5)
	_check("玩家满血 80", e.player["hp"] == 80)

func _test_strike_damage() -> void:
	var e := _engine(["goblin"])
	e.hand = ["strike"]
	e.energy = 3
	var before: int = e.enemies[0]["hp"]
	_check("打击可打出", e.play_card(0, "e0"))
	_check("打击造成 6 点伤害", before - int(e.enemies[0]["hp"]) == 6)
	_check("出牌后进入弃牌堆", e.discard_pile.has("strike"))
	_check("出牌后手牌清空", e.hand.is_empty())
	_check("能量扣 1", e.energy == 2)

func _test_block_absorbs() -> void:
	var e := _engine(["goblin"])
	e.enemies[0]["hp"] = 100
	e.enemies[0]["intent"] = {"type": "attack", "damage": 8}
	e.hand = ["defend"]
	e.energy = 3
	e.play_card(0)
	_check("防御给 5 格挡", int(e.player["block"]) == 5)
	e.end_turn()
	_check("格挡吸收 5 点，只掉 3 血", int(e.player["hp"]) == 77)
	_check("格挡被消耗完", int(e.player["block"]) == 0)

func _test_energy_gate() -> void:
	var e := _engine(["goblin"])
	e.hand = ["fireball"]
	e.energy = 1
	_check("能量不足不能出牌", not e.play_card(0, "e0"))
	_check("失败出牌不扣能量", e.energy == 1)
	_check("失败出牌保留手牌", e.hand.size() == 1)

func _test_vulnerable() -> void:
	var e := _engine(["goblin"])
	e.enemies[0]["statuses"]["vulnerable"] = 1
	e.hand = ["strike"]
	e.energy = 3
	var before: int = e.enemies[0]["hp"]
	e.play_card(0, "e0")
	_check("易伤使 6 点伤害变 9 点", before - int(e.enemies[0]["hp"]) == 9)

func _test_strength_and_weak() -> void:
	var e := _engine(["goblin"])
	e.player["statuses"]["strength"] = 2
	_check("力量 +2 后打击为 8", e.attack_value(e.player, 6) == 8)
	e.player["statuses"]["weak"] = 1
	_check("虚弱使 8 点降为 6", e.attack_value(e.player, 6) == 6)
	e.player["statuses"]["strength"] = 0
	e.player["statuses"]["weak"] = 0

func _test_draw_and_reshuffle() -> void:
	var e := _engine(["goblin"])
	e.hand.clear()
	e.draw_pile = ["strike"]
	e.discard_pile = ["defend", "flurry"]
	e.energy = 3
	e._draw(3)
	_check("抽牌堆空时洗回弃牌堆", e.hand.size() == 3)
	_check("抽完后弃牌堆清空", e.discard_pile.is_empty())

func _test_enemy_turn_and_intent() -> void:
	var e := _engine(["goblin"])
	e.enemies[0]["hp"] = 200
	var first_intent: Dictionary = e.enemies[0]["intent"].duplicate(true)
	_check("首回合意图是劈砍(8)", int(first_intent["preview"]) == 8)
	e.end_turn()
	_check("敌人行动后回合来到 2", e.turn == 2)
	_check("玩家掉了 8 血", int(e.player["hp"]) == 72)
	_check("意图推进到磨刀", str(e.enemies[0]["intent"]["type"]) == "buff")
	e.end_turn()
	_check("哥布林叠了 2 层力量", int(e.enemies[0]["statuses"]["strength"]) == 2)
	_check("意图回到劈砍并预览 10", int(e.enemies[0]["intent"]["preview"]) == 10)

func _test_poison() -> void:
	var e := _engine(["goblin"])
	e.enemies[0]["hp"] = 50
	e.enemies[0]["statuses"]["poison"] = 3
	e.end_turn()
	_check("中毒 3 层造成 3 点伤害", int(e.enemies[0]["hp"]) == 47)
	e.end_turn()
	_check("中毒衰减为 1 层并造成 2 点", int(e.enemies[0]["statuses"]["poison"]) == 1 and int(e.enemies[0]["hp"]) == 45)

func _test_victory() -> void:
	var e := _engine(["goblin"])
	e.enemies[0]["hp"] = 5
	e.hand = ["strike"]
	e.energy = 3
	e.play_card(0, "e0")
	_check("击杀后进入胜利态", e.phase == "victory")
	_check("胜利后不能继续出牌", not e.play_card(0, "e0"))

func _test_deck_average() -> void:
	# 用真实开局牌组反复跑随机出牌，确保 200 回合内不会崩溃 / 卡死
	for seed in range(30):
		var e := _engine(["goblin"])
		var guard := 0
		while e.phase != "victory" and e.phase != "defeat" and guard < 200:
			guard += 1
			var played := false
			for i in range(e.hand.size() - 1, -1, -1):
				var target := ""
				var alive := e.living_enemies()
				if not alive.is_empty():
					target = str(alive[0]["id"])
				if e.can_play(i, target):
					e.play_card(i, target)
					played = true
					break
			if not played:
				e.end_turn()
		_check("seed %d 战斗正常结束" % seed, e.phase in ["victory", "defeat"])

# ------------------------------------------------------------ 工具

func _engine(enemy_ids: Array, deck: Array = ["strike", "strike", "defend", "defend", "flurry"]) -> BattleEngine:
	var defs: Array = []
	for id in enemy_ids:
		defs.append(_db.enemy(str(id)))
	var e := BattleEngine.new()
	e.setup(deck.duplicate(), 80, 80, defs, _db.cards, 12345)
	return e

func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		print("  FAIL  ", label)
