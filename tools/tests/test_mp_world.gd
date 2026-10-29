extends SceneTree
## Prüft den Multiplayer-Abgleich von Autos, Fußgängern und XP mit zwei Prozessen in Sektor 7.
##
## Aufruf (Projektordner), zwei Prozesse gleichzeitig, Host zuerst:
##   godot --headless --path . -s res://tools/tests/test_mp_world.gd -- host
##   godot --headless --path . -s res://tools/tests/test_mp_world.gd -- client
##
## Ablauf (Sekunden ab dem Moment, in dem beide Figuren da sind):
##   3 s   Client hat die Autos und Fußgänger des Hosts als Kopien, sie bewegen sich.
##   6 s   Host erledigt Civilian1, der Client sieht ihn bei 10 s tot.
##   10 s  Client erledigt Civilian2 (Treffer geht an den Host), der Host sieht ihn bei 14 s tot.
##   14 s  Client erledigt einen Gegner. Die XP landen beim Client, nicht beim Host.
## Ergebnis in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const SLUM := "res://scenes/slum/slum.tscn"
const PORT := 7797

var _checks := 0
var _fails := 0
var _host := false
var _start := 0
var _me: Node


func _initialize() -> void:
	_host = OS.get_cmdline_user_args().has("host")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + ("[host] " if _host else "[client] ") + what)


func _wait_for(condition: Callable, timeout_ms := 15000) -> bool:
	var begin := Time.get_ticks_msec()
	while Time.get_ticks_msec() - begin < timeout_ms:
		if condition.call():
			return true
		await process_frame
	return false


func _phase(seconds: float) -> void:
	while Time.get_ticks_msec() - _start < int(seconds * 1000.0):
		await process_frame


func _have_both() -> bool:
	var local := false
	var remote := false
	for player: Node in get_nodes_in_group("player"):
		if player.get_parent() == current_scene:
			continue
		if bool(player.call("controls_local_body")):
			local = true
			_me = player
		else:
			remote = true
	return local and remote


func _run() -> void:
	var net := root.get_node(^"NetworkManager")
	if _host:
		var err: int = net.call("host_map", SLUM, PORT, false)
		_check(err == OK, "Host gestartet")
		change_scene_to_file(SLUM)
	else:
		await create_timer(4.0).timeout
		_check(int(net.call("create_client", "127.0.0.1", PORT)) == OK, "Client verbindet")
	var both := await _wait_for(_have_both, 90000)
	_check(both, "Beide Spieler in Sektor 7")
	if not both:
		_finish()
		return
	_start = Time.get_ticks_msec()
	await _phase(3.0)
	await _check_traffic()
	await _check_crowd()
	await _check_xp()
	await _phase(22.0)
	_finish()


func _traffic() -> Node:
	return get_first_node_in_group("traffic_director")


func _crowd() -> Node:
	return get_first_node_in_group("crowd_director")


func _check_traffic() -> void:
	var traffic := _traffic()
	_check(traffic != null, "TrafficDirector vorhanden")
	if traffic == null:
		return
	var cars: Array = traffic.get("cars")
	var puppets := cars.filter(func(c: Node) -> bool: return bool(c.get("net_puppet")))
	if _host:
		_check(cars.size() >= 10 and puppets.is_empty(), "Host fährt %d Autos selbst" % cars.size())
		return
	_check(cars.size() >= 10 and puppets.size() == cars.size(), "Client zeigt %d Autos als Kopie" % cars.size())
	if cars.is_empty():
		return
	var car := cars[0] as Node3D
	var before := car.global_position
	var moved := false
	for i in 40:
		await physics_frame
		var any := false
		for c: Node3D in cars:
			if is_instance_valid(c) and float(c.get("speed")) > 1.0:
				any = true
		if any:
			moved = true
			break
	_check(moved, "Autos beim Client fahren (Tempo vom Host)")
	_check(car.global_position.distance_to(before) < 20.0, "Auto springt nicht wild")


func _check_crowd() -> void:
	var crowd := _crowd()
	_check(crowd != null, "CrowdDirector vorhanden")
	if crowd == null:
		return
	var civs: Array = crowd.get("civilians")
	if _host:
		_check(civs.size() >= 20, "Host rechnet %d Fußgänger" % civs.size())
	else:
		var puppets := civs.filter(func(c: Node) -> bool: return bool(c.get("net_puppet")))
		_check(civs.size() >= 20 and puppets.size() == civs.size(), "Client zeigt %d Fußgänger als Kopie" % civs.size())
	var first := crowd.get_node_or_null(^"Civilian1")
	var second := crowd.get_node_or_null(^"Civilian2")
	_check(first != null and second != null, "Civilian1 und Civilian2 gibt es auf beiden Seiten")
	if first == null or second == null:
		return
	await _phase(6.0)
	if _host:
		first.call("take_hit", 999.0, (first as Node3D).global_position + Vector3.UP, Vector3.FORWARD)
	await _phase(10.0)
	if not _host:
		_check(bool(first.call("is_dead")), "Vom Host erledigter Fußgänger ist beim Client tot")
		second.call("take_hit", 999.0, (second as Node3D).global_position + Vector3.UP, Vector3.FORWARD)
	await _phase(14.0)
	if _host:
		_check(bool(second.call("is_dead")), "Treffer vom Client tötet den Fußgänger beim Host")


func _check_xp() -> void:
	var xp: Node = _me.get("xp")
	_check(xp != null, "Eigene Figur hat PlayerXp")
	var enemies := get_nodes_in_group("enemy")
	enemies.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	var enemy: Node = enemies[0] if not enemies.is_empty() else null
	_check(enemy != null, "Gegner vorhanden")
	if enemy == null or xp == null:
		return
	var reward := int(enemy.get("profile").get("xp_reward"))
	if not _host:
		enemy.call("take_hit", 1000.0, (enemy as Node3D).global_position + Vector3.UP, Vector3.FORWARD)
	await _phase(18.0)
	_check(bool(enemy.call("is_dead")), "Gegner ist tot")
	if _host:
		_check(int(xp.get("total_xp")) == 0, "Host bekommt keine XP für den Kill des Clients (%d)" % xp.get("total_xp"))
	else:
		_check(int(xp.get("total_xp")) == reward, "Client bekommt %d XP für seinen Kill (%d)" % [reward, xp.get("total_xp")])


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
