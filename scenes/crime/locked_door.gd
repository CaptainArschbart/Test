class_name LockedDoor
extends StaticBody3D
## Verschlossene Tür. Passender Schlüssel (Item-id = key_id) öffnet leise.
## break_open (Brechstange) öffnet laut und legt eine Fahndung.

signal opened(forced: bool)

@export var key_id := "apt_key"
@export var locked := true
var forced_open := false

var _panel: MeshInstance3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.2, 0.12)
	shape.shape = box
	shape.position = Vector3(0.0, 1.1, 0.0)
	add_child(shape)
	_panel = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.05, 2.15, 0.08)
	_panel.mesh = mesh
	_panel.position = Vector3(0.0, 1.1, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.16, 0.12)
	mat.roughness = 0.8
	_panel.material_override = mat
	add_child(_panel)


func is_open() -> bool:
	return not locked


func get_interact_text(player: Player) -> String:
	if not locked:
		return ""
	if _player_has_key(player):
		return "Aufschließen (%s)" % key_id
	return "Verschlossen"


func interact(player: Player) -> void:
	if not locked:
		return
	if not _player_has_key(player):
		player.item_user.show_message("Verschlossen. Brechstange oder Schlüssel.", Color(1.0, 0.35, 0.3))
		return
	_unlock(false)


func break_open(player: Node) -> void:
	if not locked:
		return
	forced_open = true
	_unlock(true)
	var body := player as Node3D
	var at := global_position if body == null else body.global_position
	NoiseManager.emit_noise(at, 18.0, player, StealthNoise.BURGLARY)
	if not WorldSync.is_client():
		WantedManager.report(&"burglary", at, get_instance_id())


func _unlock(forced: bool) -> void:
	locked = false
	collision_layer = 0
	collision_mask = 0
	if _panel != null:
		_panel.rotation.y = deg_to_rad(80.0)
		_panel.position = Vector3(0.45, 1.1, 0.35)
	opened.emit(forced)


func _player_has_key(player: Player) -> bool:
	if player == null or player.inventory == null:
		return false
	var inventory := player.inventory
	for i in inventory.get_size():
		var item := inventory.get_item(i)
		if item != null and item.id == key_id and inventory.get_count(i) > 0:
			return true
	return false
