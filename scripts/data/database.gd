extends Node
## 静态数据库：启动时加载 data/*.json，向全局提供只读查询。

var cards: Dictionary = {}
var enemies: Dictionary = {}
var encounters: Array = []
var load_error: String = ""

func _ready() -> void:
	reload()

func reload() -> void:
	var c := _read_json("res://data/cards.json")
	var e := _read_json("res://data/enemies.json")
	if c.is_empty() or e.is_empty():
		return
	cards.clear()
	for def in c.get("cards", []):
		cards[str(def.id)] = def
	enemies.clear()
	for def in e.get("enemies", []):
		enemies[str(def.id)] = def
	encounters = e.get("encounters", [])

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
