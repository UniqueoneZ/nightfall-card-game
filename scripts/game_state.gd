extends Node
## 一局（Run）的全局状态：牌组、生命、金币、分支地图与当前位置。

const START_DECK := [
	"strike", "strike", "strike", "strike",
	"defend", "defend", "defend", "defend",
	"flurry", "fireball", "empower", "insight",
]
const CLASS_DECKS := {
	"oathbound": [
		"g_strike", "g_strike", "g_strike", "g_guard", "g_guard", "g_guard",
		"g_bash", "g_iron", "g_riposte", "g_bulwark", "g_hold", "g_whet",
	],
	"emberwright": [
		"e_ember", "e_ember", "e_ember", "e_ember", "e_cinder", "e_cinder",
		"e_cinder", "e_kindling", "e_kindling", "e_guard", "e_guard", "e_sacrifice",
	],
	"beastcaller": [
		"b_strike", "b_strike", "b_strike", "b_guard", "b_guard", "b_wolf",
		"b_wolf", "b_mark", "b_shot", "b_pack", "b_camp", "b_call",
	],
	"hierophant": [
		"h_light", "h_light", "h_light", "h_prayer", "h_prayer", "h_seal",
		"h_mend", "h_shelter", "h_smite", "h_bless", "h_chant", "h_purify",
	],
	"shadowblade": [
		"s_dagger", "s_dagger", "s_dagger", "s_thrust", "s_thrust", "s_dodge",
		"s_dodge", "s_venom", "s_combo", "s_combo", "s_shadowstep", "s_light",
	],
}
const CLASS_NAMES := {"oathbound": "守誓者", "emberwright": "烬术士", "shadowblade": "影刃", "hierophant": "圣祷者", "beastcaller": "驭兽人"}

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
var player_class := "oathbound"
var pending_relic := false
var relic_choices: Array = []

func new_run(p_seed: int = 0, cls: String = "oathbound") -> void:
	run_seed = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system())
	player_class = cls if CLASS_DECKS.has(cls) else "oathbound"
	deck = (CLASS_DECKS[player_class] as Array).duplicate()
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
	pending_relic = false
	relic_choices = []

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
	Relics.apply_to_engine(eng, relics)
	last_stats = eng.stats
	return eng

func on_battle_won() -> void:
	mark_visited()
	hp = mini(max_hp, hp + HEAL_BETWEEN + Relics.heal_after(relics))
	gold += 25 + maxi(floor_idx, 0) * 5 + Relics.gold_bonus(relics)
	battles_won += 1

# ---------------------------------------------------------------- 遗物

func has_relic(id: String) -> bool:
	return relics.has(id)

func add_relic(id: String) -> void:
	if not relics.has(id):
		relics.append(id)

func roll_relic_choices(rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var pool: Array = []
	for id in Relics.POOL:
		if not relics.has(id):
			pool.append(id)
	var out: Array = []
	var guard := 0
	while out.size() < 3 and pool.size() > 0 and guard < 50:
		guard += 1
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	relic_choices = out
	return out

# ---------------------------------------------------------------- 存档

const SAVE_PATH := "user://run.json"

func save_run() -> void:
	var data := {
		"version": 1,
		"seed": run_seed,
		"deck": deck,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"relics": relics,
		"floor": floor_idx,
		"node": node_idx,
		"map": map,
		"battles": battles_won,
		"class": player_class,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_run() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	run_seed = int(parsed.get("seed", 0))
	deck = parsed.get("deck", [])
	hp = int(parsed.get("hp", MAX_HP))
	max_hp = int(parsed.get("max_hp", MAX_HP))
	gold = int(parsed.get("gold", 0))
	relics = parsed.get("relics", [])
	floor_idx = int(parsed.get("floor", -1))
	node_idx = int(parsed.get("node", -1))
	map = parsed.get("map", [])
	battles_won = int(parsed.get("battles", 0))
	player_class = str(parsed.get("class", "oathbound"))
	current_node = {}
	if floor_idx >= 0 and floor_idx < map.size() and node_idx >= 0 and node_idx < map[floor_idx].size():
		current_node = map[floor_idx][node_idx]
	return true

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func add_card(card_id: String) -> void:
	deck.append(card_id)

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
