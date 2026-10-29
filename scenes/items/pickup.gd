class_name ItemPickup
extends Area3D
## Item in der Welt. Leuchtet und dreht sich. Der Spieler hebt es mit "interact" (E) auf,
## wenn er es anschaut (Layer interact, siehe ItemUser). Passt nicht alles ins Inventar,
## bleibt der Rest liegen.
##
## Fallengelassene Items fliegen per throw() ein Stück und landen auf dem Boden.
## Waffen (WeaponData mit view_scene) zeigen ihr Modell statt des Würfels, Verbrauchsitems
## mit Modell (ConsumableData.model) ihr ConsumableModel, vergrößert und leicht schräg.
##
## Multiplayer: net_id kennzeichnet das Pickup auf allen Rechnern (siehe WorldSync). Neue Pickups
## entstehen über WorldSync.spawn_pickup, Aufheben fragt den Host (take_pending bis zur Antwort).

const GROUP := &"item_pickup"

@export var item: ItemData
@export_range(1, 999) var count := 1
## Abstand des Mittelpunkts über dem Boden nach der Landung.
@export var hover_height := 0.5

var _velocity := Vector3.ZERO
var _falling := false
## Sekunden, bis das Item aufgehoben werden kann (nach dem Wegwerfen).
var _pickup_delay := 0.0
var _time := randf() * TAU
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Kennung im Multiplayer. Leer bei Pickups aus der Map-Szene, _ready setzt dann "s:<Pfad>".
var net_id := ""
## Online: Aufheben ist beim Host angefragt, die Antwort fehlt noch.
var take_pending := false
var _pending_since := 0

@onready var visual: Node3D = $Visual
@onready var mesh: MeshInstance3D = $Visual/Mesh
@onready var glow: OmniLight3D = $Visual/Glow
@onready var label: Label3D = $Visual/Label


func _ready() -> void:
	if item == null:
		push_warning("ItemPickup ohne Item: %s" % get_path())
		queue_free()
		return
	add_to_group(GROUP)
	if net_id.is_empty():
		net_id = WorldSync.static_pickup_id(self)
	var material := StandardMaterial3D.new()
	material.albedo_color = item.color
	material.emission_enabled = true
	material.emission = item.color
	material.emission_energy_multiplier = 2.5
	mesh.material_override = material
	glow.light_color = item.color
	_show_weapon_model()
	_show_consumable_model()
	_update_label()


## Wirft das Item mit einer Startgeschwindigkeit; es kann erst nach kurzer Zeit wieder aufgesammelt werden.
func throw(velocity: Vector3, pickup_delay := 1.0) -> void:
	_velocity = velocity
	_falling = true
	_pickup_delay = pickup_delay


func _process(delta: float) -> void:
	_time += delta
	visual.rotate_y(delta * 1.5)
	visual.position.y = sin(_time * 2.0) * 0.08


func _physics_process(delta: float) -> void:
	if _falling:
		_fall(delta)
	if _pickup_delay > 0.0:
		_pickup_delay -= delta


## Text für die Einblendung unter dem Fadenkreuz. Leer = gerade nicht benutzbar.
func get_interact_text(_player: Player) -> String:
	if _pickup_delay > 0.0 or is_queued_for_deletion():
		return ""
	return "Aufheben: " + label.text


## Wird von ItemUser bei "interact" aufgerufen.
func interact(player: Player) -> void:
	if _pickup_delay > 0.0 or is_queued_for_deletion():
		return
	if WorldSync.is_online():
		_request_take(player)
		return
	var left := player.inventory.add_item(item, count)
	if left == 0:
		queue_free()
	elif left != count:
		count = left
		_update_label()
	else:
		player.item_user.show_message("Inventar voll")


## Neue Menge (vom Host im Multiplayer).
func set_count(value: int) -> void:
	count = value
	_update_label()


## Online: so viel anfragen, wie ins Inventar passt. Der Host antwortet über WorldSync._grant.
func _request_take(player: Player) -> void:
	# Ohne Antwort nach 2 s darf man es erneut versuchen (Paket verloren, Host weg).
	if take_pending and Time.get_ticks_msec() - _pending_since < 2000:
		return
	var amount := mini(player.inventory.space_for(item), count)
	if amount <= 0:
		player.item_user.show_message("Inventar voll")
		return
	take_pending = true
	_pending_since = Time.get_ticks_msec()
	WorldSync.request_take(net_id, amount)


func _fall(delta: float) -> void:
	_velocity.y -= _gravity * delta
	var from := global_position
	var to := from + _velocity * delta
	var space := get_world_3d().direct_space_state
	# Wände und Decken (Layer world): dort stoppen statt hindurchzufliegen.
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if hit and hit.normal.y < 0.7:
		global_position = hit.position + hit.normal * 0.2
		_velocity = Vector3(0.0, minf(_velocity.y, 0.0), 0.0)
		return
	global_position = to
	if _velocity.y <= 0.0:
		var ground := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(to, to + Vector3.DOWN * hover_height, 1))
		if ground:
			global_position = ground.position + Vector3.UP * hover_height
			_falling = false


## Waffen zeigen ihr Handmodell (vergrößert) statt des Würfels.
func _show_weapon_model() -> void:
	var weapon := item as WeaponData
	if weapon == null or weapon.view_scene == null:
		return
	var model: Node3D = weapon.view_scene.instantiate()
	model.scale = Vector3.ONE * weapon.pickup_scale
	model.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	visual.add_child(model)
	# Mündungsfeuer gehört nur in die Hand.
	for flash: String in ["Muzzle/Flash", "Muzzle/FlashLight"]:
		var node := model.get_node_or_null(flash)
		if node != null:
			node.queue_free()
	mesh.visible = false


func _show_consumable_model() -> void:
	var consumable := item as ConsumableData
	if consumable == null or not ConsumableModel.has_model(consumable.model):
		return
	var model := ConsumableModel.build(consumable.model, consumable.color)
	model.name = "ConsumableModel"
	model.scale = Vector3.ONE * ConsumableModel.pickup_scale(consumable.model)
	model.rotation_degrees = Vector3(0.0, 0.0, 14.0)
	visual.add_child(model)
	mesh.visible = false


func _update_label() -> void:
	if item.is_currency:
		label.text = "%d ¢" % count
	else:
		label.text = item.display_name if count == 1 else "%s ×%d" % [item.display_name, count]
	label.modulate = item.color
