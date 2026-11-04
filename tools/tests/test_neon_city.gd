extends SceneTree
## Prüft die Neon City auf Logikfehler: Lädt die Map, wartet aufs Navmesh und testet dann
## Start, Fußwege, Fahrspuren, Ladeneingänge, Gegnerstreifen, Erreichbarkeit und Rand. Auf dem
## Boden liegen keine Items (Beute nur von Gegnern), unbenutzbare Geldautomaten gibt es nicht.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_neon_city.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const MAP := "res://scenes/neon_city/neon_city.tscn"
const WORLD := 1
## Laufhöhe für Strahlen entlang der Wege (Hüfte).
const HIP := 1.0
## Mitte der Ostbahn des Skywalks.
const SKYWALK := Vector3(19, 7, 0)
## Gehweg 0,15 m, Fahrbahn 0: alles darunter ist Straße.
const ROAD_Y := 0.07

var _checks := 0
var _fails := 0
var _space: PhysicsDirectSpaceState3D
## Autos, Fußgänger und Gegner bewegen sich, sie zählen nicht als Hindernis der Map.
var _exclude: Array[RID] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, WORLD, _exclude)
	return _space.intersect_ray(q)


## Boden unter p (Strahl von 3 m darüber), INF wenn nichts.
func _floor(p: Vector3) -> float:
	var hit := _ray(p + Vector3.UP * 3.0, p + Vector3.DOWN * 2.0)
	return (hit["position"] as Vector3).y if not hit.is_empty() else INF


