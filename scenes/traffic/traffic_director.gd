class_name TrafficDirector
extends Node3D
## Verkehr einer Map: baut das RoadNetwork aus Kreuzungen und Straßen (aus tools/gen_slum_map.py),
## setzt die Autos (TrafficCar) auf die Spuren und regelt die Kreuzungen.
##
## Kreuzungen: Ein Auto fährt nur ein, wenn keine Kurve, die seine kreuzt, gerade befahren wird und
## auf der Spur danach Platz ist. Wer länger wartet, kommt zuerst (keine Dauer-Blockade).
## Hindernisse: einmal pro Physik-Frame werden Spieler, Fußgänger, Gegner und Autos als Punkte
## gesammelt (obstacles_near). Autos und Fußgänger fragen diese Liste.
## Leistung: Autos hinter `far_distance` rechnen nur 10× pro Sekunde, Licht und Motorton nur nah.
## Multiplayer: Nur der Host fährt die Autos. Er schickt über WorldSync (Gruppe NPC_GROUP) alle 0,1 s
## Spur, Strecke und Tempo jedes Autos. Clients erzeugen dieselben Autos (gleiche Art und Zufallszahl)
## und lassen sie nur nachfahren (TrafficCar.net_puppet).

enum Kind { PLAYER, PERSON, ENEMY, CAR }

const GROUP := &"traffic_director"
const CAR_GROUP := &"traffic_car"
const CarScript := preload("res://scenes/traffic/traffic_car.gd")
const Sounds := preload("res://scenes/traffic/vehicle_sounds.gd")

@export_group("Straßennetz")
@export var junctions := PackedVector3Array()
## Wo die Spur vor der Kreuzungsmitte endet (je Kreuzung).
@export var junction_stop := PackedFloat32Array()
## 1 = Kreuzung hat Zebrastreifen (nur zur Info für Fußgänger).
@export var junction_crosswalk := PackedInt32Array()
## Straßen als Paare von Kreuzungs-Indizes.
@export var roads := PackedInt32Array()
@export var lane_offset := 2.25

@export_group("Autos")
@export var car_count := 16
@export var speed_min := 8.0
@export var speed_max := 11.5
@export var seed_value := 35
## Kein Auto startet näher als das am Spieler.
@export var spawn_clearance := 14.0

@export_group("Leistung")
@export var far_distance := 110.0
@export var light_distance := 75.0
@export var sound_distance := 50.0

var network: RoadNetwork
var cars: Array[TrafficCar] = []
## [Position, Radius, Knoten, Kind]
var obstacles: Array = []

var _active := {}  # Kreuzung -> Array[[Kurve, Auto]]
var _waiting := {}  # Kreuzung -> {Auto: [Kurve, seit]}
var _lane_cars := {}  # Spur -> Array[TrafficCar]
var _lod_timer := 0.0
var _hit_audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = -10
	network = RoadNetwork.new(junctions, junction_stop, roads, lane_offset)
	_hit_audio = AudioStreamPlayer3D.new()
	_hit_audio.bus = &"SFX"
	_hit_audio.max_distance = 40.0
	_hit_audio.stream = Sounds.hit()
	add_child(_hit_audio)
	add_to_group(WorldSync.NPC_GROUP)
	# Client: Die Autos kommen vom Host (net_apply_state).
	if not WorldSync.is_client():
		_spawn_cars.call_deferred()


static func find(tree: SceneTree) -> TrafficDirector:
	return tree.get_first_node_in_group(GROUP) as TrafficDirector if tree != null else null


func _spawn_cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var avoid: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			avoid.append((node as Node3D).global_position)
	var used := {}  # Spur -> Array[s]
	var lanes := network.lanes.duplicate()
	var tries := 0
	while cars.size() < car_count and tries < car_count * 30:
		tries += 1
		var lane: int = lanes[rng.randi() % lanes.size()]
		var p := network.pieces[lane]
		if p.length < 12.0:
			continue
		var start := rng.randf_range(3.0, p.length - 6.0)
		var ok := true
		for other: float in used.get(lane, []):
			if absf(other - start) < 14.0:
				ok = false
		var pos := p.point_at(start)
		for a: Vector3 in avoid:
			if a.distance_to(pos) < spawn_clearance:
				ok = false
		if not ok:
			continue
		used.get_or_add(lane, []).append(start)
		var car := CarScript.new() as TrafficCar
		car.name = "Car%d" % (cars.size() + 1)
		add_child(car)
		var kinds := [VehicleModel.Kind.COMPACT, VehicleModel.Kind.SEDAN, VehicleModel.Kind.SEDAN, VehicleModel.Kind.VAN,
				VehicleModel.Kind.TAXI, VehicleModel.Kind.PICKUP]
		car.setup(self, lane, start, kinds[rng.randi() % kinds.size()], rng.randi())
		cars.append(car)


func _physics_process(delta: float) -> void:
	_collect_obstacles()
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.4
		_update_lod()


