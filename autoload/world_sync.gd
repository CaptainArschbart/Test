extends Node
## Multiplayer-Abgleich der Welt: Beute (Pickups), Granaten, Gegner (NPC) und Geräusche.
##
## Spielerfiguren gleichen sich selbst ab (PlayerAvatarSync, PlayerSync in player.tscn), Treffer
## an Spielern laufen über Player.apply_damage. Für alles andere ist hier der Host zuständig:
##
## Pickups: Jedes ItemPickup hat eine net_id. Pickups aus der Map-Szene heißen "s:<Pfad>", neu
##   erzeugte "<Peer>:<Nummer>" (spawn_pickup). Wer etwas fallen lässt, erzeugt es selbst und
##   schickt es an alle anderen. Aufheben fragt den Host (request_take). Er teilt zu, sagt allen
##   die neue Menge und gibt dem Anfragenden die Items. So kann nichts doppelt aufgehoben werden.
## Granaten: Der Werfer simuliert und macht den Schaden. Die anderen sehen eine Kopie
##   (ThrownGrenade.remote), die erst auf explode_grenade vom Werfer hochgeht, an dessen Stelle.
## NPCs (Gruppe NPC_GROUP, z. B. Enemy und StealthGuard): Nur der Host rechnet die KI. Er schickt
##   alle STATE_INTERVAL Sekunden den Zustand aller NPCs (net_get_state), die Clients zeigen ihn
##   (net_apply_state). Ereignisse wie Schüsse und Rufe kommen über npc_event. Treffer auf einen
##   NPC beim Client gehen per forward_hit an den Host.
## XP: Stirbt ein Gegner beim Host, bekommt der Spieler, der zuletzt getroffen hat, die XP (award_xp).
## Geräusche (StealthNoise) eines Clients gehen zusätzlich an den Host, damit dessen Gegner sie hören.
##
## Ein Client, der später beitritt, bekommt vom Host den Stand der Pickups (_pickup_snapshot).
## Ohne Multiplayer-Peer läuft alles lokal wie vorher.

const NPC_GROUP := &"net_npc"
## Abstand der NPC-Pakete in Sekunden.
const STATE_INTERVAL := 0.1
## Ein NPC, der so lange in keinem Paket vorkam, ist beim Host weg (Leiche abgeräumt).
const NPC_MISSING_TIME := 3.0
const PICKUP_SCENE := preload("res://scenes/items/pickup.tscn")
const GRENADE_SCRIPT := preload("res://scenes/items/grenade.gd")

var _next_id := 0
var _state_timer := 0.0
## Client: wann jeder NPC zuletzt in einem Paket stand (Pfad → Sekunden).
var _npc_seen := {}
var _npc_packets := 0
## Granaten, die gerade fliegen (net_id → ThrownGrenade).
var _grenades := {}
## Host: Peer, dessen weitergeleiteter Treffer gerade verarbeitet wird (0 = eigener Treffer).
var _hit_peer := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var net := get_node_or_null(^"/root/NetworkManager")
	if net != null and net.has_signal(&"client_ready"):
		net.connect(&"client_ready", _on_client_ready)


# --- Rollen -------------------------------------------------------------------------------

## Es gibt eine laufende Verbindung (Host oder Client).
func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer) \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Dieser Rechner entscheidet über die Welt: offline oder Host.
func has_authority() -> bool:
	return not is_online() or multiplayer.is_server()


## Client in einer Sitzung: NPCs sind hier nur Anzeige.
func is_client() -> bool:
	return is_online() and not multiplayer.is_server()


func local_peer() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


## Spielerfigur eines Peers (oder null).
func player_of(peer_id: int) -> Player:
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null:
			continue
		if not is_online():
			return player
		if player.get_multiplayer_authority() == peer_id:
			return player
	return null


func _scene() -> Node:
	return get_tree().current_scene


## Pfad ab der Map-Szene. Läuft auch, während die Szene gerade erst in den Baum kommt.
func _path_of(node: Node) -> String:
	if node == null or not node.is_inside_tree():
		return ""
	var top := node
	while top.get_parent() != null and top.get_parent() != get_tree().root:
		top = top.get_parent()
	if top == node or top.get_parent() == null:
		return ""
	return String(top.get_path_to(node))


func _node_at(path: String) -> Node:
	var scene := _scene()
	if scene == null or path.is_empty():
		return null
	return scene.get_node_or_null(NodePath(path))


func _new_id() -> String:
	_next_id += 1
	return "%d:%d" % [local_peer(), _next_id]


# --- Pickups ------------------------------------------------------------------------------

