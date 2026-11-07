class_name NetClient
extends Node
## 极简 WebSocket 客户端：只负责收发 JSON，协议见 server/relay.js。

signal connected
signal disconnected
signal message_received(msg: Dictionary)

var peer := WebSocketPeer.new()
var url := ""
var _was_open := false

func connect_to(u: String) -> void:
	url = u
	_was_open = false
	var err := peer.connect_to_url(u)
	if err != OK:
		push_error("连接失败: %s (err=%d)" % [u, err])

func _process(_delta: float) -> void:
	peer.poll()
	var st := peer.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _was_open:
		_was_open = true
		connected.emit()
	elif st == WebSocketPeer.STATE_CLOSED and _was_open:
		_was_open = false
		disconnected.emit()

	while st == WebSocketPeer.STATE_OPEN and peer.get_available_packet_count() > 0:
		var txt := peer.get_packet().get_string_from_utf8()
		var msg = JSON.parse_string(txt)
		if typeof(msg) == TYPE_DICTIONARY:
			message_received.emit(msg)

func send(obj: Dictionary) -> void:
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peer.send_text(JSON.stringify(obj))

func is_open() -> bool:
	return peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func close() -> void:
	peer.close()
