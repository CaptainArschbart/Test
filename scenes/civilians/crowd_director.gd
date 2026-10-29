class_name CrowdDirector
extends Node3D
## Fußgänger einer Map: Wegenetz (Knoten auf Gehwegen, Zebrastreifen, Plätzen; aus
## tools/gen_slum_map.py), Erzeugen der Civilians, Detailstufen und Nachschub.
##
## Wegenetz: `nodes` (Positionen), `edges` (Paare), `edge_crossing` (1 = Zebrastreifen über eine
## Fahrbahn), `node_wait` (> 0 = Ort zum Stehenbleiben, z. B. Marktstand, in Sekunden).
## LOD: die nächsten `max_full` innerhalb `full_distance` jedes Physik-Frame, bis `sleep_distance`
## 5× pro Sekunde, dahinter stehen sie (außer auf der Flucht).
## Mitziehen: Wer weiter als `relocate_distance` weg ist (und nicht im Bild), wird nach und nach an einen Knoten 30–85 m von der
## Kamera verlegt, möglichst außer Sicht. So ist um den Spieler herum immer etwas los, ohne dass
## Hunderte Figuren gleichzeitig existieren.
## Nachschub: Tote verschwinden nach `corpse_time` (wenn keiner hinschaut), neue Fußgänger kommen
## an Knoten weit weg von der Kamera dazu, bis wieder `count` unterwegs sind.
## Multiplayer: Nur der Host rechnet die Fußgänger. LOD, Verlegen und Nachschub achten auf alle Spieler,
## nicht nur auf die eigene Kamera. Über WorldSync (Gruppe NPC_GROUP) gehen alle 0,1 s Position,
## Blick, Zustand und Tempo an die Clients, die dieselben Figuren als Kopie zeigen (Civilian.net_puppet).
## Treffer beim Client gehen an den Host.

const GROUP := &"crowd_director"
const CivilianScript := preload("res://scenes/civilians/civilian.gd")

@export_group("Wegenetz")
@export var nodes := PackedVector3Array()
@export var node_wait := PackedFloat32Array()
@export var edges := PackedInt32Array()
@export var edge_crossing := PackedInt32Array()

@export_group("Fußgänger")
@export var count := 40
@export var seed_value := 7
## Abstand zum Spieler beim ersten Erzeugen (nicht direkt neben ihm auftauchen).
@export var spawn_clearance := 6.0
@export var corpse_time := 90.0
## Wie viele schlafende Fußgänger pro Runde (alle 2 s) näher an die Kamera verlegt werden.
@export var relocate_per_step := 4
@export var relocate_distance := 80.0

@export_group("Leistung")
@export var max_full := 18
@export var full_distance := 55.0
@export var sleep_distance := 120.0

var civilians: Array[Civilian] = []
var traffic: TrafficDirector

var _adjacent: Array = []  # je Knoten ein Array der Nachbarn
var _crossing := {}
var _rng := RandomNumberGenerator.new()
var _lod_timer := 0.0
var _refill_timer := 3.0
var _corpses := {}  # Civilian -> Sekunden
var _next_id := 1
## Multiplayer: Werte je Fußgänger im Paket (Nummer + Civilian.net_floats). Die Zufallszahlen fürs
## Aussehen gehen reihum für jeden NET_SEED_EVERY-ten Fußgänger mit.
const NET_STRIDE := 7
const NET_SEED_EVERY := 8
var _net_ticks := 0
## Client: Nummer → Zufallszahl des Hosts.
var _net_seeds := {}


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = seed_value
	for i: int in nodes.size():
		_adjacent.append([])
	for i: int in range(0, edges.size() - 1, 2):
		var a := edges[i]
		var b := edges[i + 1]
		_adjacent[a].append(b)
		_adjacent[b].append(a)
		if i / 2 < edge_crossing.size() and edge_crossing[i / 2] == 1:
			_crossing[_key(a, b)] = true
	add_to_group(WorldSync.NPC_GROUP)
	# Client: Die Fußgänger kommen vom Host (net_apply_state).
	if not WorldSync.is_client():
		_spawn_all.call_deferred()


static func find(tree: SceneTree) -> CrowdDirector:
	return tree.get_first_node_in_group(GROUP) as CrowdDirector if tree != null else null


func neighbors(node: int) -> PackedInt32Array:
	return PackedInt32Array(_adjacent[node]) if node >= 0 and node < _adjacent.size() else PackedInt32Array()


