@tool
class_name NeonDressing
extends Node3D
## Viele gleiche Modelle aus den Packs (Klimageräte, Balkone, Feuertreppen, Kabel, Schilder …)
## als MultiMesh: ein Draw-Call pro Fläche des Modells, egal wie viele Exemplare.
##
## Das Modell wird wie bei NeonProp normiert: Mitte unten auf den Ursprung, dann mit `model_scale`
## (Meter pro Modelleinheit) skaliert und um `yaw_fix` gedreht, damit seine Vorderseite nach +Z zeigt.
## `items` enthält pro Exemplar 7 Werte relativ zum Knoten (er steht in der Mitte seines Viertels): x, y, z, Drehung (Grad),
## Streckung x, y, z (1 = normal). Der Generator legt pro Modell und Stadtviertel einen Knoten an,
## damit Sichtweite und Frustum-Culling greifen.

const GEN_META := &"slum_generated"
const STRIDE := 7

@export_file("*.glb", "*.gltf", "*.fbx") var model := "":
	set(v):
		model = v
		_queue()
@export var model_scale := 1.0:
	set(v):
		model_scale = v
		_queue()
@export var yaw_fix := 0.0:
	set(v):
		yaw_fix = v
		_queue()
@export var items := PackedFloat32Array():
	set(v):
		items = v
		_queue()
## Box-Kollision je Exemplar (nur für Dinge am Boden, die im Weg stehen).
@export var collide := false:
	set(v):
		collide = v
		_queue()
## Kollisionsbox je Exemplar in Metern (lokal, nach Skalierung); null = ganze Hülle. Für Ampeln: nur der Mast.
@export var collider_size := Vector3.ZERO:
	set(v):
		collider_size = v
		_queue()
## Mitte der Kollisionsbox am Boden, lokal zum Exemplar.
@export var collider_offset := Vector3.ZERO:
	set(v):
		collider_offset = v
		_queue()
## Wie die Exemplare befestigt sind, für die Placement-Prüfung (test_neon_city):
## ground = steht mit der Unterkante auf einer Fläche, flat = flach auf dem Boden (Decal, Gully, Papier),
## wall = Rückseite (−Z) an einer Wand, hang = beide Enden der lokalen X-Achse an Wänden (Kabel),
## blade = eine Schmalseite (lokal ±X) an einer Wand (Ausleger-Schild).
@export_enum("ground", "flat", "wall", "hang", "blade") var mount := "ground"
## Färbt leuchtende Flächen des Modells (Neonschilder) in dieser Farbe; Alpha 0 = unverändert.
@export var emission_tint := Color(0, 0, 0, 0):
	set(v):
		emission_tint = v
		_queue()
@export var shadows := false:
	set(v):
		shadows = v
		_queue()
## Sichtweite in Metern ab der Mitte des Viertels (0 = immer).
@export var visible_range := 0.0:
	set(v):
		visible_range = v
		_queue()

## Pro Modell: [{mesh, xform}] relativ zum normierten Ursprung, dazu die Hülle (geteilt).
static var _cache := {}
var _queued := false


func _ready() -> void:
	_rebuild()


func _queue() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		_rebuild()).call_deferred()


static func _parts(path: String, tint := Color(0, 0, 0, 0)) -> Dictionary:
	var key := path + (tint.to_html() if tint.a > 0.0 else "")
	if _cache.has(key):
		return _cache[key]
	var out := {"parts": [], "box": AABB()}
	if path == "" or not ResourceLoader.exists(path):
		return out
	var scene := load(path) as PackedScene
	if scene == null:
		return out
	var inst: Node3D = scene.instantiate()
	var box := NeonProp._bounds(inst)
	var shift := Transform3D(Basis(), -Vector3(box.get_center().x, box.position.y, box.get_center().z))
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != inst and n != null:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		# Materialien fest in eine Kopie des Meshes schreiben (MultiMesh kennt keine Overrides).
		var mesh := mi.mesh.duplicate() as Mesh
		for s in mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat != null and tint.a > 0.0 and mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled 					and (mat as BaseMaterial3D).albedo_color.v > 0.5:
				# Helle Leuchtflächen (Schrift, Rahmen) in der Neonfarbe, dunkle Flächen bleiben.
				var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				m.albedo_color = tint.darkened(0.3)
				m.emission = tint
				m.emission_energy_multiplier = 2.6
				mat = m
			if mat != null:
				mesh.surface_set_material(s, mat)
		out["parts"].append({"mesh": mesh, "xform": shift * xf})
	out["box"] = Transform3D(Basis(), shift.origin) * box
	inst.free()
	_cache[key] = out
	return out


func _rebuild() -> void:
	for child in get_children():
		if child.has_meta(GEN_META):
			remove_child(child)
			child.queue_free()
	var count := items.size() / STRIDE
	if count == 0:
		return
	var data := _parts(model, emission_tint)
	if data["parts"].is_empty():
		return
	var base := Basis(Vector3.UP, deg_to_rad(yaw_fix)) * Basis.from_scale(Vector3.ONE * model_scale)
	var xforms: Array[Transform3D] = []
	xforms.resize(count)
	for i in count:
		var k := i * STRIDE
		var basis := Basis(Vector3.UP, deg_to_rad(items[k + 3])) \
				* Basis.from_scale(Vector3(items[k + 4], items[k + 5], items[k + 6])) * base
		xforms[i] = Transform3D(basis, Vector3(items[k], items[k + 1], items[k + 2]))
	for part: Dictionary in data["parts"]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part["mesh"]
		mm.instance_count = count
		var pxf: Transform3D = part["xform"]
		for i in count:
			mm.set_instance_transform(i, xforms[i] * pxf)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Parts"
		mmi.set_meta(GEN_META, true)
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if visible_range > 0.0:
			# Sichtweite gilt ab der Mitte des MultiMesh, die Hülle liegt um die Exemplare herum.
			mmi.visibility_range_end = visible_range
			mmi.visibility_range_end_margin = 10.0
		add_child(mmi)
	if collide:
		var body := StaticBody3D.new()
		body.name = "Body"
		body.set_meta(GEN_META, true)
		var hull: AABB = data["box"]
		for i in count:
			var shape := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			var k := i * STRIDE
			var size := hull.size * model_scale
			if absf(fmod(absf(yaw_fix), 180.0) - 90.0) < 1.0:
				size = Vector3(size.z, size.y, size.x)
			bs.size = (size * Vector3(items[k + 4], items[k + 5], items[k + 6])).abs()
			if collider_size != Vector3.ZERO:
				bs.size = collider_size
			shape.shape = bs
			var rot := Basis(Vector3.UP, deg_to_rad(items[k + 3]))
			shape.transform = Transform3D(rot, xforms[i].origin + rot * collider_offset + Vector3.UP * bs.size.y * 0.5)
			body.add_child(shape)
		add_child(body)
