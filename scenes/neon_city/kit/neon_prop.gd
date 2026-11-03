@tool
class_name NeonProp
extends Node3D
## Importiertes Low-Poly-Modell (assets/props/…) in fester Größe, mit Box-Kollision.
##
## Die Packs haben sehr unterschiedliche Maßstäbe (0,2 bis 600 Einheiten). Darum wird das Modell
## zur Laufzeit so skaliert, dass seine längste waagerechte Seite `fit_length` Meter misst (oder,
## wenn fit_length 0 ist, seine Höhe `fit_height`). Es steht danach mittig auf dem Ursprung, die
## lange Seite liegt auf der lokalen Z-Achse (`align_long_z`).

const GEN_META := &"slum_generated"

@export_file("*.glb", "*.gltf", "*.fbx") var model := "":
	set(v):
		model = v
		_queue()
@export var fit_length := 0.0:
	set(v):
		fit_length = v
		_queue()
@export var fit_height := 1.0:
	set(v):
		fit_height = v
		_queue()
@export var align_long_z := true:
	set(v):
		align_long_z = v
		_queue()
@export var collide := true:
	set(v):
		collide = v
		_queue()
## Grundfläche der Kollision in Metern (0 = ganze Hülle). Bäume: nur der Stamm, nicht die Krone.
@export var collider_footprint := Vector2.ZERO:
	set(v):
		collider_footprint = v
		_queue()
## Sichtweite in Metern (0 = immer).
@export var visible_range := 90.0:
	set(v):
		visible_range = v
		_queue()

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


func _rebuild() -> void:
	for child in get_children():
		if child.has_meta(GEN_META):
			remove_child(child)
			child.queue_free()
	if model == "" or not ResourceLoader.exists(model):
		return
	var scene := load(model) as PackedScene
	if scene == null:
		return
	var inst: Node3D = scene.instantiate()
	var holder := Node3D.new()
	holder.name = "Model"
	holder.set_meta(GEN_META, true)
	add_child(holder)
	holder.add_child(inst)
	var box := _bounds(inst)
	if box.size == Vector3.ZERO:
		return
	if align_long_z and box.size.x > box.size.z:
		holder.rotation.y = PI * 0.5
	var long := maxf(box.size.x, box.size.z)
	var s := fit_length / long if fit_length > 0.0 else fit_height / maxf(box.size.y, 0.001)
	holder.scale = Vector3.ONE * s
	# Mitte unten auf den Ursprung.
	var c := box.get_center()
	inst.position = -Vector3(c.x, box.position.y, c.z)
	for mi: Node in holder.find_children("*", "GeometryInstance3D", true, false):
		if visible_range > 0.0:
			(mi as GeometryInstance3D).visibility_range_end = visible_range
			(mi as GeometryInstance3D).visibility_range_end_margin = 6.0
	if collide:
		var body := StaticBody3D.new()
		body.name = "Body"
		body.set_meta(GEN_META, true)
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var size := box.size * s
		if holder.rotation.y != 0.0:
			size = Vector3(size.z, size.y, size.x)
		if collider_footprint != Vector2.ZERO:
			size = Vector3(collider_footprint.x, size.y, collider_footprint.y)
		bs.size = size
		shape.shape = bs
		shape.position = Vector3(0, size.y * 0.5, 0)
		body.add_child(shape)
		add_child(body)


static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		# Transform relativ zum Modell, ohne die Lage des Props in der Welt.
		var xf := Transform3D()
		var n: Node = m
		while n != node and n != null:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
