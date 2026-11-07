extends Node
## 无头联机测试客户端：连中继、跑同一份引擎、自动出牌，打印状态哈希用于比对。

const DECKS := [
	["g_strike", "g_strike", "g_strike", "g_strike", "g_guard", "g_guard", "g_guard",
	 "g_bash", "g_iron", "g_riposte", "g_bulwark", "cover"],
	["strike", "strike", "strike", "defend", "defend",
	 "cover", "rally", "flurry", "poison_blade", "fireball", "insight", "revive_call"],
]

var net: NetClient
var engine: CoopEngine
var seat := 0
var started := false
var timer := 0.0
var server := "ws://127.0.0.1:8787"
var room := "TEST"
var nick := "bot"
var elapsed := 0.0
var cmds_seen := 0
var life := 30.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server="): server = a.substr(9)
		elif a.begins_with("--room="): room = a.substr(7)
		elif a.begins_with("--name="): nick = a.substr(7)
		elif a.begins_with("--life="): life = float(a.substr(7))
	net = NetClient.new()
	add_child(net)
	net.message_received.connect(_on_msg)
	net.connected.connect(func() -> void: net.send({"t": "hello", "room": room, "name": nick}))
	net.connect_to(server)

func _on_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"wait":
			seat = int(m.get("seat", 0))
			print("[%s] wait seat=%d room=%s" % [nick, seat, m.get("room", "")])
		"start":
			engine = CoopEngine.new()
			engine.setup(DB.cards, [DECKS[0].duplicate(), DECKS[1].duplicate()], DB.enemy("warden"), int(m.get("seed", 0)))
			started = true
			print("[%s] START seat=%d seed=%d hash=%s" % [nick, seat, int(m.get("seed", 0)), engine.state_hash()])
		"cmd":
			if engine == null: return
			engine.execute(m.get("cmd", {}))
			cmds_seen += 1
			print("[%s] HASH seq=%d %s" % [nick, int(m.get("seq", -1)), engine.state_hash()])
		"left":
			print("[%s] partner left" % nick)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > life:
		print("[%s] DONE cmds=%d final=%s" % [nick, cmds_seen, engine.state_hash() if engine else "none"])
		get_tree().quit()
		return
	if not started or engine == null or engine.phase != "player":
		return
	timer -= delta
	if timer > 0:
		return
	timer = 0.8
	var p: Dictionary = engine.players[seat]
	for i in range(p["hand"].size() - 1, -1, -1):
		var tid := "boss" if str(engine.card_def(str(p["hand"][i])).get("target", "")) == "enemy" else ("p1" if seat == 0 else "p0")
		if engine.can_play(seat, i, tid):
			net.send({"t": "cmd", "cmd": {"type": "play", "pi": seat, "hand_index": i, "target": tid}})
			return
	net.send({"t": "cmd", "cmd": {"type": "ready", "pi": seat}})
