extends SceneTree
## Prüft den Hanfanbau in der Testmap: Aufstellen, Pflanze von Erde bis Ernte (Gießen, Düngen,
## Growlampe mit 18/6 und 12/12, Trichome), Pflegefehler (Austrocknen, Staunässe, Nährstoffbrand),
## Trocknen, Fermentieren (Lüften, Schimmel), Verpacken in Tütchen und Gläser, Growbedarf-Regal an
## der Tankstelle, Ankauf beim Hehler, Zustand und Revision (net_state/net_apply) sowie Speichern und
## Laden über GrowSync (ohne zweiten Prozess). Zeit läuft über station.simulate().
##
## Aufruf (Projektordner), headless reicht:
##   godot --headless --path . -s res://tools/tests/test_grow.gd
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const DATA := "res://scenes/items/data/%s.tres"
const STATION := "res://scenes/grow/grow_station.gd"
const ARENA := Vector3(-400.0, 300.0, 400.0)
const ITEMS := ["grow_pot", "grow_lamp", "drying_rack", "curing_jar", "packing_table", "potting_soil",
	"cannabis_seed", "fertilizer", "weed_wet", "weed_wet_premium", "weed_dry", "weed_dry_premium", "weed_cured",
	"weed_cured_premium", "baggie_empty", "jar_empty", "weed_baggie", "weed_baggie_premium", "weed_jar",
	"weed_jar_premium"]

var _checks := 0
var _fails := 0
var _player: Node3D
var _inv: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file(TESTMAP)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == TESTMAP:
			break
		await physics_frame
	await _frames(20)
	_player = get_first_node_in_group("player") as Node3D
	_inv = _player.get("inventory")
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor.add_child(shape)
	current_scene.add_child(floor)
	floor.global_position = ARENA + Vector3(0, -0.5, 0)
	_player.global_position = ARENA + Vector3(0, 0.1, 0)
	_player.rotation.y = 0.0
	await _frames(10)
	_test_items()
	await _test_place()
	await _test_grow()
	_test_mistakes()
	_test_dry_cure_pack()
	_test_stand()
	await _test_save()
	_finish()


func _item(id: String) -> ItemData:
	return load(DATA % id) as ItemData


## Item in die Hotbar legen und wählen.
func _hold(id: String, count := 1) -> void:
	var item := _item(id)
	if int(_inv.call("count_item", item)) < count:
		_inv.call("add_item", item, count - int(_inv.call("count_item", item)), false)
	for i in 36:
		if _inv.call("get_item", i) == item:
			if i >= 9:
				_inv.call("move", i, 8)
				i = 8
			_inv.call("select", i)
			return


func _use(station: Node, id: String) -> void:
	if id == "":
		_hold_nothing()
	else:
		_hold(id)
	station.call("interact", _player)


func _hold_nothing() -> void:
	if _inv.call("get_item", 8) != null:
		_inv.call("quick_move", 8)
	for i in 9:
		if _inv.call("get_item", i) == null:
			_inv.call("select", i)
			return


func _station(kind: StringName, at: Vector3) -> Node3D:
	var station: Node3D = (load(STATION) as GDScript).create(kind, null)
	current_scene.add_child(station)
	station.global_position = at
	return station


func _test_items() -> void:
	print("Items")
	var missing := []
	var no_model := []
	var display: Script = load("res://scenes/items/item_display.gd")
	for id: String in ITEMS:
		var item := _item(id)
		if item == null:
			missing.append(id)
			continue
		var model: Node3D = display.call("build", item)
		if model == null:
			no_model.append(id)
		else:
			model.free()
	_check(missing.is_empty(), "Alle 20 Anbau-Items da %s" % [missing])
	_check(no_model.is_empty(), "Jedes hat ein Modell %s" % [no_model])
	_check(str(_item("grow_lamp").get("station")) == "lamp", "Growlampe ist aufstellbar (Station lamp)")


