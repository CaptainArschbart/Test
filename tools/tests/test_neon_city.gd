extends SceneTree
## Prüft die Neon City auf Logikfehler: Lädt die Map, wartet aufs Navmesh und testet dann
## Start, Fußwege, Fahrspuren, Item-Plätze, Ladeneingänge, Erreichbarkeit und Rand.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_neon_city.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const MAP := "res://scenes/neon_city/neon_city.tscn"
const WORLD := 1
## Laufhöhe für Strahlen entlang der Wege (Hüfte).
const HIP := 1.0

var _checks := 0
var _fails := 0
var _space: PhysicsDirectSpaceState3D
## Autos und Fußgänger bewegen sich, sie zählen nicht als Hindernis der Map.
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

	# Item-Plätze.
	var bad_items := PackedStringArray()
	var spots := get_nodes_in_group(&"item_spawn")
	for spot in spots:
		var p := (spot as Node3D).global_position
		var y := _floor(p + Vector3.UP * 0.1)
		if absf(y - p.y) > 0.25 or _blocked(p, 0.25):
			bad_items.append("%s %s Boden %.2f" % [spot.name, p.round(), y])
	_check(spots.size() >= 20 and bad_items.is_empty(), "%d Item-Plätze auf freiem Boden %s" % [spots.size(), bad_items])

	# Erreichbarkeit über das Navmesh: Skywalk, alle Item-Plätze, alle Läden.
	var region := director.get("region") as NavigationRegion3D
	var map := region.get_navigation_map()
	var from := NavigationServer3D.map_get_closest_point(map, start)
	var unreachable := PackedStringArray()
	for spot in spots:
		var target := (spot as Node3D).global_position
		if not _reachable(map, from, target):
			unreachable.append(spot.name)
	for shop in shops:
		var front := 3.5 if shop.get("kind") == 0 else 8.0
		var target := shop.global_position + shop.global_basis.z * (front + 1.5)
		if not _reachable(map, from, target):
			unreachable.append(shop.name)
	_check(unreachable.is_empty(), "Alle Item-Plätze und Läden vom Start erreichbar %s" % [unreachable])
	var sky := scene.find_child("Spot_Skywalk", true, false) as Node3D
	_check(sky != null and _reachable(map, from, sky.global_position), "Skywalk über die Treppen erreichbar")
	# Hinter dem Stadtrand (zwischen Häusern und Wand) kommt man nicht hin.
	var behind := [Vector3(176, 0, 0), Vector3(-176, 0, 40), Vector3(0, 0, 176), Vector3(60, 0, -176)]
	var leaks := PackedStringArray()
	for p: Vector3 in behind:
		if _reachable(map, from, p):
			leaks.append(str(p))
	_check(leaks.is_empty(), "Hinter dem Stadtrand nicht erreichbar %s" % [leaks])
	_finish()


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
