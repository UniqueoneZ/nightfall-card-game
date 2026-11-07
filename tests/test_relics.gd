extends SceneTree
const DatabaseScript := preload("res://scripts/data/database.gd")
var _p := 0
var _f := 0

func _initialize() -> void:
	var db = DatabaseScript.new()
	db.reload()
	var e := BattleEngine.new()
	e.setup(["strike", "strike", "defend", "defend", "flurry"], 80, 80, [db.enemy("goblin")], db.cards, 1)
	Relics.apply_to_engine(e, ["iron_ring", "ember_charm", "war_drum", "thorn_badge"])
	_check("铁环 +10 生命上限", int(e.player["max_hp"]) == 90)
	_check("开局格挡 6", int(e.player["block"]) == 6)
	_check("开局力量 1", int(e.player["statuses"]["strength"]) == 1)
	_check("开局反击 3", int(e.player["statuses"]["thorns"]) == 3)
	_check("金币加成", Relics.gold_bonus(["gold_pouch", "lucky_coin"]) == 40)
	_check("战后回血", Relics.heal_after(["blood_vial"]) == 8)
	print("\n===== %d passed, %d failed =====" % [_p, _f])
	quit(0 if _f == 0 else 1)

func _check(l: String, c: bool) -> void:
	if c: _p += 1
	else:
		_f += 1
		print("  FAIL ", l)
