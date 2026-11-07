extends SceneTree
const DatabaseScript := preload("res://scripts/data/database.gd")
var _p := 0
var _f := 0

func _initialize() -> void:
	var db = DatabaseScript.new()
	db.reload()
	var e := BattleEngine.new()
	e.setup(["b_wolf","b_strike","b_guard","b_pack","b_mark"], 80, 80, [db.enemy("goblin")], db.cards, 9)
	e.enemies[0]["hp"] = 200
	e.hand = ["b_wolf"]
	e.energy = 3
	e.play_card(0)
	_check("召唤 1 只影狼", int(e.player["statuses"]["beast"]) == 1)
	var before := int(e.enemies[0]["hp"])
	e.end_turn()
	_check("影狼回合末造成 2 点", before - int(e.enemies[0]["hp"]) == 2)

	var e2 := BattleEngine.new()
	e2.setup(["b_strike","b_mark","b_guard","b_shot","b_pack"], 80, 80, [db.enemy("goblin")], db.cards, 10)
	e2.enemies[0]["hp"] = 200
	e2.hand = ["b_mark"]
	e2.energy = 3
	e2.play_card(0, "e0")
	_check("标记 3 层", int(e2.enemies[0]["statuses"]["mark"]) == 3)
	e2.hand = ["b_strike"]
	var hp := int(e2.enemies[0]["hp"])
	e2.play_card(0, "e0")
	_check("标记使 6 伤变 9 伤", hp - int(e2.enemies[0]["hp"]) == 9)
	_check("标记消耗一层", int(e2.enemies[0]["statuses"]["mark"]) == 2)

	var n := 0
	for id in db.cards:
		if str(id).ends_with("+"): continue
		if str(db.cards[id].get("class","")) == "beastcaller": n += 1
	_check("驭兽人 30 张", n == 30)
	print("\n===== %d passed, %d failed =====" % [_p, _f])
	quit(0 if _f == 0 else 1)

func _check(l: String, c: bool) -> void:
	if c: _p += 1
	else:
		_f += 1
		print("  FAIL ", l)
