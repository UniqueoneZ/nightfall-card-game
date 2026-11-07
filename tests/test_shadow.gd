extends SceneTree
const DatabaseScript := preload("res://scripts/data/database.gd")
var _p := 0
var _f := 0

func _initialize() -> void:
	var db = DatabaseScript.new()
	db.reload()
	var e := BattleEngine.new()
	e.setup(["s_dagger","s_dagger","s_combo","s_dodge","s_venom"], 80, 80, [db.enemy("goblin")], db.cards, 5)
	e.enemies[0]["hp"] = 200
	e.hand = ["s_dagger", "s_combo"]
	e.energy = 3
	e.play_card(0, "e0")
	_check("第一击后连环计数 1", int(e.player["attacks"]) == 1)
	var before := int(e.enemies[0]["hp"])
	e.play_card(0, "e0")
	var dmg := before - int(e.enemies[0]["hp"])
	_check("连环: 4 + 2×1 = 6 点", dmg == 6)
	e.start_player_turn()
	_check("新回合清零", int(e.player["attacks"]) == 0)

	var n := 0
	for id in db.cards:
		if str(id).ends_with("+"): continue
		if str(db.cards[id].get("class","")) == "shadowblade": n += 1
	_check("影刃 32 张", n == 32)
	print("\n===== %d passed, %d failed =====" % [_p, _f])
	quit(0 if _f == 0 else 1)

func _check(l: String, c: bool) -> void:
	if c: _p += 1
	else:
		_f += 1
		print("  FAIL ", l)
