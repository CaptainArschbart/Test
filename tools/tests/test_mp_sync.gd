extends SceneTree
## Prüft den Multiplayer-Abgleich mit zwei Prozessen auf diesem Rechner (WorldSync, PvP, Gegner).
##
## Aufruf (Projektordner), zwei Prozesse gleichzeitig, Host zuerst:
##   godot --headless --path . -s res://tools/tests/test_mp_sync.gd -- host testmap
##   godot --headless --path . -s res://tools/tests/test_mp_sync.gd -- client testmap
## Statt "testmap" geht "slum" (Sektor 7 mit Gegnern). Bei "slum" startet der Host über das
## Hauptmenü (Map-Auswahl in der Lobby), sonst direkt über NetworkManager.host_map.
##
## testmap: Pickups (fallen lassen, aufheben, gleichzeitig greifen), PvP-Schuss, Granate eines
##          anderen Spielers, Testwache (StealthGuard) nur beim Host gerechnet, Skills pro Spieler.
## slum:    Map-Wahl im Menü, Gegner folgen dem Host, Treffer vom Client, Tod und Beute bei beiden,
##          Gegner wählen den nächsten Spieler und ihr Schaden kommt beim Client an.
## Beide Prozesse laufen nach demselben Zeitplan (Phasen ab dem Moment, in dem beide Figuren da
## sind). Ergebnis in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const MAPS := {
	"testmap": "res://scenes/testmap/testmap.tscn",
	"slum": "res://scenes/slum/slum.tscn",
}
const PORT := 7793
const ITEM := "res://scenes/items/data/%s.tres"

var _checks := 0
var _fails := 0
var _host := false
var _map := "testmap"
var _start := 0
var _me: Node
var _other: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_host = args.has("host")
	if args.has("slum"):
		_map = "slum"
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + ("[host] " if _host else "[client] ") + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _sync() -> Node:
	return root.get_node(^"WorldSync")


func _players() -> Array[Node]:
	return get_nodes_in_group("player")


func _wait_for(condition: Callable, timeout_ms := 15000) -> bool:
	var begin := Time.get_ticks_msec()
	while Time.get_ticks_msec() - begin < timeout_ms:
		if condition.call():
			return true
		await process_frame
	return false


## Wartet bis `seconds` nach dem gemeinsamen Start (beide Figuren da).
func _phase(seconds: float) -> void:
	while Time.get_ticks_msec() - _start < int(seconds * 1000.0):
		await process_frame


func _hp(player: Node) -> float:
	return float(player.get("stats").get("hp"))


func _run() -> void:
	var net := root.get_node(^"NetworkManager")
	var path: String = MAPS[_map]
	if _host:
		if _map == "slum":
			await _host_via_menu(path)
		else:
			var err: int = net.call("host_map", path, PORT, false)
			_check(err == OK, "Host gestartet")
			change_scene_to_file(path)
	else:
		await create_timer(4.0 if _map == "slum" else 3.0).timeout
		var err: int = net.call("create_client", "127.0.0.1", PORT)
		_check(err == OK, "Client verbindet")
	var both := await _wait_for(_have_both, 90000)
	_check(both, "Beide Spieler in der Map (%d)" % _players().size())
	if not both:
		_finish()
		return
	for player: Node in _players():
		if player.get_parent() == current_scene:
			continue
		if bool(player.call("controls_local_body")):
			_me = player
		else:
			_other = player
	_start = Time.get_ticks_msec()
	_check(current_scene.scene_file_path == path, "Map ist %s" % current_scene.scene_file_path.get_file())
	await _phase(2.0)
	if _map == "slum":
		await _run_slum()
	else:
		await _run_testmap()
	await _phase(40.0 if _map == "testmap" else 30.0)
	_finish()


# --- Map-Wahl (Host über das Menü) -------------------------------------------------------

func _host_via_menu(path: String) -> void:
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await _frames(10)
	var menu := current_scene
	var select := menu.find_child("MapSelect", true, false) as OptionButton
	_check(select != null and select.item_count >= 2, "Lobby hat eine Map-Auswahl (%d Maps)" % (select.item_count if select else 0))
	if select == null:
		return
	var index := -1
	for i in select.item_count:
		if str(select.get_item_metadata(i)) == path:
			index = i
	select.select(index)
	select.item_selected.emit(index)
	(menu.get("_host_port") as LineEdit).text = str(PORT)
	menu.call("_on_host_port_pressed")
	var net := root.get_node(^"NetworkManager")
	_check(str(net.get("map_path")) == path, "Host-Map ist die gewählte (%s)" % str(net.get("map_path")).get_file())
	menu.call("_on_play_online_pressed")


