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
	await _break_in(script)
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
	for node_name: String in ["Door", "Jewelry", "Jewels", "Cash", "Television", "Artwork", "Computer", "Sofa", "Bed", "Kitchen"]:
		_check(home.get_node_or_null(NodePath(node_name)) != null, "Wohnung hat %s" % node_name)
	var door := home.get_node(^"Door")
	_check(bool(door.get("locked")), "Tür startet zu")
	var jewels := home.get_node(^"Jewels")
	_check(bool(jewels.get("sealed")), "Juwelen sind verschlossen")
	var found := 0
	for child in home.get_children():
		if str(child.name).begins_with("Resident"):
			found += 1
	_check(found == residents, "Bewohner %d, ist %d" % [residents, found])
	home.queue_free()


func _break_in(script: Script) -> void:
	var home := script.new() as Node3D
	home.set("resident_count", 2)
	home.set("key_id", "apt_alarm")
	root.add_child(home)
	await process_frame
	var wanted: Node = root.get_node(^"WantedManager")
	wanted.call("set_stars", 0)
	var door: Node = home.get_node(^"Door")
	door.call("break_open", null)
	_check(not bool(door.get("locked")), "Eddy öffnet die Tür")
	_check(int(wanted.call("star_count")) == 1, "Einbruch mit Bewohnern: 1 Stern, ist %d" % int(wanted.call("star_count")))
	wanted.call("set_stars", 0)
	home.queue_free()
