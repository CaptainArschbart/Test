class_name GroundClamp
extends SkeletonModifier3D
## Hält die Haut einer Figur über dem Boden, solange sie aus dem Ragdoll aufsteht (Schedule 1, P5-2).
##
## Beim Übergang Ragdoll -> Aufsteh-Animation werden die Knochen einzeln überblendet; Arme und Beine
## schwenken dabei auf kürzestem Weg und können durch den Boden ziehen. Dieser Modifier läuft nach dem
## Ragdoll, misst die tiefste Stelle der Haut und schiebt das ganze Skelett so weit hoch, dass sie auf
## floor_y liegt. Gemessen wird nicht jeder Hautpunkt, sondern je Knochen die äußersten Punkte in
## DIRECTIONS (einmal je Mesh berechnet und geteilt): ein paar hundert statt einiger Tausend.
##
## hold(floor_y) schaltet ihn ein, release() aus. Ohne Halten kostet er nichts.

## Richtungen im Knochenraum, in denen je Knochen der äußerste Hautpunkt gemerkt wird.
const DIRECTIONS := [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
	Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, 1), Vector3(1, -1, -1),
	Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1),
]
## Abstand zum Boden, den die Haut mindestens hält (m).
const MARGIN := 0.01

## Je Mesh (Resource-ID): Liste der Messpunkte [Punkt, Bind-Indizes, Gewichte].
static var _probes := {}

var floor_y := 0.0
## Zuletzt angehoben (m), für Tests.
var lift := 0.0

## [MeshInstance3D, Messpunkte] der Figur.
var _meshes: Array = []


## Hängt den Modifier als letzten ans Skelett und sucht die Haut-Meshes darunter bzw. daneben.
static func attach(skeleton: Skeleton3D) -> GroundClamp:
	var clamp := GroundClamp.new()
	clamp.name = "GroundClamp"
	clamp.active = false
	skeleton.add_child(clamp)
	var owner_node := skeleton.get_parent() if skeleton.get_parent() != null else skeleton
	for mi: MeshInstance3D in owner_node.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and mi.mesh != null and mi.get_node_or_null(mi.skeleton) == skeleton:
			clamp._meshes.append([mi, _probe_points(mi)])
	return clamp


func hold(floor_height: float) -> void:
	floor_y = floor_height
	lift = 0.0
	var skeleton := get_skeleton()
	if skeleton != null and get_index() != skeleton.get_child_count() - 1:
		skeleton.move_child(self, -1)
	active = true


func release() -> void:
	active = false
	lift = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _meshes.is_empty():
		return
	var low := INF
	var to_world := skeleton.global_transform
	for entry: Array in _meshes:
		var mi: MeshInstance3D = entry[0]
		if not is_instance_valid(mi):
			continue
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		mats.resize(skin.get_bind_count())
		for i in skin.get_bind_count():
			var name := skin.get_bind_name(i)
			var bone := skeleton.find_bone(name) if name != "" else skin.get_bind_bone(i)
			mats[i] = to_world * skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(i)
		for probe: Array in entry[1]:
			var p: Vector3 = probe[0]
			var binds: PackedInt32Array = probe[1]
			var weights: PackedFloat32Array = probe[2]
			var y := 0.0
			for j in binds.size():
				y += (mats[binds[j]] * p).y * weights[j]
			low = minf(low, y)
	lift = maxf(floor_y + MARGIN - low, 0.0) if low < INF else 0.0
	if lift <= 0.0:
		return
	# Ganzes Skelett anheben: alle Wurzelknochen um `lift` (Welt) nach oben, im Skelettraum.
	var up := skeleton.global_basis.inverse() * (Vector3.UP * lift)
	for bone in skeleton.get_parentless_bones():
		skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + up)


## Äußerste Hautpunkte je Knochen (im Knochenraum der Bindungspose) in DIRECTIONS.
static func _probe_points(mi: MeshInstance3D) -> Array:
	var key := mi.mesh.get_instance_id()
	if _probes.has(key):
		return _probes[key]
	var skin := mi.skin
	var best := {}
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		if verts.is_empty() or bones.is_empty():
			continue
		var per := bones.size() / verts.size()
		for v in verts.size():
			var main := -1
			var top := 0.0
			var binds := PackedInt32Array()
			var ws := PackedFloat32Array()
			for j in per:
				var w := weights[v * per + j]
				if w > 0.0:
					binds.append(bones[v * per + j])
					ws.append(w)
					if w > top:
						top = w
						main = bones[v * per + j]
			if main < 0:
				continue
			var local := skin.get_bind_pose(main) * verts[v]
			for d in DIRECTIONS.size():
				var score := local.dot(DIRECTIONS[d])
				var k := main * DIRECTIONS.size() + d
				if not best.has(k) or score > best[k][0]:
					best[k] = [score, verts[v], binds, ws]
	var out := []
	for k: int in best:
		out.append([best[k][1], best[k][2], best[k][3]])
	_probes[key] = out
	return out