# --- Testmap -------------------------------------------------------------------------------

func _run_testmap() -> void:
	var sync := _sync()
	var inventory: Node = _me.get("inventory")
	_me.set("dead", false)
	# Feste Plätze: Host bei (0, 0.2, 40), Client 4 m daneben. Nahe beieinander für Schuss und Granate.
	var base := Vector3(-4.0, 0.2, 40.0)
	_me.set("global_position", base if _host else base + Vector3(4.0, 0.0, 0.0))
	await _phase(4.0)

	# 1) Statische Pickups haben auf beiden Rechnern dieselbe Kennung.
	var street := current_scene.get_node_or_null(^"Pickups/SpawnPoints/Spot_Street/Pickup")
	_check(street != null and str(street.get("net_id")) == "s:Pickups/SpawnPoints/Spot_Street/Pickup",
		"Map-Pickup hat net_id %s" % (street.get("net_id") if street else "-"))

	# 2) Client lässt einen Drink fallen, der Host sieht ihn und hebt ihn auf.
	if not _host:
		inventory.call("add_item", load(ITEM % "energy_drink"), 1, false)
		var slot := _slot_of(inventory, "energy_drink")
		_me.call("drop_item", slot, 1)
	# Der Client prüft gleich nach dem Wurf, der Host wartet, bis der Drink bei ihm ankommt.
	var arrived := await _wait_for(func() -> bool:
		return _find_pickup_with_prefix("energy_drink", "%d:" % _client_peer()) != null, 3000)
	_check(arrived, "Fallengelassener Drink des Clients ist da")
	await _phase(7.0)
	var dropped := _find_pickup_with_prefix("energy_drink", "%d:" % _client_peer())
	if _host and dropped != null:
		dropped.set("_pickup_delay", 0.0)
		var before := _count_of(inventory, "energy_drink")
		dropped.call("interact", _me)
		var got := await _wait_for(func() -> bool: return _count_of(inventory, "energy_drink") > before, 5000)
		_check(got, "Host hat den Drink aufgehoben")
	await _phase(10.0)
	_check(_find_pickup_with_prefix("energy_drink", "%d:" % _client_peer()) == null,
		"Aufgehobener Drink ist auf beiden Rechnern weg")

	# 3) Doppelte Anfrage: Der Client fragt zweimal direkt hintereinander nach demselben Stapel
	#    (5 Data-Shards). Der Host darf ihn nur einmal ausgeben.
	var plaza := current_scene.get_node_or_null(^"Pickups/SpawnPoints/Spot_Plaza3/Pickup")
	_check(plaza != null, "Stapel Spot_Plaza3 liegt noch da")
	var plaza_count := int(plaza.get("count")) if plaza != null else 0
	var had := _count_of(inventory, "data_shard")
	if not _host and plaza != null:
		var id := str(plaza.get("net_id"))
		sync.call("request_take", id, plaza_count)
		sync.call("request_take", id, plaza_count)
	await _phase(13.0)
	if not _host:
		var gained := _count_of(inventory, "data_shard") - had
		_check(gained == plaza_count and plaza_count > 0,
			"Doppelte Anfrage: genau einmal %d bekommen (%d)" % [plaza_count, gained])
	else:
		_check(_count_of(inventory, "data_shard") == had, "Host hat nichts davon bekommen")
	_check(not is_instance_valid(plaza) or plaza.is_queued_for_deletion(), "Stapel ist auf beiden Rechnern weg")

	# 4) PvP: Client schießt mit der Pistole auf den Host.
	if not _host:
		_equip(inventory, "pistol")
		await _frames(3)
		var target: Vector3 = (_other as Node3D).global_position + Vector3.UP * 1.1
		_aim_at(target)
		await _frames(1)
		var holder: Node = _me.get("weapon_holder")
		_check(bool(holder.call("try_fire")), "Client schießt")
	var hp_before := _hp(_me)
	await _phase(17.0)
	if _host:
		var hp := _hp(_me)
		_check(hp < hp_before and hp >= hp_before - 40.0, "Host getroffen: %.0f → %.0f HP" % [hp_before, hp])
		_check(_me.get("stats").get("last_damage_cause") == &"pvp", "Ursache pvp")

	# 5) Granate: Host zündet eine Kontaktgranate 3 m vor dem Client.
	var client_hp := _hp(_me)
	if _host:
		var grenade: RigidBody3D = load("res://scenes/items/grenade.gd").new()
		grenade.set("data", load(ITEM % "contact_grenade"))
		grenade.set("thrower", _me)
		grenade.freeze = true
		current_scene.add_child(grenade)
		grenade.global_position = (_other as Node3D).global_position + Vector3(-3.0, 1.0, 0.0)
		sync.call("announce_grenade", grenade)
		await create_timer(0.5).timeout
		grenade.call("explode")
	else:
		var seen := await _wait_for(func() -> bool: return _remote_grenades() > 0, 8000)
		_check(seen, "Granate des Hosts ist beim Client zu sehen")
	await _phase(21.0)
	if not _host:
		var hp := _hp(_me)
		_check(hp < client_hp - 20.0, "Client von Granate getroffen: %.0f → %.0f HP" % [client_hp, hp])
		_check(_me.get("stats").get("last_damage_cause") == &"pvp_grenade", "Ursache pvp_grenade")
		_check(_remote_grenades() == 0, "Granaten-Kopie ist explodiert und weg")

	# 6) Testwache: Host stellt sie um, der Client sieht sie dort. Treffer vom Client zählen beim Host.
	var guard: Node3D = null
	for node: Node in get_nodes_in_group("stealth_guard"):
		guard = node as Node3D
	_check(guard != null, "Testwache gefunden")
	if guard == null:
		return
	var spot := guard.global_position + Vector3(1.5, 0.0, 0.0)
	var health_before := float(guard.get("health"))
	if _host:
		# KI anhalten, damit die Stelle fest bleibt. Pakete und Treffer laufen trotzdem.
		guard.set_physics_process(false)
		guard.global_position = spot
	await _phase(25.0)
	if not _host:
		_check(guard.global_position.distance_to(spot) < 2.5,
			"Wache beim Client an der Stelle des Hosts (%.1f m daneben)" % guard.global_position.distance_to(spot))
		guard.call("take_hit", 30.0, guard.global_position + Vector3.UP, Vector3.FORWARD)
	await _phase(29.0)
	_check(float(guard.get("health")) <= health_before - 29.0,
		"Wache hat 30 Schaden vom Client (%.0f → %.0f)" % [health_before, float(guard.get("health"))])

	# 7) Skills: Der Client lernt Zäh und Flinke Finger, der Host kennt sie an dessen Figur (z. B. für
	#    den Taschendiebstahl, den nur der Host rechnet). Der Host lernt Feilscher, der Client sieht es.
	var skills: Node = _me.get("skills")
	skills.call("set_level", 3)
	if _host:
		skills.call("learn", &"endurance")
		skills.call("learn", &"haggler")
	else:
		skills.call("learn", &"tough")
		skills.call("learn", &"quick_fingers")
	await _phase(32.0)
	var remote: Node = _other.get("skills")
	if _host:
		_check(bool(remote.call("has", &"tough")) and bool(remote.call("has", &"quick_fingers")),
			"Host kennt die Skills des Clients (%s)" % str(remote.call("to_dict")))
		_check(is_equal_approx(float(_other.call("skill_mult", &"pick_time_mult")), 0.65),
			"Taschendiebstahl-Faktor des Clients beim Host")
		_check(not bool(remote.call("has", &"haggler")), "Skills des Hosts nicht an der Client-Figur")
	else:
		_check(bool(remote.call("has", &"haggler")) and bool(remote.call("has", &"endurance")),
			"Client kennt die Skills des Hosts (%s)" % str(remote.call("to_dict")))
		_check(is_equal_approx(float(_me.get("stats").get("max_hp")), 125.0), "Zäh wirkt beim Client (125 max HP)")


