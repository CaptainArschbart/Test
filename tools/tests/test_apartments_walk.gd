extends SceneTree
## Wohnhäuser in Sektor 7 im echten Spielablauf: Spielerfigur läuft durch den Eingang die Treppe
## hoch, bricht Tür und Tresor mit der Brechstange auf, schließt eine zweite Tür auf, geht durch
## alle Zimmer. Danach in jedem Haus der Weg bis in den 2. Stock.
##
## Aufruf: godot --headless --path . -s res://tools/tests/test_apartments_walk.gd
## Letzte Zeile: "CHECKS n FAILS m". Ohne Klassennamen (-s-Skripte laufen vor den Autoloads).

const SLUM := "res://scenes/slum/slum.tscn"
const HOUSES := 8

var _checks := 0
var _fails := 0
var _player: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await _wait(10)
	current_scene.call("_start_game", SLUM)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == SLUM:
			break
		await physics_frame
	var slum := current_scene
	_player = get_first_node_in_group("player") as Node3D
	await _wait(30)
	var houses := slum.find_children("ApartmentHouse", "", true, false)
	_check(houses.size() == HOUSES, "%d Wohnhäuser, ist %d" % [HOUSES, houses.size()])
	_map_checks(houses)
	# Bewohner stehen frei auf dem Boden ihrer Wohnung. Danach stören sie, wie die Gegner, den Weg nur.
	var residents := slum.find_children("Resident*", "", true, false)
	_check(residents.size() > 0, "Es gibt Bewohner: %d" % residents.size())
	for node in residents:
		var person := node as Node3D
		var unit := person.get_parent() as Node3D
		var floor_y := unit.global_position.y + 0.1
		_check(absf(person.global_position.y - floor_y) < 0.2, "%s steht auf dem Boden" % unit.name)
		node.queue_free()
	var enemies := slum.get_node_or_null(^"SlumEnemies")
	if enemies != null:
		enemies.queue_free()
	await _wait(2)
	await _break_in(_house_named(houses, "Res2"))
	for house in houses:
		await _climb(house)
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


func _house_named(houses: Array, building: String) -> Node:
	for house in houses:
		if str(house.get_parent().name) == building:
			return house
	return houses[0]


func _map_checks(houses: Array) -> void:
	var keys := {}
	var doors := 0
	for house in houses:
		var building: Node3D = house.get_parent()
		var label := str(building.name)
		_check(int(building.get("floors")) >= 3, "%s hat mindestens 3 Stockwerke" % label)
		for door in house.find_children("Door", "", true, false):
			doors += 1
			keys[str(door.get("key_id"))] = true
		# Vor dem Eingang muss frei sein: 5 m gerade raus, in Brusthöhe.
		var depth: float = house.get("building_depth")
		var from: Vector3 = house.to_global(Vector3(0.0, 1.2, depth * 0.5 + 0.8))
		var to: Vector3 = house.to_global(Vector3(0.0, 1.2, depth * 0.5 + 5.0))
		var hit: Dictionary = building.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		# Fahrende Autos zählen nicht, sie stehen nur gerade dort.
		var free: bool = hit.is_empty() or hit.collider is CharacterBody3D
		_check(free, "%s: Eingang frei (%s)" % [label, hit.get("collider", "nichts")])
	_check(doors == HOUSES * 4, "%d Wohnungstüren, ist %d" % [HOUSES * 4, doors])
	_check(keys.size() == doors, "Jede Tür hat einen eigenen Schlüssel")


## Läuft waagerecht zum Punkt. Gibt false zurück, wenn die Figur dort nicht ankommt.
func _go(target: Vector3, secs := 7.0) -> bool:
	var left := int(secs * 60.0)
	Input.action_press("move_forward")
	var ok := false
	while left > 0:
		var pos := _player.global_position
		var flat := Vector2(target.x - pos.x, target.z - pos.z)
		if flat.length() < 0.3:
			ok = true
			break
		_player.rotation.y = atan2(-flat.x, -flat.y)
		left -= 1
		await physics_frame
	Input.action_release("move_forward")
	await _wait(6)
	return ok


