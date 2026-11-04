@tool
class_name NeonClaimsDebug
extends Node3D
## Zeigt im Editor die Flächen, die der Generator reserviert hat (Schedule 1, P0-6): rot = fest
## (Haus, Prop, Detail mit Kollision), blau = Fahrbahn, grün = freizuhaltender Weg (Gasse,
## Ladeneingang), gelb = erhöhte oder gesperrte Platte. Im Spiel zeichnet der Knoten nichts.
## Einschalten: Knoten „ClaimsDebug“ in neon_city.tscn auswählen, `show_in_editor` anhaken.

const COLORS := [Color(1.0, 0.15, 0.1, 0.35), Color(0.15, 0.35, 1.0, 0.25), Color(0.1, 1.0, 0.3, 0.4),
	Color(1.0, 0.85, 0.1, 0.35)]
const LIFT := [0.32, 0.05, 0.34, 0.36]

## Pro Fläche 5 Werte: x0, x1, z0, z1, Art (0 fest, 1 Fahrbahn, 2 frei halten, 3 erhöht).
@export var rects := PackedFloat32Array()
@export var show_in_editor := false:
	set(v):
		show_in_editor = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	if not Engine.is_editor_hint() or not show_in_editor or not is_inside_tree():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(0, rects.size(), 5):
		var kind := int(rects[k + 4])
		var y: float = LIFT[kind]
		st.set_color(COLORS[kind])
		var a := Vector3(rects[k], y, rects[k + 2])
		var b := Vector3(rects[k + 1], y, rects[k + 2])
		var c := Vector3(rects[k + 1], y, rects[k + 3])
		var d := Vector3(rects[k], y, rects[k + 3])
		for v: Vector3 in [a, b, c, a, c, d]:
			st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
