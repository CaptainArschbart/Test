extends Node
## Anbau-Stationen (GrowStation) im Multiplayer und im Spielstand.
##
## Multiplayer: Der Host rechnet die Zeit (Wachstum, Trocknen, Fermentieren) und schickt alle
##   STATE_INTERVAL Sekunden den Zustand jeder geänderten Station. Clients rechnen nicht selbst.
##   Aufstellen und Abbauen schickt der Spieler an alle (_spawn_remote, _remove_remote). Bedient
##   ein Client eine Station, ändert er sie sofort bei sich und schickt den neuen Zustand mit
##   erhöhter Revision an den Host. Der Host übernimmt ihn, wenn die Revision neuer ist, und gibt
##   ihn an alle weiter. Pakete mit älterer Revision werden verworfen. Spät beitretende Clients
##   bekommen alle Stationen (_snapshot).
## Spielstand: Offline und beim Host stehen die Stationen jeder Map in save_path (eine Sektion je
##   Map-Szene). Gespeichert wird alle SAVE_INTERVAL Sekunden, beim Verlassen der Map und beim
##   Beenden, geladen beim Betreten der Map. Während das Spiel aus ist, steht die Zeit still.
##   Headless (Tests, Server ohne Fenster) ist das Speichern aus, außer save_enabled wird gesetzt.

const SAVE_PATH := "user://grow_world.cfg"
const STATE_INTERVAL := 1.0
const SAVE_INTERVAL := 30.0
const StationScript := preload("res://scenes/grow/grow_station.gd")

var save_enabled := true
var save_path := SAVE_PATH

var _scene: Node
var _state_timer := 0.0
var _save_timer := 0.0
## Host: zuletzt gesendeter Zustand je Station (net_id → Hash).
var _sent := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_enabled = DisplayServer.get_name() != "headless"
	var net := get_node_or_null(^"/root/NetworkManager")
	if net != null and net.has_signal(&"client_ready"):
		net.connect(&"client_ready", _on_client_ready)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_enter_scene(scene)
	if _scene == null:
		return
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL:
		_save_timer = 0.0
		save_now()
	if WorldSync.is_online() and multiplayer.is_server():
		_state_timer += delta
		if _state_timer >= STATE_INTERVAL:
			_state_timer = 0.0
			_send_states()


func stations() -> Array:
	var list: Array = []
	for node: Node in get_tree().get_nodes_in_group(StationScript.GROUP):
		if not node.is_queued_for_deletion() and node.get("net_id") != "":
			list.append(node)
	return list


func find(id: String) -> Node:
	for node: Node in get_tree().get_nodes_in_group(StationScript.GROUP):
		if node.get("net_id") == id and not node.is_queued_for_deletion():
			return node
	return null


## Läuft die Zeit der Stationen hier? (Offline und beim Host.)
func simulates() -> bool:
	return WorldSync.has_authority()


# --- Von den Stationen und dem Aufsteller --------------------------------------------------

## Neue Station steht (schon im Baum, Transform gesetzt): Kennung vergeben, allen zeigen.
func placed(station: Node) -> void:
	if station.get("net_id") == "":
		station.set("net_id", "%d:%08x%04x" % [WorldSync.local_peer(), randi(), Time.get_ticks_msec() & 0xffff])
	if WorldSync.is_online():
		_spawn_remote.rpc(_entry(station))


## Der lokale Spieler hat die Station bedient.
func changed(station: Node) -> void:
	station.set("net_rev", int(station.get("net_rev")) + 1)
	if not WorldSync.is_online():
		return
	var state: Dictionary = station.call("net_state")
	if multiplayer.is_server():
		_state_remote.rpc(station.get("net_id"), state)
	else:
		_client_state.rpc_id(1, station.get("net_id"), state)


## Der lokale Spieler hat die Station abgebaut.
func removed(station: Node) -> void:
	if WorldSync.is_online():
		_remove_remote.rpc(station.get("net_id"))


# --- Netz ----------------------------------------------------------------------------------

func _entry(station: Node) -> Dictionary:
	var source: ItemData = station.get("source")
	return {
		"id": station.get("net_id"),
		"kind": String(station.get("kind")),
		"item": source.resource_path if source != null else "",
		"xform": (station as Node3D).global_transform,
		"state": station.call("net_state"),
	}