func _look_at_node(target: Node3D, height := 1.0) -> void:
	var pos := _player.global_position
	var aim := target.global_position
	_player.rotation.y = atan2(-(aim.x - pos.x), -(aim.z - pos.z))
	var head: Node3D = _player.get("head")
	var camera: Node3D = _player.get("camera")
	var eye: Vector3 = camera.global_position
	var flat := Vector2(aim.x - eye.x, aim.z - eye.z).length()
	head.rotation.x = atan2(aim.y + height - eye.y, flat)
	await _wait(3)


func _level_view() -> void:
	var head: Node3D = _player.get("head")
	head.rotation.x = 0.0


func _strike() -> bool:
	await _wait(50)
	var user: Node = _player.get("item_user")
	return bool(user.call("use_selected"))


func _stairs_up(house: Node3D, to_second: bool) -> bool:
	var depth: float = house.get("building_depth")
	var half: float = house.get("corridor_half")
	var run: float = 0.27 * 15.0 * 0.5
	var lane := half * 0.5
	var fh: float = house.get("floor_height")
	_player.global_position = house.to_global(Vector3(0.0, 0.4, depth * 0.5 + 1.6))
	_player.set("velocity", Vector3.ZERO)
	await _wait(10)
	for point: Vector3 in [Vector3(0.0, 0.0, depth * 0.5 - 0.8), Vector3(-lane, 0.0, run + 0.7), Vector3(-lane, 0.0, -run - 0.55)]:
		if not await _go(house.to_global(point)):
			return false
	if absf(_player.global_position.y - (house.global_position.y + fh)) > 0.3:
		return false
	if not to_second:
		return true
	for point: Vector3 in [Vector3(lane, 0.0, -run - 0.7), Vector3(lane, 0.0, run + 0.55)]:
		if not await _go(house.to_global(point)):
			return false
	return absf(_player.global_position.y - (house.global_position.y + fh * 2.0)) < 0.3


func _plan(unit: Node3D, x: float, z: float) -> Vector3:
	return unit.to_global(unit.call("_at", x, 0.0, z))


