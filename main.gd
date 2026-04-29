extends Node3D # 親ノードの種類に合わせて変更してください

var server_url = "ws://35.230.51.172:8765" # localhostより127.0.0.1の方が確実です
var player_scene = preload("res://player.tscn")
var peer = WebRTCMultiplayerPeer.new()
var rtc_peer = WebRTCPeerConnection.new()
var socket = WebSocketPeer.new()
var is_host = false

func _ready():
	# _readyでの自動接続は一旦コメントアウト（ボタンのみで制御）
	# socket.connect_to_url(server_url)
	
	rtc_peer.session_description_created.connect(_on_sdp)
	rtc_peer.ice_candidate_created.connect(_on_ice)
	multiplayer.peer_connected.connect(_on_connected)

func _process(_delta):
	socket.poll()
	rtc_peer.poll()
	
	var state = socket.get_ready_state()
	
	# 接続状態をチェック（デバッグ用）
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet().get_string_from_utf8()
			_handle_signaling(packet)
	elif state == WebSocketPeer.STATE_CONNECTING:
		# 接続中...（何もしない）
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		# 閉じている場合にエラーログを出す（連打防止）
		pass

func _handle_signaling(json_text):
	var data = JSON.parse_string(json_text)
	if data == null: return
	
	print("受信データ: ", data) # 何が届いているか表示

	if data.has("type") and data.type == "match":
		is_host = (data.role == "host")
		_setup_webrtc(1 if is_host else 2)
		if is_host: rtc_peer.create_offer()
	
	if data.has("sdp"):
		rtc_peer.set_remote_description(data.sdp.type, data.sdp.sdp)
		#if data.sdp.type == "offer": rtc_peer.create_answer()
	if data.has("candidate"):
		rtc_peer.add_ice_candidate(data.candidate.media, data.candidate.index, data.candidate.name)

func _setup_webrtc(my_id):
	rtc_peer.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
	peer.create_mesh(my_id)
	multiplayer.multiplayer_peer = peer
	peer.add_peer(rtc_peer, 2 if my_id == 1 else 1)
	
	# ボタンを隠す（MatchButtonに名前を統一）
	if has_node("UI/MatchButton"):
		$UI/MatchButton.visible = false
	
	if is_host: spawn_player(1)

func _on_connected(id):
	print("P2P接続成功！ ID: ", id)
	if is_host: spawn_player(id)

func spawn_player(id):
	if %World/Players.has_node(str(id)): return
	var p = player_scene.instantiate()
	p.name = str(id)
	%World/Players.add_child(p, true)

func _on_sdp(t, s):
	rtc_peer.set_local_description(t, s)
	socket.send_text(JSON.stringify({"sdp": {"type": t, "sdp": s}}))

func _on_ice(m, i, n):
	socket.send_text(JSON.stringify({"candidate": {"media": m, "index": i, "name": n}}))

# ボタンを押した時の処理
func _on_match_button_pressed() -> void:
	print("SYSTEM: サーバーに接続を開始します...")
	var state = socket.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING:
		print("すでに接続中、または接続済みです。")
		return

	var err = socket.connect_to_url(server_url)
	if err != OK:
		print("接続開始に失敗しました。エラーコード: ", err)
	else:
		print("接続試行中... (Pythonサーバー側の反応を待っています)")


func _on_input_text_text_submitted(text: String) -> void:
	if text.strip_edges() == "": return
	rpc("receive_message", multiplayer.get_unique_id(), text)
	$UI/InputText.clear()

@rpc("any_peer","call_local","reliable")
func receive_message(sender_id: int, message:String):
	var sender_label = "Me" if sender_id == multiplayer.get_unique_id() else "Oppornent"
	if has_node("UI/ChatLog"):
		$UI/ChatLog.append_text("[b]%s:[/b] %s\n" % [sender_label, message])
