extends Node3D
## Wurzel einer Waffenszene mit importiertem Modell (assets/items/weapons/).
##
## Die Farben aus der FBX sind für den Neon-Look zu hell: Jedes Mesh unter "Model" bekommt eine
## abgedunkelte, leicht metallische Kopie seines Materials (die Importe selbst bleiben unverändert).
## Wie bei den alten Box-Modellen werfen die Meshes keine Schatten in die Kamera; Spielerkörper
## und Laden setzen ihre Schattenwerte danach selbst.

## Faktor auf die Grundfarbe der Modell-Materialien (1 = wie importiert).
@export_range(0.0, 1.0) var darken := 0.45
@export_range(0.0, 1.0) var metallic := 0.45
@export_range(0.0, 1.0) var roughness := 0.45


func _ready() -> void:
	var model := get_node_or_null("Model")
	if model != null:
		_tint(model)
	_no_shadows(self)


func _tint(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var base := mi.get_active_material(i) as BaseMaterial3D
			if base == null:
				continue
			var mat := base.duplicate() as BaseMaterial3D
			mat.albedo_color = Color(base.albedo_color * darken, base.albedo_color.a)
			mat.metallic = metallic
			mat.roughness = roughness
			mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_tint(child)


func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_no_shadows(child)