func _test_place() -> void:
	print("Aufstellen")
	_hold("grow_pot", 2)
	(_player.get("head") as Node3D).rotation.x = -0.7
	await _frames(5)
	var placer: Node = (_player.get("item_user") as Node).get_node("GrowPlacer")
	var before := get_nodes_in_group(&"grow_station").size()
	var ok := bool(placer.call("place"))
	await _frames(2)
	var stations := get_nodes_in_group(&"grow_station")
	_check(ok and stations.size() == before + 1, "Topf vor dem Spieler aufgestellt")
	_check(int(_inv.call("count_item", _item("grow_pot"))) == 1, "Ein Topf weniger im Inventar")
	var pot: Node3D = stations.back()
	_check(absf(pot.global_position.y - ARENA.y) < 0.05 and pot.global_position.distance_to(_player.global_position) < 3.5,
		"Steht auf dem Boden vor dem Spieler (%.2f m)" % pot.global_position.distance_to(_player.global_position))
	(_player.get("head") as Node3D).rotation.x = 0.4
	await _frames(2)
	_check(not bool(placer.call("place")), "In die Luft: nicht aufstellbar")
	# Abbauen (leer, geduckt).
	_player.get("movement").set("crouching", true)
	var text := str(pot.call("get_interact_text", _player))
	pot.call("interact", _player)
	_player.get("movement").set("crouching", false)
	await _frames(2)
	_check(text.begins_with("Abbauen") and not is_instance_valid(pot) or pot.is_queued_for_deletion(), "Geduckt: abgebaut (%s)" % text)
	_check(int(_inv.call("count_item", _item("grow_pot"))) == 2, "Topf wieder im Inventar")
	(_player.get("head") as Node3D).rotation.x = 0.0


func _test_grow() -> void:
	print("Wachstum bis zur Ernte (mit Lampe)")
	var at := ARENA + Vector3(4, 0, 4)
	var pot := _station(&"pot", at)
	var lamp := _station(&"lamp", at - Vector3(0.12, 0, 0))
	_use(pot, "potting_soil")
	_check(int(pot.get("stage")) == 1, "Erde eingefüllt")
	_use(pot, "cannabis_seed")
	_check(int(pot.get("stage")) == 2, "Samen eingepflanzt (Keimung)")
	_check(bool(pot.call("is_lit")), "Lampe leuchtet den Topf aus")
	_hold("water_bottle", 40)
	_hold("fertilizer", 20)
	var t := 0.0
	var max_veg := 0.0
	while t < 700.0:
		_care(pot)
		pot.call("simulate", 10.0)
		t += 10.0
		max_veg = maxf(max_veg, float(pot.get("veg")))
	_check(int(pot.get("stage")) == 4 and max_veg > 1.5, "Unter 18/6 bleibt sie im Wachstum und wird größer (%.2f)" % max_veg)
	_use(lamp, "")
	_check(bool(lamp.get("flower_cycle")), "Lampe auf 12/12 umgestellt")
	pot.call("simulate", 1.0)
	_check(int(pot.get("stage")) == 5, "12/12 löst die Blüte aus")
	var clear_seen := false
	while float(pot.get("flower")) < 1.05 and t < 2000.0:
		_care(pot)
		pot.call("simulate", 10.0)
		t += 10.0
		if float(pot.get("flower")) > 0.6 and float(pot.get("flower")) < 0.8:
			clear_seen = clear_seen or str(pot.call("trichomes")) == "klar"
	_check(clear_seen and str(pot.call("trichomes")) == "milchig", "Trichome erst klar, dann milchig")
	var leaves := pot.find_children("Leaves", "MeshInstance3D", true, false)
	var buds := pot.find_children("Buds", "MeshInstance3D", true, false)
	_check(not leaves.is_empty() and not buds.is_empty(), "Pflanze mit Blättern und Blüten")
	var result: Dictionary = pot.call("harvest_result")
	var before := int(_inv.call("count_item", _item("weed_wet_premium")))
	_use(pot, "")
	var got := int(_inv.call("count_item", _item("weed_wet_premium"))) - before
	_check(got >= 40 and bool(result.premium), "Gute Pflege: %d g frische Premium-Blüten (Qualität %.2f)" % [got, float(result.quality)])
	_check(int(pot.get("stage")) == 0, "Nach der Ernte leer (Erde verbraucht)")


## Gießen und düngen wie ein sorgfältiger Gärtner.
func _care(pot: Node) -> void:
	if float(pot.get("water")) < 0.3:
		_use(pot, "water_bottle")
	if int(pot.get("stage")) >= 3 and float(pot.get("nutrients")) < 0.25:
		_use(pot, "fertilizer")


