extends SceneTree
## Prüft die Läden in Sektor 7: Boden bündig mit dem Boden davor, größeres Tor, Einkaufen, Klauen
## (unbemerkt und erwischt), Kasse ausräumen, Überfall mit der Waffe, Verkäufer erschießen.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_shop.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (siehe test_money.gd).

const SLUM := "res://scenes/slum/slum.tscn"

var _checks := 0
var _fails := 0
var _player: Node3D
var _inventory: Node
var _space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file(SLUM)
	await _frames(30)
	for i in 4:
		await physics_frame
	_player = get_first_node_in_group("player") as Node3D
	_check(_player != null, "Sektor 7 mit Spielerfigur geladen")
	if _player == null:
		_finish()
		return
	_inventory = _player.get("inventory")
	_space = (current_scene as Node3D).get_world_3d().direct_space_state
	var shops := get_nodes_in_group("shop_interior")
	_check(shops.size() >= 40, "%d Läden mit Verkäufer, Kasse und Ware" % shops.size())
	_check_geometry()
	if shops.is_empty():
		_finish()
		return
	shops.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	await _check_buy(shops[0])
	await _check_steal(shops[1])
	await _check_rob(shops[2])
	await _check_threat(shops[3])
	await _check_kill(shops[4])
	_finish()


func _ground(p: Vector3) -> float:
	var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 2.0, 1))
	return hit.position.y if not hit.is_empty() else -9.0


## Alle Läden: keine Kante zwischen Ladenboden, Schwelle und Boden davor; Tor mindestens 2,4 m hoch
## und 3 m breit.
func _check_geometry() -> void:
	var worst_step := 0.0
	var worst_name := ""
	var lowest := 99.0
	var narrowest := 99.0
	var count := 0
	for node: Node in current_scene.find_children("Shop*", "Node3D", true, false):
		if node.get("footprint") == null:
			continue
		count += 1
		var building := node as Node3D
		var fp: Vector2 = node.get("footprint")
		var xf := building.global_transform
		for x: float in [-0.8, 0.8]:
			var inside := _ground(xf * Vector3(x, 0, fp.y * 0.5 - 1.0))
			var door := _ground(xf * Vector3(x, 0, fp.y * 0.5 + 0.15))
			var outside := _ground(xf * Vector3(x, 0, fp.y * 0.5 + 0.6))
			var step := maxf(absf(inside - door), absf(door - outside))
			if step > worst_step:
				worst_step = step
				worst_name = "%s (%.2f / %.2f / %.2f)" % [node.name, inside, door, outside]
		# Lichte Höhe in der Toröffnung.
		var floor_y := _ground(xf * Vector3(0, 0, fp.y * 0.5 - 0.1))
		var from := xf * Vector3(0, floor_y + 0.2, fp.y * 0.5 - 0.1)
		var up := _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 5.0, 1))
		if not up.is_empty():
			lowest = minf(lowest, up.position.y - floor_y)
		# Breite: von der Mitte der Öffnung nach links und rechts bis zur Wand.
		var mid := xf * Vector3(0, 1.0, fp.y * 0.5 - 0.12)
		var side := xf.basis.x.normalized()
		var width := 0.0
		for s: float in [-1.0, 1.0]:
			var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(mid, mid + side * s * 6.0, 1))
			width += mid.distance_to(hit.position) if not hit.is_empty() else 6.0
		narrowest = minf(narrowest, width)
	_check(count >= 40, "%d Ladengebäude vermessen" % count)
	_check(worst_step <= 0.03, "Keine Kante am Eingang (größte Stufe %.3f m bei %s)" % [worst_step, worst_name])
	_check(lowest >= 2.4, "Tor überall mindestens 2,4 m hoch (niedrigstes %.2f m)" % lowest)
	_check(narrowest >= 3.0, "Tor überall mindestens 3 m breit (schmalstes %.2f m)" % narrowest)