# --- Sektor 7 ----------------------------------------------------------------------------

func _run_slum() -> void:
	var enemy := _first_enemy()
	_check(enemy != null, "Gegner in Sektor 7")
	if enemy == null:
		return
	_check(bool(enemy.is_in_group("net_npc")), "Gegner sind NPCs für WorldSync")
	var spot := Vector3(0.0, 0.0, 0.0)
	# 1) Host stellt einen Gegner neben den Client. Der Client sieht ihn dort.
	if _host:
		spot = (_other as Node3D).global_position + Vector3(3.0, 0.0, 0.0)
		enemy.set("lod", 2)
		enemy.set_physics_process(false)
		enemy.global_position = spot
		await _frames(2)
		enemy.set("_retarget_at", 0)
		enemy.call("_find_player")
		_check(enemy.get("_player") == _other, "Gegner jagt den nächsten Spieler (Client)")
		# Schaden eines Gegners an den Client (läuft über Player.apply_damage).
		(enemy.get("_player") as Node).call("apply_damage", 7.0, &"gang_shot")
	var hp_before := _hp(_me)
	await _phase(6.0)
	if not _host:
		var near := enemy.global_position.distance_to((_me as Node3D).global_position)
		_check(near < 5.0, "Gegner steht beim Client (%.1f m)" % near)
		_check(_hp(_me) <= hp_before - 6.9 or _me.get("stats").get("last_damage_cause") == &"gang_shot",
			"Gegner-Schaden kam beim Client an (%.0f HP)" % _hp(_me))
		# 2) Client erledigt ihn.
		enemy.call("take_hit", 1000.0, enemy.global_position + Vector3.UP, Vector3.FORWARD)
	await _phase(10.0)
	_check(bool(enemy.call("is_dead")), "Gegner ist tot (%s)" % ("Host" if _host else "Client"))
	var loot := 0
	for node: Node in get_nodes_in_group("item_pickup"):
		if (node as Node3D).global_position.distance_to(enemy.global_position) < 4.0:
			loot += 1
	_check(loot >= 1, "Beute liegt beim Toten (%d Pickups)" % loot)
	# 3) Zweiter Gegner: Client hat keine eigene KI, Position kommt vom Host.
	if not _host:
		var other := _first_enemy()
		_check(other != null and other.get("_net_position") != Vector3.INF,
			"Lebende Gegner beim Client bekommen Pakete vom Host")