func _test_mistakes() -> void:
	print("Pflegefehler")
	var dry := _station(&"pot", ARENA + Vector3(-4, 0, 4))
	_use(dry, "potting_soil")
	_use(dry, "cannabis_seed")
	_use(dry, "water_bottle")
	dry.call("simulate", 400.0)
	_check(int(dry.get("stage")) == 6 or float(dry.get("health")) < 0.5, "Nie gegossen: welkt bzw. geht ein (Gesundheit %.2f)" % float(dry.get("health")))
	var wet := _station(&"pot", ARENA + Vector3(-6, 0, 4))
	_use(wet, "potting_soil")
	_use(wet, "cannabis_seed")
	_use(wet, "water_bottle")
	wet.call("simulate", 140.0)
	_use(wet, "water_bottle")
	_use(wet, "water_bottle")
	var before := float(wet.get("health"))
	_use(wet, "water_bottle")
	_check(float(wet.get("health")) < before - 0.1, "In nasse Erde gegossen: Staunässe (%.2f → %.2f)" % [before, float(wet.get("health"))])
	before = float(wet.get("health"))
	_use(wet, "fertilizer")
	_use(wet, "fertilizer")
	_use(wet, "fertilizer")
	_check(float(wet.get("health")) < before - 0.1, "Zu viel Dünger: Nährstoffbrand")


func _test_dry_cure_pack() -> void:
	print("Trocknen, Fermentieren, Verpacken")
	var rack := _station(&"rack", ARENA + Vector3(6, 0, -3))
	_hold("weed_wet_premium", 80)
	var wet_had := int(_inv.call("count_item", _item("weed_wet_premium")))
	_use(rack, "weed_wet_premium")
	var hung := int(rack.get("grams"))
	_check(hung == mini(wet_had, 120), "%d g aufgehängt" % hung)
	rack.call("simulate", 100.0)
	_use(rack, "")
	_check(int(rack.get("grams")) == hung, "Halb trocken: noch nicht abnehmbar")
	rack.call("simulate", 90.0)
	var dry_before := int(_inv.call("count_item", _item("weed_dry_premium")))
	_use(rack, "")
	var dried := int(_inv.call("count_item", _item("weed_dry_premium"))) - dry_before
	_check(dried == int(round(hung * 0.25)), "Trocken: %d g aus %d g frisch (−75 %%)" % [dried, hung])
	# Fermentieren mit Lüften: Premium bleibt.
	var jar := _station(&"jar", ARENA + Vector3(6, 0, -5))
	_hold("weed_dry_premium", 28)
	_use(jar, "weed_dry_premium")
	_check(int(jar.get("grams")) > 0 and float(jar.get("humidity")) > 0.6, "Ins Glas gefüllt (Feuchte %.2f)" % float(jar.get("humidity")))
	for i in 13:
		jar.call("simulate", 20.0)
		if float(jar.get("humidity")) > 0.66:
			_use(jar, "")
	var cured_before := int(_inv.call("count_item", _item("weed_cured_premium")))
	var in_jar := int(jar.get("grams"))
	_use(jar, "")
	_check(int(_inv.call("count_item", _item("weed_cured_premium"))) - cured_before == in_jar, "Gelüftet und gereift: %d g Premium" % in_jar)
	# Ohne Lüften: Schimmel.
	var bad := _station(&"jar", ARENA + Vector3(6, 0, -7))
	_hold("weed_dry", 10)
	_use(bad, "weed_dry")
	bad.call("simulate", 200.0)
	_check(bool(bad.get("moldy")), "Nie gelüftet: verschimmelt")
	# Verpacken.
	var table := _station(&"table", ARENA + Vector3(-6, 0, -4))
	_hold("baggie_empty", 5)
	_hold("jar_empty", 2)
	_hold("weed_cured_premium", 20)
	var bags := int(_inv.call("count_item", _item("weed_baggie_premium")))
	_use(table, "weed_cured_premium")
	_use(table, "weed_cured_premium")
	_check(int(_inv.call("count_item", _item("weed_baggie_premium"))) == bags + 2, "Zwei Tütchen Premium (1 g)")
	_use(table, "")
	_check(str(table.get("mode")) == "jar", "Modus Glas")
	var grams := int(_inv.call("count_item", _item("weed_cured_premium")))
	_use(table, "weed_cured_premium")
	_check(int(_inv.call("count_item", _item("weed_jar_premium"))) >= 1 and int(_inv.call("count_item", _item("weed_cured_premium"))) == grams - 7,
		"Ein Glas Premium (7 g abgewogen)")
	var price := int((load("res://scenes/crime/loot_sell_pad.gd") as GDScript).call("price_for", _item("weed_jar_premium")))
	_check(price > 0, "Hehler kauft das Glas (%d ¢)" % price)


