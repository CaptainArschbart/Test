extends Node
## Host oder Client. Offline (kein Peer) bleibt Einzelspieler.
## Direkte IP nutzt ENet (UDP) und lauscht auf 0.0.0.0.
## ngrok kann nur TCP. Dafür läuft dieselbe API über WebSocket.
##
## Der Host merkt sich die Map. Beitretende laden dieselbe Szene. Die fest
## platzierte Player-Instanz wird entfernt. Figuren spawnt der
## MultiplayerSpawner unter diesem Autoload (derselbe Pfad auf jedem Peer,
## schon im Menü), damit ein späterer Beitritt den Spawner findet.
## Port 7777, höchstens 4 Spieler (Host plus 3 Clients).

const PORT := 7777
const MAX_CLIENTS := 3
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

signal peer_joined(id: int)
signal peer_left(id: int)
signal connection_failed
signal session_ended
signal client_connected

var map_path := ""
var listen_port := PORT
var tunnel_mode := false

var _banner: CanvasLayer

var _spawner: MultiplayerSpawner
var _players: Node3D
var _spawn_origin := Vector3.ZERO
var _spawn_rotation := Vector3.ZERO
var _handled_scene := 0
var _map_ready := false
var _next_slot := 0
var _slots: Dictionary = {}
var _pending_spawns: Array[int] = []
var _stopping := false


func _ready() -> void:
	_players = Node3D.new()
	_players.name = "Players"
	add_child(_players)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	add_child(_spawner)
	_spawner.spawn_path = NodePath("../Players")
	_spawner.add_spawnable_scene(PLAYER_SCENE_PATH)
	_spawner.spawn_function = _spawn_player_node
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
	var active := multiplayer.multiplayer_peer
	if active is WebSocketMultiplayerPeer:
		(active as WebSocketMultiplayerPeer).poll()
	if not has_session():
		_handled_scene = 0
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var scene_id := scene.get_instance_id()
	if scene_id == _handled_scene:
		return
	if scene.get_node_or_null("Player") == null:
		return
	_handled_scene = scene_id
	_setup_map(scene)


func has_session() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func create_server(port: int = -1, tcp_tunnel: bool = false) -> Error:
	var use_port := PORT if port <= 0 else port
	stop()
	if tcp_tunnel:
		var ws := WebSocketMultiplayerPeer.new()
		var ws_err := ws.create_server(use_port, "0.0.0.0")
		if ws_err != OK:
			ws.close()
			return ws_err
		listen_port = use_port
		tunnel_mode = true
		_bind_peer(ws)
		return OK
	var peer := ENetMultiplayerPeer.new()
	# "*" trifft auf Windows oft nur IPv6. ngrok verbindet sich per IPv4 mit 127.0.0.1.
	peer.set_bind_ip("0.0.0.0")
	var err := peer.create_server(use_port, MAX_CLIENTS)
	if err != OK:
		peer.close()
		return err
	listen_port = use_port
	tunnel_mode = false
	_bind_peer(peer)
	return OK


func create_client(address: String, port: int = -1) -> Error:
	var fallback := PORT if port <= 0 else port
	var tcp_tunnel := wants_tcp_tunnel(address)
	var endpoint := split_endpoint(address, fallback)
	var host := str(endpoint["host"])
	var use_port := int(endpoint["port"])
	if host.is_empty():
		host = "127.0.0.1"
	# ENet löst Hostnamen auf manchen Systemen nicht selbst auf.
	var resolved := resolve_host(host)
	if resolved.is_empty():
		return ERR_CANT_RESOLVE
	stop()
	if tcp_tunnel:
		var ws := WebSocketMultiplayerPeer.new()
		var ws_err := ws.create_client(_websocket_url(resolved, use_port))
		if ws_err != OK:
			ws.close()
			return ws_err
		tunnel_mode = true
		_bind_peer(ws)
		return OK
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(resolved, use_port)
	if err != OK:
		peer.close()
		return err
	tunnel_mode = false
	_bind_peer(peer)
	return OK


func host_map(path: String, port: int = -1, tcp_tunnel: bool = false) -> Error:
	var err := create_server(port, tcp_tunnel)
	if err != OK:
		return err
	map_path = path
	return OK


static func wants_tcp_tunnel(address: String) -> bool:
	var raw := address.strip_edges().to_lower()
	return raw.contains("ngrok") or raw.begins_with("tcp://") or raw.begins_with("ws://") or raw.begins_with("wss://")


static func split_endpoint(address: String, fallback_port: int) -> Dictionary:
	var raw := address.strip_edges()
	for prefix: String in ["tcp://", "udp://", "ws://", "wss://"]:
		if raw.to_lower().begins_with(prefix):
			raw = raw.substr(prefix.length())
			break
	raw = raw.trim_suffix("/").strip_edges()
	var colon := raw.rfind(":")
	if colon > 0 and not raw.contains("::"):
		var tail := raw.substr(colon + 1).strip_edges()
		if tail.is_valid_int():
			return {"host": raw.substr(0, colon).strip_edges(), "port": tail.to_int(), "explicit": true}
	return {"host": raw, "port": fallback_port, "explicit": false}


static func resolve_host(host: String) -> String:
	var clean := host.strip_edges()
	if clean.is_empty():
		return ""
	if clean.is_valid_ip_address():
		return clean
	var resolved := IP.resolve_hostname(clean, IP.TYPE_IPV4)
	if resolved.is_empty():
		resolved = IP.resolve_hostname(clean)
	return resolved


