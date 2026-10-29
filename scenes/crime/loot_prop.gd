class_name LootProp
extends StaticBody3D
## Stehlbares Objekt. sealed = true braucht break_open (Brechstange).

@export var item: ItemData
@export var count := 1
@export var sealed := false
@export var prompt_name := "Gegenstand"
var taken := false

var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.5, 0.4)
	shape.shape = box
	shape.position = Vector3(0.0, 0.25, 0.0)
	add_child(shape)
	_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	_mesh.mesh = mesh
	_mesh.position = shape.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.color if item != null else Color(0.7, 0.7, 0.75)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.4
	_mesh.material_override = mat
	add_child(_mesh)
	if item != null and ConsumableModel.has_model(item.model):
		var model := ConsumableModel.build(item.model, item.color, false)
		model.position = Vector3(0.0, 0.35, 0.0)
		model.scale = Vector3.ONE * ConsumableModel.pickup_scale(item.model)
		add_child(model)


func get_interact_text(_player: Player) -> String:
	if taken:
		return ""
	if sealed:
		return "%s aufbrechen" % prompt_name
	return "%s einstecken" % prompt_name


func interact(player: Player) -> void:
	if taken:
		return
	if sealed:
		player.item_user.show_message("Zu. Die Brechstange schafft das.", Color(1.0, 0.35, 0.3))
		return
	_give(player)


func break_open(player: Node) -> void:
	if taken or not sealed:
		if not sealed and not taken and player is Player:
			_give(player as Player)
		return
	sealed = false
	var body := player as Node3D
	var at := global_position if body == null else body.global_position
	NoiseManager.emit_noise(at, 12.0, player, StealthNoise.BURGLARY)
	if player is Player:
		(player as Player).item_user.show_message("%s offen" % prompt_name, Color(0.4, 1.0, 0.7))


func _give(player: Player) -> void:
	if item == null or player == null:
		return
	if item.is_currency:
		player.inventory.add_money(count)
	else:
		var left := player.inventory.add_item(item, count)
		if left > 0:
			player.item_user.show_message("Inventar voll", Color(1.0, 0.2, 0.35))
			return
	taken = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	player.item_user.show_message("%s eingesteckt" % prompt_name, Color(0.4, 1.0, 0.7))