## Station aus einem Eintrag (_entry) anlegen oder angleichen.
func _apply_entry(entry: Dictionary) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var id := str(entry.get("id", ""))
	var station := find(id)
	if station == null:
		var path := str(entry.get("item", ""))
		var item: ItemData = load(path) as ItemData if path != "" and ResourceLoader.exists(path) else null
		station = StationScript.create(StringName(str(entry.get("kind", "pot"))), item)
		station.set("net_id", id)
		scene.add_child(station)
		(station as Node3D).global_transform = entry.get("xform", Transform3D.IDENTITY)
	station.call("net_apply", entry.get("state", {}), true)
	return station


@rpc("any_peer", "reliable", "call_remote")
func _spawn_remote(entry: Dictionary) -> void:
	_apply_entry(entry)


@rpc("any_peer", "reliable", "call_remote")
func _remove_remote(id: String) -> void:
	var station := find(id)
	if station != null:
		station.queue_free()
	_sent.erase(id)


@rpc("any_peer", "reliable", "call_remote")
func _client_state(id: String, state: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var station := find(id)
	if station == null:
		return
	if int(state.get("rev", 0)) > int(station.get("net_rev")):
		station.call("net_apply", state, true)
		_state_remote.rpc(id, station.call("net_state"))
	else:
		# Jemand war schneller: dem Absender den gültigen Stand zurückgeben.
		_state_remote.rpc_id(multiplayer.get_remote_sender_id(), id, station.call("net_state"))


@rpc("authority", "reliable", "call_remote")
func _state_remote(id: String, state: Dictionary) -> void:
	var station := find(id)
	if station != null:
		station.call("net_apply", state, false)


@rpc("authority", "reliable", "call_remote")
func _states_remote(states: Dictionary) -> void:
	for id: String in states:
		_state_remote(id, states[id])


func _send_states() -> void:
	var states := {}
	for station: Node in stations():
		var id: String = station.get("net_id")
		var state: Dictionary = station.call("net_state")
		var h := hash(state)
		if _sent.get(id, 0) != h:
			_sent[id] = h
			states[id] = state
	if not states.is_empty():
		_states_remote.rpc(states)


## Host: alle Stationen an einen Client, der gerade die Map geladen hat.
func _on_client_ready(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var list: Array = []
	for station: Node in stations():
		list.append(_entry(station))
	_snapshot.rpc_id(peer_id, list)


@rpc("authority", "reliable", "call_remote")
func _snapshot(list: Array) -> void:
	var ids := {}
	for entry: Dictionary in list:
		ids[str(entry.get("id", ""))] = true
		_apply_entry(entry)
	for station: Node in stations():
		if not ids.has(station.get("net_id")):
			station.queue_free()


# --- Spielstand ----------------------------------------------------------------------------

func _map_key(scene: Node) -> String:
	return scene.scene_file_path if scene != null else ""


func _enter_scene(scene: Node) -> void:
	_scene = scene
	_sent.clear()
	_save_timer = 0.0
	if scene == null or _map_key(scene) == "":
		return
	scene.tree_exiting.connect(save_now)
	if simulates():
		load_stations.call_deferred()


## Stationen der aktuellen Map speichern (offline oder Host).
func save_now() -> Error:
	if not save_enabled or not simulates() or _scene == null or not is_instance_valid(_scene):
		return ERR_UNAVAILABLE
	var key := _map_key(_scene)
	if key == "":
		return ERR_UNAVAILABLE
	var config := ConfigFile.new()
	config.load(save_path)
	var list: Array = []
	for station: Node in stations():
		if _scene.is_ancestor_of(station):
			list.append(_entry(station))
	if list.is_empty() and not config.has_section(key):
		return OK
	config.set_value(key, "stations", list)
	config.set_value(key, "saved_unix", int(Time.get_unix_time_from_system()))
	return config.save(save_path)


## Stationen der aktuellen Map aus save_path aufstellen. Gibt die Anzahl zurück.
func load_stations() -> int:
	if not save_enabled or _scene == null or not is_instance_valid(_scene):
		return 0
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return 0
	var list: Array = config.get_value(_map_key(_scene), "stations", [])
	var count := 0
	for entry in list:
		if entry is Dictionary and find(str(entry.get("id", ""))) == null:
			if _apply_entry(entry) != null:
				count += 1
	return count