static func _websocket_url(ip: String, port: int) -> String:
	var literal := ip
	if ip.contains(":"):
		literal = "[%s]" % ip
	return "ws://%s:%d" % [literal, port]


func local_share_address() -> String:
	var best := "127.0.0.1"
	for raw: String in IP.get_local_addresses():
		if raw.is_valid_ip_address() and not raw.contains(":") and raw != "127.0.0.1":
			best = raw
			break
	return "%s:%d" % [best, listen_port]


func error_text(err: Error) -> String:
	if err == ERR_CANT_RESOLVE:
		return "Hostname nicht auflösbar. Internet und Adresse prüfen."
	if err == ERR_ALREADY_IN_USE or err == ERR_CANT_CREATE:
		return "Port ist belegt."
	if err == ERR_CANT_CONNECT:
		return "Keine Verbindung. Internet, IP und Port prüfen."
	return "Netzwerkfehler (%d)." % err


func show_share_banner(text: String) -> void:
	if _banner == null:
		_banner = CanvasLayer.new()
		_banner.layer = 40
		_banner.name = "ShareBanner"
		var label := Label.new()
		label.name = "ShareLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(16, 8)
		label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		_banner.add_child(label)
		add_child(_banner)
	var share := _banner.get_node("ShareLabel") as Label
	if share != null:
		share.text = text


func stop() -> void:
	if _stopping:
		return
	_stopping = true
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	map_path = ""
	_handled_scene = 0
	_map_ready = false
	_next_slot = 0
	_slots.clear()
	_pending_spawns.clear()
	tunnel_mode = false
	_clear_players()
	if _banner != null:
		_banner.queue_free()
		_banner = null
	var ngrok := get_node_or_null("/root/NgrokManager")
	if ngrok != null and ngrok.has_method("stop_tunnel"):
		ngrok.call("stop_tunnel")
	_stopping = false


@rpc("authority", "reliable", "call_remote")
func load_map(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("NetworkManager: Map fehlt: %s" % path)
		return
	map_path = path
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("NetworkManager: Map nicht ladbar (%d)." % err)


@rpc("any_peer", "reliable", "call_remote")
func client_map_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 0:
		return
	if not _map_ready:
		if not _pending_spawns.has(id):
			_pending_spawns.append(id)
		return
	_spawn_player(id)


func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)
	if not multiplayer.is_server() or map_path.is_empty():
		return
	load_map.rpc_id(id, map_path)


func _on_peer_disconnected(id: int) -> void:
	peer_left.emit(id)
	_slots.erase(id)
	_pending_spawns.erase(id)
	if not multiplayer.is_server() or _players == null:
		return
	var body := _players.get_node_or_null(str(id))
	if body != null:
		body.queue_free()


func _on_connected_to_server() -> void:
	client_connected.emit()


func _on_connection_failed() -> void:
	# close() in stop() darf nicht als Fehler der Gegenseite zählen und die Session
	# ein zweites Mal schließen.
	if _stopping:
		return
	connection_failed.emit()
	stop()


func _on_server_disconnected() -> void:
	if _stopping:
		return
	session_ended.emit()
	var current := get_tree().current_scene
	stop()
	if current != null and current.scene_file_path != MENU_SCENE:
		get_tree().change_scene_to_file(MENU_SCENE)


func _setup_map(scene: Node) -> void:
	var baked := scene.get_node_or_null("Player") as Player
	if baked == null:
		return
	_spawn_origin = baked.global_position
	_spawn_rotation = baked.global_rotation
	baked.free()
	_map_ready = true
	if not multiplayer.is_server():
		client_map_ready.rpc_id(1)
		return
	_spawn_player(multiplayer.get_unique_id())
	for id: int in _pending_spawns:
		_spawn_player(id)
	_pending_spawns.clear()
	for id: int in multiplayer.get_peers():
		_spawn_player(id)


func _bind_peer(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	# Spawner neu einhängen, damit er den Peer kennt. Der Pfad ist auf jedem
	# Rechner /root/NetworkManager/PlayerSpawner, auch schon im Menü.
	if _spawner != null and _spawner.get_parent() == self:
		remove_child(_spawner)
		add_child(_spawner)
		_spawner.spawn_path = NodePath("../Players")
		_spawner.spawn_function = _spawn_player_node


func _clear_players() -> void:
	if _players == null:
		return
	for child: Node in _players.get_children():
		child.free()


func _spawn_player(id: int) -> void:
	if not multiplayer.is_server() or _spawner == null or _players == null or id <= 0:
		return
	if _players.get_node_or_null(str(id)) != null:
		return
	var slot := _slot_for(id)
	var origin := _spawn_origin + Vector3(float(slot) * 1.6, 0.0, 0.0)
	_spawner.spawn({"id": id, "origin": origin, "rotation": _spawn_rotation})


func _spawn_player_node(data: Variant) -> Node:
	var info: Dictionary = data
	var player := PLAYER_SCENE.instantiate()
	var id := int(info.get("id", 1))
	player.name = str(id)
	player.set_multiplayer_authority(id)
	var origin: Vector3 = info.get("origin", Vector3.ZERO)
	var rotation: Vector3 = info.get("rotation", Vector3.ZERO)
	player.position = origin
	player.rotation = rotation
	return player


func _slot_for(id: int) -> int:
	if _slots.has(id):
		return int(_slots[id])
	var slot := _next_slot
	_next_slot += 1
	_slots[id] = slot
	return slot
