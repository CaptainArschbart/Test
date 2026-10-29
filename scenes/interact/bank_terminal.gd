extends StaticBody3D
## Bankautomat in der Welt. "interact" (E) öffnet das Bankfenster (bank_ui.gd): Bargeld
## einzahlen, abheben und an andere Spieler überweisen.
##
## Liegt wie VendingMachine auf Layer world. Gehäuse, Bildschirm, Tastenfeld und Schild
## entstehen im Code. Der Ursprung ist die Mitte der Grundfläche, die Front zeigt nach +Z.
## Kein class_name: das Fenster kommt per preload (siehe vital_sounds.gd).

const BankUIScript := preload("res://scenes/interact/bank_ui.gd")
const SCREEN_COLOR := Color(0.0, 0.95, 1.0)
const ACCENT_COLOR := Color(1.0, 0.1, 0.75)

@export var size := Vector3(0.9, 2.1, 0.6)
@export var bank_name := "NC-BANK"


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3.UP * size.y * 0.5
	add_child(shape)
	_build_visual()


func get_interact_text(_player: Player) -> String:
	return "%s-Automat benutzen" % bank_name


func interact(player: Player) -> void:
	if player == null or player.inventory == null or not player.controls_local_body():
		return
	var ui := BankUIScript.for_player(player)
	ui.call("open")


func _build_visual() -> void:
	var front_z := size.z * 0.5
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.1, 0.1, 0.14)
	body_material.metallic = 0.75
	body_material.roughness = 0.3
	_add_box(Vector3(size.x, size.y, size.z), Vector3.UP * size.y * 0.5, body_material)
	# Vorbau mit schrägem Tastenfeld.
	_add_box(Vector3(size.x * 0.9, 0.08, 0.28), Vector3(0.0, size.y * 0.47, front_z + 0.1),
			body_material, Vector3(deg_to_rad(18.0), 0.0, 0.0))
	var keys_material := _glow_material(Color(0.35, 0.4, 0.5), 0.4)
	for row in 3:
		for col in 3:
			var key_position := Vector3((col - 1) * 0.09, size.y * 0.47 + 0.045 - row * 0.012,
					front_z + 0.04 + row * 0.07)
			_add_box(Vector3(0.06, 0.02, 0.05), key_position, keys_material,
					Vector3(deg_to_rad(18.0), 0.0, 0.0))
	# Bildschirm.
	var screen := MeshInstance3D.new()
	var screen_mesh := QuadMesh.new()
	screen_mesh.size = Vector2(size.x * 0.7, size.y * 0.24)
	screen_mesh.material = _glow_material(SCREEN_COLOR, 1.4)
	screen.mesh = screen_mesh
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.position = Vector3(0.0, size.y * 0.66, front_z + 0.01)
	add_child(screen)
	var screen_text := Label3D.new()
	screen_text.text = "%s\nKARTE EINLEGEN" % bank_name
	screen_text.font_size = 24
	screen_text.pixel_size = 0.0035
	screen_text.modulate = Color(0.02, 0.05, 0.12)
	screen_text.position = Vector3(0.0, size.y * 0.66, front_z + 0.02)
	add_child(screen_text)
	# Kartenschlitz und Geldausgabe.
	var slot_material := _glow_material(ACCENT_COLOR, 2.0)
	_add_box(Vector3(0.16, 0.015, 0.02), Vector3(size.x * 0.28, size.y * 0.55, front_z + 0.01), slot_material)
	_add_box(Vector3(size.x * 0.5, 0.03, 0.02), Vector3(0.0, size.y * 0.38, front_z + 0.01),
			_glow_material(Color(0.3, 1.0, 0.55), 1.2))
	# Leuchtstreifen an den Kanten.
	for side: float in [-1.0, 1.0]:
		_add_box(Vector3(0.025, size.y * 0.9, 0.025),
				Vector3(side * (size.x * 0.5 - 0.01), size.y * 0.5, front_z), slot_material)
	var light := OmniLight3D.new()
	light.light_color = SCREEN_COLOR
	light.light_energy = 1.0
	light.omni_range = 3.0
	light.position = Vector3(0.0, size.y * 0.66, front_z + 0.5)
	add_child(light)
	var sign_label := Label3D.new()
	sign_label.text = "%s  ¢" % bank_name
	sign_label.font_size = 32
	sign_label.pixel_size = 0.004
	sign_label.outline_size = 10
	sign_label.modulate = SCREEN_COLOR
	sign_label.position = Vector3(0.0, size.y + 0.15, front_z)
	add_child(sign_label)


func _add_box(box_size: Vector3, at: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.rotation = rot
	add_child(mesh_instance)
	return mesh_instance


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