func is_crossing(a: int, b: int) -> bool:
	return _crossing.has(_key(a, b))


func nearest_node(pos: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i: int in nodes.size():
		var d := Vector2(nodes[i].x - pos.x, nodes[i].z - pos.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


## Alle Fußgänger im Umkreis geraten in Panik.
func panic_at(pos: Vector3, radius: float) -> void:
	for civ: Civilian in civilians:
		if is_instance_valid(civ) and not civ.is_dead() and civ.global_position.distance_to(pos) < radius:
			civ.panic(pos)


func on_civilian_died(civ: Civilian) -> void:
	_corpses[civ] = 0.0
	panic_at(civ.global_position, 14.0)


func _key(a: int, b: int) -> int:
	return mini(a, b) * 100000 + maxi(a, b)


func _spawn_all() -> void:
	traffic = TrafficDirector.find(get_tree())
	var avoid := _player_positions()
	var tries := 0
	while civilians.size() < count and tries < count * 20 and nodes.size() > 1:
		tries += 1
		var a := _rng.randi() % nodes.size()
		var next := neighbors(a)
		if next.is_empty():
			continue
		var b := next[_rng.randi() % next.size()]
		if is_crossing(a, b):
			continue
		var pos := nodes[a].lerp(nodes[b], _rng.randf())
		var ok := true
		for p: Vector3 in avoid:
			if p.distance_to(pos) < spawn_clearance:
				ok = false
		for civ: Civilian in civilians:
			if civ.global_position.distance_to(pos) < 1.2:
				ok = false
		if ok:
			_spawn(pos, b)


func _spawn(pos: Vector3, toward: int) -> Civilian:
	var civ := CivilianScript.new() as Civilian
	civ.name = "Civilian%d" % _next_id
	_next_id += 1
	civ.setup(self, toward, _rng.randi())
	civ.position = pos + Vector3.UP * 0.05
	add_child(civ)
	civilians.append(civ)
	return civ


func _player_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			out.append((node as Node3D).global_position)
	return out


func _physics_process(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.3
		_update_lod()
	if WorldSync.is_client():
		return
	_refill_timer -= delta
	if _refill_timer <= 0.0:
		_refill_timer = 2.0
		_cleanup(2.0)


func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var list: Array = []
	for civ: Civilian in civilians:
		if is_instance_valid(civ) and not civ.is_dead():
			var d := minf(civ.global_position.distance_to(eye), _nearest_player(civ.global_position))
			list.append([d * d, civ])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var full := 0
	for entry: Array in list:
		var civ: Civilian = entry[1]
		var dist := sqrt(entry[0])
		if dist < full_distance and full < max_full:
			civ.set_lod(Civilian.Lod.FULL)
			full += 1
		elif dist < sleep_distance:
			civ.set_lod(Civilian.Lod.LOW)
		else:
			civ.set_lod(Civilian.Lod.SLEEP)


func _relocate_far(eye: Vector3, cam: Camera3D) -> void:
	var moved := 0
	for civ: Civilian in civilians:
		if moved >= relocate_per_step:
			return
		if not is_instance_valid(civ) or civ.is_dead() or civ.is_panicking():
			continue
		var to := civ.global_position - eye
		# Multiplayer: nicht vor der Nase eines anderen Spielers wegnehmen.
		if _nearest_player(civ.global_position) < relocate_distance:
			continue
		if to.length() < relocate_distance or (cam != null and (-cam.global_basis.z).dot(to.normalized()) > 0.3 and to.length() < sleep_distance):
			continue
		var node := _node_out_of_sight(eye, cam)
		if node < 0:
			return
		var next := neighbors(node)
		if next.is_empty():
			continue
		civ.relocate(nodes[node], next[_rng.randi() % next.size()])
		moved += 1


## Zufälliger Knoten 25–65 m von der Kamera, möglichst nicht im Bild. -1 = keiner gefunden.
func _node_out_of_sight(eye: Vector3, cam: Camera3D) -> int:
	var fallback := -1
	for i: int in 16:
		var n := _rng.randi() % nodes.size()
		var d := nodes[n].distance_to(eye)
		if d < 25.0 or d > 65.0 or _nearest_player(nodes[n]) < 25.0:
			continue
		if cam == null or (-cam.global_basis.z).dot((nodes[n] - eye).normalized()) < 0.2:
			return n
		fallback = n
	return fallback


## Tote wegräumen (wenn die Kamera weit weg ist) und neue Fußgänger weit weg dazusetzen.
func _cleanup(step: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	for civ: Variant in _corpses.keys():
		if not is_instance_valid(civ):
			_corpses.erase(civ)
			continue
		_corpses[civ] += step
		if _corpses[civ] > corpse_time and (civ as Civilian).global_position.distance_to(eye) > 40.0 \
				and _nearest_player((civ as Civilian).global_position) > 40.0:
			_corpses.erase(civ)
			civilians.erase(civ)
			(civ as Civilian).queue_free()
	_relocate_far(eye, cam)
	var alive := 0
	for civ: Civilian in civilians:
		if is_instance_valid(civ) and not civ.is_dead():
			alive += 1
	if alive >= count or civilians.size() >= count + 8:
		return
	for i: int in 10:
		var a := _rng.randi() % nodes.size()
		if nodes[a].distance_to(eye) < 60.0 or _nearest_player(nodes[a]) < 60.0:
			continue
		var next := neighbors(a)
		if next.is_empty():
			continue
		_spawn(nodes[a], next[_rng.randi() % next.size()])
		return


## Abstand zum nächsten Spieler (im Multiplayer auch die der Mitspieler). INF ohne Spieler.
func _nearest_player(pos: Vector3) -> float:
	var best := INF
	for p: Vector3 in _player_positions():
		best = minf(best, p.distance_to(pos))
	return best


# --- Multiplayer --------------------------------------------------------------------------

## Host → Clients (WorldSync), kompakt, damit es in ein Netzpaket passt:
## [Floats je Fußgänger: Nummer, x, y, z, Blick, Zustand, Tempo; Zufallszahlen als [Nummer, Zahl, …]].
## Die Zufallszahlen (fürs Aussehen) gehen reihum mit, je Paket nur für jeden NET_SEED_EVERY-ten
## Fußgänger. Der Client braucht sie nur einmal, nach 0,8 s kennt er alle.
func net_get_state() -> Array:
	var floats := PackedFloat32Array()
	var seeds := PackedInt32Array()
	_net_ticks += 1
	var slot := _net_ticks % NET_SEED_EVERY
	var index := -1
	for civ: Civilian in civilians:
		index += 1
		if not is_instance_valid(civ) or not civ.is_inside_tree():
			continue
		var id := int(String(civ.name).trim_prefix("Civilian"))
		floats.append(id)
		floats.append_array(civ.net_floats())
		if index % NET_SEED_EVERY == slot:
			seeds.append(id)
			seeds.append(civ.net_seed)
	return [floats, seeds]


## Client: fehlende Fußgänger anlegen (gleiches Aussehen über die Zufallszahl), alle nachziehen,
## beim Host verschwundene entfernen. Ohne bekannte Zufallszahl wartet er auf das nächste Paket damit.
func net_apply_state(data: Array) -> void:
	if data.size() < 2:
		return
	var floats: PackedFloat32Array = data[0]
	var seeds: PackedInt32Array = data[1]
	for i in range(0, seeds.size() - 1, 2):
		# Zurück auf die vorzeichenlose Zahl, die der Host benutzt hat.
		_net_seeds[seeds[i]] = seeds[i + 1] & 0xFFFFFFFF
	var seen := {}
	for i in range(0, floats.size() - NET_STRIDE + 1, NET_STRIDE):
		var id := int(floats[i])
		var civ_name := "Civilian%d" % id
		seen[civ_name] = true
		var pos := Vector3(floats[i + 1], floats[i + 2], floats[i + 3])
		var civ := get_node_or_null(NodePath(civ_name)) as Civilian
		if civ == null:
			if not _net_seeds.has(id):
				continue
			civ = CivilianScript.new() as Civilian
			civ.name = civ_name
			civ.net_puppet = true
			civ.setup(self, -1, _net_seeds[id])
			civ.position = pos
			add_child(civ)
			civilians.append(civ)
		civ.net_apply(pos, floats[i + 4], int(floats[i + 5]), floats[i + 6])
	for civ: Civilian in civilians.duplicate():
		if not is_instance_valid(civ):
			civilians.erase(civ)
		elif not seen.has(String(civ.name)):
			civilians.erase(civ)
			civ.queue_free()
