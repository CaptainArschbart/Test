extends SceneTree
## Tankstellen in Sektor 7: Platz auf der Karte, Laden, Zapfsäulen.
##
## Aufruf: godot --headless --path . -s res://tools/tests/test_gas_stations.gd

const WATER := preload("res://scenes/items/data/water_bottle.tres")

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/slum/slum.tscn")
	await _frames(30)
	var content := current_scene.get_node("CityContent")
	var stations: Array[Node3D] = []
	for shop: Node in content.get_children():
		if int(shop.get("kind")) == 1:
			stations.append(shop as Node3D)
	_check(stations.size() == 3, "drei Tankstellen, ist %d" % stations.size())
	var space := current_scene.get_viewport().world_3d.direct_space_state
	for shop in stations:
		_check_site(shop, content, space)
		_check_shop(shop, space)
	_check_key(stations)
	await _check_pumps(stations[0])
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


## Kein Kit-Gebäude, keine Straße in der Grundfläche.
func _check_site(shop: Node3D, content: Node, space: PhysicsDirectSpaceState3D) -> void:
	var blocked := 0
	var road := 0
	var z := -6.0
	while z <= 8.0:
		var x := -7.5
		while x <= 7.5:
			var p: Vector3 = shop.to_global(Vector3(x, 0.0, z))
			var exclude: Array[RID] = []
			for i in 16:
				var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 3.0, 1, exclude)
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					break
				var node := hit.collider as Node
				if content.is_ancestor_of(node):
					exclude.append(hit.rid)
					continue
				if float(hit.position.y) > 0.4:
					blocked += 1
				var cur := node
				while cur != null:
					if cur is SlumStreet and (cur as SlumStreet).kind != SlumStreet.Kind.SLAB:
						road += 1
					cur = cur.get_parent()
				break
			x += 0.5
		z += 0.5
	_check(blocked == 0, "%s frei, %d Punkte belegt" % [shop.position, blocked])
	_check(road == 0, "%s nicht auf der Straße, %d Punkte" % [shop.position, road])
	_check(_crowd_points(shop) == 0, "%s kein Fußweg durch die Fläche" % shop.position)


func _crowd_points(shop: Node3D) -> int:
	var inside := 0
	for crowd: Node in current_scene.find_children("*", "CrowdDirector", true, false):
		var nodes: PackedVector3Array = crowd.get("nodes")
		var edges: PackedInt32Array = crowd.get("edges")
		for e in range(0, edges.size(), 2):
			for t in 11:
				var p: Vector3 = shop.to_local(nodes[edges[e]].lerp(nodes[edges[e + 1]], t * 0.1))
				if absf(p.x) < 7.5 and p.z > -6.0 and p.z < 8.0:
					inside += 1
	return inside


func _check_shop(shop: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var station := shop.get_node("Station") as Node3D
	var interior := station.get_node_or_null(^"ShopInterior")
	_check(interior != null, "%s hat Laden" % shop.position)
	var slots: Array = interior.get("slots")
	_check(slots.size() >= 20, "%s %d Warenplätze" % [shop.position, slots.size()])
	_check(int(interior.call("stock_total")) > 0, "%s hat Ware" % shop.position)
	var keeper := interior.get_node_or_null(^"Keeper") as Node3D
	_check(keeper != null, "%s hat Verkäufer" % shop.position)
	_check(interior.get_node_or_null(^"SecurityCamera") != null, "%s hat Kamera" % shop.position)
	_check(shop.get_node_or_null(^"%SellPad") != null, "%s Verkaufspult per %%SellPad" % shop.position)
	# Nichts schwebt: unter Kasse und Pult liegt die Theke.
	for node: Node3D in [interior.get_node(^"Register") as Node3D, shop.get_node(^"%SellPad") as Node3D]:
		var from := node.global_position + Vector3.UP * 0.02
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.3, 1, [(node as CollisionObject3D).get_rid()])
		_check(not space.intersect_ray(q).is_empty(), "%s %s steht auf der Theke" % [shop.position, node.name])
	# Tür frei: von draußen bis zwischen die Regale.
	var a: Vector3 = station.to_global(Vector3(0.6, 1.0, 1.2))
	var b: Vector3 = station.to_global(Vector3(0.5, 1.0, -1.2))
	_check(space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1)).is_empty(), "%s Tür frei" % shop.position)
	var inside: Vector3 = station.to_global(Vector3(0.5, 1.0, -1.0))
	_check(bool(interior.call("is_inside", _marker(inside))), "%s Innenraum zählt als Laden" % shop.position)
	var outside: Vector3 = station.to_global(Vector3(0.5, 1.0, 1.0))
	_check(not bool(interior.call("is_inside", _marker(outside))), "%s Vorplatz zählt nicht" % shop.position)
	var keeper_eye: Vector3 = interior.call("keeper_eye")
	var door: Vector3 = station.to_global(Vector3(0.6, 1.2, -0.5))
	var view := PhysicsRayQueryParameters3D.create(keeper_eye, door, 1, [(keeper as CollisionObject3D).get_rid()])
	_check(space.intersect_ray(view).is_empty(), "%s Verkäufer sieht die Tür" % shop.position)
	_check(float(interior.call("price_of", WATER)) == 3.0, "%s Aufschlag wie an der Tanke" % shop.position)
	var pumps := 0
	for child: Node in station.get_children():
		if child.has_method("take_hit"):
			pumps += 1
	_check(pumps == 4, "%s vier Zapfsäulen, ist %d" % [shop.position, pumps])


func _marker(at: Vector3) -> Node3D:
	var node := Node3D.new()
	current_scene.add_child(node)
	node.global_position = at
	node.queue_free()
	return node


func _check_key(stations: Array[Node3D]) -> void:
	var cards := 0
	for shop in stations:
		var prop := shop.get_node(^"Station").get_node_or_null(^"KeyCard")
		if prop != null and (prop.get("item") as ItemData).id == "apt_c":
			cards += 1
	_check(cards == 1, "Schlüsselkarte apt_c genau einmal, ist %d" % cards)


func _check_pumps(shop: Node3D) -> void:
	var station := shop.get_node("Station") as Node3D
	var pumps: Array[Node] = []
	for child: Node in station.get_children():
		if child.has_method("take_hit"):
			pumps.append(child)
	var first := pumps[0] as Node3D
	var player := get_first_node_in_group("player") as Node3D
	_check(player != null, "Spieler da")
	player.global_position = first.global_position + first.global_basis * Vector3(2.0, 0.2, 0.0)
	await _frames(3)
	var before: float = player.get("stats").get("hp")
	first.call("take_hit", 20.0, first.global_position, Vector3.UP)
	await _frames(40)
	_check(not bool(first.get("broken")), "ein Treffer lässt die Säule stehen")
	first.call("take_hit", 40.0, first.global_position, Vector3.UP)
	await _frames(40)
	_check(bool(first.get("broken")), "zerschossene Säule geht hoch")
	var after: float = player.get("stats").get("hp")
	_check(after < before, "Explosion trifft den Spieler, %.0f → %.0f" % [before, after])
	var chained := 0
	for pump in pumps:
		if pump != first and bool(pump.get("broken")):
			chained += 1
	_check(chained >= 1, "Nachbarsäule geht mit hoch, %d" % chained)
	first.set("_respawn_left", 0.01)
	await _frames(5)
	_check(not bool(first.get("broken")) and float(first.get("health")) == 45.0, "Säule steht nach Ablauf wieder")
	first.call("_set_burning", false)