func _place_in_front_of_keeper(shop: Node, distance: float) -> void:
	var keeper: Node3D = shop.get("_keeper")
	var spot: Vector3 = keeper.global_position - keeper.global_basis.z * distance
	_player.global_position = spot
	var to := keeper.global_position - spot
	_player.rotation.y = atan2(-to.x, -to.z)
	(_player.get("head") as Node3D).rotation.x = 0.0


func _check_buy(shop: Node) -> void:
	_inventory.call("take_all_money")
	_inventory.call("add_money", 20)
	var keeper: Node = shop.get("_keeper")
	_check(keeper.call("get_interact_text", _player) == "Einkaufen", "Verkäufer: [E] Einkaufen")
	keeper.call("interact", _player)
	await _frames(2)
	var ui: Node = _player.get_node_or_null(^"ShopUI")
	_check(ui != null and bool(ui.call("is_open")), "Ladenfenster ist offen")
	if ui == null:
		return
	var offers: Array = shop.call("get_offers")
	var id := str(offers[0][0])
	var price := int(offers[0][1])
	var before := _count(id)
	_check(bool(ui.call("buy", 0)) and _count(id) == before + 1 and int(_inventory.get("money")) == 20 - price,
		"Gekauft: %s für %d ¢ (Bargeld %d)" % [id, price, int(_inventory.get("money"))])
	_inventory.call("take_all_money")
	_check(not bool(ui.call("buy", 0)), "Ohne Geld kein Kauf")
	ui.call("close")
	await _frames(2)
	_check(not bool(_player.get("input_locked")), "Fenster zu, Spieler frei")


func _check_steal(shop: Node) -> void:
	var goods: Array = shop.get("_goods")
	var items: Array = shop.get("slot_items")
	var stock_before := int(shop.call("stock_left"))
	# Unbemerkt: Verkäufer räumt hinten ein.
	shop.set("busy", true)
	var id := str((items[0] as Resource).get("id"))
	var before := _count(id)
	var text: String = goods[0].call("get_interact_text", _player)
	_check(text.begins_with("Klauen"), "Ware im Regal: %s" % text)
	goods[0].call("interact", _player)
	await _frames(2)
	_check(_count(id) == before + 1 and int(shop.call("stock_left")) == stock_before - 1,
		"Unbemerkt geklaut: %s, Regal hat einen weniger" % id)
	_check(int(shop.get("keeper_state")) == 0, "Kein Alarm")
	_check(not bool(goods[0].get("visible")), "Geklaute Ware ist aus dem Regal weg")
	# Erwischt: Spieler steht vor dem Verkäufer, der hinsieht.
	shop.set("busy", false)
	shop.set("_keeper_pos", 0.0)
	_place_in_front_of_keeper(shop, 2.2)
	await _frames(3)
	for i in 3:
		await physics_frame
	_check(bool(shop.call("sees", _player)), "Verkäufer sieht den Spieler vor der Theke")
	var nearby := _enemies_near(shop, 35.0)
	goods[1].call("interact", _player)
	await _frames(2)
	_check(int(shop.get("keeper_state")) == 2, "Erwischt beim Klauen: Alarm")
	var hostile := 0
	for enemy: Node in nearby:
		if bool(enemy.get("hostile")):
			hostile += 1
	_check(nearby.is_empty() or hostile == nearby.size(), "Gegner im Umkreis feindlich (%d von %d)" % [hostile, nearby.size()])
	var keeper: Node = shop.get("_keeper")
	_check(keeper.call("get_interact_text", _player) == "", "Bei Alarm verkauft er nichts")


