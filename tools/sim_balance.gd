extends SceneTree
## 平衡性模拟：每个职业跑 N 局完整爬塔，输出胜率、平均层数、战斗回合数。
## 运行: Godot --headless --path . --script res://tools/sim_balance.gd

const DatabaseScript := preload("res://scripts/data/database.gd")
const RunMapScript := preload("res://scripts/core/run_map.gd")
const DECKS := {
	"oathbound": ["g_strike","g_strike","g_strike","g_guard","g_guard","g_heavy","g_bash","g_iron","g_riposte","g_bulwark","g_hold","g_whet"],
	"emberwright": ["e_ember","e_ember","e_ember","e_ember","e_cinder","e_cinder","e_cinder","e_kindling","e_kindling","e_guard","e_guard","e_sacrifice"],
	"shadowblade": ["s_dagger","s_dagger","s_dagger","s_thrust","s_thrust","s_dodge","s_double","s_venom","s_combo","s_combo","s_poisonblade","s_light"],
	"hierophant": ["h_light","h_light","h_light","h_prayer","h_prayer","h_seal","h_mend","h_shelter","h_smite","h_bless","h_chant","h_purify"],
	"beastcaller": ["b_strike","b_strike","b_strike","b_guard","b_guard","b_wolf","b_wolf","b_mark","b_shot","b_pack","b_camp","b_call"],
}
const NAMES := {"oathbound":"守誓者","emberwright":"烬术士","shadowblade":"影刃","hierophant":"圣祷者","beastcaller":"驭兽人"}

const RUNS := 20

func _initialize() -> void:
	var db = DatabaseScript.new()
	db.reload()
	var classes := ["oathbound", "emberwright", "shadowblade", "hierophant", "beastcaller"]
	print("职业\t\t局数\t通关\t胜率\t平均层\t平均战斗回合")
	for cls in classes:
		var deck: Array = (DECKS[cls] as Array).duplicate()
		var wins := 0
		var total_floor := 0
		var total_turns := 0
		var battles := 0
		for r in RUNS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + r * 37 + classes.find(cls) * 13
			var map: Array = RunMapScript.generate(rng.randi())
			var hp := 80
			var max_hp := 80
			var died := false
			var floor_reached := 0
			for f in map.size():
				floor_reached = f + 1
				var nodes: Array = map[f]
				var node: Dictionary = nodes[rng.randi_range(0, nodes.size() - 1)]
				var t := str(node["type"])
				if t in ["battle", "elite", "boss"]:
					var defs: Array = []
					for id in node["enemies"]:
						defs.append(db.enemy(str(id)))
					var eng := BattleEngine.new()
					eng.setup(deck, hp, max_hp, defs, db.cards, rng.randi())
					var turns := _auto_battle(eng)
					total_turns += turns
					battles += 1
					hp = int(eng.player["hp"])
					if eng.phase == "defeat":
						died = true
						break
					hp = mini(max_hp, hp + 20)
					# 模拟战后三选一（随机取一张本职业非起始卡）
					var pool: Array = []
					for cid in db.cards:
						if str(cid).ends_with("+"):
							continue
						if str(db.cards[cid].get("class", "")) == cls and str(db.cards[cid].get("rarity", "")) != "starter":
							pool.append(cid)
					if not pool.is_empty():
						deck.append(str(pool[rng.randi_range(0, pool.size() - 1)]))
					if t == "boss":
						wins += 1
				elif t == "rest":
					hp = mini(max_hp, hp + int(max_hp * 0.3))
				elif t == "event":
					hp = mini(max_hp, hp + 15)
			total_floor += floor_reached
			if died:
				pass
		var name := str(NAMES.get(cls, cls))
		print("%s\t\t%d\t%d\t%d%%\t%.1f\t%.1f" % [
			name, RUNS, wins, int(100.0 * wins / RUNS),
			float(total_floor) / RUNS, float(total_turns) / maxi(battles, 1)])
	quit(0)

func _auto_battle(eng) -> int:
	var guard := 0
	while eng.phase == "player" and guard < 120:
		guard += 1
		var played := false
		var alive: Array = eng.living_enemies()
		for i in range(eng.hand.size() - 1, -1, -1):
			var tid := "" if alive.is_empty() else str(alive[0]["id"])
			if eng.can_play(i, tid):
				eng.play_card(i, tid)
				played = true
				break
		if not played:
			eng.end_turn()
	return eng.turn