## Legt ein Item in die Welt und wirft es mit `velocity`. Online sehen es alle.
func spawn_pickup(item: ItemData, count: int, position: Vector3, velocity := Vector3.ZERO,
		pickup_delay := 1.0) -> ItemPickup:
	if item == null or count <= 0:
		return null
	var id := _new_id()
	var pickup := _spawn_pickup_local(id, item, count, position, velocity, pickup_delay)
	if is_online() and pickup != null:
		_spawn_pickup_remote.rpc(id, item.resource_path, count, position, velocity, pickup_delay)
	return pickup


func _spawn_pickup_local(id: String, item: ItemData, count: int, position: Vector3, velocity: Vector3,
		pickup_delay: float) -> ItemPickup:
	var scene := _scene()
	if scene == null:
		return null
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item = item
	pickup.count = count
	pickup.net_id = id
	scene.add_child(pickup)
	pickup.global_position = position
	if velocity != Vector3.ZERO:
		pickup.throw(velocity, pickup_delay)
	return pickup


@rpc("any_peer", "reliable", "call_remote")
func _spawn_pickup_remote(id: String, item_path: String, count: int, position: Vector3, velocity: Vector3,
		pickup_delay: float) -> void:
	var item := _load_item(item_path)
	if item == null or count <= 0 or find_pickup(id) != null:
		return
	_spawn_pickup_local(id, item, count, position, velocity, pickup_delay)


func _load_item(path: String) -> ItemData:
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData


## Pickup mit dieser net_id in der aktuellen Map.
func find_pickup(id: String) -> ItemPickup:
	if id.is_empty():
		return null
	if id.begins_with("s:"):
		var node := _node_at(id.substr(2)) as ItemPickup
		return node if node != null and not node.is_queued_for_deletion() else null
	for node: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var pickup := node as ItemPickup
		if pickup != null and pickup.net_id == id and not pickup.is_queued_for_deletion():
			return pickup
	return null


## net_id für ein Pickup aus der Map-Szene (gleicher Pfad auf jedem Rechner).
func static_pickup_id(pickup: ItemPickup) -> String:
	var path := _path_of(pickup)
	return "s:" + path if not path.is_empty() else ""


## Online-Aufheben: `amount` Stück vom Pickup `id` beim Host anfragen.
func request_take(id: String, amount: int) -> void:
	if amount <= 0:
		return
	if multiplayer.is_server():
		_handle_take(local_peer(), id, amount)
	else:
		_request_take_remote.rpc_id(1, id, amount)


@rpc("any_peer", "reliable", "call_remote")
func _request_take_remote(id: String, amount: int) -> void:
	if not multiplayer.is_server():
		return
	_handle_take(multiplayer.get_remote_sender_id(), id, amount)


func _handle_take(peer_id: int, id: String, amount: int) -> void:
	var pickup := find_pickup(id)
	if pickup == null:
		_deny_take(peer_id, id)
		return
	var granted := clampi(amount, 0, pickup.count)
	if granted <= 0:
		_deny_take(peer_id, id)
		return
	var left := pickup.count - granted
	var item_path := pickup.item.resource_path
	_set_pickup_count_remote.rpc(id, left)
	_apply_pickup_count(id, left)
	if peer_id == local_peer():
		_grant(id, item_path, granted)
	else:
		_grant_remote.rpc_id(peer_id, id, item_path, granted)


func _deny_take(peer_id: int, id: String) -> void:
	if peer_id == local_peer():
		_grant(id, "", 0)
	else:
		_grant_remote.rpc_id(peer_id, id, "", 0)


@rpc("authority", "reliable", "call_remote")
func _set_pickup_count_remote(id: String, count: int) -> void:
	_apply_pickup_count(id, count)


func _apply_pickup_count(id: String, count: int) -> void:
	var pickup := find_pickup(id)
	if pickup == null:
		return
	if count <= 0:
		pickup.queue_free()
	else:
		pickup.set_count(count)


@rpc("authority", "reliable", "call_remote")
func _grant_remote(id: String, item_path: String, amount: int) -> void:
	_grant(id, item_path, amount)


## Antwort des Hosts: Items ins Inventar. Passt inzwischen nicht mehr alles, fällt der Rest vor die Füße.
func _grant(id: String, item_path: String, amount: int) -> void:
	var player := player_of(local_peer())
	var pickup := find_pickup(id)
	if pickup != null:
		pickup.take_pending = false
	if player == null:
		return
	if amount <= 0:
		player.item_user.show_message("Schon weg")
		return
	var item := _load_item(item_path)
	if item == null:
		return
	var left := player.inventory.add_item(item, amount)
	if left > 0:
		spawn_pickup(item, left, player.global_position + Vector3.UP * 0.8, Vector3.UP * 1.5, 0.5)


