extends SceneTree
## 地图生成测试
const DatabaseScript := preload("res://scripts/data/database.gd")
const RunMapScript := preload("res://scripts/core/run_map.gd")

var _pass := 0
var _fail := 0

func _initialize() -> void:
	for seed in range(8):
		var m: Array = RunMapScript.generate(seed)
		_check("seed %d: 8 层" % seed, m.size() == 8)
		_check("seed %d: 最后一层是 Boss" % seed, m[7].size() == 1 and str(m[7][0]["type"]) == "boss")
		var all_rest := true
		for n in m[6]:
			if str(n["type"]) != "rest":
				all_rest = false
		_check("seed %d: Boss 前一层是篝火" % seed, all_rest)
		_check("seed %d: 第一层是战斗" % seed, str(m[0][0]["type"]) == "battle")
		var ok := true
		for f in m.size():
			for n in m[f]:
				if str(n["type"]) in ["battle", "elite", "boss"] and (n["enemies"] as Array).is_empty():
					ok = false
		_check("seed %d: 战斗节点都有敌人" % seed, ok)
	var db = DatabaseScript.new()
	db.reload()
	var strike: Dictionary = db.card("strike")
	var strike_up: Dictionary = db.card("strike+")
	_check("升级版存在", not strike_up.is_empty())
	_check("升级后伤害提高", int(strike_up["effects"][0]["v"]) > int(strike["effects"][0]["v"]))
	_check("升级版有描述", str(strike_up.get("desc", "")) != "")
	_check("升级版名称带＋", str(strike_up.get("name", "")).ends_with("＋"))
	print("\n===== %d passed, %d failed =====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

func _check(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL  ", label)
