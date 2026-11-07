extends SceneTree
const DatabaseScript := preload("res://scripts/data/database.gd")
var _p := 0
var _f := 0

func _initialize() -> void:
	var db = DatabaseScript.new()
	db.reload()
	# 圣印：回合末打伤害
	var e := BattleEngine.new()
	e.setup(["h_seal","h_light","h_prayer","h_mend","h_bless"], 80, 80, [db.enemy("goblin")], db.cards, 7)
	e.enemies[0]["hp"] = 100
	e.hand = ["h_seal"]
	e.energy = 3
	e.play_card(0)
	_check("圣印 +1", int(e.player["statuses"]["seal"]) == 1)
	var before := int(e.enemies[0]["hp"])
	e.end_turn()
	_check("圣印回合末造成 4 点", before - int(e.enemies[0]["hp"]) == 4)

	# 溢流：过量治疗转格挡
	var e2 := BattleEngine.new()
	e2.setup(["h_overflow","h_mend","h_prayer","h_light","h_bless"], 80, 80, [db.enemy("goblin")], db.cards, 8)
	e2.player["hp"] = 78
	e2.hand = ["h_overflow"]
	e2.energy = 3
	e2.play_card(0)
	e2.hand = ["h_mend"]
	e2.energy = 3
	e2.play_card(0)
	_check("过量治疗转格挡", int(e2.player["block"]) >= 4)
	_check("生命不超过上限", int(e2.player["hp"]) == 80)

	var n := 0
	for id in db.cards:
		if str(id).ends_with("+"): continue
		if str(db.cards[id].get("class","")) == "hierophant": n += 1
	_check("圣祷者 30 张", n == 30)
	print("\n===== %d passed, %d failed =====" % [_p, _f])
	quit(0 if _f == 0 else 1)

func _check(l: String, c: bool) -> void:
	if c: _p += 1
	else:
		_f += 1
		print("  FAIL ", l)