## Rundgang in Res2: Brechstange kaufen ist hier nur ins Inventar legen.
func _break_in(house: Node3D) -> void:
	var inventory: Node = _player.get("inventory")
	var user: Node = _player.get("item_user")
	var bar: Resource = load("res://scenes/items/data/crowbar.tres")
	inventory.call("add_item", bar, 1)
	for i in int(inventory.call("get_size")):
		if inventory.call("get_item", i) == bar:
			inventory.call("select", i)
	var wanted: Node = root.get_node(^"WantedManager")
	wanted.call("set_stars", 0)
	_check(await _stairs_up(house, true), "Treppe bis in den 2. Stock von Res2")
	var unit: Node3D = house.find_child("Unit_apt_c", true, false)
	var door: Node3D = unit.get_node(^"Door")
	var near: Vector3 = door.to_global(Vector3(0.0, 0.0, 0.85))
	_check(await _go(near), "Zur Tür der Wohnung 2 R gelaufen")
	await _look_at_node(door)
	var target: Object = user.call("find_target")
	_check(target == door, "Fadenkreuz trifft die Tür (%s)" % target)
	if target != null:
		var text: String = target.call("get_interact_text", _player)
		_check(text.contains("Linksklick"), "Hinweis mit Brechstange: %s" % text)
	user.call("interact")
	_check(bool(door.get("locked")), "E ohne Schlüssel öffnet nicht")
	_check(await _strike(), "Brechstange schlägt zu")
	_check(not bool(door.get("locked")) and bool(door.get("forced_open")), "Tür aufgebrochen")
	_check(int(wanted.call("star_count")) == 1, "Einbruch ein Stern")
	_level_view()
	# Durch die Tür, Flur, Wohnküche, Schlafzimmer.
	var bed_wall: float = unit.get("_bed_wall")
	var bath_wall: float = unit.get("_bath_wall")
	var door_x: float = unit.get("_door_x")
	var bath_front: float = unit.get("_bath_front")
	var back: float = unit.get("_back")
	var front: float = unit.get("_front")
	_check(await _go(_plan(unit, door_x, front - 1.0)), "In den Flur der Wohnung")
	# Ins Bad durch den Durchgang.
	_check(await _go(_plan(unit, bath_wall + 0.78, bath_front + 0.6)), "Vor die Badtür")
	_check(await _go(_plan(unit, bath_wall + 0.78, bath_front - 0.9)), "Im Bad")
	_check(await _go(_plan(unit, bath_wall + 0.78, bath_front + 0.6)), "Aus dem Bad")
	_check(await _go(_plan(unit, bath_wall - 0.5, front - 0.7)), "In die Wohnküche")
	_check(await _go(_plan(unit, bed_wall + 0.5, front - 0.72)), "Vor die Schlafzimmertür")
	_check(await _go(_plan(unit, bed_wall - 0.7, front - 0.72)), "Ins Schlafzimmer")
	var safe: Node3D = unit.get_node(^"Safe")
	_check(await _go(_plan(unit, bed_wall - 0.45, back + 1.75)), "Zum Tresor gelaufen")
	await _look_at_node(safe, 0.45)
	_check(user.call("find_target") == safe, "Fadenkreuz trifft den Tresor")
	var before := _count(inventory, "cash_wad")
	user.call("interact")
	_check(_count(inventory, "cash_wad") == before, "E öffnet den Tresor nicht")
	_check(await _strike(), "Brechstange schlägt auf den Tresor")
	_check(not bool(safe.get("sealed")), "Tresor aufgebrochen")
	_check(bool(user.call("interact")), "Tresor mit E ausgeräumt")
	_check(_count(inventory, "cash_wad") == before + int(safe.get("count")), "Geld aus dem Tresor im Inventar")
	_check(bool(safe.get("taken")) and safe.visible, "Tresor steht leer da")
	_level_view()
	# Zweite Wohnung: Schlüssel statt Brechstange, ohne Fahndung.
	var other: Node3D = house.find_child("Unit_apt_3", true, false)
	var other_door: Node3D = other.get_node(^"Door")
	var key: Resource = load("res://scenes/crime/apartment_block.gd").call("key_item", str(other_door.get("key_id")))
	inventory.call("add_item", key, 1)
	wanted.call("set_stars", 0)
	_player.global_position = other_door.to_global(Vector3(0.0, 0.3, 0.85))
	await _wait(10)
	await _look_at_node(other_door)
	var locked_target: Object = user.call("find_target")
	_check(locked_target == other_door and str(other_door.call("get_interact_text", _player)) == "Aufschließen", "Mit Schlüssel: Aufschließen")
	user.call("interact")
	_check(not bool(other_door.get("locked")) and not bool(other_door.get("forced_open")), "Schlüssel öffnet leise")
	_check(int(wanted.call("star_count")) == 0, "Mit Schlüssel keine Fahndung")
	_level_view()
	wanted.call("set_stars", 0)


func _count(inventory: Node, id: String) -> int:
	var total := 0
	for i in int(inventory.call("get_size")):
		var item: Resource = inventory.call("get_item", i)
		if item != null and str(item.get("id")) == id:
			total += int(inventory.call("get_count", i))
	return total


func _climb(house: Node3D) -> void:
	var label := str(house.get_parent().name)
	for second: bool in [false, true]:
		var fine: bool = await _stairs_up(house, second)
		_check(fine, "%s: Treppe bis Stock %d" % [label, 2 if second else 1])
		if not fine:
			print("    Stand: ", house.to_local(_player.global_position))
			return
		var user: Node = _player.get("item_user")
		var seen := 0
		for door in house.find_children("Door", "", true, false):
			var upper: bool = door.get_parent().global_position.y > house.global_position.y + 4.0
			if upper != second:
				continue
			# Vor der Tür stehen. Eine schon offene Tür lässt sich nicht mehr anvisieren.
			var there: bool = await _go(door.to_global(Vector3(0.0, 0.0, 0.85)))
			await _look_at_node(door)
			if there and (user.call("find_target") == door or not bool(door.get("locked"))):
				seen += 1
		_level_view()
		_check(seen == 2, "%s: beide Türen in Stock %d erreichbar (%d)" % [label, 2 if second else 1, seen])
