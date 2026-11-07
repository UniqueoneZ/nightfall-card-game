extends Node
## 一局（Run）的全局状态：牌组、生命、金币、分支地图与当前位置。

const START_DECK := [
	"strike", "strike", "strike", "strike",
	"defend", "defend", "defend", "defend",
	"flurry", "fireball", "empower", "insight",
]
const MAX_HP := 80
const HEAL_BETWEEN := 20

var deck: Array = []
var hp := MAX_HP
var max_hp := MAX_HP
var gold := 80
var run_seed := 0
var map: Array = []
var floor_idx := -1
var node_idx := -1
var current_node: Dictionary = {}
var relics: Array = []
var last_stats: Dictionary = {}
var battles_won := 0

func new_run(p_seed: int = 0) -> void:
	run_seed = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system())
	deck = START_DECK.duplicate()
	hp = MAX_HP
	max_hp = MAX_HP
	gold = 80
	map = RunMap.generate(run_seed)
	floor_idx = -1
	node_idx = -1
	current_node = {}
	relics.clear()
	battles_won = 0
	last_stats = {}

func ensure_run() -> void:
	if map.is_empty():
		new_run()

# ---------------------------------------------------------------- 地图

func reachable() -> Array:
	if map.is_empty():
		return []
	if floor_idx < 0:
		var out: Array = []
		for i in map[0].size():
			out.append(Vector2i(0, i))
		return out
	var nf := floor_idx + 1
	if nf >= map.size():
		return []
	var width: int = map[nf].size()
	var res: Array = []
	for d in [-1, 0, 1]:
		var i: int = node_idx + d
		if i >= 0 and i < width:
			res.append(Vector2i(nf, i))
	return res

func can_travel(f: int, i: int) -> bool:
	return reachable().has(Vector2i(f, i))

func travel(f: int, i: int) -> void:
	if not can_travel(f, i):
		return
	floor_idx = f
	node_idx = i
	current_node = map[f][i]

func node_type() -> String:
	return str(current_node.get("type", ""))

func is_battle_node() -> bool:
	return node_type() in ["battle", "elite", "boss"]

func mark_visited() -> void:
	if floor_idx >= 0 and node_idx >= 0:
		map[floor_idx][node_idx]["visited"] = true

# ---------------------------------------------------------------- 战斗

func create_battle() -> BattleEngine:
	var defs: Array = []
	var ids: Array = current_node.get("enemies", [])
	if ids.is_empty():
		ids = ["goblin"]
	for id in ids:
		var d := DB.enemy(str(id))
		if not d.is_empty():
			defs.append(d)
	var eng := BattleEngine.new()
	eng.setup(deck, hp, max_hp, defs, DB.cards, run_seed + maxi(floor_idx, 0) * 7919 + maxi(node_idx, 0))
	last_stats = eng.stats
	return eng

func on_battle_won() -> void:
	mark_visited()
	hp = mini(max_hp, hp + HEAL_BETWEEN)
	gold += 25 + maxi(floor_idx, 0) * 5
	battles_won += 1

func add_card(card_id: String) -> void:
	deck.append(card_id)

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
