class_name Relics
extends RefCounted
## 遗物：全局被动。用简单字段描述效果，战斗开始时统一应用。

const DATA := {
	"iron_ring": {"name": "铁环", "desc": "生命上限 +10", "max_hp": 10},
	"ember_charm": {"name": "余烬护符", "desc": "战斗开始获得 6 点格挡", "start_block": 6},
	"war_drum": {"name": "战鼓", "desc": "战斗开始获得 1 点力量", "start_strength": 1},
	"blood_vial": {"name": "血瓶", "desc": "每场战斗后回复 8 点生命", "heal_after": 8},
	"gold_pouch": {"name": "钱袋", "desc": "战斗金币 +15", "gold_bonus": 15},
	"thorn_badge": {"name": "荆棘徽章", "desc": "战斗开始获得 3 点反击", "start_thorns": 3},
	"stone_heart": {"name": "石之心", "desc": "生命上限 +18", "max_hp": 18},
	"lucky_coin": {"name": "幸运币", "desc": "战斗金币 +25", "gold_bonus": 25},
}

const POOL := ["iron_ring", "ember_charm", "war_drum", "blood_vial", "gold_pouch", "thorn_badge", "stone_heart", "lucky_coin"]

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})

static func apply_to_engine(engine, owned: Array) -> void:
	if owned.is_empty():
		return
	var bonus_hp := 0
	for id in owned:
		var d := get_def(str(id))
		bonus_hp += int(d.get("max_hp", 0))
	if bonus_hp > 0:
		engine.player["max_hp"] = int(engine.player["max_hp"]) + bonus_hp
		engine.player["hp"] = int(engine.player["hp"]) + bonus_hp
	for id in owned:
		var d := get_def(str(id))
		if int(d.get("start_block", 0)) > 0:
			engine.player["block"] = int(engine.player["block"]) + int(d["start_block"])
			engine._emit({"t": "block", "target": "player", "amount": int(d["start_block"]), "total": engine.player["block"]})
		if int(d.get("start_strength", 0)) > 0:
			engine.player["statuses"]["strength"] = int(engine.player["statuses"]["strength"]) + int(d["start_strength"])
		if int(d.get("start_thorns", 0)) > 0:
			engine.player["statuses"]["thorns"] = int(engine.player["statuses"]["thorns"]) + int(d["start_thorns"])

static func gold_bonus(owned: Array) -> int:
	var g := 0
	for id in owned:
		g += int(get_def(str(id)).get("gold_bonus", 0))
	return g

static func heal_after(owned: Array) -> int:
	var h := 0
	for id in owned:
		h += int(get_def(str(id)).get("heal_after", 0))
	return h