func _collect_obstacles() -> void:
	obstacles.clear()
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Node3D and node.is_inside_tree():
			obstacles.append([(node as Node3D).global_position, 0.45, node, Kind.PLAYER])
	for node: Node in get_tree().get_nodes_in_group(&"civilian"):
		if node is Node3D:
			obstacles.append([(node as Node3D).global_position, 0.35, node, Kind.PERSON])
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if node is Node3D:
			obstacles.append([(node as Node3D).global_position, 0.4, node, Kind.ENEMY])
	for car: TrafficCar in cars:
		for point: Vector3 in car.body_points():
			obstacles.append([point, 1.0, car, Kind.CAR])


## Hindernisse im Umkreis (waagerecht).
func obstacles_near(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	for o: Array in obstacles:
		var p: Vector3 = o[0]
		if Vector2(p.x - pos.x, p.z - pos.z).length_squared() < r2:
			out.append(o)
	return out


## Für Fußgänger: Kommt in den nächsten Sekunden ein Auto über diesen Übergang (a → b)?
func crossing_clear(a: Vector3, b: Vector3, seconds := 3.5) -> bool:
	var mid := (a + b) * 0.5
	var along := (b - a)
	along.y = 0.0
	var half := along.length() * 0.5 + 1.5
	var dir := along.normalized()
	for car: TrafficCar in cars:
		var to := car.global_position - mid
		to.y = 0.0
		var dist := to.length()
		if dist > 45.0:
			continue
		# Schon auf dem Übergang?
		var side := absf(to.dot(dir))
		var across := absf(to.dot(Vector3(-dir.z, 0, dir.x)))
		if side < half and across < car.model.half_length + 2.0:
			return false
		var fwd := -car.global_basis.z
		var closing := -to.normalized().dot(fwd)
		if closing > 0.5 and car.speed > 0.5 and dist - car.model.half_length < car.speed * seconds + 4.0:
			return false
	return true


func try_enter(car: TrafficCar, turn_id: int, since: float) -> bool:
	var t := network.pieces[turn_id]
	var j := t.junction
	var active: Array = _active.get_or_add(j, [])
	var waiting: Dictionary = _waiting.get_or_add(j, {})
	waiting[car] = [turn_id, since]
	for i: int in range(active.size() - 1, -1, -1):
		if not is_instance_valid(active[i][1]):
			active.remove_at(i)
	for entry: Array in active:
		if entry[1] == car:
			return true
		if (entry[0] as int) in t.conflicts:
			return false
	# Wer länger wartet und sich mit uns kreuzt, fährt zuerst.
	for other: Variant in waiting.keys():
		if other == car or not is_instance_valid(other):
			if not is_instance_valid(other):
				waiting.erase(other)
			continue
		var w: Array = waiting[other]
		if (w[0] as int) in t.conflicts and (w[1] as float) < since - 0.3:
			return false
	# Platz auf der Spur danach.
	for other: TrafficCar in _lane_cars.get(t.out_lane, []):
		if other.s < other.model.half_length + car.model.half_length + 3.0:
			return false
	active.append([turn_id, car])
	waiting.erase(car)
	return true


func leave_junction(car: TrafficCar) -> void:
	for j: Variant in _active:
		var active: Array = _active[j]
		for i: int in range(active.size() - 1, -1, -1):
			if active[i][1] == car:
				active.remove_at(i)


func lane_enter(lane: int, car: TrafficCar) -> void:
	var list: Array = _lane_cars.get_or_add(lane, [])
	if car not in list:
		list.append(car)


func lane_leave(lane: int, car: TrafficCar) -> void:
	var list: Array = _lane_cars.get(lane, [])
	list.erase(car)


func play_hit(at: Vector3) -> void:
	_hit_audio.global_position = at
	_hit_audio.play()


func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	for car: TrafficCar in cars:
		var d := car.global_position.distance_to(eye)
		car.set_near(d < light_distance, d < sound_distance, d > far_distance)


# --- Multiplayer --------------------------------------------------------------------------

## Host → Clients (WorldSync): je Auto [Nummer, Art, Zufallszahl, Spur, Strecke, Versatz, Tempo, Bremse].
func net_get_state() -> Array:
	var out: Array = []
	for car: TrafficCar in cars:
		if is_instance_valid(car):
			out.append([int(String(car.name).trim_prefix("Car")), car.kind_id, car.seed_id] + car.net_entry())
	return out


## Client: fehlende Autos anlegen, alle nachziehen, beim Host verschwundene entfernen.
func net_apply_state(data: Array) -> void:
	if network == null:
		return
	var seen := {}
	for entry: Variant in data:
		if not entry is Array or (entry as Array).size() < 8:
			continue
		var e: Array = entry
		var car_name := "Car%d" % int(e[0])
		var lane := int(e[3])
		if lane < 0 or lane >= network.pieces.size():
			continue
		seen[car_name] = true
		var car := get_node_or_null(NodePath(car_name)) as TrafficCar
		if car == null:
			car = CarScript.new() as TrafficCar
			car.name = car_name
			car.net_puppet = true
			add_child(car)
			car.setup(self, lane, float(e[4]), int(e[1]) as VehicleModel.Kind, int(e[2]))
			cars.append(car)
		car.net_apply(lane, float(e[4]), float(e[5]), float(e[6]), bool(e[7]))
	for car: TrafficCar in cars.duplicate():
		if not seen.has(String(car.name)):
			cars.erase(car)
			lane_leave(car.piece_id, car)
			car.queue_free()