func _test_stand() -> void:
	print("Growbedarf an der Tankstelle")
	var shop: Node3D = (load("res://scenes/crime/street_shop.gd") as GDScript).new()
	shop.set("kind", 1)
	current_scene.add_child(shop)
	shop.global_position = ARENA + Vector3(0, 0, 30)
	var stand := shop.get_node_or_null("GrowStand")
	var sold := []
	if stand != null:
		for child in stand.get_children():
			if child.get("item") != null:
				sold.append(str(child.get("item").get("id")))
	_check(stand != null and sold.size() == 10 and sold.has("cannabis_seed") and sold.has("grow_lamp"), "Regal mit 10 Plätzen %s" % [sold])


func _test_save() -> void:
	print("Zustand und Spielstand")
	var sync: Node = root.get_node_or_null("GrowSync")
	_check(sync != null, "Autoload GrowSync da")
	if sync == null:
		return
	_check(bool(sync.call("simulates")), "Offline rechnet dieser Rechner die Zeit")
	var base := ARENA + Vector3(8, 0, 8)
	var pot := _station(&"pot", base)
	var lamp := _station(&"lamp", base + Vector3(-0.12, 0, 0))
	var jar := _station(&"jar", base + Vector3(1.5, 0, 0))
	lamp.rotation.y = 0.7
	for station: Node in [pot, lamp, jar]:
		sync.call("placed", station)
	_check(str(pot.get("net_id")) != "" and pot.get("net_id") != lamp.get("net_id"), "Eindeutige Kennungen (%s)" % pot.get("net_id"))
	_use(pot, "potting_soil")
	_use(pot, "cannabis_seed")
	_use(pot, "water_bottle")
	_use(lamp, "")
	pot.call("simulate", 200.0)
	_hold("weed_dry", 10)
	_use(jar, "weed_dry")
	jar.call("simulate", 30.0)
	_check(int(pot.get("net_rev")) == 3 and int(lamp.get("net_rev")) == 1, "Jede Bedienung zählt die Revision (%d)" % pot.get("net_rev"))
	# Revision: ältere Stände werden verworfen, neuere übernommen.
	var state: Dictionary = pot.call("net_state")
	var old := state.duplicate()
	old["rev"] = 1
	old["water"] = 0.77
	pot.call("net_apply", old)
	_check(not is_equal_approx(float(pot.get("water")), 0.77), "Älterer Stand verworfen")
	var newer := state.duplicate()
	newer["rev"] = 9
	newer["health"] = 0.5
	pot.call("net_apply", newer)
	_check(is_equal_approx(float(pot.get("health")), 0.5) and int(pot.get("net_rev")) == 9, "Neuerer Stand übernommen")
	# Speichern, alles abräumen, laden.
	var before := {}
	for station: Node3D in [pot, lamp, jar]:
		before[station.get("net_id")] = [station.call("net_state"), station.global_transform]
	sync.set("save_enabled", true)
	sync.set("save_path", "user://test_grow_world.cfg")
	var err: int = sync.call("save_now")
	_check(err == OK, "Gespeichert (%s)" % error_string(err))
	for station: Node in sync.call("stations"):
		station.queue_free()
	await _frames(2)
	_check((sync.call("stations") as Array).is_empty(), "Stationen abgeräumt")
	var loaded: int = sync.call("load_stations")
	await _frames(2)
	_check(loaded == 3, "Drei Stationen geladen (%d)" % loaded)
	var same := true
	var bad := []
	for id: String in before:
		var station: Node3D = sync.call("find", id)
		if station == null:
			same = false
			bad.append(id)
			continue
		var want: Dictionary = before[id][0]
		var got: Dictionary = station.call("net_state")
		for key: String in want:
			var a = want[key]
			var b = got.get(key)
			if (a is float and not is_equal_approx(a, float(b))) or (not a is float and a != b):
				same = false
				bad.append("%s.%s" % [station.get("kind"), key])
		if not station.global_transform.is_equal_approx(before[id][1]):
			same = false
			bad.append("%s.xform" % station.get("kind"))
	_check(same, "Zustand und Lage gleich wie vorher %s" % [bad])
	var pot2: Node = null
	for station: Node in sync.call("stations"):
		if station.get("kind") == &"pot":
			pot2 = station
	_check(pot2 != null and int(pot2.get("stage")) >= 2 and pot2.get_child_count() >= 2, "Geladene Pflanze mit Modell")
	_check(int(sync.call("load_stations")) == 0, "Zweites Laden legt nichts doppelt an")
	# Abbauen speichert sich mit: leere Liste überschreibt den alten Stand.
	for station: Node in sync.call("stations"):
		station.queue_free()
	await _frames(2)
	sync.call("save_now")
	_check(int(sync.call("load_stations")) == 0, "Nach Abräumen gespeichert: nichts mehr da")
	sync.set("save_enabled", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_grow_world.cfg"))


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
