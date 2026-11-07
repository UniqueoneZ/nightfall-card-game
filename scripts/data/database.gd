extends Node
## 静态数据库：启动时加载 data/*.json，向全局提供只读查询。

var cards: Dictionary = {}
var enemies: Dictionary = {}
var encounters: Array = []
var net: Dictionary = {}
var load_error: String = ""

func _ready() -> void:
	reload()

func reload() -> void:
	var c := _read_json("res://data/cards.json")
	var e := _read_json("res://data/enemies.json")
	var n := _read_json("res://data/net.json")
	net = n if not n.is_empty() else {}
	if c.is_empty() or e.is_empty():
		return
	cards.clear()
	for def in c.get("cards", []):
		cards[str(def.id)] = def
	_build_upgrades()
	enemies.clear()
	for def in e.get("enemies", []):
		enemies[str(def.id)] = def
	encounters = e.get("encounters", [])

## 为每张卡生成 "+" 升级版：数值 +30%，描述按效果自动重写
func _build_upgrades() -> void:
	var ids: Array = cards.keys()
	for id in ids:
		if str(id).ends_with("+"):
			continue
		var base: Dictionary = cards[id]
		var up := base.duplicate(true)
		up["id"] = str(id) + "+"
		up["name"] = str(base.get("name", "")) + "＋"
		up["rarity"] = str(base.get("rarity", "common"))
		up["upgraded"] = true
		var effs: Array = []
		for e in base.get("effects", []):
			var ne: Dictionary = e.duplicate(true)
			match str(ne.get("k", "")):
				"damage", "block", "self_block", "heal":
					ne["v"] = int(ceil(float(ne.get("v", 0)) * 1.3))
				"draw":
					ne["v"] = int(ne.get("v", 1)) + 1
				"damage_by_block":
					ne["add"] = int(ne.get("add", 0)) + 4
				"status", "self_status":
					ne["v"] = int(ne.get("v", 0)) + 1
				"revive":
					ne["v"] = int(ne.get("v", 0)) + 6
			effs.append(ne)
		up["effects"] = effs
		up["desc"] = describe(effs)
		cards[up["id"]] = up

static func describe(effs: Array) -> String:
	var parts: Array = []
	var names := {"strength": "力量", "vulnerable": "易伤", "weak": "虚弱", "poison": "中毒", "thorns": "反击", "retain": "壁垒"}
	for e in effs:
		var v := int(e.get("v", 0))
		match str(e.get("k", "")):
			"damage":
				var hits := int(e.get("hits", 1))
				parts.append("造成 %d 点伤害" % v if hits <= 1 else "造成 %d 点伤害，%d 次" % [v, hits])
			"block", "self_block":
				parts.append("获得 %d 点格挡" % v)
			"draw":
				parts.append("抽 %d 张牌" % v)
			"energy":
				parts.append("获得 %d 点能量" % v)
			"heal":
				parts.append("回复 %d 点生命" % v)
			"status":
				parts.append("施加 %d 层%s" % [v, names.get(str(e.get("status", "")), "")])
			"self_status":
				parts.append("获得 %d 点%s" % [v, names.get(str(e.get("status", "")), "")])
			"damage_by_block":
				parts.append("造成等同于格挡的伤害（+%d）" % int(e.get("add", 0)))
			"revive":
				parts.append("复活队友并回复 %d 点生命" % v)
	if parts.is_empty():
		return "无效果"
	return "，".join(parts) + "。"

func card(id: String) -> Dictionary:
	return cards.get(id, {})

func enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func encounter(index: int) -> Dictionary:
	if index < 0 or index >= encounters.size():
		return {}
	return encounters[index]

func encounter_count() -> int:
	return encounters.size()

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		load_error = "缺少数据文件: %s" % path
		push_error(load_error)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "数据文件格式错误: %s" % path
		push_error(load_error)
		return {}
	return parsed
