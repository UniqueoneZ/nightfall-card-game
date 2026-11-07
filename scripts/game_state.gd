extends Node
## 一局（Run）的全局状态：牌组、生命、当前层数。战斗结束时由 UI 调用推进。

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
var encounter_index := 0
var run_seed := 0
var battles_won := 0
var last_stats: Dictionary = {}

func new_run(p_seed: int = 0) -> void:
	run_seed = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system())
	deck = START_DECK.duplicate()
	hp = MAX_HP
	max_hp = MAX_HP
	encounter_index = 0
	battles_won = 0
	last_stats = {}

func create_battle() -> BattleEngine:
	var enc := DB.encounter(encounter_index)
	var defs: Array = []
	for id in enc.get("enemies", []):
		var d := DB.enemy(str(id))
		if not d.is_empty():
			defs.append(d)
	var eng := BattleEngine.new()
	# 同一局内每场战斗使用确定性子种子，便于复现 bug
	eng.setup(deck, hp, max_hp, defs, DB.cards, run_seed + encounter_index * 7919)
	return eng

func encounter_title() -> String:
	return str(DB.encounter(encounter_index).get("title", "未知之地"))

func is_boss() -> bool:
	return bool(DB.encounter(encounter_index).get("boss", false))

## 战斗胜利后推进；返回 true 表示还有下一场
func advance() -> bool:
	battles_won += 1
	hp = mini(max_hp, hp + HEAL_BETWEEN)
	encounter_index += 1
	return encounter_index < DB.encounter_count()
