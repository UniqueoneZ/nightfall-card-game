class_name RunMap
extends RefCounted
## 分支地图生成：8 列节点，节点类型与敌人随层数递进，Boss 前必有一个篝火。

const FLOORS := 8
const WIDTH := 3

const T_BATTLE := "battle"
const T_ELITE := "elite"
const T_EVENT := "event"
const T_SHOP := "shop"
const T_REST := "rest"
const T_BOSS := "boss"

static func generate(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var floors: Array = []
	for f in FLOORS:
		var count := 1 if f == FLOORS - 1 else WIDTH
		var nodes: Array = []
		for i in count:
			var t := _type_for(f, rng)
			nodes.append({
				"type": t,
				"enemies": _enemies_for(t, f, rng),
				"visited": false,
				"gold": 0,
			})
		floors.append(nodes)
	return floors

static func _type_for(f: int, rng: RandomNumberGenerator) -> String:
	if f == 0:
		return T_BATTLE
	if f == FLOORS - 1:
		return T_BOSS
	if f == FLOORS - 2:
		return T_REST
	var r := rng.randf()
	if r < 0.48:
		return T_BATTLE
	if r < 0.62:
		return T_ELITE
	if r < 0.80:
		return T_EVENT
	if r < 0.90:
		return T_SHOP
	return T_REST

static func _enemies_for(t: String, f: int, rng: RandomNumberGenerator) -> Array:
	match t:
		T_BOSS:
			return ["warden3"]
		T_ELITE:
			return ["bishop"] if rng.randf() < 0.5 else ["warden"]
		T_BATTLE:
			var pool := ["goblin"]
			if f >= 2:
				pool.append("gargoyle")
			if f >= 5:
				pool.append("bishop")
			var n := 1
			if f >= 3 and rng.randf() < 0.45:
				n = 2
			var out: Array = []
			for i in n:
				out.append(str(pool[rng.randi_range(0, pool.size() - 1)]))
			return out
	return []

static func type_label(t: String) -> String:
	match t:
		T_BATTLE: return "战斗"
		T_ELITE: return "精英"
		T_EVENT: return "事件"
		T_SHOP: return "商店"
		T_REST: return "篝火"
		T_BOSS: return "Boss"
	return "?"

static func type_color(t: String) -> Color:
	match t:
		T_BATTLE: return Color("#C1544F")
		T_ELITE: return Color("#E08A48")
		T_EVENT: return Color("#5B8FC0")
		T_SHOP: return Color("#D8B36A")
		T_REST: return Color("#5FA88B")
		T_BOSS: return Color("#9270C0")
	return Color.WHITE