## Ist an p in Körperhöhe etwas Festes (Kugel r)?
func _blocked(p: Vector3, r := 0.3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = r
	q.shape = s
	q.transform = Transform3D(Basis(), p + Vector3.UP * HIP)
	q.collision_mask = WORLD
	q.exclude = _exclude
	return not _space.intersect_shape(q, 1).is_empty()


func _run() -> void:
	change_scene_to_file(MAP)
	for i in 10:
		await physics_frame
	var scene := current_scene
	_check(scene != null and scene.scene_file_path == MAP, "Neon City geladen")
	var director := get_first_node_in_group(&"enemy_director")
	_check(director != null, "Gegner-Director da (Navmesh für Gegner und Polizei)")
	var waited := 0
	while director != null and not director.get("is_nav_ready") and waited < 1200:
		await physics_frame
		waited += 1
	_check(director != null and director.get("is_nav_ready"), "Navmesh gebacken (%d Frames)" % waited)
	for i in 5:
		await physics_frame
	_space = (scene as Node3D).get_world_3d().direct_space_state
	var life := scene.get_node_or_null("NeonCityLife")
	if life != null:
		for body in life.find_children("*", "CollisionObject3D", true, false):
			_exclude.append((body as CollisionObject3D).get_rid())
	var foes := scene.get_node_or_null("NeonCityEnemies")
	if foes != null:
		for body in foes.find_children("*", "CollisionObject3D", true, false):
			_exclude.append((body as CollisionObject3D).get_rid())

	# Spieler-Start.
	var player := get_first_node_in_group(&"player") as Node3D
	_check(player != null, "Spieler gespawnt")
	var start := player.global_position
	_check(absf(_floor(start) - start.y) < 0.35, "Spieler steht auf Boden (%.2f)" % start.y)
	_check(not _blocked(start), "Spieler-Start ist frei")

	# Läden.
	var content := scene.get_node_or_null("CityContent")
	var shops: Array[Node3D] = []
	if content != null:
		for c in content.get_children():
			shops.append(c as Node3D)
	_check(shops.size() == 7, "7 Läden aufgebaut (%d)" % shops.size())
	var bad_fronts := PackedStringArray()
	for shop in shops:
		# 1,5 m vor der Front (Waffenladen 3,5 m, Tankstelle 8 m vor der Mitte) muss Gehweg sein.
		var front := 3.5 if str(shop.get("kind")) == "0" or shop.get("kind") == 0 else 8.0
		var p := shop.global_position + shop.global_basis.z * (front + 1.5)
		if absf(_floor(p) - 0.15) > 0.2 or _blocked(p, 0.4):
			bad_fronts.append("%s bei %s" % [shop.name, p.round()])
	_check(bad_fronts.is_empty(), "Vor jedem Laden ist Gehweg frei %s" % [bad_fronts])
	var layouts := PackedStringArray()
	for shop in shops:
		for e: String in shop.get("layout_errors"):
			layouts.append("%s: %s" % [shop.name, e])
	_check(layouts.is_empty(), "R1/R2/R5 Ladeninnenräume ohne Placement-Fehler %s" % [layouts.slice(0, 6)])

	# Fußwege.
	var crowd := scene.find_child("Crowd", true, false)
	var nodes: PackedVector3Array = crowd.get("nodes")
	var edges: PackedInt32Array = crowd.get("edges")
	var bad_nodes := PackedStringArray()
	for p in nodes:
		if absf(_floor(p) - p.y) > 0.25 or _blocked(p):
			bad_nodes.append(str(p.round()))
	_check(nodes.size() > 300 and bad_nodes.is_empty(), "%d Fußweg-Knoten auf freiem Boden %s" % [nodes.size(), bad_nodes.slice(0, 8)])
	var bad_edges := PackedStringArray()
	for k in range(0, edges.size(), 2):
		var a := nodes[edges[k]] + Vector3.UP * HIP
		var b := nodes[edges[k + 1]] + Vector3.UP * HIP
		if not _ray(a, b).is_empty() or not _ray(b, a).is_empty():
			bad_edges.append("%s-%s" % [nodes[edges[k]].round(), nodes[edges[k + 1]].round()])
	_check(bad_edges.is_empty(), "%d Fußwege ohne Hindernis %s" % [edges.size() / 2, bad_edges.slice(0, 8)])

	# Fahrspuren zwischen den Kreuzungen.
	var traffic := scene.find_child("Traffic", true, false)
	var junctions: PackedVector3Array = traffic.get("junctions")
	var roads: PackedInt32Array = traffic.get("roads")
	var lane: float = traffic.get("lane_offset")
	var bad_lanes := PackedStringArray()
	for k in range(0, roads.size(), 2):
		var a := junctions[roads[k]]
		var b := junctions[roads[k + 1]]
		var side := (b - a).normalized().cross(Vector3.UP) * lane
		for s: float in [-1.0, 1.0]:
			var from := a + side * s + Vector3.UP * 0.8
			var to := b + side * s + Vector3.UP * 0.8
			if not _ray(from, to).is_empty() or absf(_floor((a + b) * 0.5 + side * s)) > 0.05:
				bad_lanes.append("%s-%s" % [a.round(), b.round()])
	_check(roads.size() == 80 and bad_lanes.is_empty(), "40 Straßen, Fahrspuren frei und auf Fahrbahnhöhe %s" % [bad_lanes])

	# Keine Items auf dem Boden, keine Deko-Geldautomaten.
	var pickups := scene.find_children("*", "ItemPickup", true, false).size() + get_nodes_in_group(&"item_spawn").size()
	_check(pickups == 0, "Keine Items auf dem Boden (%d)" % pickups)
	var atms := 0
	for n in scene.find_children("*", "Node3D", true, false):
		var model = n.get("model")
		if model is String and (model as String).contains("ATM"):
			atms += 1
	_check(atms == 0, "Keine unbenutzbaren Geldautomaten (%d)" % atms)

	# Erreichbarkeit über das Navmesh: Skywalk, alle Läden, alle Gegner.
	var region := director.get("region") as NavigationRegion3D
	var map := region.get_navigation_map()
	var from := NavigationServer3D.map_get_closest_point(map, start)
	var unreachable := PackedStringArray()
	for shop in shops:
		var front := 3.5 if shop.get("kind") == 0 else 8.0
		var target := shop.global_position + shop.global_basis.z * (front + 1.5)
		if not _reachable(map, from, target):
			unreachable.append(shop.name)
	_check(unreachable.is_empty(), "Alle Läden vom Start erreichbar %s" % [unreachable])
	_check(_reachable(map, from, SKYWALK), "Skywalk über die Treppen erreichbar")
	# Zweite Ebene: jede Galerie in den Höfen (Neonmeile, Megablöcke) steht auf Deckhöhe und ist zu Fuß erreichbar.
	var decks := 0
	var cut_off := PackedStringArray()
	for n in scene.find_children("Galerie*", "Node3D", true, false):
		if n is NeonSkywalk and not String(n.name).begins_with("GalerieEcke"):
			decks += 1
			var top := (n as Node3D).global_position + Vector3.UP * float(n.get("height"))
			if absf(_floor(top + Vector3.UP * 0.5) - top.y) > 0.1 or not _reachable(map, from, top):
				cut_off.append(n.name)
	_check(decks >= 18 and cut_off.is_empty(), "Zweite Ebene: %d Galerien auf 6 m erreichbar %s" % [decks, cut_off])
	_check_enemies(scene, map, from, nodes, edges)
	# Hinter dem Stadtrand (zwischen Häusern und Wand) kommt man nicht hin.
	var behind := [Vector3(176, 0, 0), Vector3(-176, 0, 40), Vector3(0, 0, 176), Vector3(60, 0, -176)]
	var leaks := PackedStringArray()
	for p: Vector3 in behind:
		if _reachable(map, from, p):
			leaks.append(str(p))
	_check(leaks.is_empty(), "Hinter dem Stadtrand nicht erreichbar %s" % [leaks])
	_check_placement(scene, nodes, edges)
	_finish()


## Placement-Regeln aus Schedule 1, Phase 0, für alle Details aus den Packs (NeonDressing):
## R1 nichts schwebt (Boden-Teile stehen auf einer Fläche, Wandteile haben eine Wand im Rücken,
## Kabel und Ausleger-Schilder hängen an Wänden), R3 flache Teile liegen sichtbar über dem Boden
## (kein Z-Fighting), R6 über Fuß- und Streifenwegen ist bis 2,3 m Höhe nichts im Weg.
func _check_placement(scene: Node, nodes: PackedVector3Array, edges: PackedInt32Array) -> void:
	# Strahlen ignorieren die Details selbst (sonst trifft ein Boden-Strahl die eigene Kollision).
	var saved := _exclude.duplicate()
	var dressing: Array[NeonDressing] = []
	for n in scene.find_children("*", "Node3D", true, false):
		if n is NeonDressing:
			dressing.append(n)
		if (n is NeonDressing or n is NeonProp) and n.get_node_or_null("Body") != null:
			_exclude.append((n.get_node("Body") as CollisionObject3D).get_rid())
	var floating := PackedStringArray()
	var loose := PackedStringArray()
	var fighting := PackedStringArray()
	var obstacles: Array = []  # [AABB, Name]
	var count := 0
	for d in dressing:
		var box: AABB = NeonDressing._parts(d.model, d.emission_tint)["box"]
		var base := Basis(Vector3.UP, deg_to_rad(d.yaw_fix)) * Basis.from_scale(Vector3.ONE * d.model_scale)
		var items := d.items
		for k in range(0, items.size(), NeonDressing.STRIDE):
			count += 1
			var rot := Basis(Vector3.UP, deg_to_rad(items[k + 3]))
			var stretch := Vector3(items[k + 4], items[k + 5], items[k + 6])
			var xf := d.global_transform * Transform3D(rot * Basis.from_scale(stretch) * base,
					Vector3(items[k], items[k + 1], items[k + 2]))
			var origin := xf.origin
			var world := xf * box
			var fwd := (d.global_basis * rot * Vector3.BACK).normalized()
			var side := (d.global_basis * rot * Vector3.RIGHT).normalized()
			var local := (Basis(Vector3.UP, deg_to_rad(d.yaw_fix)) * box.size).abs() * d.model_scale * stretch
			var h := world.size.y
			var tag := "%s %s" % [d.name.rstrip("0123456789_"), origin.snapped(Vector3.ONE * 0.1)]
			match d.mount:
				"ground", "flat":
					# Mit eigener Kollisionsbox (Ampel: nur der Mast) zählt deren Fuß, nicht die Mitte der Hülle.
					var foot := origin + d.global_basis * rot * d.collider_offset
					var hit := _ray(foot + Vector3.UP * 0.6, foot + Vector3.DOWN * 0.6)
					if hit.is_empty() or absf((hit["position"] as Vector3).y - foot.y) > 0.03:
						floating.append(tag)
					elif d.mount == "flat" and origin.y + h - (hit["position"] as Vector3).y < 0.004:
						fighting.append(tag)
				"wall":
					var c := origin + Vector3.UP * h * 0.5
					if _ray(c + fwd * 0.05, c - fwd * (local.z * 0.5 + 0.45)).is_empty():
						loose.append(tag)
				"hang":
					var top := origin + Vector3.UP * h
					for s: float in [-1.0, 1.0]:
						var e := top + side * s * local.x * 0.5
						if _ray(e - side * s * 0.3, e + side * s * 0.6).is_empty():
							loose.append(tag)
							break
				"blade":
					var c := origin + Vector3.UP * h * 0.5
					var reach := local.x * 0.5 + 0.5
					if _ray(c, c + side * reach).is_empty() and _ray(c, c - side * reach).is_empty():
						loose.append(tag)
			if d.mount == "flat" or h < 0.1:
				continue
			if d.collider_size != Vector3.ZERO:
				var cc := origin + d.global_basis * rot * d.collider_offset
				world = AABB(cc - Vector3(d.collider_size.x, 0, d.collider_size.z) * 0.5, d.collider_size).abs()
			obstacles.append([world, tag])
	_exclude = saved
	_check(count > 3000, "%d Details aus den Packs geprüft" % count)
	_check(floating.is_empty(), "R1 Kein Detail schwebt oder steckt im Boden %s" % [floating.slice(0, 8)])
	_check(loose.is_empty(), "R1 Wandteile, Kabel und Schilder haben Halt an einer Wand %s" % [loose.slice(0, 8)])
	_check(fighting.is_empty(), "R3 Flache Teile liegen mindestens 4 mm über dem Boden %s" % [fighting.slice(0, 8)])
	# R6: Wegpunkte alle 0,5 m (Fußwege und Streifen), nach 4-m-Zellen einsortiert.
	var cells := {}
	var legs: Array = []
	for k in range(0, edges.size(), 2):
		legs.append([nodes[edges[k]], nodes[edges[k + 1]]])
	var routes := scene.get_node_or_null("NeonCityEnemies/Routes")
	for route in (routes.get_children() if routes != null else []):
		var pts: Array[Vector3] = []
		for m in route.get_children():
			pts.append((m as Node3D).global_position)
		for i in pts.size():
			legs.append([pts[i], pts[(i + 1) % pts.size()]])
	for leg: Array in legs:
		var a: Vector3 = leg[0]
		var b: Vector3 = leg[1]
		var n := maxi(1, int(a.distance_to(b) / 0.5))
		for i in n + 1:
			var p := a.lerp(b, float(i) / n)
			var key := Vector2i(floori(p.x / 4.0), floori(p.z / 4.0))
			if not cells.has(key):
				cells[key] = []
			(cells[key] as Array).append(p)
	var low := PackedStringArray()
	for o: Array in obstacles:
		var bb: AABB = o[0]
		var hit := false
		for cx in range(floori((bb.position.x - 0.25) / 4.0), floori((bb.end.x + 0.25) / 4.0) + 1):
			for cz in range(floori((bb.position.z - 0.25) / 4.0), floori((bb.end.z + 0.25) / 4.0) + 1):
				for p: Vector3 in cells.get(Vector2i(cx, cz), []):
					if p.x > bb.position.x - 0.25 and p.x < bb.end.x + 0.25 and p.z > bb.position.z - 0.25 \
							and p.z < bb.end.z + 0.25 and bb.position.y < p.y + 2.3 and bb.end.y > p.y + 0.05:
						hit = true
						break
				if hit:
					break
			if hit:
				break
		if hit:
			low.append(o[1])
	_check(low.is_empty(), "R6 Über Fuß- und Streifenwegen bis 2,3 m nichts im Weg %s" % [low.slice(0, 8)])


## Gegner: keine Scharfschützen, Wegpunkte auf freiem Gehweg-Niveau, jede Teilstrecke gerade frei,
## der Navmesh-Pfad dazwischen nie auf der Fahrbahn, alle vom Start erreichbar. Wachposten stehen
## nicht auf Fußwegen.
func _check_enemies(scene: Node, map: RID, from: Vector3, nodes: PackedVector3Array, edges: PackedInt32Array) -> void:
	var foes := scene.get_node_or_null("NeonCityEnemies/Enemies")
	var list: Array[Node] = foes.get_children() if foes != null else []
	var snipers := PackedStringArray()
	var lost := PackedStringArray()
	var posts: Array[Vector3] = []
	for e in list:
		var prof = e.get("profile")
		if prof != null and (str(prof.resource_path).contains("sniper") or int(prof.get("style")) == 2):
			snipers.append(e.name)
		if e.get("route") == null:
			var home: Vector3 = e.get("_home_position")
			posts.append(home)
			if absf(_floor(home + Vector3.UP * 0.2) - 0.15) > 0.2 or not _reachable(map, from, home):
				lost.append(e.name)
	_check(list.size() >= 24, "%d Gegner in der Neon City" % list.size())
	_check(snipers.is_empty(), "Keine Scharfschützen %s" % [snipers])
	var routes := scene.get_node_or_null("NeonCityEnemies/Routes")
	var bad_points := PackedStringArray()
	var bad_legs := PackedStringArray()
	var road_legs := PackedStringArray()
	for route in (routes.get_children() if routes != null else []):
		var pts: Array[Vector3] = []
		for m in route.get_children():
			pts.append((m as Node3D).global_position)
		for p in pts:
			var y := _floor(p + Vector3.UP * 0.2)
			if absf(y - p.y) > 0.25 or y < ROAD_Y or _blocked(p, 0.35):
				bad_points.append("%s %s" % [route.name, p.round()])
		if not _reachable(map, from, pts[0]):
			lost.append(route.name)
		for k in pts.size():
			var a := pts[k]
			var b := pts[(k + 1) % pts.size()]
			if not _ray(a + Vector3.UP * HIP, b + Vector3.UP * HIP).is_empty():
				bad_legs.append("%s %s-%s" % [route.name, a.round(), b.round()])
			var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, a),
					NavigationServer3D.map_get_closest_point(map, b), true)
			for i in range(path.size() - 1):
				for t: float in [0.0, 0.5]:
					var q := path[i].lerp(path[i + 1], t)
					if _floor(q + Vector3.UP * 0.5) < ROAD_Y:
						road_legs.append("%s bei %s" % [route.name, q.round()])
						break
	_check(routes != null and routes.get_child_count() >= 10 and bad_points.is_empty(),
			"Streifenpunkte auf freiem Gehweg %s" % [bad_points.slice(0, 6)])
	_check(bad_legs.is_empty(), "Streifen-Teilstrecken ohne Hindernis %s" % [bad_legs.slice(0, 6)])
	_check(road_legs.is_empty(), "Keine Streife über eine Fahrbahn %s" % [road_legs.slice(0, 6)])
	_check(lost.is_empty(), "Alle Gegner und Streifen vom Start erreichbar %s" % [lost])
	var in_way := PackedStringArray()
	for post in posts:
		for k in range(0, edges.size(), 2):
			var a := nodes[edges[k]]
			var b := nodes[edges[k + 1]]
			var c := Geometry3D.get_closest_point_to_segment(post, a, b)
			if Vector2(c.x - post.x, c.z - post.z).length() < 0.9:
				in_way.append(str(post.round()))
				break
	_check(in_way.is_empty(), "Wachposten stehen nicht auf Fußwegen %s" % [in_way])


## Endet der Navmesh-Pfad nah am Ziel (und liegt das Ziel selbst auf dem Navmesh)?
func _reachable(map: RID, from: Vector3, target: Vector3) -> bool:
	var on_mesh := NavigationServer3D.map_get_closest_point(map, target)
	if on_mesh.distance_to(target) > 1.5:
		return false
	var path := NavigationServer3D.map_get_path(map, from, on_mesh, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(on_mesh) < 1.0


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
