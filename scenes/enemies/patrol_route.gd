@tool
class_name PatrolRoute
extends Node3D
## Streifenweg für Gegner: die Marker3D-Kinder sind die Wegpunkte, in Reihenfolge.
##
## Am Wegpunkt wartet der Gegner `wait_time` Sekunden (Metadaten "wait" am Marker überschreiben das)
## und schaut dabei in die Richtung des Markers (-Z), wenn der Marker die Metadaten "look" = true hat.
## Ein einzelner Marker = Wachposten. Im Editor zeigt eine Linie den Weg.

## true: nach dem letzten Punkt zurück zum ersten. false: hin und zurück.
@export var loop := true
@export var wait_time := 2.5
@export var line_color := Color(1.0, 0.3, 0.6)

var _preview: MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		_draw_preview()
		child_order_changed.connect(_draw_preview)


func point_count() -> int:
	return get_points().size()


func get_points() -> Array[Marker3D]:
	var out: Array[Marker3D] = []
	for child: Node in get_children():
		if child is Marker3D:
			out.append(child)
	return out


## Index des nächsten Punkts. `direction` (1/-1) wird beim Hin-und-Zurück umgedreht.
func next_index(index: int, direction: int) -> Vector2i:
	var count := point_count()
	if count <= 1:
		return Vector2i(0, 1)
	if loop:
		return Vector2i((index + 1) % count, 1)
	var next := index + direction
	if next < 0 or next >= count:
		direction = -direction
		next = index + direction
	return Vector2i(next, direction)


## Nächster Wegpunkt zu einer Position (nach Kampf oder Suche dort weitermachen).
func closest_index(position: Vector3) -> int:
	var best := 0
	var best_dist := INF
	var points := get_points()
	for i: int in points.size():
		var d := points[i].global_position.distance_squared_to(position)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func wait_at(index: int) -> float:
	var points := get_points()
	if index < 0 or index >= points.size():
		return wait_time
	return float(points[index].get_meta(&"wait", wait_time))


func looks_at(index: int) -> bool:
	var points := get_points()
	return index >= 0 and index < points.size() and bool(points[index].get_meta(&"look", false))


func _draw_preview() -> void:
	if _preview == null:
		_preview = MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = line_color
		mat.no_depth_test = true
		_preview.material_override = mat
		add_child(_preview, false, Node.INTERNAL_MODE_BACK)
	var points := get_points()
	var mesh := ImmediateMesh.new()
	if points.size() >= 2:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p: Marker3D in points:
			mesh.surface_add_vertex(p.position + Vector3.UP * 0.1)
		if loop:
			mesh.surface_add_vertex(points[0].position + Vector3.UP * 0.1)
		mesh.surface_end()
	_preview.mesh = mesh