func _check_rob(shop: Node) -> void:
	var register: Node = shop.get("_register")
	var cash := int(shop.get("cash"))
	_check(cash > 0 and str(register.call("get_interact_text", _player)).contains("%d" % cash),
		"Kasse: %s" % register.call("get_interact_text", _player))
	# Vor seinen Augen: kein Geld, Alarm.
	_place_in_front_of_keeper(shop, 1.6)
	await _frames(2)
	_inventory.call("take_all_money")
	register.call("interact", _player)
	await _frames(2)
	_check(int(_inventory.get("money")) == 0 and int(shop.get("keeper_state")) == 2,
		"Vor dem Verkäufer: kein Geld, Alarm")
	# Verkäufer weggedreht: Geld.
	shop.set("keeper_state", 0)
	shop.set("busy", true)
	register.call("interact", _player)
	await _frames(2)
	_check(int(_inventory.get("money")) == cash and int(shop.get("cash")) == 0,
		"Kasse ausgeräumt, während er hinten war: +%d ¢" % int(_inventory.get("money")))
	_check(float(shop.get("_silent_alarm_left")) > 0.0, "Er merkt es kurz danach (stiller Alarm läuft)")


func _check_threat(shop: Node) -> void:
	var cash := int(shop.get("cash"))
	_place_in_front_of_keeper(shop, 3.0)
	# Auf die Brust des Verkäufers zielen.
	var keeper: Node3D = shop.get("_keeper")
	var camera: Camera3D = _player.get("camera")
	await _frames(2)
	var target := keeper.global_position + Vector3.UP * 1.2
	var rise := target.y - camera.global_position.y
	var flat := Vector2(target.x - camera.global_position.x, target.z - camera.global_position.z).length()
	(_player.get("head") as Node3D).rotation.x = atan2(rise, flat)
	await _frames(2)
	_check(bool(shop.call("aims_at_keeper", _player)), "Spieler zielt auf den Verkäufer")
	var before := get_nodes_in_group("item_pickup").size()
	shop.call("request", _player, &"threat")
	await _frames(3)
	_check(int(shop.get("keeper_state")) == 1, "Verkäufer ergibt sich (Hände hoch)")
	var found := false
	for node: Node in get_nodes_in_group("item_pickup"):
		var item: Resource = node.get("item")
		if item != null and item.get("id") == "credchip" and int(node.get("count")) == cash:
			found = true
	_check(found and get_nodes_in_group("item_pickup").size() == before + 1,
		"Kassengeld (%d ¢) liegt auf der Theke" % cash)
	_check(int(shop.get("cash")) == 0, "Kasse danach leer")
	await create_timer(4.5).timeout
	_check(float(shop.get("_alarm_left")) > 0.0, "Stiller Alarm nach dem Überfall")


func _check_kill(shop: Node) -> void:
	var keeper: Node = shop.get("_keeper")
	keeper.call("take_hit", 30.0, Vector3.ZERO, Vector3.FORWARD)
	await _frames(2)
	_check(int(shop.get("keeper_state")) == 2 and float(shop.get("keeper_health")) < 60.0,
		"Treffer: Alarm, Leben %.0f" % float(shop.get("keeper_health")))
	keeper.call("take_hit", 40.0, Vector3.ZERO, Vector3.FORWARD)
	await _frames(2)
	_check(int(shop.get("keeper_state")) == 3 and int((keeper as CollisionObject3D).collision_layer) == 0,
		"Verkäufer tot, keine Kollision mehr")
	var cash := int(shop.get("cash"))
	_inventory.call("take_all_money")
	shop.get("_register").call("interact", _player)
	await _frames(2)
	_check(cash > 0 and int(_inventory.get("money")) == cash, "Kasse nach seinem Tod frei: +%d ¢" % cash)


func _count(id: String) -> int:
	var total := 0
	for i: int in int(_inventory.call("get_size")):
		var item: Resource = _inventory.call("get_item", i)
		if item != null and item.get("id") == id:
			total += int(_inventory.call("get_count", i))
	return total


func _enemies_near(shop: Node, radius: float) -> Array:
	var keeper: Node3D = shop.get("_keeper")
	var list: Array = []
	for node: Node in get_nodes_in_group("enemy"):
		if (node as Node3D).global_position.distance_to(keeper.global_position) <= radius:
			list.append(node)
	return list


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
