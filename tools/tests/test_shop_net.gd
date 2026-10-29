extends SceneTree
## Prüft die Läden im Multiplayer mit zwei Prozessen (Host und Client) in Sektor 7.
##
## Aufruf (Projektordner), zwei Prozesse gleichzeitig, Host zuerst:
##   godot --headless --path . -s res://tools/tests/test_shop_net.gd -- host
##   godot --headless --path . -s res://tools/tests/test_shop_net.gd -- client
## Ablauf: Der Host schickt den Verkäufer von Laden A nach hinten, der Client klaut dort unbemerkt
## (Item beim Client, Regal bei beiden leer). Der Client erschießt den Verkäufer von Laden B (Treffer
## gehen an den Host, Tod bei beiden) und räumt die Kasse aus (Geld beim Client, Kasse bei beiden leer).
## Ergebnis in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const SLUM := "res://scenes/slum/slum.tscn"
const PORT := 7795

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


func _shops() -> Array:
	var list := get_nodes_in_group("shop_interior")
	list.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	return list


func _count(id: String) -> int:
	var inventory: Node = _me.get("inventory")
	var total := 0
	for i: int in int(inventory.call("get_size")):
		var item: Resource = inventory.call("get_item", i)
		if item != null and item.get("id") == id:
			total += int(inventory.call("get_count", i))
	return total


func _run() -> void:
	var net := root.get_node(^"NetworkManager")
	if _host:
		_check(int(net.call("host_map", SLUM, PORT, false)) == OK, "Host gestartet")
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
	var shops := _shops()
	_check(shops.size() >= 40, "%d Läden" % shops.size())
	var a: Node = shops[5]
	var b: Node = shops[6]
	var inventory: Node = _me.get("inventory")

	# 1) Klauen, während der Verkäufer hinten ist.
	await _phase(2.0)
	if _host:
		a.set("busy", true)
		a.set("_busy_left", 60.0)
	await _phase(5.0)
	var items: Array = a.get("slot_items")
	var id := str((items[0] as Resource).get("id"))
	var stock_before := int(a.call("stock_left"))
	if not _host:
		_check(bool(a.get("busy")), "Client sieht: Verkäufer ist hinten")
		var before := _count(id)
		(a.get("_goods") as Array)[0].call("interact", _me)
		var got := await _wait_for(func() -> bool: return _count(id) > before, 5000)
		_check(got, "Client hat %s geklaut" % id)
	await _phase(9.0)
	_check(not bool(a.get("stock")[0]), "Regalplatz ist bei beiden leer")
	_check(int(a.get("keeper_state")) == 0, "Kein Alarm")

	# 2) Client erschießt den Verkäufer von Laden B und räumt die Kasse aus.
	var cash := int(b.get("cash"))
	if not _host:
		var keeper: Node = b.get("_keeper")
		keeper.call("take_hit", 35.0, Vector3.ZERO, Vector3.FORWARD)
		keeper.call("take_hit", 35.0, Vector3.ZERO, Vector3.FORWARD)
	await _phase(13.0)
	_check(int(b.get("keeper_state")) == 3, "Verkäufer von Laden B ist bei beiden tot")
	if not _host:
		inventory.call("take_all_money")
		b.get("_register").call("interact", _me)
		var paid := await _wait_for(func() -> bool: return int(inventory.get("money")) > 0, 5000)
		_check(paid and int(inventory.get("money")) == cash, "Client hat die Kasse ausgeräumt (+%d ¢)" % int(inventory.get("money")))
	await _phase(17.0)
	_check(int(b.get("cash")) == 0, "Kasse von Laden B ist bei beiden leer")
	if _host:
		_check(int(inventory.get("money")) != cash or cash == 0, "Host hat das Geld nicht bekommen")
	await _phase(20.0)
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