# --- Hilfen -------------------------------------------------------------------------------

## Eigene Figur und eine fremde sind da (die Figur aus der Map-Datei zählt nicht).
func _have_both() -> bool:
	var local := false
	var remote := false
	for player: Node in _players():
		if player.get_parent() == current_scene:
			continue
		if bool(player.call("controls_local_body")):
			local = true
		else:
			remote = true
	return local and remote


func _client_peer() -> int:
	if _host:
		return _other.get_multiplayer_authority()
	return _me.get_multiplayer_authority()


func _first_enemy() -> Node3D:
	var list := get_nodes_in_group("enemy")
	list.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	return list[0] as Node3D if not list.is_empty() else null


func _slot_of(inventory: Node, id: String) -> int:
	for i: int in int(inventory.call("get_size")):
		var item: Resource = inventory.call("get_item", i)
		if item != null and item.get("id") == id:
			return i
	return -1


func _count_of(inventory: Node, id: String) -> int:
	var total := 0
	for i: int in int(inventory.call("get_size")):
		var item: Resource = inventory.call("get_item", i)
		if item != null and item.get("id") == id:
			total += int(inventory.call("get_count", i))
	return total


func _equip(inventory: Node, id: String) -> void:
	inventory.call("add_item", load(ITEM % id), 1, false)
	inventory.call("select", _slot_of(inventory, id))


func _aim_at(target: Vector3) -> void:
	var me := _me as Node3D
	var camera: Camera3D = _me.get("camera")
	var flat := Vector3(target.x - me.global_position.x, 0.0, target.z - me.global_position.z)
	me.rotation.y = atan2(-flat.x, -flat.z)
	var head: Node3D = _me.get("head")
	var rise := target.y - camera.global_position.y
	head.rotation.x = atan2(rise, flat.length())


func _find_pickup_with_prefix(item_id: String, prefix: String) -> Node:
	for node: Node in get_nodes_in_group("item_pickup"):
		if node.is_queued_for_deletion():
			continue
		var item: Resource = node.get("item")
		if item != null and item.get("id") == item_id and str(node.get("net_id")).begins_with(prefix):
			return node
	return null


func _remote_grenades() -> int:
	var found := 0
	for node: Node in current_scene.get_children():
		if node is RigidBody3D and bool(node.get("remote")) and not node.is_queued_for_deletion():
			found += 1
	return found



func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
