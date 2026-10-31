extends SceneTree
## Wohnungs-Beute, 35-%-Bewohner, Einbruch eine Fahndungsstufe.
##
## Aufruf: godot --headless --path . -s res://tools/tests/test_apartments.gd

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _run() -> void:
	await process_frame
	var script: Script = load("res://scenes/crime/apartment_block.gd")
	_rolls(script)
	await _one(script, 0)
	await _one(script, 2)
	_break_in(script)
	await _house()
	await _sell()
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


func _rolls(script: Script) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var hits := 0
	var ones := 0
	var twos := 0
	var n := 4000
	for _i in n:
		var count: int = int(script.call("resolve_resident_count", rng, -1))
		if count == 0:
			pass
		elif count == 1:
			hits += 1
			ones += 1
		elif count == 2:
			hits += 1
			twos += 1
		else:
			_check(false, "Wurf %d" % count)
			return
	var rate := float(hits) / float(n)
	_check(rate > 0.32 and rate < 0.38, "Bewohner-Quote %.3f bei 4000 Würfen" % rate)
	_check(ones > 500 and twos > 500, "davon 1: %d, 2: %d" % [ones, twos])
	_check(int(script.call("resolve_resident_count", rng, 0)) == 0, "erzwungen leer")
	_check(int(script.call("resolve_resident_count", rng, 2)) == 2, "erzwungen zwei")


func _one(script: Script, residents: int) -> void:
	var home := script.new() as Node3D
	home.set("resident_count", residents)
	home.set("key_id", "apt_test_%d" % residents)
	root.add_child(home)
	await process_frame
	for node_name: String in ["Door", "Safe", "Jewelry", "Jewels", "Cash", "Television", "Artwork", "Computer", "Phone", "Sofa", "Bed", "Kitchen", "Toilet", "Shower", "Wardrobe"]:
		_check(home.get_node_or_null(NodePath(node_name)) != null, "Wohnung hat %s" % node_name)
	var door := home.get_node(^"Door")
	_check(bool(door.get("locked")), "Tür startet zu")
	var jewels := home.get_node(^"Jewels")
	_check(bool(jewels.get("sealed")), "Juwelen sind verschlossen")
	_check(bool(home.get_node(^"Safe").get("sealed")), "Tresor ist verschlossen")
	var found := 0
	for child in home.get_children():
		if str(child.name).begins_with("Resident"):
			found += 1
	_check(found == residents, "Bewohner %d, ist %d" % [residents, found])
	home.free()


func _break_in(script: Script) -> void:
	var home := script.new() as Node3D
	home.set("resident_count", 2)
	home.set("key_id", "apt_alarm")
	home.position = Vector3(0, 0, 400)
	root.add_child(home)
	await process_frame
	var wanted: Node = root.get_node(^"WantedManager")
	wanted.call("set_stars", 0)
	var door: Node = home.get_node(^"Door")
	door.call("break_open", null)
	_check(not bool(door.get("locked")), "Brechstange öffnet die Tür")
	var listeners := 0
	for node in get_nodes_in_group(&"noise_listener"):
		listeners += 1
	_check(int(wanted.call("star_count")) == 1, "Einbruch Stern %d, Hörer %d" % [int(wanted.call("star_count")), listeners])
	wanted.call("set_stars", 0)
	home.queue_free()


func _house() -> void:
	var house := load("res://scenes/crime/apartment_house.gd").new() as Node3D
	house.set("building_width", 12.0)
	house.set("building_depth", 10.0)
	house.set("floor_height", 3.0)
	root.add_child(house)
	await process_frame
	var doors := house.find_children("Door", "", true, false)
	_check(doors.size() == 4, "Haus hat 4 Türen, ist %d" % doors.size())
	var keys: Array[String] = []
	for door in doors:
		keys.append(str(door.get("key_id")))
		_check(bool(door.get("locked")), "Tür %s zu" % door.get("key_id"))
	_check(keys.has("apt_c") and keys.has("apt_1"), "Schlüssel apt_1 und apt_c")
	_check(house.find_children("Safe", "", true, false).size() == 4, "Jede Wohnung hat einen Tresor")
	house.queue_free()


func _sell() -> void:
	var pad: Script = load("res://scenes/crime/loot_sell_pad.gd")
	var jewelry: Resource = load("res://scenes/items/data/jewelry.tres")
	var tv: Resource = load("res://scenes/items/data/tv_set.tres")
	_check(int(pad.call("price_for", jewelry)) == 20, "Schmuck verkauft für 20 ¢")
	_check(int(pad.call("price_for", tv)) == 27, "Fernseher verkauft für 27 ¢")
	var inventory: Node = load("res://scenes/inventory/inventory.gd").new()
	root.add_child(inventory)
	await process_frame
	inventory.call("add_item", jewelry, 1)
	var paid: int = pad.call("sell_one", inventory, jewelry)
	_check(paid == 20 and int(inventory.get("money")) == 20, "Verkauf schreibt 20 ¢, ist %d" % paid)
	var left := false
	for i in int(inventory.call("get_size")):
		if inventory.call("get_item", i) != null:
			left = true
	_check(not left, "Schmuck ist aus dem Inventar")
	inventory.queue_free()
