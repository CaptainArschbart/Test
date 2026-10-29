extends SceneTree
## Prüft die Läden im Multiplayer mit zwei Prozessen (Host und Client) in Sektor 7.
##
## Aufruf (Projektordner), zwei Prozesse gleichzeitig, Host zuerst:
##   godot --headless --path . -s res://tools/tests/test_shop_net.gd -- host
##   godot --headless --path . -s res://tools/tests/test_shop_net.gd -- client
## Ablauf:
##   1. Der Host macht Laden A „sicher zum Testen“ (keine Sicherung, Kamera aus, Verkäufer räumt ein).
##   2. Der Client nimmt Ware: Item beim Client, Warenkorb beim Client, Regal bei beiden kleiner.
##   3. Der Client bezahlt: Geld weg, Warenkorb leer.
##   4. Der Client nimmt noch etwas und geht raus: geklaut, kein Alarm, Warenkorb leer.
##   5. Der Client erschießt den Verkäufer von Laden B (Tod bei beiden) und knackt die Kasse (Geld beim Client).
## Ergebnis in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const SLUM := "res://scenes/slum/slum.tscn"
const PORT := 7795

var _checks := 0
var _fails := 0
var _host := false
var _start := 0
var _me: Node3D


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
			_me = player as Node3D
		else:
			remote = true
	return local and remote


func _shops() -> Array:
	var list := get_nodes_in_group("shop_interior")
	list.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	return list


func _shelf_slot(shop: Node) -> int:
	for i in (shop.get("slots") as Array).size():
		if shop.call("slot_kind", i) == "shelf" and shop.call("item_at", i) != null:
			return i
	return -1


func _count(id: String) -> int:
	var inventory: Node = _me.get("inventory")
	var total := 0
	for i: int in int(inventory.call("get_size")):
		var item: Resource = inventory.call("get_item", i)
		if item != null and item.get("id") == id:
			total += int(inventory.call("get_count", i))
	return total


func _inside_spot(shop: Node) -> Vector3:
	var b: AABB = shop.get("bounds")
	return (shop as Node3D).to_global(Vector3(b.get_center().x, float(shop.get("floor_y")) + 0.05, b.end.z - 1.0))


func _outside_spot(shop: Node) -> Vector3:
	var b: AABB = shop.get("bounds")
	return (shop as Node3D).to_global(Vector3(0.0, float(shop.get("floor_y")) + 0.05, b.end.z + 1.5))


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

	# 1) Host richtet Laden A ein.
	await _phase(2.0)
	if _host:
		a.set("has_sensor", false)
		a.set("camera_alive", false)
		a.set("busy", true)
		a.set("_busy_left", 999.0)
	await _phase(5.0)
	_check(bool(a.get("busy")) and not bool(a.get("camera_alive")), "Laden A: Verkäufer räumt ein, Kamera aus (bei beiden)")

	# 2) Client nimmt Ware.
	var slot := _shelf_slot(a)
	var item: Resource = a.call("item_at", slot)
	var id := str(item.get("id")) if item else ""
	var price := int(a.call("price_of", item)) if item else 0
	var stock_before := int(a.call("stock_total"))
	if not _host:
		_me.global_position = _inside_spot(a)
		await create_timer(0.3).timeout
		inventory.call("take_all_money")
		inventory.call("add_money", 50)
		a.call("request", _me, &"take", slot)
		var got := await _wait_for(func() -> bool: return _count(id) == 1, 5000)
		_check(got and int(a.get("my_unpaid")) == price, "Client hat %s genommen, Warenkorb %d ¢" % [id, int(a.get("my_unpaid"))])
	await _phase(9.0)
	var smaller := await _wait_for(func() -> bool: return int(a.call("stock_total")) < stock_before, 10000)
	_check(smaller, "Regal ist bei beiden kleiner (%d → %d)" % [stock_before, int(a.call("stock_total"))])

	# 3) Client bezahlt.
	if not _host:
		a.call("request", _me, &"pay")
		var paid := await _wait_for(func() -> bool: return int(inventory.get("money")) == 50 - price, 5000)
		_check(paid and int(a.get("my_unpaid")) == 0, "Bezahlt: Bargeld %d, Warenkorb leer" % int(inventory.get("money")))

	# 4) Client nimmt noch etwas und geht raus.
	await _phase(12.0)
	var slot2 := _shelf_slot(a)
	var id2 := str((a.call("item_at", slot2) as Resource).get("id")) if slot2 >= 0 else ""
	if not _host and slot2 >= 0:
		var before := _count(id2)
		a.call("request", _me, &"take", slot2)
		await _wait_for(func() -> bool: return _count(id2) > before, 5000)
		_me.global_position = _outside_spot(a)
		var cleared := await _wait_for(func() -> bool: return int(a.get("my_unpaid")) == 0, 5000)
		_check(cleared and _count(id2) > before, "Mit unbezahltem %s raus: geklaut, Warenkorb leer" % id2)
	await _phase(16.0)
	_check(int(a.get("keeper_state")) == 0, "Kein Alarm in Laden A")

	# 5) Laden B: Verkäufer erschießen, Kasse knacken.
	var cash := int(b.get("cash"))
	if not _host:
		var keeper: Node = b.get("_keeper")
		keeper.call("take_hit", 35.0, Vector3.ZERO, Vector3.FORWARD)
		keeper.call("take_hit", 35.0, Vector3.ZERO, Vector3.FORWARD)
	await _phase(19.0)
	var dead := await _wait_for(func() -> bool: return int(b.get("keeper_state")) == 3, 10000)
	_check(dead, "Verkäufer von Laden B ist bei beiden tot")
	if not _host:
		var register: Node3D = b.get("_register")
		_me.global_position = register.global_position + (b as Node3D).global_basis.x.normalized() * 0.9
		_me.global_position.y = (b as Node3D).global_position.y + float(b.get("floor_y")) + 0.02
		await create_timer(0.3).timeout
		inventory.call("take_all_money")
		register.call("interact", _me)
		var robbed := await _wait_for(func() -> bool: return int(inventory.get("money")) > 0, 6000)
		_check(robbed and int(inventory.get("money")) == cash, "Kasse von Laden B geknackt (+%d ¢)" % int(inventory.get("money")))
	await _phase(25.0)
	var empty := await _wait_for(func() -> bool: return int(b.get("cash")) == 0, 12000)
	_check(empty, "Kasse von Laden B ist bei beiden leer")
	# Der Host bleibt länger, damit der Client fertig wird, bevor die Sitzung endet.
	await _phase(45.0 if _host else 30.0)
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
