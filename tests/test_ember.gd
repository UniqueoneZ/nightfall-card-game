extends SceneTree
const DatabaseScript := preload("res://scripts/data/database.gd")
var _p := 0
var _f := 0

func _initialize() -> void:
	var db = DatabaseScript.new()
	db.reload()
	var e := BattleEngine.new()
	e.setup(["e_ember","e_ember","e_kindling","e_cinder","e_guard"], 80, 80, [db.enemy("goblin")], db.cards, 3)
	e.enemies[0]["hp"] = 100
	e.hand = ["e_kindling"]
	e.energy = 3
	e.play_card(0, "e0")
	_check("引燃施加 3 层灼烧", int(e.enemies[0]["statuses"]["burn"]) == 3)
	var before := int(e.enemies[0]["hp"])
	e.end_turn()
	_check("灼烧回合末造成 3 点", before - int(e.enemies[0]["hp"]) == 3)
	_check("灼烧衰减为 2", int(e.enemies[0]["statuses"]["burn"]) == 2)

	var e2 := BattleEngine.new()
	e2.setup(["e_sacrifice","e_ember","e_guard","e_cinder","e_flare"], 80, 80, [db.enemy("goblin")], db.cards, 4)
	e2.hand = ["e_sacrifice"]
	e2.energy = 3
	e2.play_card(0)
	_check("献祭自伤 3", int(e2.player["hp"]) == 77)
	_check("献祭给 2 力量", int(e2.player["statuses"]["strength"]) == 2)

	var n := 0
	for id in db.cards:
		if str(id).ends_with("+"): continue
		if str(db.cards[id].get("class","")) == "emberwright": n += 1
	_check("烬术士 32 张", n == 32)
	print("\n===== %d passed, %d failed =====" % [_p, _f])
	quit(0 if _f == 0 else 1)

func _check(l: String, c: bool) -> void:
	if c: _p += 1
	else:
		_f += 1
		print("  FAIL ", l)
