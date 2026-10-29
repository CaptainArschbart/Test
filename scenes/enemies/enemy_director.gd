class_name EnemyDirector
extends Node3D
## Verwaltet die Gegner einer Map: Navmesh, Detailstufen (LOD) und wer gerade schießen darf.
##
## Navmesh: wird beim Start aus allen statischen Kollisionen der Map (Layer world) gebacken,
## in einem Hintergrund-Thread (~0,5 s für Sektor 7). Das Mapkit baut seine Geometrie erst zur
## Laufzeit, ein gespeichertes Navmesh würde bei jeder Map-Änderung veralten. Bis es fertig ist,
## stehen die Gegner still (nav_ready).
##
## LOD: alle 0,25 s nach Abstand zur Kamera sortiert. Die nächsten `max_full_ai` innerhalb
## `full_distance` denken jedes Physik-Frame, weiter weg 5× pro Sekunde, hinter `sleep_distance`
## gar nicht (außer im Alarm). Taschenlampen nur bis `light_distance`.
##
## Angriffe: höchstens `max_shooters` Gegner schießen gleichzeitig auf den Spieler.

signal nav_ready

const GROUP := &"enemy_director"

@export_group("Navmesh")
@export var bake_on_ready := true
## Ab hier wird die Geometrie fürs Navmesh gesammelt (die Map). Leer = Elternknoten.
@export var source_root: NodePath
## Bereich, in dem gebacken wird (Standard ±82 m; Sektor 7 setzt seit der Erweiterung ±140 m).
@export var bake_area := AABB(Vector3(-82, -3, -82), Vector3(164, 45, 164))
@export var agent_radius := 0.25
@export var agent_height := 1.8
## Höchste Stufe, die ein Gegner hochgeht (Treppen im Kit: 0,2 m).
@export var agent_max_climb := 0.4
@export var agent_max_slope := 40.0

@export_group("Leistung")
@export var max_full_ai := 12
@export var full_distance := 55.0
@export var sleep_distance := 110.0
@export var light_distance := 45.0
@export var max_shooters := 3

var region: NavigationRegion3D
var is_nav_ready := false

var _lod_timer := 0.0
var _shooters: Array[Node] = []
var _bake_started_msec := 0


func _ready() -> void:
	add_to_group(GROUP)
	region = get_node_or_null("NavRegion") as NavigationRegion3D
	if region == null:
		region = NavigationRegion3D.new()
		region.name = "NavRegion"
		add_child(region)
	if bake_on_ready:
		bake.call_deferred()


static func find(tree: SceneTree) -> EnemyDirector:
	return tree.get_first_node_in_group(GROUP) as EnemyDirector if tree != null else null


## Navmesh aus der Map backen. Die Map (Elternknoten) muss fertig gebaut sein.
func bake() -> void:
	var map_root := get_node_or_null(source_root) if not source_root.is_empty() else null
	if map_root == null:
		map_root = get_parent() if get_parent() != null else self
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.25
	mesh.cell_height = 0.1
	mesh.agent_radius = agent_radius
	mesh.agent_height = agent_height
	mesh.agent_max_climb = agent_max_climb
	mesh.agent_max_slope = agent_max_slope
	mesh.region_min_size = 2.0
	# Monotone: Regionen überlappen sich garantiert nie. Mit Watershed (Standard) bekommen die
	# Feuertreppen (Fluchten liegen übereinander) Dreiecke, die Stockwerke verbinden, und die Gegner
	# bleiben auf dem ersten Podest stehen. Layers wäre auch richtig, braucht für Sektor 7 aber Minuten.
	mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.filter_baking_aabb = bake_area
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, mesh.cell_height)
	var source := NavigationMeshSourceGeometryData3D.new()
	_bake_started_msec = Time.get_ticks_msec()
	NavigationServer3D.parse_source_geometry_data(mesh, source, map_root)
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_baked.bind(mesh))


func _on_baked(mesh: NavigationMesh) -> void:
	if not is_inside_tree():
		return
	region.navigation_mesh = mesh
	print("EnemyDirector: Navmesh %d Polygone in %d ms" % [mesh.get_polygon_count(), Time.get_ticks_msec() - _bake_started_msec])
	# Die Karte übernimmt das Navmesh erst beim nächsten Sync.
	# Fertig, sobald die Karte das Navmesh kennt (ein Punkt lässt sich darauf abbilden).
	var map := get_world_3d().navigation_map
	var probe := mesh.get_vertices()[0] if mesh.get_vertices().size() > 0 else Vector3.ZERO
	for i: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_closest_point_owner(map, probe).is_valid():
			break
	is_nav_ready = true
	nav_ready.emit()


## Nächster Punkt auf dem Navmesh (oder `point`, wenn es noch keins gibt).
func snap(point: Vector3) -> Vector3:
	if not is_nav_ready:
		return point
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)


## Deckungspunkt in der Nähe von `from`, den `threat_eye` nicht sieht. Vector3.INF = keiner.
func find_cover(from: Vector3, threat_eye: Vector3, radius := 7.0, exclude: Array[RID] = []) -> Vector3:
	if not is_nav_ready:
		return Vector3.INF
	var space := get_world_3d().direct_space_state
	var best := Vector3.INF
	var best_score := INF
	var away := Vector3(from.x - threat_eye.x, 0.0, from.z - threat_eye.z).normalized()
	for i: int in 14:
		var angle := TAU * i / 14.0
		var dist := radius * (0.45 if i % 2 == 0 else 1.0)
		var candidate := snap(from + Vector3(cos(angle), 0.0, sin(angle)) * dist)
		if absf(candidate.y - from.y) > 1.5:
			continue
		var chest := candidate + Vector3.UP * 1.1
		var query := PhysicsRayQueryParameters3D.create(threat_eye, chest, 1, exclude)
		if space.intersect_ray(query).is_empty():
			continue
		# Lieber nah und vom Spieler weg.
		var dir := Vector3(candidate.x - from.x, 0.0, candidate.z - from.z).normalized()
		var score := from.distance_to(candidate) - away.dot(dir) * 2.0
		if score < best_score:
			best_score = score
			best = candidate
	return best


func request_attack(enemy: Node) -> bool:
	_shooters = _shooters.filter(func(e: Node) -> bool: return is_instance_valid(e) and e.is_attacking())
	if enemy in _shooters:
		return true
	if _shooters.size() >= max_shooters:
		return false
	_shooters.append(enemy)
	return true


func release_attack(enemy: Node) -> void:
	_shooters.erase(enemy)


func _physics_process(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer > 0.0:
		return
	_lod_timer = 0.25
	_update_lod()


func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var list: Array = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		list.append([enemy.global_position.distance_squared_to(eye), enemy])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var full := 0
	for entry: Array in list:
		var enemy: Enemy = entry[1]
		var dist := sqrt(entry[0])
		var lod := Enemy.Lod.SLEEP
		if dist < full_distance and full < max_full_ai:
			lod = Enemy.Lod.FULL
			full += 1
		elif dist < sleep_distance or enemy.is_engaged():
			lod = Enemy.Lod.LOW
		enemy.set_lod(lod, dist < light_distance)