## Host: Stand aller Pickups für einen Client, der gerade die Map geladen hat.
func _on_client_ready(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var statics := {}
	var dynamic: Array = []
	for node: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var pickup := node as ItemPickup
		if pickup == null or pickup.is_queued_for_deletion() or pickup.item == null:
			continue
		if pickup.net_id.begins_with("s:"):
			statics[pickup.net_id] = pickup.count
		else:
			dynamic.append([pickup.net_id, pickup.item.resource_path, pickup.count, pickup.global_position])
	_pickup_snapshot.rpc_id(peer_id, statics, dynamic)


@rpc("authority", "reliable", "call_remote")
func _pickup_snapshot(statics: Dictionary, dynamic: Array) -> void:
	for node: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var pickup := node as ItemPickup
		if pickup == null or not pickup.net_id.begins_with("s:"):
			continue
		if not statics.has(pickup.net_id):
			pickup.queue_free()
		elif int(statics[pickup.net_id]) != pickup.count:
			pickup.set_count(int(statics[pickup.net_id]))
	for entry: Array in dynamic:
		var id := str(entry[0])
		if find_pickup(id) != null:
			continue
		var item := _load_item(str(entry[1]))
		if item != null:
			_spawn_pickup_local(id, item, int(entry[2]), entry[3], Vector3.ZERO, 0.0)


# --- Granaten -----------------------------------------------------------------------------

## Werfer: Granate den anderen zeigen. Gibt die net_id zurück.
func announce_grenade(grenade: ThrownGrenade) -> void:
	if not is_online() or grenade == null or grenade.data == null:
		return
	grenade.net_id = _new_id()
	_grenades[grenade.net_id] = grenade
	_spawn_grenade_remote.rpc(grenade.net_id, grenade.data.resource_path, grenade.global_position,
		grenade.linear_velocity, local_peer())


@rpc("any_peer", "reliable", "call_remote")
func _spawn_grenade_remote(id: String, data_path: String, position: Vector3, velocity: Vector3,
		thrower_peer: int) -> void:
	var data := _load_item(data_path) as GrenadeData
	var scene := _scene()
	if data == null or scene == null or _grenades.has(id):
		return
	var grenade: ThrownGrenade = GRENADE_SCRIPT.new()
	grenade.data = data
	grenade.remote = true
	grenade.net_id = id
	scene.add_child(grenade)
	grenade.global_position = position
	grenade.linear_velocity = velocity
	var thrower := player_of(thrower_peer)
	if thrower != null:
		grenade.add_collision_exception_with(thrower)
	_grenades[id] = grenade


## Werfer: Explosion an `center` an alle.
func announce_explosion(grenade: ThrownGrenade, center: Vector3) -> void:
	_grenades.erase(grenade.net_id)
	if is_online() and not grenade.net_id.is_empty():
		_explode_grenade_remote.rpc(grenade.net_id, center)


@rpc("any_peer", "reliable", "call_remote")
func _explode_grenade_remote(id: String, center: Vector3) -> void:
	var grenade: ThrownGrenade = _grenades.get(id)
	_grenades.erase(id)
	if grenade != null and is_instance_valid(grenade):
		grenade.explode_remote(center)


func forget_grenade(id: String) -> void:
	_grenades.erase(id)


# --- NPCs ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_online():
		_npc_seen.clear()
		_npc_packets = 0
		return
	if multiplayer.is_server():
		_state_timer -= delta
		if _state_timer <= 0.0:
			_state_timer = STATE_INTERVAL
			_send_npc_states()
	else:
		_drop_missing_npcs()


func _send_npc_states() -> void:
	if multiplayer.get_peers().is_empty():
		return
	var states := {}
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		if not node.has_method("net_get_state"):
			continue
		var path := _path_of(node)
		if not path.is_empty():
			states[path] = node.call("net_get_state")
	_npc_states.rpc(_scene().scene_file_path if _scene() != null else "", states)


@rpc("authority", "unreliable_ordered", "call_remote")
func _npc_states(map_path: String, states: Dictionary) -> void:
	var scene := _scene()
	if scene == null or scene.scene_file_path != map_path:
		return
	var now := Time.get_ticks_msec() / 1000.0
	_npc_packets += 1
	for path: String in states:
		var node := _node_at(path)
		if node != null and node.has_method("net_apply_state"):
			node.call("net_apply_state", states[path])
			_npc_seen[path] = now


## Client: NPCs, die der Host nicht mehr schickt (Leiche abgeräumt), auch hier entfernen.
func _drop_missing_npcs() -> void:
	if _npc_packets < 5:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		var path := _path_of(node)
		if path.is_empty():
			continue
		if not _npc_seen.has(path):
			_npc_seen[path] = now
		elif now - float(_npc_seen[path]) > NPC_MISSING_TIME:
			_npc_seen.erase(path)
			node.queue_free()


## Host: Ereignis eines NPCs (Schuss, Ruf, Treffer, Tod …) an alle Clients.
func npc_event(npc: Node, event: StringName, args: Array = []) -> void:
	if not is_online() or not multiplayer.is_server():
		return
	var path := _path_of(npc)
	if not path.is_empty():
		_npc_event_remote.rpc(path, event, args)


@rpc("authority", "reliable", "call_remote")
func _npc_event_remote(path: String, event: StringName, args: Array) -> void:
	var node := _node_at(path)
	if node != null and node.has_method("net_event"):
		node.call("net_event", event, args)


## Client: Treffer auf einen NPC an den Host. `method` ist take_hit, melee_hit oder emp_hit.
func forward_hit(npc: Node, method: StringName, args: Array) -> void:
	var path := _path_of(npc)
	if path.is_empty():
		return
	_forward_hit_remote.rpc_id(1, path, method, args)


@rpc("any_peer", "reliable", "call_remote")
func _forward_hit_remote(path: String, method: StringName, args: Array) -> void:
	if not multiplayer.is_server():
		return
	if not method in [&"take_hit", &"melee_hit", &"emp_hit"]:
		return
	var node := _node_at(path)
	if node == null or not node.has_method(method):
		return
	var attacker := player_of(multiplayer.get_remote_sender_id())
	if node.has_method("net_set_attacker"):
		node.call("net_set_attacker", attacker)
	_hit_peer = multiplayer.get_remote_sender_id()
	node.callv(method, args)
	_hit_peer = 0


## Host bzw. offline: wer den laufenden Treffer ausgeteilt hat (Peer-Id). Ohne weitergeleiteten
## Treffer ist es dieser Rechner.
func hit_source_peer() -> int:
	return _hit_peer if _hit_peer != 0 else local_peer()


## XP an den Spieler von `peer` (Kill). Offline und beim eigenen Peer direkt, sonst per RPC.
func award_xp(peer: int, amount: int) -> void:
	if amount <= 0 or peer <= 0:
		return
	if not is_online() or peer == local_peer():
		_add_local_xp(amount)
	elif multiplayer.is_server():
		_xp_remote.rpc_id(peer, amount)


@rpc("authority", "reliable", "call_remote")
func _xp_remote(amount: int) -> void:
	_add_local_xp(clampi(amount, 0, 1000))


func _add_local_xp(amount: int) -> void:
	var player := player_of(local_peer())
	if player != null and player.xp != null:
		player.xp.add_xp(amount)


## Ein Spieler ist nach dem Tod respawnt: Gegner, die ihn gejagt haben, vergessen ihn.
## Offline wie früher alle, online nur die NPCs mit ihm als Ziel (beim Host).
func notify_revived(player: Player) -> void:
	if not is_online():
		for listener: Node in get_tree().get_nodes_in_group(StealthNoise.GROUP):
			if listener.has_method("reset_alert"):
				listener.call("reset_alert")
	elif multiplayer.is_server():
		_reset_npcs_for(player)
	else:
		_revived_remote.rpc_id(1)


@rpc("any_peer", "reliable", "call_remote")
func _revived_remote() -> void:
	if multiplayer.is_server():
		_reset_npcs_for(player_of(multiplayer.get_remote_sender_id()))


func _reset_npcs_for(player: Player) -> void:
	if player == null:
		return
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		if node.has_method("net_targets") and node.call("net_targets", player) and node.has_method("reset_alert"):
			node.call("reset_alert")


# --- Geräusche ----------------------------------------------------------------------------

## Client: eigenes Geräusch auch beim Host hörbar machen (StealthNoise.emit ruft das auf).
func forward_noise(position: Vector3, radius: float, kind: StringName) -> void:
	if is_client():
		_noise_remote.rpc_id(1, position, radius, kind)


@rpc("any_peer", "unreliable", "call_remote")
func _noise_remote(position: Vector3, radius: float, kind: StringName) -> void:
	if not multiplayer.is_server() or radius <= 0.0 or radius > 80.0:
		return
	var source := player_of(multiplayer.get_remote_sender_id())
	StealthNoise.emit_local(get_tree(), position, radius, source, kind)
